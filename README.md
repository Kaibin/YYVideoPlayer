# iOS实现在线视频边下边播
  
  近期在做短视频相关的开发，需要实现一个可以支持断点续传的边下载边播放的视频播放器，整个过程涉及到视频文件的下载管理和播放，这篇文章就当做个总结吧。

  首先是要确定作为播放器输入的视频文件格式， 由于MPEG4编码格式已经在各种移动设备广泛应用， 各安卓和iOS平台都支持MPEG4格式，因此播放器选择MPEG4作为视频文件格式。MPEG4格式有个规范，就是 MPEG4默认会将 moov atom放置于文件尾部，这个moov atom 是视频数据的索引，播放器需要先读取视频文件的索引数据才可以播放视频，因此如果要边下载边播放，那么就要将moov atom放置在视频数据前面。
  
  关于moov atom元数据具体可查阅这篇文章：http://www.adobe.com/devnet/video/articles/mp4_movie_atom.html。

  在iOS平台，如果视频是通过摄像头录制而来的，其输出的文件默认是.mov格式，可以通过AVAssetExportSession在mov转MPEG4时设置shouldOptimizeForNetworkUse = YES将 moov atom 移动到文件首部，使视频可以支持边下边播。

  视频播放器选择AVFoundation库中的AVPlayer，简单介绍播放过程需要用到的几个类：
<ul>
<li>AVURLAsset：AVAsset的子类，可以根据一个URL路径创建一个包含媒体信息的AVURLAsset对象。这个URL可以是本地视频路径也可以是网络视频路径。</li>
<li>AVPlayerItem：一个媒体资源管理对象，管理视频的一些基本信息和状态，一个AVPlayerItem对应着一个视频资源。</li>
<li>AVPlayerLayer：AVPlayer本身并不能显示视频，因此AVPlayer要显示视频必须创建一个播放器层AVPlayerLayer用于展示，AVPlayerLayer继承于CALayer，创建完成之后将其添加到播放器要显示到的view上即可。</li>
</ul>
 <pre><code>
    self.videoURLAsset = [AVURLAsset URLAssetWithURL:videoURLl options:nil];
    self.currentPlayerItem = [AVPlayerItem playerItemWithAsset:self.videoURLAsset];
    self.player = [AVPlayer playerWithPlayerItem:self.currentPlayerItem];
    self.currentPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.currentPlayerLayer.frame = containerView.bounds;//这里的containerView即是指播放器要在哪个view上显示视频
    self.currentPlayerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;//视频填充模式
    [containerView.layer addSublayer:self.currentPlayerLayer];
</code></pre>
通过AVURLAsset传入视频文件的URL地址，AVPlayer既可以播放本地视频，也可以播放在线网络视频。但播放网络视频时，每次播放都要去视频服务器请求数据，这显然是很浪费流量的，而且整个过程中的数据流完全由AVPlayer控制，我们无法控制下载和播放，也就无法进行优化。我们要做到的是视频完整下载过一次之后，就将视频文件保存到本地，下一次再播放时就可以播放本地缓存视频，不再请求网络数据，从而快速播放视频。这就需要在播放器和网络视频服务器之间加一层视频文件加载的机制，在播放视频之前先检测本地是否已经缓存视频，如果有就直接播放，没有再去获取视频数据。

苹果为我们提供了一种本地代理的方案，AVURLAsset 有个 AVAssetResourceLoader属性，通过其代理AVAssetResourceLoaderDelegate让播放器不再直接向视频URL服务器请求数据，而是向这个delegate询问数据。需要注意的时， AVAssetResourceLoader属性只有在custom URL schemes的AVURLAsset时才会调用其代理方法。因此， 在初始化AVURLAsset时需要先将视频的URL协议转换为一个自定义的协议，比如将视频url的http协议改为自定义的stream协议，这样，通过修改后的URL请求视频数据时，AVAssetResourceLoaderDelegate的代理方法就会被调用到，在代理方法里再向服务器请求数据，最后将数据转发给播放器。
播放器部分代码如下：<pre><code>
@property (nonatomic, strong) AVPlayer  *player;
@property (nonatomic, strong) AVPlayerItem  *currentPlayerItem;
@property (nonatomic, strong) AVPlayerLayer  *currentPlayerLayer;
@property (nonatomic, weak  ) UIView  *containerView;
@property (nonatomic, strong) AVURLAsset   *videoURLAsset;
@property (nonatomic, strong) ResourceLoader *resourceLoader;

if ([self isVideoExistsWithURL:videoURL]) {
    //本地已经缓存视频
    self.videoURLAsset = [AVURLAsset URLAssetWithURL:videoURL options:nil];
    self.currentPlayerItem = [AVPlayerItem playerItemWithAsset:self.videoURLAsset];
    self.player = [AVPlayer playerWithPlayerItem:self.currentPlayerItem];
    self.currentPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.currentPlayerLayer.frame = containerView.bounds;//这里的containerView是指播放器要在哪个view上显示视频
   [containerView.layer addSublayer:self.currentPlayerLayer];
} else {
    //通过AVAssetResourceLoaderDelegate加载视频
    self.resourceLoader = [[ResourceLoader alloc] init];
    self.resourceLoader.delegate = self;
    self.videoURLAsset = [AVURLAsset URLAssetWithURL:[self customSchemeURL:videoURL] options:nil];
    [self.videoURLAsset.resourceLoader setDelegate:self.resourceLoader queue:dispatch_get_main_queue()];
    self.currentPlayerItem = [AVPlayerItem playerItemWithAsset:self.videoURLAsset];
    self.player = [AVPlayer playerWithPlayerItem:self.currentPlayerItem];
    self.currentPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.currentPlayerLayer.frame = view.bounds;
}
</code></pre>
ResourceLoader实现的AVAssetResourceLoaderDelegate代理方法如下:
<pre><code>
- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    [self addLoadingRequest:loadingRequest];
    return YES;
}
</code></pre>
  
当视频播放器要加载视频时就通过这个代理方法发起一个AVAssetResourceLoadingRequest请求，AVAssetResourceLoadingRequest的dataRequest中的requestedOffset和requestedLength就是一次请求播放要播放的起始点和播放长度，只要向该请求提供数据就实现视频的分段播放。 这个代理方法会被调用多次以请求不同片段的视频数据。在实际过程中，我们会保存这些请求，然后在请求的数据响应完毕后再移除这些请求。接下来就是我们要获取视频数据提供给这些请求了。在第一次请求播放时，需要向视频URL服务器发起下载请求。
ResourceLoader部分代码如下：
<pre><code>
- (void)addLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    [self.requestList addObject:loadingRequest];//保存播放器的数据请求
    @synchronized(self) {
        if (self.requestTask) {
            if (loadingRequest.dataRequest.requestedOffset >= self.requestTask.requestOffset && //requestTask.requestOffset表示开始下载的起始点
                loadingRequest.dataRequest.requestedOffset <= self.requestTask.requestOffset + self.requestTask.cacheLength) {
                //数据已经缓存，则直接完成
                [self processRequestList];
            }
        } else {
               //播放器第一次请求数据时开启下载任务
            [self newTaskWithLoadingRequest:loadingRequest cache:YES];
        }
    }
}
- (void)newTaskWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest cache:(BOOL)cache {
    NSUInteger fileLength = 0;
    self.requestTask = [[RequestTask alloc] init];
    self.requestTask.requestURL = loadingRequest.request.URL;
    self.requestTask.requestOffset = (NSUInteger)loadingRequest.dataRequest.requestedOffset;
    self.requestTask.cache = cache;
    if (fileLength > 0) {
        self.requestTask.fileLength = fileLength;
    }
    self.requestTask.delegate = self;
    [self.requestTask start];
}
</code></pre>
iOS系统提供两种下载数据的任务：NSURLSessionDownloadTask和NSURLSessionDataTask。
<ul>
<li>NSURLSessionDownloadTask可以在取消任务的时候返回已下载的数据，保存这份数据下次就可以恢复继续断点下载，但NSURLSessionDownloadTask 在下载完成之前无法获得已下载的数据，其NSURLSessionDownloadDelegate代理方法didFinishDownloadingToURL:(NSURL *)location 只在下载完成之后返回一个位于沙盒tmp目录下的location地址，下载完后还需要自己把这个文件移到自定义的目录位置否则会被自动删除掉。</li>
<li>NSURLSessionDataTask 通过设置NSURLSessionDataDelegate 代理有一个didReceiveData:(NSData *)data方法可以拿到每次分段下载的数据，将这个数据保存后就可以提供给播放器播放，在需要断点下载时只需读取这个已经下载的数据文件，取得长度，并通过设置http 协议请求头的Range字段即可指定从网络下载数据包的位置和大小。这里我们选择NSURLSessionDataTask作为视频文件的下载方式。RequestTask部分代码如下：</li>
</ul>
<pre><code>
//开始下载
- (void)start
{
NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:videoURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:kRequestTimeout];
if (![[NSFileManager defaultManager] fileExistsAtPath:self.tempFilePath]) {
    //没下载过，创建一个保存下载数据的临时文件，在下载完成后要将此临时文件移至视频缓存目录
    [[NSFileManager defaultManager] createFileAtPath:self.tempFilePath contents:nil attributes:nil];
} else {
     //已经下载过，获取计算已下载的长度再断点续传
    NSData *resumeData = [[NSData alloc] initWithContentsOfFile:tempFilePath];
    NSUInteger resumeOffset = resumeData.length;
    if (resumeOffset > 0) {
        self.cacheLength += resumeData.length;//总共已下载的数据
        [request addValue:[NSString stringWithFormat:@"bytes=%ld-%ld", (unsigned long)resumeOffset, (unsigned long)self.fileLength - 1] forHTTPHeaderField:@"Range"];
    }
}
[request setValue:@"video/mp4" forHTTPHeaderField:@"Content-Type"];
NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
[self.session invalidateAndCancel];
self.operationQueue = [NSOperationQueue new];                //自定义队列
self.operationQueue.maxConcurrentOperationCount = 1;    //1表示串行队列
//这里的delegateQueue为自定义的串行队列，表示NSURLSession代理方法将会在独立线程中执行，从而实现多线程下载
self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:self.operationQueue];
self.task = [self.session dataTaskWithRequest:request];
[self.task resume];
}
//服务器响应请求
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
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
            GTMLoggerError(@"******* response not return video mime type!!!");
            [self retry];
            return;
        }
    }
    if (!self.writeFileHandle) {
        // 创建一个用来写数据的文件句柄对象
        self.writeFileHandle = [NSFileHandle fileHandleForWritingAtPath:self.tempFilePath];
    }
}

//服务器返回数据 可能会调用多次
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self.writeFileHandle seekToEndOfFile];     // 移动到文件的最后面
    [self.writeFileHandle writeData:data];        //写入数据到文件，由于session代理队列为自定义队列，所以这里是在后台主线程操作
    self.cacheLength += data.length;
   dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(requestTaskDidUpdateCache)]) {
            [self.delegate requestTaskDidUpdateCache];
        }
    });
}
//请求完成会调用该方法，请求失败则error有值
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (!error) {
        //下载完后将临时文件移至缓存目录
        [self cacheTempFileWithURL:self.requestURL];
    }
    //关闭文件
    [self.writeFileHandle closeFile];
    self.writeFileHandle = nil;
}
</code></pre>
在上面的didReceiveData:(NSData *)data方法中，我们将下载的数据保存到一个临时文件tempFilePath中，然后通过requestTaskDidUpdateCache 方法，在ResourceLoader中读取数据并播放已下载的视频片段。代码如下：
<pre><code>
- (void)requestTaskDidUpdateCache {
    [self processRequestList];//处理之前保存的播放器的数据请求
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
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(@"video/mp4"), NULL);
    loadingRequest.contentInformationRequest.contentType = CFBridgingRelease(contentType);//要加载的视频文件格式
    loadingRequest.contentInformationRequest.byteRangeAccessSupported = YES;
    loadingRequest.contentInformationRequest.contentLength = self.requestTask.fileLength;//视频总长度

    //读文件，填充数据
    NSUInteger cacheLength = self.requestTask.cacheLength;
    NSUInteger startOffset = (NSUInteger)loadingRequest.dataRequest.requestedOffset;//播放器请求起始点
    if (loadingRequest.dataRequest.currentOffset != 0) {
        startOffset = (NSUInteger)loadingRequest.dataRequest.currentOffset;//播放器开始播放的起始点
    }
    NSUInteger canReadLength = cacheLength - startOffset;
    NSUInteger respondLength = MIN(canReadLength, loadingRequest.dataRequest.requestedLength);

    if ([AppUtils isFileExist:self.tempFilePath]) {
        if (!self.readFileHandle) {
            self.readFileHandle = [NSFileHandle fileHandleForReadingAtPath:self.tempFilePath];
        }
        [self.readFileHandle seekToFileOffset:startOffset];
        NSData *data = [self.readFileHandle readDataOfLength:respondLength];//读取下载的视频数据
        [loadingRequest.dataRequest respondWithData:data];//加载视频数据
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
</code></pre>
至此，我们已经实现一个简单的边下边播播放器，根据URL初始化播放器之后调用 [self.player play] 就可以播放在线网络视频了。
