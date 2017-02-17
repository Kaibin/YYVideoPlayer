//
//  VideoPlayerView.h
//
//  Created by kaibin on 16/11/16.
//  Copyright © 2016年 yy. All rights reserved.
//

#import <UIKit/UIKit.h>

@class VideoPlayer;

@interface VideoPlayerView : UIView
@property (nonatomic, strong) NSURL *fileURL;       //要播放的视频文件URL
@property (nonatomic, strong) VideoPlayer *player;

- (void)pausePlayer;

@end
