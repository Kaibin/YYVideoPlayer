//
//  RequestTaskManager.m
//  ada
//
//  Created by kaibin on 16/12/20.
//  Copyright © 2016年 yy. All rights reserved.
//

#import "RequestTaskManager.h"
#import "RequestTask.h"


@interface RequestTaskManager ()

@end

@implementation RequestTaskManager

+ (instancetype)sharedInstance
{
    static RequestTaskManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[RequestTaskManager alloc] init];
    });
    return manager;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.taskDic = [YYThreadSafeDictionary dictionary];
    }
    return self;
}

- (RequestTask *)taskForURL:(NSURL *)url
{
    return [self.taskDic objectForKey:url];
}

- (void)setTask:(RequestTask *)task forURL:(NSURL *)url
{
    [self.taskDic setObject:task forKey:url];
}

- (void)removeTaskForURL:(NSURL *)url
{
    if ([self.taskDic objectForKey:url]) {
        [self.taskDic removeObjectForKey:url];
    }
}

@end
