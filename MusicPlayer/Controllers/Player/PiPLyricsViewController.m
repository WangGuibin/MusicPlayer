//
//  PiPLyricsViewController.m
//  VodTV
//
//  Created by Claude on 2025/9/7.
//

#import "PiPLyricsViewController.h"
#import "MusicPlayerController.h"
#import "MusicAPIManager.h"
#import "MusicImageCacheManager.h"
#import <Masonry/Masonry.h>
#import <SDWebImage/UIImageView+WebCache.h>

@interface PiPLyricsViewController () <AVPictureInPictureControllerDelegate, AVPlayerItemMetadataOutputPushDelegate>

// Picture-in-Picture components
@property (nonatomic, strong) AVPlayer *pipPlayer;
@property (nonatomic, strong) AVPlayerLayer *pipPlayerLayer;
@property (nonatomic, strong) AVPictureInPictureController *pipController;
@property (nonatomic, strong) AVPlayerItem *loopingVideoItem;

// Custom overlay view for PiP window
@property (nonatomic, strong) UIView *pipOverlayView;
@property (nonatomic, strong) UILabel *songTitleLabel;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) UILabel *currentLyricsLabel;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UIButton *previousButton;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, strong) UISlider *progressSlider;
@property (nonatomic, strong) UIImageView *albumImageView;

// Video container for PiP
@property (nonatomic, strong) UIView *videoContainerView;

// Lyrics data
@property (nonatomic, strong) NSArray<NSDictionary *> *lyricsData;
@property (nonatomic, strong) NSTimer *lyricsUpdateTimer;
@property (nonatomic, assign) NSInteger currentLyricsIndex;

@end

@implementation PiPLyricsViewController

#pragma mark - Singleton

+ (instancetype)sharedController {
    static PiPLyricsViewController *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[PiPLyricsViewController alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self setupVideoPiP];
    [self addPlayerObservers];
    self.currentLyricsIndex = -1;
}

- (void)dealloc {
    [self removePlayerObservers];
    [self.lyricsUpdateTimer invalidate];
    if (self.pipController) {
        [self.pipController stopPictureInPicture];
        self.pipController = nil;
    }
    if (self.pipPlayer) {
        [self.pipPlayer pause];
        self.pipPlayer = nil;
    }
}

#pragma mark - System Picture-in-Picture Setup

- (void)setupVideoPiP {
    // Check if PiP is supported
    if (![AVPictureInPictureController isPictureInPictureSupported]) {
        NSLog(@"🎵 Picture-in-Picture not supported on this device");
        return;
    }
    
    // Create a simple looping video for PiP background
    [self createLoopingVideo];
    
    // Setup the player layer
    self.pipPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.pipPlayer];
    self.pipPlayerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    // Add to video container
    [self.videoContainerView.layer addSublayer:self.pipPlayerLayer];
    
    // Create PiP controller
    if (@available(iOS 15.0, *)) {
        // iOS 15.0+ supports video call content source, but our view controller must inherit from AVPictureInPictureVideoCallViewController
        // For now, use the simpler playerLayer approach for broader compatibility
        self.pipController = [[AVPictureInPictureController alloc] initWithPlayerLayer:self.pipPlayerLayer];
    } else {
        // Fallback for older iOS versions
        self.pipController = [[AVPictureInPictureController alloc] initWithPlayerLayer:self.pipPlayerLayer];
    }
    
    self.pipController.delegate = self;
    
    // Enable automatic PiP for music
    if (@available(iOS 14.2, *)) {
        self.pipController.canStartPictureInPictureAutomaticallyFromInline = YES;
    }
    
    NSLog(@"🎵 Video Picture-in-Picture setup completed");
}

- (void)createLoopingVideo {
    // Create a simple colored video or use a default music visualization video
    // For now, we'll create a simple solid color video that loops
    
    // You can replace this with an actual video file for music visualization
    NSURL *videoURL = [self createDefaultMusicVideoURL];
    
    if (videoURL) {
        self.loopingVideoItem = [AVPlayerItem playerItemWithURL:videoURL];
        self.pipPlayer = [AVPlayer playerWithPlayerItem:self.loopingVideoItem];
        
        // Setup looping
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playerItemDidReachEnd:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:self.loopingVideoItem];
        
        // Start playing the background video
        [self.pipPlayer play];
    } else {
        // Fallback: Create a basic video programmatically
        [self createProgrammaticVideo];
    }
}

- (NSURL *)createDefaultMusicVideoURL {
    // Look for a default music visualization video in the app bundle
    NSString *videoPath = [[NSBundle mainBundle] pathForResource:@"music_visualization" ofType:@"mp4"];
    if (videoPath) {
        return [NSURL fileURLWithPath:videoPath];
    }
    
    // Try alternative names
    NSArray *possibleNames = @[@"music_bg", @"pip_background", @"visualization"];
    for (NSString *name in possibleNames) {
        videoPath = [[NSBundle mainBundle] pathForResource:name ofType:@"mp4"];
        if (videoPath) {
            return [NSURL fileURLWithPath:videoPath];
        }
    }
    
    // Create a temporary simple video URL using a system approach
    // Note: For production, you should include a small video file in your app bundle
    // The video can be a simple black screen or music visualization
    // Recommended: Create a 5-second looping video file (320x180 or 640x360 resolution)
    
    NSLog(@"🎵 No music visualization video found in bundle");
    NSLog(@"🎵 Tip: Add a small .mp4 file named 'music_visualization.mp4' to your app bundle");
    NSLog(@"🎵 The video can be a simple black screen or music visualization animation");
    
    return nil;
}

- (void)createProgrammaticVideo {
    // Create a more sophisticated music visualization background
    // This creates a dynamic animated background suitable for PiP
    
    UIView *visualizationView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 180)];
    visualizationView.backgroundColor = [UIColor blackColor];
    
    // Create multiple gradient layers for dynamic effect
    NSArray *colors1 = @[
        (id)[UIColor colorWithRed:0.2 green:0.3 blue:0.8 alpha:0.8].CGColor,
        (id)[UIColor colorWithRed:0.8 green:0.2 blue:0.4 alpha:0.8].CGColor,
        (id)[UIColor colorWithRed:0.3 green:0.8 blue:0.2 alpha:0.8].CGColor
    ];
    
    NSArray *colors2 = @[
        (id)[UIColor colorWithRed:0.8 green:0.4 blue:0.2 alpha:0.6].CGColor,
        (id)[UIColor colorWithRed:0.4 green:0.8 blue:0.8 alpha:0.6].CGColor,
        (id)[UIColor colorWithRed:0.8 green:0.2 blue:0.8 alpha:0.6].CGColor
    ];
    
    // Create animated gradient layers
    for (int i = 0; i < 3; i++) {
        CAGradientLayer *gradientLayer = [CAGradientLayer layer];
        gradientLayer.frame = visualizationView.bounds;
        gradientLayer.colors = (i % 2 == 0) ? colors1 : colors2;
        gradientLayer.startPoint = CGPointMake(0, 0);
        gradientLayer.endPoint = CGPointMake(1, 1);
        gradientLayer.opacity = 0.4 + (i * 0.1);
        
        // Rotate each layer for variety
        gradientLayer.transform = CATransform3DMakeRotation(M_PI * i / 3, 0, 0, 1);
        
        [visualizationView.layer addSublayer:gradientLayer];
        
        // Add color animation (using CAKeyframeAnimation for values)
        CAKeyframeAnimation *colorAnimation = [CAKeyframeAnimation animationWithKeyPath:@"colors"];
        colorAnimation.values = @[colors1, colors2, colors1];
        colorAnimation.duration = 4.0 + i; // Different durations for each layer
        colorAnimation.repeatCount = INFINITY;
        colorAnimation.autoreverses = YES;
        [gradientLayer addAnimation:colorAnimation forKey:[NSString stringWithFormat:@"colorChange%d", i]];
        
        // Add rotation animation
        CABasicAnimation *rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        rotationAnimation.fromValue = @(M_PI * i / 3);
        rotationAnimation.toValue = @(M_PI * i / 3 + M_PI * 2);
        rotationAnimation.duration = 8.0 + (i * 2); // Different rotation speeds
        rotationAnimation.repeatCount = INFINITY;
        [gradientLayer addAnimation:rotationAnimation forKey:[NSString stringWithFormat:@"rotation%d", i]];
    }
    
    // Add some circular visual elements
    for (int i = 0; i < 5; i++) {
        UIView *circle = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 20 + i * 10, 20 + i * 10)];
        circle.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.1 + i * 0.05];
        circle.layer.cornerRadius = circle.frame.size.width / 2;
        circle.center = CGPointMake(50 + i * 40, 60 + (i % 2) * 60);
        [visualizationView addSubview:circle];
        
        // Add pulsing animation
        CABasicAnimation *pulseAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        pulseAnimation.fromValue = @0.8;
        pulseAnimation.toValue = @1.2;
        pulseAnimation.duration = 1.5 + i * 0.3;
        pulseAnimation.repeatCount = INFINITY;
        pulseAnimation.autoreverses = YES;
        [circle.layer addAnimation:pulseAnimation forKey:@"pulse"];
    }
    
    // Add a subtle overlay pattern
    CAGradientLayer *overlayGradient = [CAGradientLayer layer];
    overlayGradient.frame = visualizationView.bounds;
    overlayGradient.colors = @[
        (id)[UIColor clearColor].CGColor,
        (id)[[UIColor blackColor] colorWithAlphaComponent:0.3].CGColor,
        (id)[UIColor clearColor].CGColor
    ];
    overlayGradient.startPoint = CGPointMake(0, 0);
    overlayGradient.endPoint = CGPointMake(1, 1);
    [visualizationView.layer addSublayer:overlayGradient];
    
    [self.videoContainerView addSubview:visualizationView];
    
    // Create a simple AVPlayer with a solid color video for system PiP requirements
    // This is needed because the system requires an actual video for PiP to work
    [self createMinimalVideoPlayer];
}

- (void)createMinimalVideoPlayer {
    // Create a minimal AVPlayer for system PiP requirements
    // We'll create a simple single-color video programmatically
    
    // Create a player with a short looping black video
    // Note: In a real implementation, you'd want to include a minimal video file
    // For now, we'll create a basic player that can work with PiP
    
    // Create a dummy video URL (this would normally be a real video file)
    // For demonstration, we'll try to create a minimal video source
    NSURL *blackVideoURL = [self createBlackVideoURL];
    
    if (blackVideoURL) {
        self.loopingVideoItem = [AVPlayerItem playerItemWithURL:blackVideoURL];
        self.pipPlayer = [AVPlayer playerWithPlayerItem:self.loopingVideoItem];
        
        // Make video very quiet (muted)
        self.pipPlayer.volume = 0.0;
        
        // Setup looping
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playerItemDidReachEnd:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:self.loopingVideoItem];
        
        // Start playing the background video silently
        [self.pipPlayer play];
        
        NSLog(@"🎵 Created minimal video player for PiP");
    } else {
        NSLog(@"🎵 Warning: Could not create video player for PiP");
    }
}

- (NSURL *)createBlackVideoURL {
    // Look for any small video file in the bundle that can be used as background
    // This is a placeholder - you should add a small looping video file to your bundle
    
    NSArray *videoExtensions = @[@"mp4", @"mov", @"m4v"];
    NSArray *possibleNames = @[@"black", @"background", @"music_bg", @"pip_bg"];
    
    for (NSString *name in possibleNames) {
        for (NSString *ext in videoExtensions) {
            NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:ext];
            if (path) {
                return [NSURL fileURLWithPath:path];
            }
        }
    }
    
    // If no video file found, return nil and PiP might not work properly
    // In this case, you should add a small black video file to your app bundle
    NSLog(@"🎵 No background video found - PiP may not work. Please add a small video file.");
    return nil;
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    // Loop the video
    [self.pipPlayer seekToTime:kCMTimeZero];
    [self.pipPlayer play];
}

#pragma mark - Picture-in-Picture Control

- (BOOL)isPiPSupported {
    return [AVPictureInPictureController isPictureInPictureSupported];
}

- (void)startPiPMode {
    if (![self isPiPSupported]) {
        NSLog(@"🎵 Picture-in-Picture not supported on this device");
        return;
    }
    
    // Ensure we have a valid player and video content
    if (!self.pipPlayer || !self.pipController) {
        NSLog(@"🎵 PiP components not properly initialized");
        return;
    }
    
    // Update content before starting PiP
    [self updatePiPContent];
    
    // Start the background video if not already playing
    if (self.pipPlayer.rate == 0) {
        [self.pipPlayer play];
    }
    
    // Try to start Picture-in-Picture
    if (self.pipController.isPictureInPicturePossible) {
        [self startLyricsUpdateTimer];
        [self.pipController startPictureInPicture];
        NSLog(@"🎵 Started system Picture-in-Picture");
    } else {
        NSLog(@"🎵 Picture-in-Picture not possible right now - checking requirements...");
        
        // Debug info
        NSLog(@"🎵 PiP Debug - Player: %@, Layer: %@, Controller: %@", 
              self.pipPlayer, self.pipPlayerLayer, self.pipController);
        NSLog(@"🎵 PiP Debug - Player rate: %f, Player status: %ld", 
              self.pipPlayer.rate, (long)self.pipPlayer.status);
        
        // Try to make it possible by ensuring proper setup
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.pipController.isPictureInPicturePossible) {
                [self startLyricsUpdateTimer];
                [self.pipController startPictureInPicture];
                NSLog(@"🎵 Started Picture-in-Picture after delay");
            } else {
                NSLog(@"🎵 Picture-in-Picture still not possible - may need video file");
            }
        });
    }
}

- (void)stopPiPMode {
    if (self.pipController.isPictureInPictureActive) {
        [self.pipController stopPictureInPicture];
        [self.lyricsUpdateTimer invalidate];
        self.lyricsUpdateTimer = nil;
        NSLog(@"🎵 Stopped Picture-in-Picture");
    }
}

- (BOOL)isPiPActive {
    return self.pipController.isPictureInPictureActive;
}

#pragma mark - UI Setup

- (void)setupUI {
    self.view.backgroundColor = [UIColor clearColor];
    
    // Video container for PiP
    self.videoContainerView = [[UIView alloc] init];
    self.videoContainerView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:self.videoContainerView];
    
    // Overlay view for custom controls (visible in PiP)
    self.pipOverlayView = [[UIView alloc] init];
    self.pipOverlayView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.pipOverlayView];
    
    // Album artwork (smaller, positioned in corner)
    self.albumImageView = [[UIImageView alloc] init];
    self.albumImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.albumImageView.layer.cornerRadius = 8;
    self.albumImageView.layer.masksToBounds = YES;
    self.albumImageView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.8];
    [self.pipOverlayView addSubview:self.albumImageView];
    
    // Song title
    self.songTitleLabel = [[UILabel alloc] init];
    self.songTitleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.songTitleLabel.textColor = [UIColor whiteColor];
    self.songTitleLabel.numberOfLines = 1;
    self.songTitleLabel.shadowColor = [UIColor blackColor];
    self.songTitleLabel.shadowOffset = CGSizeMake(1, 1);
    [self.pipOverlayView addSubview:self.songTitleLabel];
    
    // Artist
    self.artistLabel = [[UILabel alloc] init];
    self.artistLabel.font = [UIFont systemFontOfSize:14];
    self.artistLabel.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    self.artistLabel.numberOfLines = 1;
    self.artistLabel.shadowColor = [UIColor blackColor];
    self.artistLabel.shadowOffset = CGSizeMake(1, 1);
    [self.pipOverlayView addSubview:self.artistLabel];
    
    // Current lyrics (prominent display)
    self.currentLyricsLabel = [[UILabel alloc] init];
    self.currentLyricsLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    self.currentLyricsLabel.textColor = [UIColor colorWithRed:0.3 green:0.8 blue:0.4 alpha:1.0];
    self.currentLyricsLabel.numberOfLines = 2;
    self.currentLyricsLabel.textAlignment = NSTextAlignmentCenter;
    self.currentLyricsLabel.shadowColor = [UIColor blackColor];
    self.currentLyricsLabel.shadowOffset = CGSizeMake(1, 1);
    [self.pipOverlayView addSubview:self.currentLyricsLabel];
    
    // Control buttons
    self.previousButton = [self createControlButtonWithSystemName:@"backward.end.fill" action:@selector(previousTapped)];
    self.playPauseButton = [self createControlButtonWithSystemName:@"play.fill" action:@selector(playPauseTapped)];
    self.nextButton = [self createControlButtonWithSystemName:@"forward.end.fill" action:@selector(nextTapped)];
    
    // Progress slider
    self.progressSlider = [[UISlider alloc] init];
    self.progressSlider.minimumValue = 0;
    self.progressSlider.maximumValue = 1;
    self.progressSlider.minimumTrackTintColor = [UIColor colorWithRed:0.3 green:0.8 blue:0.4 alpha:1.0];
    self.progressSlider.maximumTrackTintColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    [self.progressSlider addTarget:self action:@selector(progressSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.pipOverlayView addSubview:self.progressSlider];
    
    [self setupConstraints];
}

- (UIButton *)createControlButtonWithSystemName:(NSString *)systemName action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:[UIImage systemImageNamed:systemName] forState:UIControlStateNormal];
    button.tintColor = [UIColor whiteColor];
    button.layer.shadowColor = [UIColor blackColor].CGColor;
    button.layer.shadowOffset = CGSizeMake(1, 1);
    button.layer.shadowOpacity = 0.8;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.pipOverlayView addSubview:button];
    return button;
}

- (void)setupConstraints {
    [self.videoContainerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    [self.pipOverlayView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    // Layout optimized for PiP window aspect ratio (16:9 approximately)
    [self.albumImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.equalTo(self.pipOverlayView).offset(8);
        make.width.height.equalTo(@50);
    }];
    
    [self.songTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.albumImageView.mas_right).offset(8);
        make.top.equalTo(self.albumImageView).offset(2);
        make.right.equalTo(self.pipOverlayView).offset(-8);
        make.height.equalTo(@18);
    }];
    
    [self.artistLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.songTitleLabel);
        make.top.equalTo(self.songTitleLabel.mas_bottom).offset(1);
        make.height.equalTo(@16);
    }];
    
    // Position lyrics prominently in the center
    [self.currentLyricsLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.pipOverlayView);
        make.centerY.equalTo(self.pipOverlayView).offset(5);
        make.left.equalTo(self.pipOverlayView).offset(12);
        make.right.equalTo(self.pipOverlayView).offset(-12);
    }];
    
    // Progress slider near the bottom
    [self.progressSlider mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.pipOverlayView).offset(12);
        make.right.equalTo(self.pipOverlayView).offset(-12);
        make.bottom.equalTo(self.playPauseButton.mas_top).offset(-8);
        make.height.equalTo(@4);
    }];
    
    // Control buttons at the bottom
    [self.playPauseButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.pipOverlayView);
        make.bottom.equalTo(self.pipOverlayView).offset(-12);
        make.width.height.equalTo(@36);
    }];
    
    [self.previousButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.playPauseButton.mas_left).offset(-20);
        make.centerY.equalTo(self.playPauseButton);
        make.width.height.equalTo(@30);
    }];
    
    [self.nextButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.playPauseButton.mas_right).offset(20);
        make.centerY.equalTo(self.playPauseButton);
        make.width.height.equalTo(@30);
    }];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.pipPlayerLayer) {
        self.pipPlayerLayer.frame = self.videoContainerView.bounds;
    }
}

#pragma mark - Content Updates

- (void)updatePiPContent {
    MusicPlayerController *player = [MusicPlayerController sharedController];
    
    if (!player.currentTrack) {
        return;
    }
    
    // Update labels
    self.songTitleLabel.text = player.currentTrack.name;
    self.artistLabel.text = [player.currentTrack.artist componentsJoinedByString:@", "];
    
    // Update album art
    [self updateAlbumArt];
    
    // Update play/pause button
    [self updatePlayPauseButton];
    
    // Update progress
    [self updateProgress];
    
    // Load lyrics for current track
    [self loadLyricsForCurrentTrack];
}

- (void)updateAlbumArt {
    MusicModel *track = [MusicPlayerController sharedController].currentTrack;
    
    // Set placeholder
    UIImage *placeholderImage = [UIImage systemImageNamed:@"music.note"];
    if (@available(iOS 13.0, *)) {
        placeholderImage = [placeholderImage imageWithTintColor:[UIColor colorWithWhite:1.0 alpha:0.6]];
    }
    self.albumImageView.image = placeholderImage;
    
    if (track.picId) {
        [[MusicImageCacheManager sharedManager] getImageURLWithPicId:track.picId 
                                                               source:track.source 
                                                                 size:MusicImageSizeSmall 
                                                           completion:^(NSString * _Nullable imageUrl, NSError * _Nullable error) {
            if (imageUrl) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.albumImageView sd_setImageWithURL:[NSURL URLWithString:imageUrl] 
                                            placeholderImage:placeholderImage];
                });
            }
        }];
    }
}

- (void)updatePlayPauseButton {
    BOOL isPlaying = [MusicPlayerController sharedController].isPlaying;
    NSString *imageName = isPlaying ? @"pause.fill" : @"play.fill";
    [self.playPauseButton setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
}

- (void)updateProgress {
    MusicPlayerController *player = [MusicPlayerController sharedController];
    self.progressSlider.value = player.progress;
}

#pragma mark - Lyrics Management

- (void)loadLyricsForCurrentTrack {
    MusicModel *track = [MusicPlayerController sharedController].currentTrack;
    if (!track) return;
    
    // Load lyrics from API
    [[MusicAPIManager sharedManager] getLyricsWithTrackId:track.trackId 
                                                   source:track.source 
                                               completion:^(NSString * _Nullable lyrics, NSError * _Nullable error) {
        if (lyrics && lyrics.length > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self parseLyrics:lyrics];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.currentLyricsLabel.text = @"♪ 暂无歌词 ♪";
                self.lyricsData = @[]; // Use empty array instead of nil
                self.currentLyricsIndex = -1;
            });
        }
    }];
}

- (void)parseLyrics:(NSString *)lyricsText {
    NSMutableArray *parsedLyrics = [NSMutableArray array];
    
    NSArray *lines = [lyricsText componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        if (line.length == 0) continue;
        
        // Parse LRC format: [mm:ss.xx]lyrics
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\[(\\d+):(\\d+(?:\\.\\d+)?)\\](.+)" 
                                                                               options:0 
                                                                                 error:nil];
        NSTextCheckingResult *match = [regex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
        
        if (match) {
            NSString *minutesStr = [line substringWithRange:[match rangeAtIndex:1]];
            NSString *secondsStr = [line substringWithRange:[match rangeAtIndex:2]];
            NSString *text = [line substringWithRange:[match rangeAtIndex:3]];
            
            NSTimeInterval time = [minutesStr integerValue] * 60 + [secondsStr doubleValue];
            
            [parsedLyrics addObject:@{
                @"time": @(time),
                @"text": text
            }];
        }
    }
    
    // Sort by time
    [parsedLyrics sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        return [obj1[@"time"] compare:obj2[@"time"]];
    }];
    
    self.lyricsData = parsedLyrics;
    self.currentLyricsIndex = -1;
    
    NSLog(@"🎵 Parsed %ld lyrics lines for PiP", (long)parsedLyrics.count);
}

- (void)updateCurrentLyrics:(NSString *)lyrics {
    self.currentLyricsLabel.text = lyrics ?: @"♪ ♪ ♪";
}

- (void)setLyricsData:(NSArray<NSDictionary *> *)lyricsData {
    _lyricsData = lyricsData;
    self.currentLyricsIndex = -1;
}

- (void)startLyricsUpdateTimer {
    [self.lyricsUpdateTimer invalidate];
    self.lyricsUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 
                                                              target:self 
                                                            selector:@selector(updateLyricsDisplay) 
                                                            userInfo:nil 
                                                             repeats:YES];
}

- (void)updateLyricsDisplay {
    if (!self.lyricsData || self.lyricsData.count == 0) {
        return;
    }
    
    NSTimeInterval currentTime = [MusicPlayerController sharedController].currentTime;
    
    // Find current lyrics line
    NSInteger newIndex = -1;
    for (NSInteger i = 0; i < self.lyricsData.count; i++) {
        NSTimeInterval lyricsTime = [self.lyricsData[i][@"time"] doubleValue];
        if (currentTime >= lyricsTime) {
            newIndex = i;
        } else {
            break;
        }
    }
    
    // Update display if lyrics changed
    if (newIndex != self.currentLyricsIndex && newIndex >= 0) {
        self.currentLyricsIndex = newIndex;
        NSString *lyricsText = self.lyricsData[newIndex][@"text"];
        
        // Animate lyrics change
        [UIView transitionWithView:self.currentLyricsLabel 
                          duration:0.3 
                           options:UIViewAnimationOptionTransitionCrossDissolve 
                        animations:^{
            self.currentLyricsLabel.text = lyricsText;
        } completion:nil];
    }
}

#pragma mark - Control Actions

- (void)playPauseTapped {
    MusicPlayerController *player = [MusicPlayerController sharedController];
    if (player.isPlaying) {
        [player pause];
    } else {
        [player play];
    }
}

- (void)previousTapped {
    [[MusicPlayerController sharedController] playPreviousTrack];
}

- (void)nextTapped {
    [[MusicPlayerController sharedController] playNextTrack];
}

- (void)progressSliderChanged:(UISlider *)slider {
    [[MusicPlayerController sharedController] seekToProgress:slider.value];
}

#pragma mark - AVPictureInPictureControllerDelegate

- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    NSLog(@"🎵 Picture-in-Picture will start");
}

- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    NSLog(@"🎵 Picture-in-Picture did start");
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
           failedToStartPictureInPictureWithError:(NSError *)error {
    NSLog(@"🎵 Picture-in-Picture failed to start: %@", error.localizedDescription);
}

- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    NSLog(@"🎵 Picture-in-Picture will stop");
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    NSLog(@"🎵 Picture-in-Picture did stop");
    [self.lyricsUpdateTimer invalidate];
    self.lyricsUpdateTimer = nil;
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
    // Restore the full music player UI
    NSLog(@"🎵 Restoring user interface from Picture-in-Picture");
    completionHandler(YES);
}

#pragma mark - Player Observers

- (void)addPlayerObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerDidStartPlaying:) name:MusicPlayerDidStartPlayingNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerDidChangeProgress:) name:MusicPlayerDidChangeProgressNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerDidPause:) name:MusicPlayerDidPauseNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerDidResume:) name:MusicPlayerDidResumeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerDidStop:) name:MusicPlayerDidStopNotification object:nil];
}

- (void)removePlayerObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)playerDidStartPlaying:(NSNotification *)notification {
    if ([self isPiPActive]) {
        [self updatePiPContent];
    }
}

- (void)playerDidChangeProgress:(NSNotification *)notification {
    if ([self isPiPActive]) {
        [self updateProgress];
    }
}

- (void)playerDidPause:(NSNotification *)notification {
    if ([self isPiPActive]) {
        [self updatePlayPauseButton];
    }
}

- (void)playerDidResume:(NSNotification *)notification {
    if ([self isPiPActive]) {
        [self updatePlayPauseButton];
    }
}

- (void)playerDidStop:(NSNotification *)notification {
    [self stopPiPMode];
}

@end