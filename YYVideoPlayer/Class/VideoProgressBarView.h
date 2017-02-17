//
//  VideoProgressBarView.h
//
//  Created by kaibin on 16/11/16.
//  Copyright © 2016年 yy. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface VideoProgressBarView : UIView

@property (nonatomic, strong) UIColor *progressTintColor;
@property (nonatomic, assign) float progress;

- (void)setProgressTintColor:(UIColor *)tintColor;
- (void)setProgress:(float)progress duration:(NSTimeInterval)duration;

@end
