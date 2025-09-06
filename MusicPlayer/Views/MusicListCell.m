//
//  MusicListCell.m
//  MusicPlayer
//
//  Created by Gemini on 2025/9/4.
//

#import "MusicListCell.h"
#import "MusicModel.h"
#import "PlaylistModel.h"
#import "MusicAPIManager.h"
#import "MusicPlayerController.h"
#import "SpectrumView.h"
#import "MusicImageCacheManager.h"
#import <Masonry/Masonry.h>
#import <SDWebImage/UIImageView+WebCache.h>
#import <objc/runtime.h>

@interface MusicListCell () <UIContextMenuInteractionDelegate>

@property (nonatomic, strong) UIImageView *albumImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) UIView *separatorLine;
@property (nonatomic, strong) MusicModel *currentTrack;
@property (nonatomic, strong) SpectrumView *spectrumIndicator;

@end

@implementation MusicListCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupUI];
        [self addPlayerObservers];
    }
    return self;
}

- (void)dealloc {
    [self removePlayerObservers];
}

#pragma mark - Observers

- (void)addPlayerObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerDidStartPlaying:) name:MusicPlayerDidStartPlayingNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerDidPause:) name:MusicPlayerDidPauseNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerDidResume:) name:MusicPlayerDidResumeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerDidStop:) name:MusicPlayerDidStopNotification object:nil];
    
    // 应用生命周期通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)removePlayerObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notification Handlers

- (void)playerDidStartPlaying:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateAnimationState];
    });
}

- (void)playerDidPause:(NSNotification *)notification {
    if ([self isCurrentlyPlayingTrack]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pauseAlbumArtRotation];
        });
    }
}

- (void)playerDidResume:(NSNotification *)notification {
    if ([self isCurrentlyPlayingTrack]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self resumeAlbumArtRotation];
        });
    }
}

- (void)playerDidStop:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self stopAlbumArtRotation];
    });
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    // 应用进入后台时暂停动画
    if ([self isCurrentlyPlayingTrack]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pauseAlbumArtRotation];
        });
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    // 应用回到前台时恢复动画
    if ([self isCurrentlyPlayingTrack] && [MusicPlayerController sharedController].isPlaying) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateAnimationState];
        });
    }
}

- (void)setupUI {
    self.backgroundColor = [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleGray;
    
    // Add context menu support for iOS 13+
    if (@available(iOS 13.0, *)) {
        UIContextMenuInteraction *contextMenuInteraction = [[UIContextMenuInteraction alloc] initWithDelegate:self];
        [self addInteraction:contextMenuInteraction];
    }
    
    // Album Image View
    self.albumImageView = [[UIImageView alloc] init];
    self.albumImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.albumImageView.layer.cornerRadius = 30; // 60x60 size
    self.albumImageView.layer.masksToBounds = YES;
    [self.contentView addSubview:self.albumImageView];
    
    // Title Label
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.textColor = [UIColor whiteColor];
    [self.contentView addSubview:self.titleLabel];
    
    // Artist Label
    self.artistLabel = [[UILabel alloc] init];
    self.artistLabel.textColor = [UIColor lightGrayColor];
    [self.contentView addSubview:self.artistLabel];
    
    // Separator
    self.separatorLine = [UIView new];
    self.separatorLine.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    [self.contentView addSubview:self.separatorLine];
    
    // Spectrum indicator (small spectrum visualization for currently playing track)
    self.spectrumIndicator = [[SpectrumView alloc] init];
    self.spectrumIndicator.numberOfBars = 4;
    self.spectrumIndicator.barSpacing = 1.5;
    self.spectrumIndicator.barColor = [UIColor colorWithRed:30/255.0 green:215/255.0 blue:96/255.0 alpha:1.0];
    self.spectrumIndicator.hidden = YES;
    [self.contentView addSubview:self.spectrumIndicator];

    // Constraints
    [self.albumImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).offset(20);
        make.centerY.equalTo(self.contentView);
        make.width.height.equalTo(@60);
    }];
    
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.albumImageView.mas_right).offset(15);
        make.right.equalTo(self.spectrumIndicator.mas_left).offset(-10);
        make.top.equalTo(self.albumImageView.mas_top).offset(5);
    }];
    
    [self.artistLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.titleLabel.mas_left);
        make.right.equalTo(self.titleLabel.mas_right);
        make.bottom.equalTo(self.albumImageView.mas_bottom).offset(-5);
    }];
    
    [self.spectrumIndicator mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.contentView).offset(-20);
        make.centerY.equalTo(self.contentView);
        make.width.equalTo(@24);
        make.height.equalTo(@16);
    }];
    
    [self.separatorLine mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.titleLabel.mas_left);
        make.right.equalTo(self.contentView);
        make.bottom.equalTo(self.contentView);
        make.height.equalTo(@0.5);
    }];
}

- (void)configureWithTrack:(MusicModel *)track {
    self.currentTrack = track;
    self.titleLabel.text = track.name;
    self.artistLabel.text = [track.artist componentsJoinedByString:@", "];
    
    // 设置自适应字体
    [self updateFontsForScreenSize];
    
    // 设置默认占位图片
    UIImage *placeholderImage = [UIImage systemImageNamed:@"music.note"];
    if (@available(iOS 13.0, *)) {
        placeholderImage = [placeholderImage imageWithTintColor:[UIColor colorWithWhite:1.0 alpha:0.3]];
    }
    self.albumImageView.image = placeholderImage;
    self.albumImageView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];

    // 取消之前的图片加载请求
    [self.albumImageView sd_cancelCurrentImageLoad];
    
    // 使用缓存管理器获取图片URL
    if (track.picId && track.picId.length > 0) {
        NSLog(@"🎵 [MusicListCell] Loading image for track: %@, picId: %@", track.name, track.picId);
        [[MusicImageCacheManager sharedManager] getImageURLWithPicId:track.picId
                                                               source:track.source
                                                                 size:MusicImageSizeSmall
                                                           completion:^(NSString * _Nullable imageUrl, NSError * _Nullable error) {
            // 确保cell没有被复用，并且track ID匹配
            if (imageUrl && imageUrl.length > 0 && [self.currentTrack.trackId isEqualToString:track.trackId]) {
                NSLog(@"🎵 [MusicListCell] Got image URL for track: %@, URL: %@", track.name, imageUrl);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.albumImageView sd_setImageWithURL:[NSURL URLWithString:imageUrl]
                                            placeholderImage:placeholderImage
                                                     options:SDWebImageRetryFailed | SDWebImageRefreshCached
                                                   completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
                        // 再次检查cell是否还对应相同的track
                        if (image && [self.currentTrack.trackId isEqualToString:track.trackId]) {
                            NSLog(@"🎵 [MusicListCell] Image loaded successfully for track: %@", track.name);
                            self.albumImageView.backgroundColor = [UIColor clearColor];
                            // 图片加载完成后立即更新动画状态
                            [self updateAnimationState];
                        } else if (error && [self.currentTrack.trackId isEqualToString:track.trackId]) {
                            NSLog(@"🎵 [MusicListCell] Image loading failed for track: %@, error: %@", track.name, error.localizedDescription);
                            // 保持占位符图片
                        }
                    }];
                });
            } else if (error && [self.currentTrack.trackId isEqualToString:track.trackId]) {
                NSLog(@"🎵 [MusicListCell] Failed to get image URL for track: %@, error: %@", track.name, error.localizedDescription);
                // 图片URL获取失败，保持占位符图片即可，不需要额外处理
            } else if ((!imageUrl || imageUrl.length == 0) && [self.currentTrack.trackId isEqualToString:track.trackId]) {
                NSLog(@"🎵 [MusicListCell] Empty image URL returned for track: %@", track.name);
                // 空URL，保持占位符图片即可
            }
        }];
    } else {
        NSLog(@"🎵 [MusicListCell] No picId available for track: %@", track.name);
        // 没有picId，已经设置了占位符图片，不需要额外处理
    }
    
    // 立即更新动画状态（不管图片是否加载完成）
    [self updateAnimationState];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    
    // 完全停止所有动画
    [self stopAlbumArtRotation];
    [self stopSpectrumIndicatorAnimation];
    
    // 取消图片加载请求
    [self.albumImageView sd_cancelCurrentImageLoad];
    
    // 重置为占位符图片而不是nil，避免空白
    UIImage *placeholderImage = [UIImage systemImageNamed:@"music.note"];
    if (@available(iOS 13.0, *)) {
        placeholderImage = [placeholderImage imageWithTintColor:[UIColor colorWithWhite:1.0 alpha:0.3]];
    }
    self.albumImageView.image = placeholderImage;
    self.albumImageView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    
    // 确保layer状态完全重置
    self.albumImageView.layer.speed = 1.0;
    self.albumImageView.layer.timeOffset = 0.0;
    self.albumImageView.layer.beginTime = 0.0;
    self.albumImageView.transform = CGAffineTransformIdentity;
    
    self.currentTrack = nil;
    self.titleLabel.text = nil;
    self.artistLabel.text = nil;
    self.spectrumIndicator.hidden = YES;
    
    NSLog(@"🎵 [Cell] Prepared for reuse - all animations stopped");
}

#pragma mark - Animation Helpers

- (BOOL)isCurrentlyPlayingTrack {
    MusicModel *currentPlayingTrack = [MusicPlayerController sharedController].currentTrack;
    return currentPlayingTrack && self.currentTrack && 
           [currentPlayingTrack.trackId isEqualToString:self.currentTrack.trackId];
}

- (void)updateAnimationState {
    BOOL isCurrentTrack = [self isCurrentlyPlayingTrack];
    BOOL isPlaying = [MusicPlayerController sharedController].isPlaying;
    
    // 更新频谱指示器的显示状态
    self.spectrumIndicator.hidden = !isCurrentTrack;
    
    if (isCurrentTrack) {
        if (isPlaying) {
            // 当前播放且正在播放 - 启动所有动画
            [self startAlbumArtRotation];
            [self startSpectrumIndicatorAnimation];
        } else {
            // 当前播放但暂停 - 暂停动画
            [self pauseAlbumArtRotation];
            [self stopSpectrumIndicatorAnimation];
        }
    } else {
        // 不是当前播放的歌曲 - 停止所有动画
        [self stopAlbumArtRotation];
        [self stopSpectrumIndicatorAnimation];
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
    
    NSLog(@"🎵 [Animation] Started rotation animation for track: %@", self.currentTrack.name ?: @"Unknown");
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
    
    NSLog(@"🎵 [Animation] Paused rotation animation for track: %@", self.currentTrack.name ?: @"Unknown");
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
    
    NSLog(@"🎵 [Animation] Resumed rotation animation for track: %@", self.currentTrack.name ?: @"Unknown");
}

- (void)stopAlbumArtRotation {
    [self.albumImageView.layer removeAnimationForKey:@"rotationAnimation"];
    // 重置layer状态
    self.albumImageView.layer.speed = 1.0;
    self.albumImageView.layer.timeOffset = 0.0;
    self.albumImageView.layer.beginTime = 0.0;
    
    NSLog(@"🎵 [Animation] Stopped rotation animation for track: %@", self.currentTrack.name ?: @"Unknown");
}

#pragma mark - Spectrum Indicator Animation

- (void)startSpectrumIndicatorAnimation {
    // Create a simple animation for the spectrum indicator
    CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateSpectrumIndicator)];
    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
    // Store the display link for later cleanup
    objc_setAssociatedObject(self, @selector(startSpectrumIndicatorAnimation), displayLink, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)stopSpectrumIndicatorAnimation {
    CADisplayLink *displayLink = objc_getAssociatedObject(self, @selector(startSpectrumIndicatorAnimation));
    [displayLink invalidate];
    objc_setAssociatedObject(self, @selector(startSpectrumIndicatorAnimation), nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // Reset spectrum to minimal state
    float levels[4] = {0.1, 0.1, 0.1, 0.1};
    [self.spectrumIndicator updateWithLevels:levels];
}

- (void)updateSpectrumIndicator {
    float levels[4];
    for (int i = 0; i < 4; i++) {
        // Create a simple bouncing animation
        float phase = CACurrentMediaTime() * (3 + i * 0.5);
        levels[i] = 0.3 + 0.4 * (sin(phase) * 0.5 + 0.5);
    }
    [self.spectrumIndicator updateWithLevels:levels];
}

#pragma mark - UIContextMenuInteractionDelegate

- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location API_AVAILABLE(ios(13.0)) {
    if (!self.currentTrack) return nil;
    
    return [UIContextMenuConfiguration configurationWithIdentifier:nil
                                                   previewProvider:nil
                                                    actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        return [self createContextMenu];
    }];
}

- (UIMenu *)createContextMenu API_AVAILABLE(ios(13.0)) {
    if (!self.delegate || !self.currentTrack) {
        return nil;
    }
    
    NSMutableArray<UIAction *> *actions = [NSMutableArray array];
    
    // Get available playlists from delegate
    NSArray<PlaylistModel *> *playlists = [self.delegate availablePlaylists];
    
    if (playlists.count > 0) {
        // Create submenu for playlists
        NSMutableArray<UIAction *> *playlistActions = [NSMutableArray array];
        
        for (PlaylistModel *playlist in playlists) {
            UIAction *playlistAction = [UIAction actionWithTitle:playlist.name
                                                           image:[UIImage systemImageNamed:@"music.note.list"]
                                                      identifier:nil
                                                         handler:^(__kindof UIAction * _Nonnull action) {
                [self.delegate addMusic:self.currentTrack toPlaylist:playlist];
            }];
            [playlistActions addObject:playlistAction];
        }
        
        UIMenu *playlistMenu = [UIMenu menuWithTitle:@"添加到歌单"
                                               image:[UIImage systemImageNamed:@"plus.circle"]
                                          identifier:nil
                                             options:UIMenuOptionsDisplayInline
                                            children:playlistActions];
        
        [actions addObject:playlistMenu];
    }
    
    // Create "Play Next" action
    UIAction *playNextAction = [UIAction actionWithTitle:@"下一首播放"
                                                   image:[UIImage systemImageNamed:@"text.insert"]
                                              identifier:nil
                                                 handler:^(__kindof UIAction * _Nonnull action) {
        // Add logic to play next (this would need to be implemented in the music controller)
        NSLog(@"Play next: %@", self.currentTrack.name);
    }];
    [actions addObject:playNextAction];
    
    return [UIMenu menuWithTitle:@""
                           image:nil
                      identifier:nil
                         options:0
                        children:actions];
}

- (void)updateFontsForScreenSize {
    CGFloat screenWidth = [[UIScreen mainScreen] bounds].size.width;
    CGFloat titleFontSize, artistFontSize;
    
    if (screenWidth <= 390) { // iPhone
        titleFontSize = 16;
        artistFontSize = 13;
    } else if (screenWidth <= 834) { // iPad Mini/iPhone Plus
        titleFontSize = 18;
        artistFontSize = 15;
    } else { // iPad/Mac
        titleFontSize = 20;
        artistFontSize = 17;
    }
    
    self.titleLabel.font = [UIFont systemFontOfSize:titleFontSize weight:UIFontWeightMedium];
    self.artistLabel.font = [UIFont systemFontOfSize:artistFontSize];
}

@end
