//
//  VideoPlayer.h
//  ada
//
//  Created by kaibin on 16/11/15.
//  Copyright © 2016年 yy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

extern NSString *const kPlayerProgressChangedNotification;
extern NSString *const kPlayerLoadProgressChangedNotification;
extern NSString *const kPlayerDidPlayeToEnd;    //结束播放
extern NSString *const kPlayerWillStartToPlay;  //开始播放
extern NSString *const kPlayerStatusFailed;     //播放视频


//播放器的几种状态
typedef NS_ENUM(NSInteger, PlayerState) {
    PlayerStateBuffering = 1,
    PlayerStatePlaying   = 2,
    PlayerStateStopped   = 3,
    PlayerStatePause     = 4
};

@interface VideoPlayer : NSObject

@property (nonatomic) PlayerState   state;
@property (nonatomic) CGFloat       loadedProgress;   //缓冲进度
@property (nonatomic) CGFloat       duration;         //视频总时间
@property (nonatomic) CGFloat       current;          //当前播放时间
@property (nonatomic, readonly) CGFloat       progress;                 //播放进度 0~1
@property (nonatomic) BOOL          stopWhenAppDidEnterBackground;      // default is YES
@property (nonatomic) BOOL          resumeWhenAppDidEnterForeground;    // default is NO
@property (nonatomic) BOOL          isPlayLoop;
@property (nonatomic) BOOL          isAutoPlay;
@property (nonatomic,strong)        NSURL* currentURL;
@property (nonatomic) BOOL mute;            //静音

- (instancetype)initWithContainerView:(UIView *)view;
- (void)playWithUrl:(NSURL *)url;
- (void)playWithUrl:(NSURL *)url inView:(UIView *)view;

//从头开始
- (void)start;
//暂停后继续
- (void)resume;
//暂停
- (void)pause;
//停止
- (void)stop;
//是否正在播放
- (BOOL)isPlaying;
//调整播放进度
- (void)seekToTime:(CGFloat)seconds andPlay:(BOOL)play;
@end
