//
//  PipLyricsManager.m
//  PipLyricsManagerDemo
//
//  Created by 王贵彬 on 2022/7/11.
//

#import "PipLyricsManager.h"
#import "Masonry.h"

@interface PipLyricsManager ()<NSURLSessionDelegate,AVPictureInPictureControllerDelegate>

@property (nonatomic) NSURLSession *session;
@property (nonatomic) NSURLSessionDownloadTask *downloadTask;
@property (nonatomic) BOOL isBackGround;

@property (nonatomic, strong) UIView *customView;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) CADisplayLink *displayLink;

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *videoLayer;
@property (nonatomic, strong) AVPictureInPictureController *pipVC;


@end

@implementation PipLyricsManager{
    UIBackgroundTaskIdentifier *bgTask;
}

+ (PipLyricsManager *)shareTool{
    static PipLyricsManager *__tool;
    static dispatch_once_t instanceToken;
    dispatch_once(&instanceToken, ^{
        __tool = [[self alloc] init];
        [__tool initConfig];
    });
    return __tool;
}

- (void)initConfig{
    self.pipType = PipLyricsTypeSingleLine;
}

- (void)showPipWithPlayerLayer:(AVPlayerLayer *)playerLayer{
    [self stopPictureInPicture];
    if ([AVPictureInPictureController isPictureInPictureSupported]) {
        NSError *error = nil;
        @try {
            if (@available(iOS 10.0, *)) {
                [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeSpokenAudio options:AVAudioSessionCategoryOptionInterruptSpokenAudioAndMixWithOthers error:&error];
            } else {
                // Fallback on earlier versions
                [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
            }
            [[AVAudioSession sharedInstance] setActive:YES error:&error];
        } @catch (NSException *exception) {
            NSLog(@"AVAudioSession发生错误 %@",error);
        }
        self.pipVC = [[AVPictureInPictureController alloc] initWithPlayerLayer:playerLayer];
        if (@available(iOS 14.2, *)) {
            self.pipVC.canStartPictureInPictureAutomaticallyFromInline = YES;
        } else {
            // Fallback on earlier versions
        }
        self.pipVC.delegate = self;
    }
}

- (void)showLyricsWithSuperView:(UIView *)superView{
    [self stopPictureInPicture];
    self.isShowLyrics = YES;
    if (!superView) {
        return;
    }
    [self setupPipWithSuperView:superView];
    [self setupCustomView];
}

- (void)startPictureInPicture{
    [self.pipVC startPictureInPicture];
}

- (void)stopPictureInPicture{
    [self.pipVC stopPictureInPicture];
    [self dismiss];
}

- (void)dismiss{
    [self stopDisplayLink];
    if (self.customView) {
        [self.customView removeFromSuperview];
    }
}

- (void)showConsoleLogWithSuperView:(UIView *)superView{
    [self stopPictureInPicture];
    self.isConsoleLog = YES;
    if (!superView) {
        return;
    }
    [self setupPipWithSuperView:superView];
    self.customView = [[UIView alloc] init];
    self.customView.backgroundColor = [UIColor blackColor];
    self.textView = [[UITextView alloc] initWithFrame:CGRectZero];
    [self.customView addSubview:self.textView];
    self.textView.font = [UIFont systemFontOfSize:12];
    self.textView.textColor = [UIColor greenColor];
    self.textView.backgroundColor = [UIColor blackColor];
    self.textView.textAlignment = NSTextAlignmentLeft;
    self.textView.userInteractionEnabled = NO;
    [self.textView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(self.customView);
    }];
}

- (void)addLastLineText:(NSString *)text{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isConsoleLog) {
            // 控制台日志模式：直接设置文本
            self.textView.text = text;
        } else if (self.isShowLyrics) {
            // 歌词模式：需要更新整个显示内容
            [self updateLyricsDisplayWithText:text];
        }
    });
}

- (void)updateLyricsDisplayWithText:(NSString *)text {
    if (!text) {
        text = @"♪";
    }
    
    // 更新 textView 的内容和样式
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineSpacing = self.lineSpacing ?: 15;
    paragraphStyle.alignment = self.alignment ?: NSTextAlignmentCenter;
    
    NSDictionary *attributes = @{
        NSFontAttributeName: self.textFont ?: [UIFont boldSystemFontOfSize:20],
        NSParagraphStyleAttributeName: paragraphStyle,
        NSForegroundColorAttributeName: self.textColor ?: [UIColor whiteColor],
    };
    
    self.textView.attributedText = [[NSAttributedString alloc] initWithString:text attributes:attributes];
    
    // 强制刷新视图
    [self.textView layoutIfNeeded];
    [self.customView layoutIfNeeded];
    
    // 如果需要，可以触发重绘
    [self.textView setNeedsLayout];
    [self.customView setNeedsLayout];
}

- (void)setupPipWithSuperView:(UIView *)superView{
    CGFloat rateScale = 1000.0/416.0;
    CGFloat videoWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat videoHeight = videoWidth/rateScale;
    NSString *path = [[NSBundle mainBundle] pathForResource:@(self.pipType).stringValue ofType:@"mov"];
    NSURL *fileURL = [NSURL fileURLWithPath:path];
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:fileURL];
    AVPlayer *player = [AVPlayer playerWithPlayerItem:item];
    player.muted = YES;
    AVPlayerLayer *videoLayer = [AVPlayerLayer playerLayerWithPlayer:player];
    videoLayer.opacity = 0.0f;
    self.videoLayer = videoLayer;
    videoLayer.frame = CGRectMake(0, 0, videoWidth , videoHeight);
    videoLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [superView.layer addSublayer:videoLayer];
    [player play];
    self.player = player;
    
    if ([AVPictureInPictureController isPictureInPictureSupported]) {
//        NSError *error = nil;
//        @try {
//            if (@available(iOS 10.0, *)) {
//                [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeMoviePlayback options:AVAudioSessionCategoryOptionInterruptSpokenAudioAndMixWithOthers error:&error];
//            } else {
//                // Fallback on earlier versions
//                [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
//            }
//            [[AVAudioSession sharedInstance] setActive:YES error:&error];
//        } @catch (NSException *exception) {
//            NSLog(@"AVAudioSession发生错误 %@",error);
//        }
        self.pipVC = [[AVPictureInPictureController alloc] initWithPlayerLayer:self.videoLayer];
        self.pipVC.delegate = self;
        // 使用 KVC，隐藏播放按钮、快进快退按钮
        [self.pipVC setValue:@(1) forKey:@"controlsStyle"];
    }
}

- (void)setupCustomView {
    self.customView = [[UIView alloc] init];
    self.customView.backgroundColor = self.backgroundColor? : [UIColor blackColor];
    UIWindow *firstWindow = [UIApplication sharedApplication].windows.firstObject;
    [firstWindow addSubview:self.customView];

    NSString *text = self.text? : @"默认文本";
    self.textView = [[UITextView alloc] initWithFrame:CGRectZero];
    [self.customView addSubview:self.textView];
    self.textView.textAlignment = NSTextAlignmentCenter;
    self.textView.backgroundColor = [UIColor clearColor]; // 改为透明背景
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineSpacing = self.lineSpacing? : 15;// 字体的行间距
    paragraphStyle.alignment = self.alignment? : NSTextAlignmentCenter;
    NSDictionary *attributes = @{
        NSFontAttributeName:self.textFont? : [UIFont boldSystemFontOfSize:20],
                                 NSParagraphStyleAttributeName:paragraphStyle,
        NSForegroundColorAttributeName : self.textColor? : [UIColor whiteColor],
                                 };
    self.textView.attributedText = self.attributeText? : [[NSAttributedString alloc] initWithString:text? : @"" attributes:attributes];
    self.textView.userInteractionEnabled = NO;
    self.textView.scrollEnabled = NO; // 禁止滚动
    self.textView.showsVerticalScrollIndicator = NO;
    self.textView.showsHorizontalScrollIndicator = NO;
    
    [self.textView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(self.customView);
    }];
    
    NSLog(@"🎵 Custom view setup completed for PiP lyrics");
}


- (void)startDisplayLink {
    [self stopDisplayLink];
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(move)];
    if (@available(iOS 10.0, *))  {
        self.displayLink.preferredFramesPerSecond = self.preferredFramesPerSecond? : 24;
    }else{
        self.displayLink.frameInterval = (60/self.preferredFramesPerSecond)? : 3;
    }
    NSRunLoop *currentRunloop = [NSRunLoop currentRunLoop];
    // 使用常驻线程
    [currentRunloop addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
    [self.displayLink addToRunLoop:currentRunloop forMode:NSDefaultRunLoopMode];
}

// 关闭DisplayLink
- (void)stopDisplayLink {
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}

#pragma - mark 移动
- (void)move {
    if (self.pipType == PipLyricsTypeSingleLine) {
        return;
    }
    self.textView.contentOffset = CGPointMake(0, self.textView.contentOffset.y+1);
    if (self.textView.contentOffset.y > self.textView.contentSize.height) {
        self.textView.contentOffset = CGPointZero;
    }
}

#pragma mark - 旋转
- (void)rotate {
    static CGFloat angle = 0;
    angle += 0.5;
    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    window.transform = CGAffineTransformMakeRotation(M_PI * angle);
    
    AVPlayerItem * currentItem = self.pipVC.playerLayer.player.currentItem;
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"2" withExtension:@"mov"];
    AVAsset *asset = [AVAsset assetWithURL:url];
    AVPlayerItem * item = [[AVPlayerItem alloc] initWithAsset:asset];
    [self.pipVC.playerLayer.player replaceCurrentItemWithPlayerItem:item];
    [self.pipVC.playerLayer.player replaceCurrentItemWithPlayerItem:currentItem];
    
    [self.customView removeFromSuperview];
    [window addSubview:self.customView];
    [self.customView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(window);
    }];
}

- (void)transformWithPipType:(PipLyricsType)pipType {
    self.pipType = pipType;
    NSString *videoName = @(pipType).stringValue;
    NSURL *url = [[NSBundle mainBundle] URLForResource:videoName withExtension:@"mov"];
    AVAsset *asset = [AVAsset assetWithURL:url];
    AVPlayerItem * item = [[AVPlayerItem alloc] initWithAsset:asset];
    [self.pipVC.playerLayer.player replaceCurrentItemWithPlayerItem:item];
}

// 即将开启画中画
- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    NSLog(@"🎵 PiP will start - isShowLyrics: %@, isConsoleLog: %@", @(self.isShowLyrics), @(self.isConsoleLog));
    
    if (self.isShowLyrics || self.isConsoleLog) {
        UIWindow *firstWindow = [UIApplication sharedApplication].windows.firstObject;
        [firstWindow addSubview:self.customView];
        [self.customView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.edges.mas_equalTo(firstWindow);
        }];
        NSLog(@"🎵 Custom view added to window for PiP display");
    }
}
// 已经开启画中画
- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    self.isInPip = YES;
    NSLog(@"🎵 PiP did start - isShowLyrics: %@", @(self.isShowLyrics));
    
    if (self.isShowLyrics) {
        [self startDisplayLink];
        NSLog(@"🎵 Display link started for lyrics animation");
    }
}
// 开启画中画失败
- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController failedToStartPictureInPictureWithError:(NSError *)error {
    self.isInPip = NO;
    self.isConsoleLog = NO;
    self.isShowLyrics = NO;
    [self stopPictureInPicture];
    NSLog(@"开启画中画失败: %@",error);
}
// 即将关闭画中画
- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    [self dismiss];
}
// 已经关闭画中画
- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    if (!self.isConsoleLog && !self.isShowLyrics) {
        //播放视频的话 关闭画中画时恢复到播放器播放
        [pictureInPictureController.playerLayer.player play];
    }
    self.isInPip = NO;
    self.isConsoleLog = NO;
    self.isShowLyrics = NO;
}

// 关闭画中画且恢复播放界面
- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
    self.isInPip = NO;
    completionHandler(YES);
}



@end
