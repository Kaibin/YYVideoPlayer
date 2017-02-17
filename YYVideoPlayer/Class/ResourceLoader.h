
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "RequestTask.h"

#define VideoMimeType @"video/mp4"

@class ResourceLoader;

@protocol LoaderDelegate <NSObject>
@optional
- (void)loader:(ResourceLoader *)loader cacheProgress:(CGFloat)progress;
- (void)loader:(ResourceLoader *)loader failLoadingWithError:(NSError *)error;
@end

@interface ResourceLoader : NSObject<AVAssetResourceLoaderDelegate,RequestTaskDelegate>

@property (nonatomic, weak) id<LoaderDelegate> delegate;
@property (atomic, assign) BOOL seekRequired; //Seek标识
@property (nonatomic, assign) BOOL cacheFinished;
@property (nonatomic, strong) RequestTask *requestTask;

- (void)stopLoading;
+ (NSString *)getResourceCachePathByURL:(NSString *)url;
+ (BOOL)isResourceExistsWithURL:(NSURL *)url;

@end

