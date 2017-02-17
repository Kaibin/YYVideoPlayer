//
//  VideoPlayerView.m
//
//  Created by kaibin on 16/11/16.
//  Copyright © 2016年 yy. All rights reserved.
//

#import "VideoPlayerView.h"
#import "VideoPlayer.h"

@interface VideoPlayerView ()

@property (nonatomic, strong) UIView *showView;
@property (nonatomic, strong) UIButton *actionButton;
@end

@implementation VideoPlayerView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initSubview];
        _player = [[VideoPlayer alloc] init];
    }
    return self;
}

- (void)dealloc
{
    if (_player) {
        [_player stop];
    }
}

- (void)initSubview
{
    self.showView = [[UIView alloc] init];
    self.showView.backgroundColor = [UIColor clearColor];
    self.showView.frame = self.bounds;
    [self addSubview:self.showView];
        
    self.actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.actionButton.titleLabel.font = [UIFont systemFontOfSize:20];
    self.actionButton.backgroundColor = [UIColor whiteColor];
    [self.actionButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [self.actionButton setTitle:@"暂停" forState:UIControlStateNormal];
    self.actionButton.frame = CGRectMake((self.bounds.size.width-80)/2, self.bounds.size.height - 100, 80, 50);
    [self addSubview:self.actionButton];
    [self.actionButton addTarget:self action:@selector(onActionButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)setFileURL:(NSURL *)fileURL
{
    _fileURL = fileURL;
    self.player = [[VideoPlayer alloc] init];
    [self.player playWithUrl:_fileURL inView:self.showView];
}

- (void)onActionButtonPressed:(id)sender
{
    if (self.player.state == PlayerStatePlaying) {
        [self.player pause];
        [self.actionButton setTitle:@"播放" forState:UIControlStateNormal];
    } else {
        [self.player resume];
        [self.actionButton setTitle:@"暂停" forState:UIControlStateNormal];
    }
}

@end
