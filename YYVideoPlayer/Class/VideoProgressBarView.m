
//  VideoProgressBarView.m
//
//  Created by kaibin on 16/11/16.
//  Copyright © 2016年 yy. All rights reserved.
//

#import "VideoProgressBarView.h"

#define UIColorRGB(r, g, b)     [UIColor colorWithRed:((r) / 255.0f) green:((g) / 255.0f) blue:((b) / 255.0f) alpha:1]

@interface VideoProgressBarView ()

@property (nonatomic, strong) CAShapeLayer* shapeLayer;
@end

@implementation VideoProgressBarView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2f];
    self.progress = 0;
    
    UIBezierPath *bezierPath = [UIBezierPath bezierPath];
    [bezierPath moveToPoint:CGPointMake(0, 1)];
    [bezierPath addLineToPoint:CGPointMake(self.bounds.size.width, 1)];
    
    CAShapeLayer* layer = [CAShapeLayer layer];
    layer.frame = self.bounds;
    layer.strokeColor = UIColorRGB(0xfc, 0xd3, 0x43).CGColor;
    layer.path = bezierPath.CGPath;
    layer.lineWidth = self.bounds.size.height;
    layer.lineJoin = kCALineJoinRound;
    layer.lineCap = kCALineCapRound;
    layer.fillColor = [UIColor colorWithWhite:1.0 alpha:0.2f].CGColor;
    layer.position = CGPointMake(self.bounds.size.width*0.5, self.bounds.size.height*0.5);
    layer.strokeStart = 0;
    layer.strokeEnd = 0;
    
    _shapeLayer = layer;
    
    [self.layer addSublayer:layer];
}

- (void)setProgress:(float)progress
{
    if (progress >= 0 && progress <= 1) {
        _progress = progress;
        _shapeLayer.strokeEnd = progress;
    }
}

- (void)setProgressTintColor:(UIColor *)tintColor
{
    self.shapeLayer.strokeColor = tintColor.CGColor;
}

- (void)setProgress:(float)progress duration:(NSTimeInterval)duration
{
    self.progress = progress;
}

- (void)reset
{
    self.progress = 0;
}

@end
