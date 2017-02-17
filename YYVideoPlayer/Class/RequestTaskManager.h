//
//  RequestTaskManager.h
//
//  Created by kaibin on 16/12/20.
//  Copyright © 2016年 yy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YYThreadSafeDictionary.h"

@class NSURLSessionDataTask;
@class RequestTask;

@interface RequestTaskManager : NSObject

@property (nonatomic, strong) YYThreadSafeDictionary *taskDic;

+ (instancetype)sharedInstance;

- (RequestTask *)taskForURL:(NSURL *)url;

- (void)setTask:(RequestTask *)task forURL:(NSURL *)url;

- (void)removeTaskForURL:(NSURL *)url;

@end
