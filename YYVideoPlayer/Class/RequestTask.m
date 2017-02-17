
#import "RequestTask.h"
#import "NSURL+Category.h"
#import "ResourceLoader.h"
#import "AppDelegate.h"
#import "RequestTaskManager.h"
#import "VideoPlayer.h"

@interface RequestTask ()<NSURLSessionDataDelegate>

@property (nonatomic, strong) NSURL *originalSchemeURL;           //发起网络请求真正的URL
@property (nonatomic, assign) BOOL once;
@property (nonatomic, strong) NSFileHandle *writeFileHandle;
@property (nonatomic, strong) NSString *tempFilePath;
@property (nonatomic, assign) NSUInteger counter;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@end

@implementation RequestTask

- (instancetype)init {
    if (self = [super init]) {
    }
    return self;
}

- (void)dealloc
{
    [self.session invalidateAndCancel];
}

- (void)start
{
    self.originalSchemeURL = [self.requestURL originalSchemeURL];
    self.tempFilePath = [self tempFilePath];
    RequestTask *task = [[RequestTaskManager sharedInstance] taskForURL:self.originalSchemeURL];
    if (task) {
        NSLog(@"******cancel existed requestTask:%@", self.originalSchemeURL);
        self.cancel = YES;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.originalSchemeURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:RequestTimeout];
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.tempFilePath]) {
        //没下载过，创建下载临时文件
        [[NSFileManager defaultManager] createFileAtPath:self.tempFilePath contents:nil attributes:nil];
        if (self.requestOffset > 0) {
            [request addValue:[NSString stringWithFormat:@"bytes=%ld-%ld", (unsigned long)self.requestOffset, (unsigned long)self.fileLength-1] forHTTPHeaderField:@"Range"];
        }
    } else {
        //已经下载过，断点续传
        NSData *resumeData = [[NSData alloc] initWithContentsOfFile:self.tempFilePath];
        NSUInteger resumeOffset = resumeData.length;
        if (resumeOffset > 0) {
            NSLog(@"******resume offset:%ld requestTask:%@", (unsigned long)resumeOffset, self.originalSchemeURL);
            self.cacheLength = resumeData.length;
            [request addValue:[NSString stringWithFormat:@"bytes=%ld-%ld", (unsigned long)resumeOffset, (unsigned long)self.fileLength - 1] forHTTPHeaderField:@"Range"];
        }
    }
    [request setValue:@"video/mp4" forHTTPHeaderField:@"Content-Type"];
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    [self.session invalidateAndCancel];
    self.operationQueue = [NSOperationQueue new];           //自定义队列
    self.operationQueue.maxConcurrentOperationCount = 1;    //1表示串行队列
    self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:self.operationQueue];
    self.task = [self.session dataTaskWithRequest:request];
    [self.task resume];
    self.cancel = NO;
    [[RequestTaskManager sharedInstance] setTask:self forURL:self.originalSchemeURL];
}

- (void)setCancel:(BOOL)cancel
{
    _cancel = cancel;
    if (cancel) {
        NSLog(@"******cancel task: %@",self.originalSchemeURL);
        RequestTask *task = [[RequestTaskManager sharedInstance] taskForURL:self.originalSchemeURL];
        [task.task cancel];
        [[RequestTaskManager sharedInstance] removeTaskForURL:self.originalSchemeURL];
    }
}

- (void)suspend
{
    [self.task suspend];
}

- (void)resume
{
    [self.task resume];
}

#pragma mark - NSURLSessionDataDelegate
//服务器响应
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    if (_cancel) {
        NSLog(@"******didReceiveResponse:%@ is cancel", dataTask.originalRequest.URL);
        return;
    };
    NSLog(@"******response: %@",response);
    completionHandler(NSURLSessionResponseAllow);
    NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)response;
    NSDictionary *dic = (NSDictionary *)[httpResponse allHeaderFields] ;
    if ([dic.allKeys containsObject:@"Content-Range"]) {
        NSString *contentRange = [dic objectForKey:@"Content-Range"];
        NSString *fileLength = [[contentRange componentsSeparatedByString:@"/"] lastObject];
        self.fileLength = fileLength.integerValue ;
    } else {
         self.fileLength = (NSUInteger)response.expectedContentLength;
    }
    if ([dic.allKeys containsObject:@"Content-Type"]) {
        NSString *contentType = [dic objectForKey:@"Content-Type"];
        if ([contentType rangeOfString:@"text/html"].location != NSNotFound) {
            NSLog(@"******* response not return video mime type!!!");
            [self retry];
            return;
        }
    }
    if (!self.writeFileHandle) {
        self.writeFileHandle = [NSFileHandle fileHandleForWritingAtPath:self.tempFilePath];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(requestTaskDidReceiveResponse)]) {
            [self.delegate requestTaskDidReceiveResponse];
        }
    });
}

//服务器返回数据 可能会调用多次
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    NSLog(@"downloading progress: %0.2lf", 1.0 * self.cacheLength / self.fileLength);

    if (_cancel) {
        NSLog(@"******didReceiveData:%@ is cancel", dataTask.originalRequest.URL);
        return;
    }
    
    [self.writeFileHandle seekToEndOfFile];
    [self.writeFileHandle writeData:data];
    self.cacheLength += data.length;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(requestTaskDidUpdateCache)]) {
            [self.delegate requestTaskDidUpdateCache];
        }
    });
}

//请求完成会调用该方法，请求失败则error有值
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (_cancel || error.code == NSURLErrorCancelled) {
    } else {
        [[RequestTaskManager sharedInstance] removeTaskForURL:self.originalSchemeURL];
        if (error) {
            NSLog(@"******urlsession error:%@", error);
            if (error.code == NSURLErrorTimedOut && !_once) {      //网络超时，重连一次
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self retry];
                });
            }
            if (error.code == NSURLErrorNotConnectedToInternet) {
                NSLog(@"******urlsession error:%@", @"无网络连接...");

            }
            if (self.delegate && [self.delegate respondsToSelector:@selector(requestTaskDidFailWithError:)]) {
                [self.delegate requestTaskDidFailWithError:error];
            }
        } else {
            NSLog(@"******success download:%@", self.requestURL.absoluteString);
            //可以缓存则保存文件
            if (self.cache) {
                [self cacheTempFileWithURL:self.requestURL];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.delegate && [self.delegate respondsToSelector:@selector(requestTaskDidFinishLoadingWithCache:)]) {
                    [self.delegate requestTaskDidFinishLoadingWithCache:self.cache];
                }
            });
        }
    }
    [self.writeFileHandle closeFile];
    self.writeFileHandle = nil;
}

#pragma mark - private

- (void)retry
{
    NSLog(@"******retry request:%@", self.originalSchemeURL);
    _once = YES;
    [self start];
}

// http下载临时数据文件
- (NSString *)tempFilePath
{
    NSString *filename = self.requestURL.lastPathComponent;
    NSString *tempFilePath = [[NSTemporaryDirectory() stringByAppendingPathComponent:filename] stringByAppendingString:@".tmp"];
    return tempFilePath;
}

// 最终下载完的文件
- (void)cacheTempFileWithURL:(NSURL *)url
{
    NSString *cacheFilePath = [ResourceLoader getResourceCachePathByURL:url.absoluteString];
    NSError *error;
    if ([[NSFileManager defaultManager] fileExistsAtPath:cacheFilePath]) {
        NSLog(@"******cache file %@ already exist, remove it first", cacheFilePath);
        [[NSFileManager defaultManager] removeItemAtPath:cacheFilePath error:&error];
    }
    BOOL success = [[NSFileManager defaultManager] moveItemAtPath:self.tempFilePath toPath:cacheFilePath error:&error];
    if (!success || error) {
        NSLog(@"******cache file error: %@", error);
    } else {
        NSLog(@"******success cache file : %@", [NSURL URLWithString:cacheFilePath].lastPathComponent);
    }
}


@end
