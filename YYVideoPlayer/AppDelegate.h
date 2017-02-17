//
//  AppDelegate.h
//  YYVideoPlayer
//
//  Created by kaibin on 17/2/17.
//  Copyright © 2017年 demo. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

+ (AppDelegate *)sharedObject;
- (BOOL)isDirectoryExist:(NSString *)path;
- (NSString *)appResourceCachePath;
@end

