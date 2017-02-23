//
//  VideoPlayer.m
//
//  Created by kaibin on 16/11/15.
//  Copyright © 2016年 yy. All rights reserved.
//

#import "VideoPlayer.h"
#import "VideoProgressBarView.h"
#import "ResourceLoader.h"
#import "AppDelegate.h"
#import "ResourceLoader.h"
#import "NSURL+Category.h"
#import "RequestTaskManager.h"

NSString *const kPlayerProgressChangedNotification = @"PlayerProgressChangedNotification";
NSString *const kPlayerLoadProgressChangedNotification = @"PlayerLoadProgressChangedNotification";
NSString *const kPlayerDidPlayeToEnd = @"PlayerDidPlayeToEnd";
NSString *const kPlayerWillStartToPlay = @"PlayerWillStartToPlay";
NSString *const kPlayerStatusFailed = @"kPlayerStatusFailed";

@interface VideoPlayer () <AVAssetResourceLoaderDelegate, ResourceLoaderDelegate>

@property (nonatomic, strong) ResourceLoader *resourceLoader;
@property (nonatomic, strong) AVPlayer       *player;
@property (nonatomic, strong) AVPlayerItem   *currentPlayerItem;
@property (nonatomic, strong) AVPlayerLayer  *currentPlayerLayer;
@property (nonatomic        ) id playbackTimeObserver;
@property (nonatomic, weak  ) UIView         *containerView;
@property (nonatomic, strong) AVURLAsset     *videoURLAsset;
@property (nonatomic, assign) BOOL           isLocalVideo;          //是否播放本地文件
@property (nonatomic, strong) VideoProgressBarView *progressView;   //播放进度
@property (nonatomic, strong) UILabel *loadingProgressLabel;        //已加载进度
@end

@implementation VideoPlayer

- (instancetype)init
{
    self = [super init];
    if (self) {
        _loadedProgress = 0;
        _duration = 0;
        _current  = 0;
        _state = PlayerStateStopped;
        _stopWhenAppDidEnterBackground = YES;
        _isPlayLoop = YES;
        _isAutoPlay = YES;
    }
    return self;
}

- (instancetype)initWithContainerView:(UIView *)view
{
    self = [super init];
    if (self) {
        _loadedProgress = 0;
        _duration = 0;
        _current  = 0;
        _state = PlayerStateStopped;
        _stopWhenAppDidEnterBackground = YES;
        _containerView = view;
        _isPlayLoop = YES;
        _isAutoPlay = YES;
    }
    return self;
}

- (void)dealloc
{
    [self stop];
}

- (void)playWithUrl:(NSURL *)url inView:(UIView *)view
{
    _containerView = view;
    [self playWithUrl:url];
}

- (void)playWithUrl:(NSURL *)url
{
    //把旧的Avplayer释放掉
    if (self.player) {
        [self stop];
    }
    self.currentURL = url;
    if ([url.scheme isEqualToString:@"file"]) {
        //本地资源
        self.isLocalVideo = YES;
        [self initLocalPlayer:url inView:_containerView];
    } else {
        //http资源
        if ([ResourceLoader isResourceExistsWithURL:url]) {
            //本地已经缓存视频
            NSString *cacheFilePath = [ResourceLoader getResourceCachePathByURL:url.absoluteString];
            if (cacheFilePath) {
                NSLog(@"VideoPlayer resource exist in cache: %@", url);
                NSURL *localURL = [NSURL fileURLWithPath:cacheFilePath];
                [self initLocalPlayer:localURL inView:_containerView];
            }
        } else {
            self.isLocalVideo = NO;
            [self initStreamPlayer:url inView:_containerView];
        }
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kPlayerProgressChangedNotification object:nil];
}

-(void)setCurrentPlayerLayer:(AVPlayerLayer *)currentPlayerLayer
{
    if (_currentPlayerLayer) {
        [_currentPlayerLayer removeFromSuperlayer];
        _currentPlayerLayer = nil;
    }
    _currentPlayerLayer = currentPlayerLayer;
}

- (void)initLocalPlayer:(NSURL *)url inView:(UIView *)view
{
    self.videoURLAsset = [AVURLAsset URLAssetWithURL:url options:nil];
    self.currentPlayerItem = [AVPlayerItem playerItemWithAsset:self.videoURLAsset];
    if (!self.player) {
        self.player = [AVPlayer playerWithPlayerItem:self.currentPlayerItem];
    } else {
        [self.player replaceCurrentItemWithPlayerItem:self.currentPlayerItem];
    }
    self.currentPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.currentPlayerLayer.frame = view.bounds;
    self.currentPlayerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;//视频填充模式
    [view.layer addSublayer:self.currentPlayerLayer];
    [self setProgressBar];
    [self addObservers];
}

- (void)initStreamPlayer:(NSURL *)url inView:(UIView *)view
{
    self.resourceLoader = [[ResourceLoader alloc] init];
    self.resourceLoader.delegate = self;
    self.videoURLAsset = [AVURLAsset URLAssetWithURL:[url customSchemeURL] options:nil];
    [self.videoURLAsset.resourceLoader setDelegate:self.resourceLoader queue:dispatch_get_main_queue()];
    self.currentPlayerItem = [AVPlayerItem playerItemWithAsset:self.videoURLAsset];
    self.player = [AVPlayer playerWithPlayerItem:self.currentPlayerItem];
    self.currentPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.currentPlayerLayer.frame = view.bounds;
    self.currentPlayerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;//视频填充模式
    [view.layer addSublayer:self.currentPlayerLayer];
    [self setProgressBar];
    [self addObservers];
}

- (void)addObservers
{
    [self.player addObserver:self forKeyPath:@"rate" options:NSKeyValueObservingOptionNew context:nil];
    [self.currentPlayerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
    [self.currentPlayerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    [self.currentPlayerItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
    [self.currentPlayerItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.currentPlayerItem];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemPlaybackStalled:) name:AVPlayerItemPlaybackStalledNotification object:self.currentPlayerItem];//停顿
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterForeground) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    AVPlayerItem *playerItem = (AVPlayerItem *)object;
    if ([keyPath isEqualToString:@"status"]) {
        if ([playerItem status] == AVPlayerItemStatusReadyToPlay) {
            //给播放器添加计时器
            const NSInteger newValue = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
            const NSInteger oldValue = [[change objectForKey:NSKeyValueChangeOldKey] integerValue];
            if (newValue != oldValue) {
                [self monitoringPlayback:playerItem];
            }
        } else if ([playerItem status] == AVPlayerItemStatusFailed || [playerItem status] == AVPlayerItemStatusUnknown) {
            NSLog(@"******AVPlayerItemStatusFailed: %@ || %@", self.player.error.description, self.currentPlayerItem.error.description);
            [[NSNotificationCenter defaultCenter] postNotificationName:kPlayerStatusFailed object:self];
            //播放失败时重新下载再播放
            [self stop];
            [self initStreamPlayer:self.currentURL inView:_containerView];
        }
    } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
        //监听播放器的下载进度
        [self calculateDownloadProgress:playerItem];
    } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
        //监听播放器在缓冲数据的状态
        if (playerItem.isPlaybackBufferEmpty) {
            self.state = PlayerStateBuffering;
            [self bufferingSomeSecond];
        }
    } else if ([keyPath isEqualToString:@"rate"]) {
        if (self.player.rate == 0.0) {
            self.state = PlayerStatePause;
        }else {
            self.state = PlayerStatePlaying;
        }
    }
}

- (void)calculateDownloadProgress:(AVPlayerItem *)playerItem
{
    NSArray *loadedTimeRanges = [playerItem loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
    float startSeconds = CMTimeGetSeconds(timeRange.start);
    float durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval totalBuffer = startSeconds + durationSeconds;// 计算缓冲总进度
    CMTime duration = playerItem.duration;
    CGFloat totalDuration = CMTimeGetSeconds(duration);
    self.loadedProgress = totalBuffer / totalDuration;
    NSString *percent = [NSNumberFormatter localizedStringFromNumber:@(self.loadedProgress) numberStyle:NSNumberFormatterPercentStyle];
    NSLog(@"******缓冲进度：%@, 共缓冲%.2fs",percent, totalBuffer);
}

- (void)bufferingSomeSecond
{
    // playbackBufferEmpty会反复进入，因此在bufferingOneSecond延时播放执行完之前再调用bufferingSomeSecond都忽略
    static BOOL isBuffering = NO;
    if (isBuffering) {
        return;
    }
    isBuffering = YES;

    // 需要先暂停一小会之后再播放，否则网络状况不好的时候时间在走，声音播放不出来
    [self.player pause];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.player play];
        isBuffering = NO;
        // 如果执行了play还是没有播放则说明还没有缓存好，则再次缓存一段时间
        if (!self.currentPlayerItem.isPlaybackLikelyToKeepUp) {
            [self bufferingSomeSecond];
        }
    });
}

- (void)appDidEnterBackground
{
    if (self.stopWhenAppDidEnterBackground) {
        [self pause];
    }
}

- (void)appDidEnterForeground
{
    if (self.resumeWhenAppDidEnterForeground) {
        [self resume];
    }
}

- (void)playerItemDidPlayToEnd:(NSNotification *)notification
{
    if (_isPlayLoop) {
        // 播放完成后重复播放,跳到最新的时间点开始播放
        __weak typeof(self) weakSelf = self;
        [self.player seekToTime:kCMTimeZero toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
            if (finished) {
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                [strongSelf monitoringPlayback:self.currentPlayerItem];
            }
        }];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:kPlayerDidPlayeToEnd object:nil userInfo:nil];
    }
}

- (void)playerItemPlaybackStalled:(NSNotification *)notification
{
    // 这里网络不好的时候，就会进入，不做处理，会在playbackBufferEmpty里面缓存之后重新播放
    NSLog(@"******buffering******");
}

// 给播放器添加进度更新
- (void)monitoringPlayback:(AVPlayerItem *)playerItem
{
    self.duration = playerItem.duration.value / playerItem.duration.timescale; //视频总时间
    [self.player play];
    __weak typeof(self) weakSelf = self;
    self.playbackTimeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        [strongSelf updateProgressBar:time];
        CGFloat current = CMTimeGetSeconds(time);
        strongSelf.current = current;
        [[NSNotificationCenter defaultCenter] postNotificationName:kPlayerProgressChangedNotification object:nil];
    }];
}

- (CGFloat)progress
{
    if (self.duration > 0) {
        return self.current / self.duration;
    }
    return 0;
}

- (void)start
{
    if (!self.currentPlayerItem) {
        return;
    }
    dispatch_block_t block = ^{
        [self.player play];
        self.state = PlayerStatePlaying;
        [self setProgressBar];
    };
    if (self.progress > 0.1) {
        @try {
            [self.player seekToTime:kCMTimeZero toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
                if (finished) {
                    block();
                }
            }];
        } @catch (NSException *exception) {
            block();
        }
    } else {
        block();
    }
}

- (void)seekToTime:(CGFloat)seconds andPlay:(BOOL)play
{
    if (self.state == PlayerStatePlaying || self.state == PlayerStatePause) {
        if (self.state == PlayerStatePlaying) {
            [self.player pause];//先暂停后面再seek
        }
        __weak typeof(self) weakSelf = self;
        CMTime time = CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC);
        [self.player seekToTime:time toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            if (finished) {
                [strongSelf updateProgressBar:time];
                if (play) {
                    [strongSelf.player play];
                    strongSelf.state = PlayerStatePlaying;
                } else {
                    strongSelf.state = PlayerStatePause;
                }
            }
        }];
    }
}

- (void)resume
{
    if (!self.currentPlayerItem) {
        NSLog(@"******resume but currentPlayerItem is nil");
        return;
    }
    [self.player play];
    self.state = PlayerStatePlaying;
    //断点续传
    ResourceLoader *loader = self.resourceLoader;
    if (loader.requestTask.cancel && loader.requestTask.cacheLength < loader.requestTask.fileLength) {
        [loader.requestTask start];
    }
}

- (void)pause
{
    if (!self.currentPlayerItem) {
        return;
    }
    self.state = PlayerStatePause;
    [self.player pause];
    //停止下载任务
    RequestTask *task = [[RequestTaskManager sharedInstance] taskForURL:self.currentURL];
    if (task) {
        [self.resourceLoader stopLoading];
    }
}

- (void)stop
{
    if (!self.player) return;
    self.state = PlayerStateStopped;
    [self.player pause];
    [self.player cancelPendingPrerolls];
    if (self.currentPlayerLayer) {
        [self.currentPlayerLayer removeFromSuperlayer];
        self.currentPlayerLayer = nil;
    }
    [self.videoURLAsset.resourceLoader setDelegate:nil queue:dispatch_get_main_queue()];
    [self.resourceLoader stopLoading];
    self.resourceLoader = nil;
    [self resetPlayer];
    [self.progressView removeFromSuperview];
    [[NSNotificationCenter defaultCenter] postNotificationName:kPlayerProgressChangedNotification object:nil];
}

- (BOOL)isPlaying
{
    return (self.player && self.player.rate != 0.0);
}

-(void)setMute:(BOOL)mute
{
    _mute = mute;
    self.player.muted = mute;
}

//清空播放器监听属性
- (void)resetPlayer
{
    self.loadedProgress = 0;
    self.duration = 0;
    self.current = 0;
    
    if (!self.currentPlayerItem) {
        return;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.currentPlayerItem removeObserver:self forKeyPath:@"status"];
    [self.currentPlayerItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [self.currentPlayerItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
    [self.currentPlayerItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    [self.player removeObserver:self forKeyPath:@"rate"];
    
    if (self.playbackTimeObserver) {
        [self.player removeTimeObserver:self.playbackTimeObserver];
        self.playbackTimeObserver = nil;
    }
    self.videoURLAsset = nil;
    self.playbackTimeObserver = nil;
    self.currentPlayerItem = nil;
    self.player = nil;
}

- (void)setProgressBar
{
    if (!self.progressView) {
        self.progressView = [[VideoProgressBarView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.containerView.frame), 2)];
        [self.currentPlayerLayer addSublayer:self.progressView.layer];
    } else {
        self.progressView.progress = 0;
        [self.progressView.layer removeFromSuperlayer];
        [self.currentPlayerLayer addSublayer:self.progressView.layer];
    }
}

- (void)updateProgressBar:(CMTime)cmtime
{
    AVPlayerItem* item = _player.currentItem;
    Float64 duration = CMTimeGetSeconds(item.duration);
    Float64 time = CMTimeGetSeconds(cmtime);
    Float64 progress = time / duration;
    
    _progressView.progress = progress;
}

#pragma mark - ResourceLoaderDelegate
- (void)loader:(ResourceLoader *)loader cacheProgress:(CGFloat)progress
{
    if (!self.loadingProgressLabel) {
        self.loadingProgressLabel = [[UILabel alloc] init];
        self.loadingProgressLabel.font = [UIFont systemFontOfSize:14.0];
        self.loadingProgressLabel.textColor = [UIColor yellowColor];
        self.loadingProgressLabel.frame = CGRectMake(0, 0, 120, 40);
        [self.containerView addSubview:self.loadingProgressLabel];
    }
    self.loadingProgressLabel.text = [NSString stringWithFormat:@"buffering:%.0f%%", progress*100];
}

@end
