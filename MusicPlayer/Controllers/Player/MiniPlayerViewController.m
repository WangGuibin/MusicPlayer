//
//  MiniPlayerViewController.m
//  MusicPlayer
//
//  Created by Gemini on 2025/9/5.
//

#import "MiniPlayerViewController.h"
#import "MusicPlayerController.h"
#import "PlayerViewController.h"
#import "MusicAPIManager.h"
#import "MusicImageCacheManager.h"
#import <Masonry/Masonry.h>
#import <SDWebImage/UIImageView+WebCache.h>

@interface MiniPlayerViewController () 

@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIImageView *albumImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, strong) UIView *spectrumView;

@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) NSMutableArray<CAShapeLayer *> *spectrumLayers;

// Interactive transition properties
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
@property (nonatomic, strong) PlayerViewController *playerViewController;
@property (nonatomic, assign) BOOL isTransitioning;
@property (nonatomic, assign) CGFloat initialTranslation;

// Snapshot transition properties
@property (nonatomic, strong) UIImageView *backgroundSnapshotView;
@property (nonatomic, strong) UIImage *cachedBackgroundSnapshot;

@end

@implementation MiniPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self setupSpectrum];
    [self setupGestures];
    
    [self addPlayerObservers];
    [self updateForPlayerState];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // Cache background snapshot for smooth transitions
    [self cacheBackgroundSnapshot];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // Clear cached snapshot to free memory
    [self clearBackgroundSnapshot];
}

- (void)dealloc {
    [self removePlayerObservers];
    [_displayLink invalidate];
}

#pragma mark - Observers

- (void)addPlayerObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerDidStartPlaying:) name:MusicPlayerDidStartPlayingNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerDidPause:) name:MusicPlayerDidPauseNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerDidResume:) name:MusicPlayerDidResumeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerDidStop:) name:MusicPlayerDidStopNotification object:nil];
}

- (void)removePlayerObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notification Handlers

- (void)playerDidStartPlaying:(NSNotification *)notification {
    [self updateForPlayerState];
}

- (void)playerDidPause:(NSNotification *)notification {
    [self updatePlayPauseButtonState];
    [self pauseAlbumArtRotation];
}

- (void)playerDidResume:(NSNotification *)notification {
    [self updatePlayPauseButtonState]; 
    [self startAlbumArtRotation];
}

- (void)playerDidStop:(NSNotification *)notification {
    [self updateForPlayerState];
    [self stopAlbumArtRotation];
}

#pragma mark - UI

- (void)setupUI {
    self.view.backgroundColor = [UIColor clearColor];
    self.view.clipsToBounds = YES;

    self.blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    [self.view addSubview:self.blurView];
    [self.blurView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];

    self.albumImageView = [[UIImageView alloc] init];
    self.albumImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.albumImageView.layer.cornerRadius = 22;
    self.albumImageView.layer.masksToBounds = YES;
    [self.view addSubview:self.albumImageView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.textColor = [UIColor whiteColor];
    
    // 根据屏幕大小调整字体
    CGFloat screenWidth = [[UIScreen mainScreen] bounds].size.width;
    CGFloat fontSize = 14;
    if (screenWidth > 834) { // iPad/Mac
        fontSize = 17;
    } else if (screenWidth > 600) { // iPad Mini
        fontSize = 15;
    }
    
    self.titleLabel.font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightMedium];
    [self.view addSubview:self.titleLabel];

    self.playPauseButton = [self createButtonWithImageName:@"play.fill" action:@selector(playPauseTapped)];
    self.nextButton = [self createButtonWithImageName:@"forward.end.fill" action:@selector(nextTapped)];
    
    self.spectrumView = [[UIView alloc] init];
    [self.view addSubview:self.spectrumView];

    [self.albumImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(25);
        make.top.equalTo(self.view).offset(10);
        make.width.height.equalTo(@44);
    }];

    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.albumImageView.mas_right).offset(12);
        make.centerY.equalTo(self.albumImageView);
        make.right.equalTo(self.spectrumView.mas_left).offset(-12);
    }];
    
    [self.nextButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.view).offset(-25);
        make.centerY.equalTo(self.albumImageView);
        make.width.height.equalTo(@40);
    }];

    [self.playPauseButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.nextButton.mas_left).offset(-5);
        make.centerY.equalTo(self.albumImageView);
        make.width.height.equalTo(@40);
    }];
    
    [self.spectrumView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.playPauseButton.mas_left).offset(-10);
        make.centerY.equalTo(self.view);
        make.width.equalTo(@24);
        make.height.equalTo(@20);
    }];
}

- (UIButton *)createButtonWithImageName:(NSString *)name action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:[UIImage systemImageNamed:name] forState:UIControlStateNormal];
    button.tintColor = [UIColor whiteColor];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    return button;
}

#pragma mark - Public Methods

- (void)updateForPlayerState {
    MusicPlayerController *player = [MusicPlayerController sharedController];
    self.view.hidden = (player.currentTrack == nil);

    if (player.currentTrack) {
        self.titleLabel.text = [NSString stringWithFormat:@"%@ - %@", player.currentTrack.name, [player.currentTrack.artist componentsJoinedByString:@", "]];
        [self updateAlbumArt];
        [self updatePlayPauseButtonState];
    }
}

- (void)updateAlbumArt {
    MusicModel *track = [MusicPlayerController sharedController].currentTrack;
    
    // Set placeholder image first  
    UIImage *placeholderImage = [UIImage systemImageNamed:@"music.note"];
    if (@available(iOS 13.0, *)) {
        placeholderImage = [placeholderImage imageWithTintColor:[UIColor colorWithWhite:1.0 alpha:0.4]];
    }
    self.albumImageView.image = placeholderImage;
    self.albumImageView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    
    // 取消之前的图片加载
    [self.albumImageView sd_cancelCurrentImageLoad];
    
    if (track.picId) {
        // 使用缓存管理器获取图片URL
        [[MusicImageCacheManager sharedManager] getImageURLWithPicId:track.picId 
                                                               source:track.source 
                                                                 size:MusicImageSizeSmall 
                                                           completion:^(NSString * _Nullable imageUrl, NSError * _Nullable error) {
            if (imageUrl) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 检查是否还是同一首歌
                    MusicModel *currentTrack = [MusicPlayerController sharedController].currentTrack;
                    if (currentTrack && [currentTrack.trackId isEqualToString:track.trackId]) {
                        [self.albumImageView sd_setImageWithURL:[NSURL URLWithString:imageUrl] 
                                                placeholderImage:placeholderImage
                                                         options:SDWebImageRetryFailed | SDWebImageRefreshCached
                                                       completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
                            if (image) {
                                self.albumImageView.backgroundColor = [UIColor clearColor];
                                // 检查是否需要启动旋转动画
                                if ([MusicPlayerController sharedController].isPlaying) {
                                    [self startAlbumArtRotation];
                                }
                            } else if (error) {
                                NSLog(@"Failed to load mini player album art: %@", error.localizedDescription);
                            }
                        }];
                    }
                });
            }
        }];
    }
    
    // 立即更新播放状态
    [self updatePlayPauseButtonState];
}

- (void)updatePlayPauseButtonState {
    BOOL isPlaying = [MusicPlayerController sharedController].isPlaying;
    NSString *imageName = isPlaying ? @"pause.fill" : @"play.fill";
    [self.playPauseButton setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
    
    if (isPlaying) {
        [self startSpectrumAnimation];
        [self startAlbumArtRotation];
    } else {
        [self stopSpectrumAnimation];
        [self pauseAlbumArtRotation];
    }
}

#pragma mark - Gesture Setup

- (void)setupGestures {
    // Keep tap gesture for quick access
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewTapped)];
    [self.view addGestureRecognizer:tap];
    
    // Add pan gesture for interactive transition
    self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    self.panGesture.delegate = self;
    [self.view addGestureRecognizer:self.panGesture];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    // Allow tap and pan to work together for better responsiveness
    return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.panGesture) {
        CGPoint velocity = [(UIPanGestureRecognizer *)gestureRecognizer velocityInView:self.view];
        CGPoint translation = [(UIPanGestureRecognizer *)gestureRecognizer translationInView:self.view];
        
        // Much more responsive - any upward movement
        BOOL isUpwardGesture = velocity.y < 0 || translation.y < 0;
        return isUpwardGesture && !self.isTransitioning;
    }
    return YES;
}

#pragma mark - Snapshot Management

- (void)cacheBackgroundSnapshot {
    // Capture snapshot of the underlying view controller
    UIViewController *rootVC = self.parentViewController;
    if (rootVC && rootVC.view) {
        // Hide mini player temporarily for clean snapshot
        BOOL wasHidden = self.view.hidden;
        self.view.hidden = YES;
        
        // Take snapshot
        UIGraphicsBeginImageContextWithOptions(rootVC.view.bounds.size, YES, [UIScreen mainScreen].scale);
        [rootVC.view drawViewHierarchyInRect:rootVC.view.bounds afterScreenUpdates:NO];
        self.cachedBackgroundSnapshot = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        // Restore mini player visibility
        self.view.hidden = wasHidden;
    }
}

- (void)clearBackgroundSnapshot {
    self.cachedBackgroundSnapshot = nil;
    [self.backgroundSnapshotView removeFromSuperview];
    self.backgroundSnapshotView = nil;
}

- (void)setupSnapshotBackground {
    if (!self.cachedBackgroundSnapshot) {
        [self cacheBackgroundSnapshot];
    }
    
    if (self.cachedBackgroundSnapshot && !self.backgroundSnapshotView) {
        self.backgroundSnapshotView = [[UIImageView alloc] initWithImage:self.cachedBackgroundSnapshot];
        self.backgroundSnapshotView.contentMode = UIViewContentModeScaleAspectFill;
        self.backgroundSnapshotView.alpha = 0.0;
        
        UIViewController *rootVC = self.parentViewController;
        [rootVC.view insertSubview:self.backgroundSnapshotView atIndex:0];
        self.backgroundSnapshotView.frame = rootVC.view.bounds;
    }
}

#pragma mark - Actions

- (void)viewTapped {
    [self presentFullScreenPlayer];
}

- (void)presentFullScreenPlayer {
    if (self.isTransitioning) return;
    
    PlayerViewController *playerVC = [[PlayerViewController alloc] init];
    playerVC.modalPresentationStyle = UIModalPresentationFullScreen;
    [self.parentViewController presentViewController:playerVC animated:YES completion:nil];
}

- (void)playPauseTapped {
    if ([MusicPlayerController sharedController].isPlaying) {
        [[MusicPlayerController sharedController] pause];
    } else {
        [[MusicPlayerController sharedController] play];
    }
}

- (void)nextTapped {
    [[MusicPlayerController sharedController] playNextTrack];
}

#pragma mark - Spectrum Animation

- (void)setupSpectrum {
    self.spectrumLayers = [NSMutableArray array];
    int barCount = 4;
    CGFloat barWidth = 4.0;
    CGFloat barSpacing = 2.0;
    for (int i = 0; i < barCount; i++) {
        CAShapeLayer *layer = [CAShapeLayer layer];
        layer.frame = CGRectMake(i * (barWidth + barSpacing), 0, barWidth, self.spectrumView.bounds.size.height);
        layer.backgroundColor = [UIColor colorWithRed:30/255.0 green:215/255.0 blue:96/255.0 alpha:1.0].CGColor;
        [self.spectrumView.layer addSublayer:layer];
        [self.spectrumLayers addObject:layer];
    }
}

- (void)startSpectrumAnimation {
    if (self.displayLink) return;
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateSpectrum)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopSpectrumAnimation {
    [self.displayLink invalidate];
    self.displayLink = nil;
    // Reset to a default state
    for (CAShapeLayer *layer in self.spectrumLayers) {
        layer.transform = CATransform3DMakeScale(1.0, 0.1, 1.0);
    }
}

- (void)updateSpectrum {
    for (CAShapeLayer *layer in self.spectrumLayers) {
        CGFloat randomHeightScale = (arc4random_uniform(100) / 100.0f);
        layer.transform = CATransform3DMakeScale(1.0, randomHeightScale, 1.0);
    }
}

#pragma mark - Album Art Animation

- (void)startAlbumArtRotation {
    // 检查是否已经有动画并且在运行
    CAAnimation *existingAnimation = [self.albumImageView.layer animationForKey:@"rotationAnimation"];
    if (existingAnimation && self.albumImageView.layer.speed > 0) {
        // 动画已经在运行，无需重复添加
        return;
    }
    
    // 如果动画被暂停了，恢复它
    if (existingAnimation && self.albumImageView.layer.speed == 0) {
        [self resumeAlbumArtRotation];
        return;
    }
    
    // 移除旧动画并创建新动画
    [self.albumImageView.layer removeAnimationForKey:@"rotationAnimation"];
    
    CABasicAnimation *rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotationAnimation.toValue = @(M_PI * 2.0);
    rotationAnimation.duration = 20.0;
    rotationAnimation.cumulative = YES;
    rotationAnimation.repeatCount = HUGE_VALF;
    rotationAnimation.removedOnCompletion = NO;
    rotationAnimation.fillMode = kCAFillModeForwards;
    
    // 确保动画在主线程添加
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.albumImageView.layer addAnimation:rotationAnimation forKey:@"rotationAnimation"];
    });
    
    NSLog(@"🎵 [MiniPlayer] Started rotation animation");
}

- (void)pauseAlbumArtRotation {
    CALayer *layer = self.albumImageView.layer;
    if (layer.speed == 0) {
        // Already paused
        return;
    }
    
    CFTimeInterval pausedTime = [layer convertTime:CACurrentMediaTime() fromLayer:nil];
    layer.speed = 0.0;
    layer.timeOffset = pausedTime;
    
    NSLog(@"🎵 [MiniPlayer] Paused rotation animation");
}

- (void)resumeAlbumArtRotation {
    CALayer *layer = self.albumImageView.layer;
    if (layer.speed > 0) {
        // Already running
        return;
    }
    
    CFTimeInterval pausedTime = layer.timeOffset;
    layer.speed = 1.0;
    layer.timeOffset = 0.0;
    layer.beginTime = 0.0;
    CFTimeInterval timeSincePause = [layer convertTime:CACurrentMediaTime() fromLayer:nil] - pausedTime;
    layer.beginTime = timeSincePause;
    
    NSLog(@"🎵 [MiniPlayer] Resumed rotation animation");
}

- (void)stopAlbumArtRotation {
    [self.albumImageView.layer removeAnimationForKey:@"rotationAnimation"];
    // 重置layer状态
    self.albumImageView.layer.speed = 1.0;
    self.albumImageView.layer.timeOffset = 0.0;
    self.albumImageView.layer.beginTime = 0.0;
    
    NSLog(@"🎵 [MiniPlayer] Stopped rotation animation");
}

#pragma mark - Interactive Transition

- (void)handlePanGesture:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.view];
    CGPoint velocity = [gesture velocityInView:self.view];
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            // Much more lenient - any upward movement triggers
            if (velocity.y > 50 && translation.y > 5) {
                gesture.state = UIGestureRecognizerStateCancelled;
                return;
            }
            
            self.isTransitioning = YES;
            self.initialTranslation = translation.y;
            
            // Setup background snapshot for smooth transition
            [self setupSnapshotBackground];
            
            // Create and setup player view controller
            self.playerViewController = [[PlayerViewController alloc] init];
            
            // Add player view as overlay with transparent background
            UIViewController *rootVC = self.parentViewController;
            [rootVC addChildViewController:self.playerViewController];
            [rootVC.view addSubview:self.playerViewController.view];
            [self.playerViewController didMoveToParentViewController:rootVC];
            
            // Initial setup for transition
            self.playerViewController.view.frame = rootVC.view.bounds;
            self.playerViewController.view.transform = CGAffineTransformMakeTranslation(0, rootVC.view.bounds.size.height);
            self.playerViewController.view.alpha = 0.0;
            
            // Add shadow to mini player during transition
            self.view.layer.shadowColor = [UIColor blackColor].CGColor;
            self.view.layer.shadowOffset = CGSizeMake(0, -2);
            self.view.layer.shadowOpacity = 0.0;
            self.view.layer.shadowRadius = 8;
            
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (!self.isTransitioning) return;
            
            // Calculate progress
            CGFloat screenHeight = self.view.window.rootViewController.view.bounds.size.height;
            CGFloat rawProgress = MAX(0, MIN(1, -translation.y / (screenHeight * 0.4)));
            CGFloat progress = [self easeOutCubic:rawProgress];
            
            // Update player view transform and alpha
            CGFloat translateY = screenHeight * (1 - progress);
            self.playerViewController.view.transform = CGAffineTransformMakeTranslation(0, translateY);
            self.playerViewController.view.alpha = MIN(1.0, progress * 1.2);
            
            // Update mini player scaling and alpha
            CGFloat miniPlayerScale = 1.0 - (progress * 0.03);
            CGFloat miniPlayerAlpha = 1.0 - (progress * 0.2);
            self.view.transform = CGAffineTransformMakeScale(miniPlayerScale, miniPlayerScale);
            self.view.alpha = miniPlayerAlpha;
            
            // Fade in background snapshot to cover window background
            if (self.backgroundSnapshotView) {
                self.backgroundSnapshotView.alpha = progress * 0.8; // Subtle background
            }
            
            // Update shadow
            self.view.layer.shadowOpacity = progress * 0.15;
            
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (!self.isTransitioning) return;
            
            CGFloat screenHeight = self.parentViewController.view.bounds.size.height;
            CGFloat rawProgress = MAX(0, MIN(1, -translation.y / (screenHeight * 0.4)));
            CGFloat progress = [self easeOutCubic:rawProgress];
            
            // More responsive completion threshold
            BOOL shouldComplete = progress > 0.15 || (velocity.y < -600 && progress > 0.05);
            
            if (shouldComplete) {
                // Complete transition to full screen
                [self completeTransitionToFullScreen];
            } else {
                // Cancel transition, return to mini player
                [self cancelTransitionToMiniPlayer];
            }
            
            break;
        }
        default:
            break;
    }
}

// Easing function for smoother animations
- (CGFloat)easeOutCubic:(CGFloat)t {
    CGFloat f = t - 1;
    return f * f * f + 1;
}

- (void)completeTransitionToFullScreen {
    [UIView animateWithDuration:0.6
                          delay:0
         usingSpringWithDamping:0.85
          initialSpringVelocity:0.3
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        // Animate player to full screen
        self.playerViewController.view.transform = CGAffineTransformIdentity;
        self.playerViewController.view.alpha = 1.0;
        
        // Hide mini player
        self.view.transform = CGAffineTransformMakeScale(0.97, 0.97);
        self.view.alpha = 0.0;
        self.view.layer.shadowOpacity = 0.0;
        
        // Fade out snapshot
        if (self.backgroundSnapshotView) {
            self.backgroundSnapshotView.alpha = 0.0;
        }
    } completion:^(BOOL finished) {
        self.isTransitioning = NO;
        
        // Reset mini player
        self.view.transform = CGAffineTransformIdentity;
        self.view.alpha = 1.0;
        self.view.layer.shadowOpacity = 0.0;
        
        // Clean up snapshot
        [self clearBackgroundSnapshot];
        
        // Convert to proper modal presentation
        [self.playerViewController willMoveToParentViewController:nil];
        [self.playerViewController.view removeFromSuperview];
        [self.playerViewController removeFromParentViewController];
        
        // Present using the correct presenting view controller
        self.playerViewController.modalPresentationStyle = UIModalPresentationFullScreen;
        
        // Find the correct view controller to present from 
        UIViewController *presentingVC = self.parentViewController;
        [presentingVC presentViewController:self.playerViewController animated:NO completion:nil];
        
        self.playerViewController = nil;
    }];
}

- (void)cancelTransitionToMiniPlayer {
    [UIView animateWithDuration:0.5
                          delay:0
         usingSpringWithDamping:0.85
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        // Return player to off-screen position
        CGFloat screenHeight = self.parentViewController.view.bounds.size.height;
        self.playerViewController.view.transform = CGAffineTransformMakeTranslation(0, screenHeight);
        self.playerViewController.view.alpha = 0.0;
        
        // Restore mini player
        self.view.transform = CGAffineTransformIdentity;
        self.view.alpha = 1.0;
        self.view.layer.shadowOpacity = 0.0;
        
        // Fade out snapshot
        if (self.backgroundSnapshotView) {
            self.backgroundSnapshotView.alpha = 0.0;
        }
    } completion:^(BOOL finished) {
        // Clean up player view controller
        [self.playerViewController willMoveToParentViewController:nil];
        [self.playerViewController.view removeFromSuperview];
        [self.playerViewController removeFromParentViewController];
        self.playerViewController = nil;
        
        // Clean up snapshot
        [self clearBackgroundSnapshot];
        
        self.isTransitioning = NO;
    }];
}

@end
