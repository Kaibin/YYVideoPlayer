
#import <Foundation/Foundation.h>

#define RequestTimeout 15.0

@class RequestTask;
@protocol RequestTaskDelegate <NSObject>

@required
- (void)requestTaskDidUpdateCache; //更新缓冲进度代理方法

@optional
- (void)requestTaskDidReceiveResponse;
- (void)requestTaskDidFinishLoadingWithCache:(BOOL)cache;
- (void)requestTaskDidFailWithError:(NSError *)error;

@end

@interface RequestTask : NSObject

@property (nonatomic, weak) id<RequestTaskDelegate> delegate;
@property (nonatomic, strong) NSURL *requestURL;        //播放器修改协议后的URL stream://
@property (nonatomic, assign) NSUInteger requestOffset; //请求起始位置，用于播放器拖拽快进
@property (nonatomic, assign) NSUInteger fileLength;    //文件长度
@property (nonatomic, assign) NSUInteger cacheLength;   //缓冲长度
@property (nonatomic, assign) BOOL cache; //是否缓存文件
@property (nonatomic, assign) BOOL cancel; //是否取消请求
@property (nonatomic, strong) NSURLSession *session;              //会话对象
@property (nonatomic, strong) NSURLSessionDataTask *task;         //任务

/**
 *  开始请求
 */
- (void)start;

/**
 *  暂停请求
 */
- (void)suspend;

@end
