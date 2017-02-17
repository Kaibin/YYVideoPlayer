//
//  ViewController.m
//  YYVideoPlayer
//
//  Created by kaibin on 17/2/17.
//  Copyright © 2017年 demo. All rights reserved.
//

#import "ViewController.h"
#import "VideoPlayerView.h"

@interface ViewController ()

@property (nonatomic, strong) VideoPlayerView *videoView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self addVideoPlayer];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)addVideoPlayer
{
    self.view.backgroundColor = [UIColor grayColor];
    self.videoView = [[VideoPlayerView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.videoView];
    
    NSString *url = @"http://ada.bs2dl.huanjuyun.com/A7CE8FA4A2C03DFB1949D2D2687BD66C.mp4";
    NSURL *URL = [[NSURL alloc] initWithString:url];
    [self.videoView setFileURL:URL];

}
@end
