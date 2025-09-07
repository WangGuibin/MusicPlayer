//
//  PlayerViewController.m
//  MusicPlayer
//
//  Created by Gemini on 2025/9/4.
//

#import "PlayerViewController.h"
#import "MusicPlayerController.h"
#import "MusicAPIManager.h"
#import "CurrentPlaylistViewController.h"
#import "PlaylistManagementViewController.h"
#import "MusicStorageManager.h"
#import "PlaylistModel.h"
#import "SpectrumView.h"
#import "BufferedProgressView.h"
#import "MusicImageCacheManager.h"
#import "PipLyricsManager.h"
#import "MusicSettingsManager.h"
#import <Masonry/Masonry.h>
#import <SDWebImage/UIImageView+WebCache.h>
#import <QuartzCore/QuartzCore.h>
#import "MusicSettingsViewController.h"

// Simple class to hold parsed lyric lines
@interface LyricLine : NSObject
@property (nonatomic, assign) NSTimeInterval time;
@property (nonatomic, copy) NSString *text;
@end
@implementation LyricLine
@end


@interface PlayerViewController () <UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate, BufferedProgressViewDelegate>

// UI Components
@property (nonatomic, strong) UIImageView *backgroundImageView;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) CAGradientLayer *gradientLayer;

@property (nonatomic, strong) UIButton *dismissButton;
@property (nonatomic, strong) UIButton *addToPlaylistButton;
@property (nonatomic, strong) UIButton *pipButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *artistLabel;

@property (nonatomic, strong) UIView *albumArtContainer;
@property (nonatomic, strong) UIImageView *albumImageView;
@property (nonatomic, strong) UITableView *lyricsTableView;

@property (nonatomic, strong) UILabel *lyricPreviewLine1;
@property (nonatomic, strong) UILabel *lyricPreviewLine2;

@property (nonatomic, strong) BufferedProgressView *progressView;
@property (nonatomic, strong) UILabel *currentTimeLabel;
@property (nonatomic, strong) UILabel *totalTimeLabel;

@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, strong) UIButton *prevButton;
@property (nonatomic, strong) UIButton *modeButton;
@property (nonatomic, strong) UIButton *playlistButton;

// Spectrum visualization
@property (nonatomic, strong) SpectrumView *spectrumView;
@property (nonatomic, strong) CADisplayLink *displayLink;

// State & Data
@property (nonatomic, strong) NSArray<LyricLine *> *lyrics;
@property (nonatomic, assign) NSInteger currentLyricIndex;
@property (nonatomic, assign) BOOL isUserScrubbing;

// Interactive dismissal properties
@property (nonatomic, strong) UIPanGestureRecognizer *dismissPanGesture;
@property (nonatomic, assign) BOOL isDismissing;
@property (nonatomic, assign) CGFloat initialDismissTranslation;

// Snapshot transition properties
@property (nonatomic, strong) UIImageView *backgroundSnapshotView;
@property (nonatomic, strong) UIImage *cachedBackgroundSnapshot;

// Picture-in-Picture properties
@property (nonatomic, strong) NSTimer *pipLyricsUpdateTimer;
@property (nonatomic, copy) NSString *currentPipLyrics;

@end

@implementation PlayerViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Set modal presentation background color
    if (@available(iOS 13.0, *)) {
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }
    
    [self setupUI];
    [self setupGestures];
    [self addPlayerObservers];
    
    [self updateUIForTrack:[MusicPlayerController sharedController].currentTrack];
    [self updatePlayPauseButtonState];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateProgressUIWithPlayer:[MusicPlayerController sharedController]];
    [self updatePlayPauseButtonState];
    // Cache background snapshot for smooth dismiss transitions
    [self performSelector:@selector(cacheBackgroundSnapshot) withObject:nil afterDelay:0.1];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // Clear cached snapshot to free memory
    [self clearBackgroundSnapshot];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.gradientLayer.frame = self.view.bounds;
    // Set the album image view to be circular
    self.albumImageView.layer.cornerRadius = self.albumImageView.frame.size.width / 2;
}

- (void)dealloc {
    [self removePlayerObservers];
    [_displayLink invalidate];
    [self stopPipLyricsUpdate];
    
    // 清理 PiP 相关资源
    PipLyricsManager *pipManager = [PipLyricsManager shareTool];
    if (pipManager.isInPip) {
        [pipManager stopPictureInPicture];
    }
}

#pragma mark - Observers

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

#pragma mark - Notification Handlers

- (void)playerDidStartPlaying:(NSNotification *)notification {
    MusicModel *track = notification.userInfo[MusicPlayerTrackUserInfoKey];
    [self updateUIForTrack:track];
    [self resumeAlbumArtRotation];
    [self startSpectrumAnimation];
    [self updatePlayPauseButtonState];
}

- (void)playerDidChangeProgress:(NSNotification *)notification {
    if (!self.isUserScrubbing) {
        CGFloat progress = [notification.userInfo[MusicPlayerProgressUserInfoKey] floatValue];
        NSTimeInterval currentTime = [notification.userInfo[MusicPlayerCurrentTimeUserInfoKey] doubleValue];
        NSTimeInterval totalTime = [notification.userInfo[MusicPlayerTotalTimeUserInfoKey] doubleValue];
        CGFloat bufferedProgress = [notification.userInfo[MusicPlayerBufferedProgressUserInfoKey] floatValue];
        
        self.progressView.progress = progress;
        self.progressView.bufferedProgress = bufferedProgress;
        self.currentTimeLabel.text = [self formatTime:currentTime];
        self.totalTimeLabel.text = [self formatTime:totalTime];
        [self updateLyricHighlightingForTime:currentTime];
    }
}

- (void)playerDidPause:(NSNotification *)notification {
    [self updatePlayPauseButtonState];
    [self pauseAlbumArtRotation];
    [self stopSpectrumAnimation];
}

- (void)playerDidResume:(NSNotification *)notification {
    [self updatePlayPauseButtonState];
    [self resumeAlbumArtRotation];
    [self startSpectrumAnimation];
}

- (void)playerDidStop:(NSNotification *)notification {
    [self updatePlayPauseButtonState];
    [self stopAlbumArtRotation];
    [self stopSpectrumAnimation];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UI Setup

- (void)setupUI {
    // Set a dark background color to prevent black flashes
    self.view.backgroundColor = [UIColor colorWithRed:22/255.0 green:22/255.0 blue:22/255.0 alpha:1.0];

    // Background & Effects
    self.backgroundImageView = [[UIImageView alloc] init];
    self.backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.backgroundImageView.backgroundColor = [UIColor colorWithRed:22/255.0 green:22/255.0 blue:22/255.0 alpha:1.0]; // Fallback color
    [self.view addSubview:self.backgroundImageView];
    
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    self.blurView.alpha = 0.98; // 设置透明度，让歌词更清晰可见，同时保持背景连续性
    [self.view addSubview:self.blurView];

    self.gradientLayer = [CAGradientLayer layer];
    self.gradientLayer.colors = @[(id)[UIColor colorWithWhite:0 alpha:0.1].CGColor, (id)[UIColor colorWithWhite:0 alpha:0.6].CGColor];
    [self.view.layer addSublayer:self.gradientLayer];

    // Top Controls
    self.dismissButton = [self createButtonWithImageName:@"chevron.down" target:self action:@selector(dismissTapped:)];
    self.addToPlaylistButton = [self createButtonWithImageName:@"plus.circle" target:self action:@selector(addToPlaylistButtonTapped:)];
    self.pipButton = [self createButtonWithImageName:@"pip" target:self action:@selector(pipButtonTapped:)];
    self.titleLabel = [self createLabelWithFontSize:18 weight:UIFontWeightBold alignment:NSTextAlignmentCenter];
    self.artistLabel = [self createLabelWithFontSize:14 weight:UIFontWeightMedium alignment:NSTextAlignmentCenter];
    self.artistLabel.textColor = [UIColor lightGrayColor];

    // Content Container
    self.albumArtContainer = [[UIView alloc] init];
    self.albumArtContainer.backgroundColor = [UIColor clearColor]; // 确保容器背景透明
    self.albumArtContainer.clipsToBounds = YES;
    [self.view addSubview:self.albumArtContainer];

    self.albumImageView = [[UIImageView alloc] init];
    self.albumImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.albumImageView.layer.masksToBounds = YES;
    self.albumImageView.layer.cornerRadius = 0; // Will be set in viewDidLayoutSubviews
    self.albumImageView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0]; // Better fallback color
    [self.albumArtContainer addSubview:self.albumImageView];

    self.lyricsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.lyricsTableView.backgroundColor = [UIColor clearColor];
    self.lyricsTableView.dataSource = self;
    self.lyricsTableView.delegate = self;
    self.lyricsTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.lyricsTableView.showsVerticalScrollIndicator = NO;
    self.lyricsTableView.opaque = NO; // 确保表格视图不opaque，以支持透明背景
    [self.lyricsTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"LyricCell"];
    self.lyricsTableView.alpha = 0.0;
    [self.view addSubview:self.lyricsTableView];

    // Lyric Preview Labels
    self.lyricPreviewLine1 = [self createLabelWithFontSize:18 weight:UIFontWeightBold alignment:NSTextAlignmentCenter];
    self.lyricPreviewLine2 = [self createLabelWithFontSize:18 weight:UIFontWeightMedium alignment:NSTextAlignmentCenter];
    self.lyricPreviewLine2.textColor = [UIColor lightGrayColor];

    // Progress Controls
    self.progressView = [[BufferedProgressView alloc] init];
    self.progressView.delegate = self;
    self.progressView.trackHeight = 4.0;
    self.progressView.thumbSize = 20.0;
    self.progressView.trackColor = [UIColor colorWithWhite:1.0 alpha:0.3];
    self.progressView.bufferedTrackColor = [UIColor colorWithWhite:1.0 alpha:0.5];
    self.progressView.progressTrackColor = [UIColor colorWithRed:30/255.0 green:215/255.0 blue:96/255.0 alpha:1.0];
    self.progressView.thumbColor = [UIColor whiteColor];

    self.currentTimeLabel = [self createLabelWithFontSize:12 weight:UIFontWeightRegular alignment:NSTextAlignmentLeft];
    self.totalTimeLabel = [self createLabelWithFontSize:12 weight:UIFontWeightRegular alignment:NSTextAlignmentRight];

    // Bottom Controls
    self.playPauseButton = [self createButtonWithImageName:@"play.fill" target:self action:@selector(playPauseTapped:)];
    self.nextButton = [self createButtonWithImageName:@"forward.end.fill" target:self action:@selector(nextTapped:)];
    self.prevButton = [self createButtonWithImageName:@"backward.end.fill" target:self action:@selector(prevTapped:)];
    self.modeButton = [self createButtonWithImageName:@"repeat" target:self action:@selector(modeTapped:)];
    self.playlistButton = [self createButtonWithImageName:@"list.bullet" target:self action:@selector(playlistButtonTapped:)];

    // Spectrum visualization
    self.spectrumView = [[SpectrumView alloc] init];
    self.spectrumView.numberOfBars = 12;
    self.spectrumView.barSpacing = 3.0;
    self.spectrumView.barColor = [UIColor colorWithRed:30/255.0 green:215/255.0 blue:96/255.0 alpha:0.8];

    // Add all subviews
    [self.view addSubview:self.dismissButton];
    [self.view addSubview:self.addToPlaylistButton];
    [self.view addSubview:self.pipButton];
    [self.view addSubview:self.titleLabel];
    [self.view addSubview:self.artistLabel];
    [self.view addSubview:self.lyricPreviewLine1];
    [self.view addSubview:self.lyricPreviewLine2];
    [self.view addSubview:self.progressView];
    [self.view addSubview:self.currentTimeLabel];
    [self.view addSubview:self.totalTimeLabel];
    [self.view addSubview:self.playPauseButton];
    [self.view addSubview:self.nextButton];
    [self.view addSubview:self.prevButton];
    [self.view addSubview:self.modeButton];
    [self.view addSubview:self.playlistButton];
    [self.view addSubview:self.spectrumView];

    [self setupConstraints];
}

- (void)setupConstraints {
    [self.backgroundImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    [self.blurView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];

    [self.dismissButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(10);
        make.left.equalTo(self.view.mas_safeAreaLayoutGuideLeft).offset(20);
        make.width.height.equalTo(@44);
    }];

    [self.addToPlaylistButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(10);
        make.right.equalTo(self.view.mas_safeAreaLayoutGuideRight).offset(-20);
        make.width.height.equalTo(@44);
    }];

    [self.pipButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(10);
        make.right.equalTo(self.addToPlaylistButton.mas_left).offset(-10);
        make.width.height.equalTo(@44);
    }];

    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.dismissButton.mas_bottom).offset(10); // Move title closer to top
        make.left.equalTo(self.view).offset(40);
        make.right.equalTo(self.view).offset(-40);
    }];

    [self.artistLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.titleLabel.mas_bottom).offset(5); // Reduce spacing between title and artist
        make.left.right.equalTo(self.titleLabel);
    }];

    [self.albumArtContainer mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.artistLabel.mas_bottom).offset(30); // Reduce spacing from artist label
        make.left.equalTo(self.view).offset(40);
        make.right.equalTo(self.view).offset(-40);
        make.height.equalTo(self.albumArtContainer.mas_width);
    }];

    [self.albumImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.albumArtContainer);
        make.width.height.equalTo(self.albumArtContainer.mas_width).multipliedBy(0.8);
    }];
    
    [self.lyricsTableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.albumArtContainer);
    }];

    [self.lyricPreviewLine1 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.albumArtContainer.mas_bottom).offset(15);
        make.left.right.equalTo(self.albumArtContainer);
    }];

    [self.lyricPreviewLine2 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.lyricPreviewLine1.mas_bottom).offset(5);
        make.left.right.equalTo(self.albumArtContainer);
    }];

    [self.progressView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self.playPauseButton.mas_top).offset(-30);
        make.left.equalTo(self.view).offset(40);
        make.right.equalTo(self.view).offset(-40);
        make.height.equalTo(@30);
    }];

    [self.currentTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.progressView.mas_bottom).offset(8);
        make.left.equalTo(self.progressView.mas_left);
    }];

    [self.totalTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.progressView.mas_bottom).offset(8);
        make.right.equalTo(self.progressView.mas_right);
    }];

    // 5-button layout for player controls (moved add to playlist to top)
    [self.playPauseButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).offset(-50);
        make.centerX.equalTo(self.view);
        make.width.height.equalTo(@70);
    }];

    [self.prevButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.playPauseButton.mas_centerY);
        make.right.equalTo(self.playPauseButton.mas_left).offset(-30);
        make.width.height.equalTo(@50);
    }];

    [self.nextButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.playPauseButton.mas_centerY);
        make.left.equalTo(self.playPauseButton.mas_right).offset(30);
        make.width.height.equalTo(@50);
    }];
    
    [self.modeButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.playPauseButton.mas_centerY);
        make.right.equalTo(self.prevButton.mas_left).offset(-25);
        make.width.height.equalTo(@40);
    }];
    
    [self.playlistButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.playPauseButton.mas_centerY);
        make.left.equalTo(self.nextButton.mas_right).offset(25);
        make.width.height.equalTo(@40);
    }];
    
    // Spectrum visualization positioned between album art and progress slider
    [self.spectrumView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.lyricPreviewLine2.mas_bottom).offset(20);
        make.centerX.equalTo(self.view);
        make.width.equalTo(@180);
        make.height.equalTo(@40);
        make.bottom.lessThanOrEqualTo(self.progressView.mas_top).offset(-20);
    }];
}

- (void)setupGestures {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleLyricsView)];
    [self.albumArtContainer addGestureRecognizer:tap];
    
    // Add swipe gestures for switching views
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeGesture:)];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.view addGestureRecognizer:swipeLeft];
    
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeGesture:)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:swipeRight];
    
    // Add pan gesture for interactive dismissal
    self.dismissPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDismissPanGesture:)];
    self.dismissPanGesture.delegate = self;
    [self.view addGestureRecognizer:self.dismissPanGesture];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    // Allow simultaneous recognition with table view scroll gesture
    if (gestureRecognizer == self.dismissPanGesture && [otherGestureRecognizer.view isKindOfClass:[UITableView class]]) {
        return YES;
    }
    return NO;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.dismissPanGesture) {
        CGPoint velocity = [(UIPanGestureRecognizer *)gestureRecognizer velocityInView:self.view];
        CGPoint translation = [(UIPanGestureRecognizer *)gestureRecognizer translationInView:self.view];
        
        // More lenient velocity threshold and add translation consideration
        if (velocity.y <= 100 && translation.y <= 10) return NO;
        
        if (self.lyricsTableView.alpha > 0.5) {
            // If lyrics are visible, only allow dismiss when table is at top
            return self.lyricsTableView.contentOffset.y <= 0;
        }
        return YES;
    }
    return YES;
}

#pragma mark - UI Update

- (void)updateUIForTrack:(MusicModel *)track {
    if (!track) return;

    self.titleLabel.text = track.name;
    self.artistLabel.text = [track.artist componentsJoinedByString:@", "];
    
    // Update PiP button state and visibility
    MusicSettingsManager *settingsManager = [MusicSettingsManager sharedManager];
    if (settingsManager.pipLyricsEnabled) {
        self.pipButton.hidden = NO;
        self.pipButton.alpha = 1.0;
        
        PipLyricsManager *pipManager = [PipLyricsManager shareTool];
        if (pipManager.isInPip) {
            [self.pipButton setImage:[UIImage systemImageNamed:@"pip.fill"] forState:UIControlStateNormal];
            self.pipButton.tintColor = [UIColor colorWithRed:0.3 green:0.8 blue:0.4 alpha:1.0];
        } else {
            [self.pipButton setImage:[UIImage systemImageNamed:@"pip"] forState:UIControlStateNormal];
            self.pipButton.tintColor = [UIColor whiteColor];
        }
    } else {
        // 当设置关闭时，隐藏按钮或使其半透明
        self.pipButton.alpha = 0.5;
        [self.pipButton setImage:[UIImage systemImageNamed:@"pip"] forState:UIControlStateNormal];
        self.pipButton.tintColor = [UIColor lightGrayColor];
    }
    
    // Reset UI
    self.albumImageView.image = nil;
    self.lyricPreviewLine1.text = @"";
    self.lyricPreviewLine2.text = @"";
    [self stopAlbumArtRotation];
    self.lyrics = @[];
    [self.lyricsTableView reloadData];

    // Load Album Art
    // Set placeholder image first
    UIImage *placeholderImage = [[UIImage systemImageNamed:@"music.note"] imageWithRenderingMode:(UIImageRenderingModeAlwaysOriginal)];
    if (@available(iOS 13.0, *)) {
        placeholderImage = [placeholderImage imageWithTintColor:[UIColor colorWithWhite:1.0 alpha:0.3]];
    }
    self.albumImageView.image = placeholderImage;
    self.albumImageView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    
    if (track.picId) {
        // 使用缓存管理器获取大尺寸图片URL
        [[MusicImageCacheManager sharedManager] getImageURLWithPicId:track.picId 
                                                               source:track.source 
                                                                 size:MusicImageSizeLarge 
                                                           completion:^(NSString * _Nullable imageUrl, NSError * _Nullable error) {
            if (imageUrl) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.albumImageView sd_setImageWithURL:[NSURL URLWithString:imageUrl] 
                                            placeholderImage:placeholderImage
                                                     options:SDWebImageRetryFailed | SDWebImageProgressiveLoad
                                                   completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
                        if (image) {
                            // Set background image for player background
                            self.backgroundImageView.image = image;
                            self.albumImageView.backgroundColor = [UIColor clearColor];
                            
                            // Start rotation if playing
                            if ([MusicPlayerController sharedController].isPlaying) {
                                [self startAlbumArtRotation];
                            }
                        } else {
                            // Keep placeholder if loading failed
                            NSLog(@"Failed to load album art: %@", error.localizedDescription);
                        }
                    }];
                });
            } else {
                NSLog(@"No album art URL available");
            }
        }];
    }

    // Load Lyrics
    if (track.lyric_id) {
        [[MusicAPIManager sharedManager] getLyricsWithLyricId:track.lyric_id source:track.source completion:^(NSString * _Nullable lyrics, NSString * _Nullable translatedLyrics, NSError * _Nullable error) {
            if (lyrics) {
                NSLog(@"🎵 Raw lyrics received: %@", [lyrics substringToIndex:MIN(200, lyrics.length)]);
                self.lyrics = [self parseLyrics:lyrics];
                NSLog(@"🎵 Parsed %ld lyric lines", self.lyrics.count);
                if (self.lyrics.count > 0) {
                    NSLog(@"🎵 First lyric: Time:%.2f Text:%@", self.lyrics[0].time, self.lyrics[0].text);
                    if (self.lyrics.count > 1) {
                        NSLog(@"🎵 Second lyric: Time:%.2f Text:%@", self.lyrics[1].time, self.lyrics[1].text);
                    }
                }
                [self.lyricsTableView reloadData];
            } else if (error) {
                NSLog(@"🎵 Failed to load lyrics: %@", error.localizedDescription);
            }
        }];
    }
}

- (void)updatePlayPauseButtonState {
    BOOL isPlaying = [MusicPlayerController sharedController].isPlaying;
    NSString *imageName = isPlaying ? @"pause.fill" : @"play.fill";
    [self.playPauseButton setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
}

- (void)updateProgressUIWithPlayer:(MusicPlayerController *)player {
    self.progressView.progress = player.progress;
    self.progressView.bufferedProgress = player.bufferedProgress;
    self.currentTimeLabel.text = [self formatTime:player.currentTime];
    self.totalTimeLabel.text = [self formatTime:player.totalTime];
}

#pragma mark - Actions & Gestures

- (void)dismissTapped:(UIButton *)sender {
    // 恢复状态栏样式到默认
    if (@available(iOS 13.0, *)) {
        // iOS 13+ 会自动使用下一个视图控制器的样式
    } else {
        // iOS 12及以下版本恢复默认状态栏样式
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - BufferedProgressViewDelegate

- (void)progressViewDidBeginSeeking:(UIView *)progressView {
    self.isUserScrubbing = YES;
}

- (void)progressViewDidEndSeeking:(UIView *)progressView withProgress:(CGFloat)progress {
    self.isUserScrubbing = NO;
    [[MusicPlayerController sharedController] seekToProgress:progress];
}

- (void)progressViewDidChangeProgress:(UIView *)progressView toProgress:(CGFloat)progress {
    NSTimeInterval newTime = [MusicPlayerController sharedController].totalTime * progress;
    self.currentTimeLabel.text = [self formatTime:newTime];
}

- (void)playPauseTapped:(UIButton *)sender {
    if ([MusicPlayerController sharedController].isPlaying) {
        [[MusicPlayerController sharedController] pause];
    } else {
        [[MusicPlayerController sharedController] play];
    }
}

- (void)nextTapped:(UIButton *)sender {
    [[MusicPlayerController sharedController] playNextTrack];
}

- (void)prevTapped:(UIButton *)sender {
    [[MusicPlayerController sharedController] playPreviousTrack];
}

- (void)modeTapped:(UIButton *)sender {
    MusicPlayerController *player = [MusicPlayerController sharedController];
    PlaybackMode newMode = (player.playbackMode + 1) % 4;
    player.playbackMode = newMode;
    
    NSString *imageName = @"repeat";
    switch (newMode) {
        case PlaybackModeRepeatAll: imageName = @"repeat"; break;
        case PlaybackModeRepeatOne: imageName = @"repeat.1"; break;
        case PlaybackModeShuffle: imageName = @"shuffle"; break;
        case PlaybackModeSequential: imageName = @"arrow.right"; break; // Placeholder
    }
    [self.modeButton setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
}

- (void)addToPlaylistButtonTapped:(UIButton *)sender {
    MusicModel *currentTrack = [MusicPlayerController sharedController].currentTrack;
    if (!currentTrack) {
        return;
    }
    
    // Check if UIMenu is available (iOS 14.0+)
    if (@available(iOS 14.0, *)) {
        [self presentUIMenu:sender forTrack:currentTrack];
    } else {
        // Fallback to action sheet for older systems
        [self presentActionSheet:sender forTrack:currentTrack];
    }
}

- (void)pipButtonTapped:(UIButton *)sender {
    MusicPlayerController *player = [MusicPlayerController sharedController];
    
    if (!player.currentTrack) {
        return;
    }
    
    // 检查设置中是否启用了画中画歌词功能
    if (![MusicSettingsManager sharedManager].pipLyricsEnabled) {
        [self showPipDisabledAlert];
        return;
    }
    
    PipLyricsManager *pipManager = [PipLyricsManager shareTool];
    
    if (pipManager.isInPip) {
        // 停止画中画模式
        [pipManager stopPictureInPicture];
        [self stopPipLyricsUpdate];
        
        [sender setImage:[UIImage systemImageNamed:@"pip"] forState:UIControlStateNormal];
        sender.tintColor = [UIColor whiteColor];
        
        NSLog(@"🎵 Picture-in-Picture mode disabled using PipLyricsManager");
    } else {
        // 启用画中画模式
        [self setupPipLyricsWithCurrentTrack];
        
        [sender setImage:[UIImage systemImageNamed:@"pip.fill"] forState:UIControlStateNormal]; 
        sender.tintColor = [UIColor colorWithRed:0.3 green:0.8 blue:0.4 alpha:1.0];
        
        NSLog(@"🎵 Picture-in-Picture mode enabled using PipLyricsManager");
        
        // 延迟dismiss，让PiP有时间启动
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self dismissViewControllerAnimated:YES completion:nil];
        });
    }
}

- (void)presentUIMenu:(UIButton *)sender forTrack:(MusicModel *)track API_AVAILABLE(ios(14.0)) {
    NSArray<PlaylistModel *> *playlists = [[MusicStorageManager sharedManager] getAllPlaylists];
    NSMutableArray<UIAction *> *menuActions = [NSMutableArray array];
    
    // Add action for creating new playlist
    UIAction *createNewAction = [UIAction actionWithTitle:@"创建新歌单" 
                                                   image:[UIImage systemImageNamed:@"plus.circle"]
                                              identifier:nil 
                                                 handler:^(__kindof UIAction * _Nonnull action) {
        [self createNewPlaylistWithTrack:track];
    }];
    [menuActions addObject:createNewAction];
    
    // Add separator if there are existing playlists
    if (playlists.count > 0) {
        [menuActions addObject:[UIAction actionWithTitle:@"" image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {}]];
    }
    
    // Add actions for existing playlists
    for (PlaylistModel *playlist in playlists) {
        UIAction *playlistAction = [UIAction actionWithTitle:playlist.name
                                                       image:[UIImage systemImageNamed:@"music.note.list"]
                                                  identifier:playlist.playlistId
                                                     handler:^(__kindof UIAction * _Nonnull action) {
            [self addTrack:track toPlaylist:playlist];
        }];
        [menuActions addObject:playlistAction];
    }
    
    UIMenu *menu = [UIMenu menuWithTitle:@"添加到歌单" children:menuActions];
    
    // Check if device supports context menus (not available on Mac Catalyst)
    if ([sender respondsToSelector:@selector(setMenu:)]) {
        sender.menu = menu;
        sender.showsMenuAsPrimaryAction = YES;
    } else {
        // Fallback for Mac Catalyst or other unsupported environments
        [self presentActionSheet:sender forTrack:track];
    }
}

- (void)presentActionSheet:(UIButton *)sender forTrack:(MusicModel *)track {
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"添加到歌单"
                                                                         message:nil
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSArray<PlaylistModel *> *playlists = [[MusicStorageManager sharedManager] getAllPlaylists];
    
    // Add action for creating new playlist
    UIAlertAction *createNewAction = [UIAlertAction actionWithTitle:@"创建新歌单"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * _Nonnull action) {
        [self createNewPlaylistWithTrack:track];
    }];
    [actionSheet addAction:createNewAction];
    
    // Add actions for existing playlists
    for (PlaylistModel *playlist in playlists) {
        UIAlertAction *playlistAction = [UIAlertAction actionWithTitle:playlist.name
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction * _Nonnull action) {
            [self addTrack:track toPlaylist:playlist];
        }];
        [actionSheet addAction:playlistAction];
    }
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [actionSheet addAction:cancelAction];
    
    // Configure for iPad
    if (actionSheet.popoverPresentationController) {
        actionSheet.popoverPresentationController.sourceView = sender;
        actionSheet.popoverPresentationController.sourceRect = sender.bounds;
    }
    
    [self presentViewController:actionSheet animated:YES completion:nil];
}

- (void)createNewPlaylistWithTrack:(MusicModel *)track {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"创建歌单"
                                                                   message:@"请输入歌单名称"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"歌单名称";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    UIAlertAction *createAction = [UIAlertAction actionWithTitle:@"创建"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
        UITextField *textField = alert.textFields.firstObject;
        NSString *playlistName = textField.text;
        if (playlistName.length > 0) {
            PlaylistModel *newPlaylist = [[MusicStorageManager sharedManager] createPlaylistWithName:playlistName];
            [self addTrack:track toPlaylist:newPlaylist];
        }
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:createAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)addTrack:(MusicModel *)track toPlaylist:(PlaylistModel *)playlist {
    [[MusicStorageManager sharedManager] addMusic:track toPlaylist:playlist];
    
    // Show success feedback
    UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"成功"
                                                                           message:[NSString stringWithFormat:@"已将「%@」添加到歌单「%@」", track.name, playlist.name]
                                                                    preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [successAlert addAction:okAction];
    [self presentViewController:successAlert animated:YES completion:nil];
}

- (void)playlistButtonTapped:(UIButton *)sender {
    CurrentPlaylistViewController *playlistVC = [[CurrentPlaylistViewController alloc] init];
    if (@available(iOS 15.0, *)) {
        if (playlistVC.sheetPresentationController) {
            playlistVC.sheetPresentationController.detents = @[[UISheetPresentationControllerDetent mediumDetent], [UISheetPresentationControllerDetent largeDetent]];
            playlistVC.sheetPresentationController.prefersGrabberVisible = YES;
        }
    }
    [self presentViewController:playlistVC animated:YES completion:nil];
}

- (void)toggleLyricsView {
    BOOL showLyrics = self.lyricsTableView.alpha == 0.0;
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.lyricsTableView.alpha = showLyrics ? 1.0 : 0.0;
        self.albumImageView.alpha = showLyrics ? 0.0 : 1.0;
        self.lyricPreviewLine1.alpha = showLyrics ? 0.0 : 1.0;
        self.lyricPreviewLine2.alpha = showLyrics ? 0.0 : 1.0;
        
        // 同时调整约束
        if (showLyrics) {
            [self.lyricsTableView mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.top.left.right.equalTo(self.albumArtContainer);
                make.bottom.equalTo(self.progressView.mas_top).offset(-10); // 撑开到接近进度条
            }];
        } else {
            [self.lyricsTableView mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.edges.equalTo(self.albumArtContainer);
            }];
        }
    } completion:nil];
}

- (void)handleSwipeGesture:(UISwipeGestureRecognizer *)gesture {
    BOOL isLyricsVisible = self.lyricsTableView.alpha > 0.5;
    
    if (gesture.direction == UISwipeGestureRecognizerDirectionLeft) {
        // Swipe left to show lyrics
        if (!isLyricsVisible) {
            [self toggleLyricsView];
        }
    } else if (gesture.direction == UISwipeGestureRecognizerDirectionRight) {
        // Swipe right to show album art
        if (isLyricsVisible) {
            [self toggleLyricsView];
        }
    }
}

#pragma mark - Snapshot Management

- (void)cacheBackgroundSnapshot {
    // Capture snapshot of the presenting view controller
    UIViewController *presentingVC = self.presentingViewController;
    if (presentingVC && presentingVC.view) {
        // Take snapshot of presenting view
        UIGraphicsBeginImageContextWithOptions(presentingVC.view.bounds.size, YES, [UIScreen mainScreen].scale);
        [presentingVC.view drawViewHierarchyInRect:presentingVC.view.bounds afterScreenUpdates:NO];
        self.cachedBackgroundSnapshot = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
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
        
        // Insert behind current view
        UIView *parentView = self.view.superview ?: self.view.window;
        [parentView insertSubview:self.backgroundSnapshotView belowSubview:self.view];
        self.backgroundSnapshotView.frame = parentView.bounds;
    }
}

#pragma mark - Interactive Dismissal

- (void)handleDismissPanGesture:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.view];
    CGPoint velocity = [gesture velocityInView:self.view];
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            self.isDismissing = YES;
            self.initialDismissTranslation = translation.y;
            
            // Setup background snapshot for smooth dismiss
            [self setupSnapshotBackground];
            
            // Add subtle shadow effect during dismissal
            self.view.layer.shadowColor = [UIColor blackColor].CGColor;
            self.view.layer.shadowOffset = CGSizeMake(0, 4);
            self.view.layer.shadowOpacity = 0.0;
            self.view.layer.shadowRadius = 12;
            
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (!self.isDismissing) return;
            
            // Calculate progress with gentler curve
            CGFloat screenHeight = self.view.bounds.size.height;
            CGFloat rawProgress = MAX(0, MIN(1.2, translation.y / (screenHeight * 0.5)));
            CGFloat progress = MIN(1.0, [self easeOutQuad:rawProgress]);
            
            // Apply elastic resistance for over-scrolling
            CGFloat translateY;
            if (rawProgress <= 1.0) {
                translateY = translation.y;
            } else {
                CGFloat overScroll = translation.y - (screenHeight * 0.5);
                translateY = (screenHeight * 0.5) + (overScroll * 0.15);
            }
            
            // Update view transform with smoother scaling
            CGFloat scale = 1.0 - (progress * 0.08);
            self.view.transform = CGAffineTransformConcat(
                CGAffineTransformMakeTranslation(0, translateY),
                CGAffineTransformMakeScale(scale, scale)
            );
            
            // Smoother alpha transition
            self.view.alpha = 1.0 - (progress * 0.4);
            
            // Fade in background snapshot to cover black window
            if (self.backgroundSnapshotView) {
                self.backgroundSnapshotView.alpha = progress * 0.9;
            }
            
            // Update shadow
            self.view.layer.shadowOpacity = progress * 0.2;
            
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (!self.isDismissing) return;
            
            CGFloat screenHeight = self.view.bounds.size.height;
            CGFloat rawProgress = MAX(0, MIN(1.2, translation.y / (screenHeight * 0.5)));
            CGFloat progress = MIN(1.0, [self easeOutQuad:rawProgress]);
            
            // More conservative dismissal threshold with velocity consideration
            BOOL shouldDismiss = progress > 0.35 || (velocity.y > 1200 && progress > 0.15);
            
            if (shouldDismiss) {
                // Complete dismissal
                [self completeDismissal];
            } else {
                // Cancel dismissal, return to normal position
                [self cancelDismissal];
            }
            
            break;
        }
        default:
            break;
    }
}

// Additional easing function for dismissal
- (CGFloat)easeOutQuad:(CGFloat)t {
    return 1 - (1 - t) * (1 - t);
}

- (void)completeDismissal {
    CGFloat screenHeight = self.view.bounds.size.height;
    
    [UIView animateWithDuration:0.5
                          delay:0
         usingSpringWithDamping:0.85
          initialSpringVelocity:0.6
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.view.transform = CGAffineTransformConcat(
            CGAffineTransformMakeTranslation(0, screenHeight),
            CGAffineTransformMakeScale(0.92, 0.92)
        );
        self.view.alpha = 0.0;
        self.view.layer.shadowOpacity = 0.0;
        
        // Keep background snapshot visible
        if (self.backgroundSnapshotView) {
            self.backgroundSnapshotView.alpha = 1.0;
        }
    } completion:^(BOOL finished) {
        // Clean up snapshot after dismiss
        [self clearBackgroundSnapshot];
        
        // 恢复状态栏样式到默认
        if (@available(iOS 13.0, *)) {
            // iOS 13+ 会自动使用下一个视图控制器的样式
        } else {
            // iOS 12及以下版本恢复默认状态栏样式
            [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
        }
        
        // Ensure we dismiss to the correct view controller hierarchy
        [self dismissViewControllerAnimated:NO completion:^{
            // If we were presented from a tab bar controller context, make sure we return properly
            UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
            if ([rootVC isKindOfClass:[UITabBarController class]]) {
                UITabBarController *tabBarController = (UITabBarController *)rootVC;
                // Make sure the correct tab is selected if needed
                // This helps maintain proper view controller hierarchy
            }
        }];
    }];
}


- (void)cancelDismissal {
    [UIView animateWithDuration:0.5
                          delay:0
         usingSpringWithDamping:0.85
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.view.transform = CGAffineTransformIdentity;
        self.view.alpha = 1.0;
        self.view.layer.shadowOpacity = 0.0;
        
        // Fade out background snapshot
        if (self.backgroundSnapshotView) {
            self.backgroundSnapshotView.alpha = 0.0;
        }
    } completion:^(BOOL finished) {
        self.isDismissing = NO;
        // Clean up snapshot and shadow
        [self clearBackgroundSnapshot];
        self.view.layer.shadowColor = nil;
    }];
}

#pragma mark - Lyric Handling

- (NSArray<LyricLine *> *)parseLyrics:(NSString *)lyricString {
    NSMutableArray *lines = [NSMutableArray array];
    NSArray *rawLines = [lyricString componentsSeparatedByString:@"\n"];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\[(\\d{2}):(\\d{2})\\.(\\d{2,3})\\]" options:0 error:nil];

    for (NSString *rawLine in rawLines) {
        NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:rawLine options:0 range:NSMakeRange(0, rawLine.length)];
        if (matches.count > 0) {
            NSString *text = [[regex stringByReplacingMatchesInString:rawLine options:0 range:NSMakeRange(0, rawLine.length) withTemplate:@""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (text.length > 0) {
                for (NSTextCheckingResult *match in matches) {
                    NSString *min = [rawLine substringWithRange:[match rangeAtIndex:1]];
                    NSString *sec = [rawLine substringWithRange:[match rangeAtIndex:2]];
                    NSString *ms = [rawLine substringWithRange:[match rangeAtIndex:3]];
                    NSTimeInterval time = min.doubleValue * 60 + sec.doubleValue + ms.doubleValue / 1000.0;
                    
                    LyricLine *line = [[LyricLine alloc] init];
                    line.time = time;
                    line.text = text;
                    [lines addObject:line];
                }
            }
        }
    }
    
    [lines sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"time" ascending:YES]]];
    return lines;
}

- (void)updateLyricHighlightingForTime:(NSTimeInterval)time {
    if (self.lyrics.count == 0) return;

    NSInteger newIndex = -1;
    for (NSInteger i = 0; i < self.lyrics.count; i++) {
        if (time >= self.lyrics[i].time) {
            newIndex = i;
        } else {
            break;
        }
    }

    if (newIndex != -1 && newIndex != self.currentLyricIndex) {
        self.currentLyricIndex = newIndex;
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.currentLyricIndex inSection:0];
        [self.lyricsTableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
        [self.lyricsTableView reloadData];
    }
    
    // 更新预览标签
    if (newIndex != -1) {
        self.lyricPreviewLine1.text = self.lyrics[newIndex].text;
        if (newIndex + 1 < self.lyrics.count) {
            self.lyricPreviewLine2.text = self.lyrics[newIndex + 1].text;
        } else {
            self.lyricPreviewLine2.text = @"";
        }
    } else {
        self.lyricPreviewLine1.text = @"";
        self.lyricPreviewLine2.text = @"";
    }
}



#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.lyrics.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"LyricCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.backgroundColor = [UIColor clearColor];
        cell.contentView.backgroundColor = [UIColor clearColor]; // 确保contentView也透明
        cell.textLabel.textColor = [UIColor whiteColor];
        
        // 根据屏幕大小调整字体
        CGFloat screenWidth = [[UIScreen mainScreen] bounds].size.width;
        CGFloat fontSize = 16;
        if (screenWidth > 834) { // iPad/Mac
            fontSize = 19;
        } else if (screenWidth > 600) { // iPad Mini
            fontSize = 17;
        }
        cell.textLabel.font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightMedium];
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone; // 不显示选中效果
    }
    
    // 确保单元格背景透明
    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];
    
    if (indexPath.row < self.lyrics.count) {
        LyricLine *lyric = self.lyrics[indexPath.row];
        cell.textLabel.text = lyric.text;
        
        // 根据是否是当前播放的歌词来设置样式
        if (indexPath.row == self.currentLyricIndex) {
            cell.textLabel.textColor = [UIColor whiteColor];
            
            CGFloat screenWidth = [[UIScreen mainScreen] bounds].size.width;
            CGFloat currentFontSize = 20;
            if (screenWidth > 834) { // iPad/Mac
                currentFontSize = 24;
            } else if (screenWidth > 600) { // iPad Mini
                currentFontSize = 22;
            }
            cell.textLabel.font = [UIFont systemFontOfSize:currentFontSize weight:UIFontWeightHeavy];
        } else {
            cell.textLabel.textColor = [UIColor whiteColor];
            
            CGFloat screenWidth = [[UIScreen mainScreen] bounds].size.width;
            CGFloat normalFontSize = 16;
            if (screenWidth > 834) { // iPad/Mac
                normalFontSize = 19;
            } else if (screenWidth > 600) { // iPad Mini
                normalFontSize = 17;
            }
            cell.textLabel.font = [UIFont systemFontOfSize:normalFontSize weight:UIFontWeightThin];
        }
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < self.lyrics.count) {
        LyricLine *lyric = self.lyrics[indexPath.row];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SeekToTime" object:nil userInfo:@{@"time": @(lyric.time)}];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}



#pragma mark - Animation

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
    
    NSLog(@"🎵 [PlayerView] Started rotation animation");
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
    
    NSLog(@"🎵 [PlayerView] Paused rotation animation");
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
    
    NSLog(@"🎵 [PlayerView] Resumed rotation animation");
}

- (void)stopAlbumArtRotation {
    [self.albumImageView.layer removeAnimationForKey:@"rotationAnimation"];
    // 重置layer状态
    self.albumImageView.layer.speed = 1.0;
    self.albumImageView.layer.timeOffset = 0.0;
    self.albumImageView.layer.beginTime = 0.0;
    
    NSLog(@"🎵 [PlayerView] Stopped rotation animation");
}


#pragma mark - Spectrum Animation

- (void)startSpectrumAnimation {
    if (self.displayLink) return;
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateSpectrum)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopSpectrumAnimation {
    [self.displayLink invalidate];
    self.displayLink = nil;
    
    // Reset spectrum to default state
    float levels[12];
    for (int i = 0; i < 12; i++) {
        levels[i] = 0.1;
    }
    [self.spectrumView updateWithLevels:levels];
}

- (void)updateSpectrum {
    float levels[12];
    for (int i = 0; i < 12; i++) {
        // Create more varied and realistic spectrum animation
        float baseLevel = 0.2 + (arc4random_uniform(50) / 100.0f);
        float variation = sin(CACurrentMediaTime() * (2 + i * 0.3)) * 0.3;
        levels[i] = MIN(1.0, MAX(0.1, baseLevel + variation));
    }
    [self.spectrumView updateWithLevels:levels];
}

#pragma mark - Helpers

- (UILabel *)createLabelWithFontSize:(CGFloat)size weight:(UIFontWeight)weight alignment:(NSTextAlignment)alignment {
    UILabel *label = [[UILabel alloc] init];
    label.textColor = [UIColor whiteColor];
    
    // 根据屏幕大小调整字体
    CGFloat screenWidth = [[UIScreen mainScreen] bounds].size.width;
    CGFloat adjustedSize = size;
    
    if (screenWidth > 834) { // iPad/Mac
        adjustedSize = size * 1.2;
    } else if (screenWidth > 600) { // iPad Mini
        adjustedSize = size * 1.1;
    }
    
    label.font = [UIFont systemFontOfSize:adjustedSize weight:weight];
    label.textAlignment = alignment;
    label.numberOfLines = 0; // Allow multiple lines for preview
    return label;
}

- (UIButton *)createButtonWithImageName:(NSString *)imageName target:(id)target action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *image = [[UIImage systemImageNamed:imageName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [button setImage:image forState:UIControlStateNormal];
    button.tintColor = [UIColor whiteColor];
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (NSString *)formatTime:(NSTimeInterval)interval {
    NSInteger minutes = (NSInteger)interval / 60;
    NSInteger seconds = (NSInteger)interval % 60;
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
}

#pragma mark - Picture-in-Picture Management

- (void)setupPipLyricsWithCurrentTrack {
    MusicPlayerController *player = [MusicPlayerController sharedController];
    MusicModel *currentTrack = player.currentTrack;
    
    if (!currentTrack) {
        NSLog(@"⚠️ No current track for PiP mode");
        return;
    }
    
    NSLog(@"🎵 Setting up PiP lyrics for track: %@", currentTrack.name);
    
    PipLyricsManager *pipManager = [PipLyricsManager shareTool];
    
    // 配置 PipLyricsManager 
    pipManager.pipType = PipLyricsTypeSingleLine; // 单行歌词展示
    pipManager.textColor = [UIColor whiteColor];
    pipManager.backgroundColor = [UIColor blackColor];
    pipManager.alignment = NSTextAlignmentCenter;
    pipManager.textFont = [UIFont boldSystemFontOfSize:18];
    pipManager.lineSpacing = 8.0;
    pipManager.preferredFramesPerSecond = 30;
    
    // 设置初始歌词文本
    NSString *initialLyrics = [self getCurrentLyricsText] ?: [NSString stringWithFormat:@"🎵 %@ - %@", 
                                                              currentTrack.name, 
                                                              [currentTrack.artist componentsJoinedByString:@", "]];
    pipManager.text = initialLyrics;
    
    NSLog(@"🎵 Initial lyrics: %@", initialLyrics);
    NSLog(@"🎵 PipType: %ld", (long)pipManager.pipType);
    
    // 显示歌词在主视图中（为了设置 PiP）
    [pipManager showLyricsWithSuperView:self.view];
    
    // 延迟启动 PiP 以确保设置完成
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"🎵 Attempting to start PiP...");
        [pipManager startPictureInPicture];
        [self startPipLyricsUpdate];
    });
}

- (void)startPipLyricsUpdate {
    [self stopPipLyricsUpdate]; // 先停止现有的定时器
    
    // 创建定时器定期更新歌词
    self.pipLyricsUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                                 target:self
                                                               selector:@selector(updatePipLyrics)
                                                               userInfo:nil
                                                                repeats:YES];
}

- (void)stopPipLyricsUpdate {
    if (self.pipLyricsUpdateTimer) {
        [self.pipLyricsUpdateTimer invalidate];
        self.pipLyricsUpdateTimer = nil;
    }
}

- (void)updatePipLyrics {
    PipLyricsManager *pipManager = [PipLyricsManager shareTool];
    NSString *currentLyrics = [self getCurrentLyricsText];
    // 添加调试日志
    MusicPlayerController *player = [MusicPlayerController sharedController];
    NSLog(@"🎵 PiP Update - Time: %.2f, Lyrics: %@, Count: %ld", 
          player.currentTime, currentLyrics ?: @"(nil)", self.lyrics.count);
    
    // 只有歌词发生变化时才更新，避免不必要的刷新
    if (![currentLyrics isEqualToString:self.currentPipLyrics]) {
        [pipManager updateLyricsDisplayWithText:currentLyrics ?: @"🎵 暂无歌词"];
        self.currentPipLyrics = currentLyrics;
        NSLog(@"🎵 PiP Lyrics Updated: %@", currentLyrics ?: @"🎵 暂无歌词");
    }
}

- (NSString *)getCurrentLyricsText {
    MusicPlayerController *player = [MusicPlayerController sharedController];
    NSTimeInterval currentTime = player.currentTime;
    
    if (self.lyrics.count == 0) {
        return nil;
    }
    
    // 查找当前时间对应的歌词
    for (NSInteger i = self.lyrics.count - 1; i >= 0; i--) {
        LyricLine *lyric = self.lyrics[i];
        if (currentTime >= lyric.time) {
            return lyric.text.length > 0 ? lyric.text : @"♪";
        }
    }
    
    return @"♪";
}

- (void)showPipDisabledAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"画中画歌词功能已关闭" 
                                                                   message:@"请在音乐设置中开启画中画歌词功能" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:@"前往设置" 
                                                             style:UIAlertActionStyleDefault 
                                                           handler:^(UIAlertAction * _Nonnull action) {
        MusicSettingsViewController *vc = [MusicSettingsViewController new];
        [self presentViewController:vc animated:YES completion:nil];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" 
                                                           style:UIAlertActionStyleCancel 
                                                         handler:nil];
    
    [alert addAction:settingsAction];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}


@end
