
#import "ResourceLoader.h"
#import "RequestTaskManager.h"
#import "NSURL+Category.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "AppDelegate.h"

@interface ResourceLoader ()

@property (nonatomic, strong) NSMutableArray *requestList;
@property (nonatomic, strong) NSFileHandle *readFileHandle;
@property (nonatomic, strong) NSString *tempFilePath;
@end

@implementation ResourceLoader

- (instancetype)init {
    if (self = [super init]) {
        self.requestList = [NSMutableArray array];
    }
    return self;
}

- (void)stopLoading {
    self.requestTask.cancel = YES;
}

- (void)dealloc
{
}

#pragma mark - AVAssetResourceLoaderDelegate
//加载自定义scheme的URLAsset资源时回调，会被调用多次请求不同片段的视频数据，保存这些请求，在断点下载返回数据给播放器后移除请求
//第一次请求时会开始断点下载，连接视频播放和视频断点下载
- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    NSLog(@"WaitingLoadingRequest < requestedOffset = %lld, currentOffset = %lld, requestedLength = %lld >", loadingRequest.dataRequest.requestedOffset, loadingRequest.dataRequest.currentOffset, (long long)loadingRequest.dataRequest.requestedLength);
    [self addLoadingRequest:loadingRequest];
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    NSLog(@"CancelLoadingRequest  < requestedOffset = %lld, currentOffset = %lld, requestedLength = %lld >", loadingRequest.dataRequest.requestedOffset, loadingRequest.dataRequest.currentOffset, (long long)loadingRequest.dataRequest.requestedLength);
    [self removeLoadingRequest:loadingRequest];
}

#pragma mark - RequestTaskDelegate
- (void)requestTaskDidUpdateCache {
    [self processRequestList];
    if (self.delegate && [self.delegate respondsToSelector:@selector(loader:cacheProgress:)]) {
        CGFloat cacheProgress = (CGFloat)self.requestTask.cacheLength / (self.requestTask.fileLength - self.requestTask.requestOffset);
        [self.delegate loader:self cacheProgress:cacheProgress];
    }
}

- (void)requestTaskDidFinishLoadingWithCache:(BOOL)cache {
    self.cacheFinished = cache;
}

- (void)requestTaskDidFailWithError:(NSError *)error {
    //加载数据错误的处理
}

#pragma mark - 处理LoadingRequest
- (void)addLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    [self.requestList addObject:loadingRequest];
    @synchronized(self) {
        if (self.requestTask) {
            if (loadingRequest.dataRequest.requestedOffset >= self.requestTask.requestOffset && //requestTask.requestOffset表示开始下载的起始点
                loadingRequest.dataRequest.requestedOffset <= self.requestTask.requestOffset + self.requestTask.cacheLength) {
                //数据已经缓存，则直接完成
                NSLog(@"******processRequestList %@", self.requestTask.requestURL);
                [self processRequestList];
            } else {
                //数据还没缓存，则等待数据下载；如果是Seek操作，则重新请求
                if (self.seekRequired) {
                    NSLog(@"******resourceloader seekRequired");
                    [self newTaskWithLoadingRequest:loadingRequest cache:NO];
                }
            }
        } else {
            RequestTask *task = [[RequestTaskManager sharedInstance] taskForURL:[loadingRequest.request.URL originalSchemeURL]];
            if (task) {
                //已经在下载，不取消，复用下载连接
                NSLog(@"******reuse existed requestTask:%@", [loadingRequest.request.URL originalSchemeURL]);
                self.requestTask = task;
                self.requestTask.delegate = self;
                [self processRequestList];
            } else {
                [self newTaskWithLoadingRequest:loadingRequest cache:YES];
            }
        }
    }
}

- (void)newTaskWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest cache:(BOOL)cache {
    NSUInteger fileLength = 0;
    if (self.requestTask) {
        NSLog(@"******cancel request task before new one");
        fileLength = self.requestTask.fileLength;
        self.requestTask.cancel = YES;
    }
    self.requestTask = [[RequestTask alloc] init];
    self.requestTask.requestURL = loadingRequest.request.URL;
    self.requestTask.requestOffset = (NSUInteger)loadingRequest.dataRequest.requestedOffset;
    self.requestTask.cache = cache;
    if (fileLength > 0) {
        self.requestTask.fileLength = fileLength;
    }
    self.requestTask.delegate = self;
    [self.requestTask start];
    self.seekRequired = NO;
}

- (void)removeLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    [self.requestList removeObject:loadingRequest];
}

- (void)processRequestList {
    NSMutableArray *finishRequestList = [NSMutableArray array];
    for (AVAssetResourceLoadingRequest *loadingRequest in self.requestList) {
        if ([self finishLoadingWithLoadingRequest:loadingRequest]) {
            [finishRequestList addObject:loadingRequest];
        }
    }
    [self.requestList removeObjectsInArray:finishRequestList];
}

- (BOOL)finishLoadingWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    //填充信息
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(VideoMimeType), NULL);
    loadingRequest.contentInformationRequest.contentType = CFBridgingRelease(contentType);
    loadingRequest.contentInformationRequest.byteRangeAccessSupported = YES;
    loadingRequest.contentInformationRequest.contentLength = self.requestTask.fileLength;
    
    //读文件，填充数据
    NSUInteger cacheLength = self.requestTask.cacheLength;
    NSUInteger startOffset = (NSUInteger)loadingRequest.dataRequest.requestedOffset;//播放器请求起始点
    if (loadingRequest.dataRequest.currentOffset != 0) {
        startOffset = (NSUInteger)loadingRequest.dataRequest.currentOffset;//播放器开始播放的起始点，在这之前的数据已经通过respondWithData加载
    }
    NSUInteger canReadLength = cacheLength - (startOffset - self.requestTask.requestOffset);//requestTask.requestOffset开始下载的起始点，一般都为0
    NSUInteger respondLength = MIN(canReadLength, loadingRequest.dataRequest.requestedLength);
    
    if (!self.tempFilePath) {
        NSString *filename = loadingRequest.request.URL.absoluteString.lastPathComponent;
        self.tempFilePath =  [[NSTemporaryDirectory() stringByAppendingPathComponent:filename] stringByAppendingString:@".tmp"];

    }
    // 防止有些文件需要全部下载完再播放，此时由于temp文件已被删除，用缓存文件
    if (![self isFileExist:self.tempFilePath]) {
        self.tempFilePath = [ResourceLoader getResourceCachePathByURL:loadingRequest.request.URL.absoluteString];
    }
    if ([self isFileExist:self.tempFilePath]) {
        if (!self.readFileHandle) {
            self.readFileHandle = [NSFileHandle fileHandleForReadingAtPath:self.tempFilePath];
        }
        [self.readFileHandle seekToFileOffset:startOffset-self.requestTask.requestOffset];//requestTask.requestOffset开始下载的起始点，一般都为0
        NSData *data = [self.readFileHandle readDataOfLength:respondLength];
        [loadingRequest.dataRequest respondWithData:data];
    } else {
        NSLog(@"******respondWithData error, file not exist: %@", self.tempFilePath );
    }
    //如果完全响应了所需要的数据，则完成
    NSUInteger nowendOffset = startOffset + canReadLength;
    NSUInteger reqEndOffset = (NSUInteger)loadingRequest.dataRequest.requestedOffset + (NSUInteger)loadingRequest.dataRequest.requestedLength;
    if (nowendOffset >= reqEndOffset) {
        [loadingRequest finishLoading];
        if (self.readFileHandle) {
            [self.readFileHandle closeFile];
            self.readFileHandle = nil;
        }
        return YES;
    }
    return NO;
}

- (BOOL)isFileExist:(NSString *)path
{
    BOOL isDirectory;
    return [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] && !isDirectory;
}

+ (NSString *)getResourceCachePathByURL:(NSString *)url
{
    NSString *subUrl = url.lastPathComponent;
    if (subUrl.length > 0) {
        NSString *directory = [[AppDelegate sharedObject] appResourceCachePath];
        NSString *fileName = [subUrl stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
        fileName = [fileName stringByReplacingOccurrencesOfString:@"?" withString:@"_"];
        if (fileName.length > 0) {
            return [directory stringByAppendingPathComponent:fileName];
        }
    }
    
    return nil;
}

+ (BOOL)isResourceExistsWithURL:(NSURL *)url
{
    NSString *filePath = [self getResourceCachePathByURL:url.absoluteString];
    if (filePath != nil && [[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        return YES;
    }
    return NO;
}

@end
