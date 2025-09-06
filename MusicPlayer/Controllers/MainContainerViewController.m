//
//  MainContainerViewController.m
//  MusicPlayer
//
//  Created by Gemini on 2025/9/5.
//

#import "MainContainerViewController.h"
#import "HomeViewController.h"
#import "MiniPlayerViewController.h"
#import "MusicPlayerController.h"
#import <Masonry/Masonry.h>
#import <KTVHTTPCache/KTVHTTPCache.h>

@interface MainContainerViewController ()

@property (nonatomic, strong) UINavigationController *navController;
@property (nonatomic, strong) MiniPlayerViewController *miniPlayerVC;
@property (nonatomic, strong) NSLayoutConstraint *miniPlayerHeightConstraint;

@end

@implementation MainContainerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    // Set modal presentation background color
    if (@available(iOS 13.0, *)) {
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }

    
    [self setupChildViewControllers];
    [self addPlayerObservers];
    [KTVHTTPCache proxySetPort:8181];
    [KTVHTTPCache proxyStart:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // Stop music playback when exiting the music module to ensure separation from video playback
    if (self.isBeingDismissed) {
        [[MusicPlayerController sharedController] stop];
        NSLog(@"Music player stopped - exiting music module");
    }
}

- (void)dealloc {
    // Ensure music is stopped and cleanup when the container is deallocated
    [KTVHTTPCache proxyStop];
    [[MusicPlayerController sharedController] stop];
    [self removePlayerObservers];
    NSLog(@"MainContainerViewController deallocated - music playback stopped");
}

- (void)setupChildViewControllers {
    // Main Content
    HomeViewController *homeVC = [[HomeViewController alloc] init];
    self.navController = [[UINavigationController alloc] initWithRootViewController:homeVC];
    self.navController.view.backgroundColor = [UIColor clearColor];

    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    // 创建模糊效果
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 100);
    blurView.alpha = 0.5;
    UIImage *blurImage = [self snapshotOfView:blurView];
    // 设置背景图片
    [appearance configureWithTransparentBackground];
    appearance.backgroundImage = blurImage;

    appearance.titleTextAttributes = @{
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSFontAttributeName: [UIFont boldSystemFontOfSize:18]
    };
    // 设置大标题样式
    appearance.largeTitleTextAttributes = @{
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSFontAttributeName: [UIFont boldSystemFontOfSize:34]
    };
    // 应用到导航栏
    self.navController.navigationBar.standardAppearance = appearance;
    self.navController.navigationBar.scrollEdgeAppearance = appearance;
    self.navController.navigationBar.compactAppearance = appearance;
    
    [self addChildViewController:self.navController];
    [self.view addSubview:self.navController.view];
    [self.navController didMoveToParentViewController:self];

    // Mini Player
    self.view.backgroundColor = [UIColor whiteColor];
    self.miniPlayerVC = [[MiniPlayerViewController alloc] init];
    [self addChildViewController:self.miniPlayerVC];
    [self.view addSubview:self.miniPlayerVC.view];
    [self.miniPlayerVC didMoveToParentViewController:self];

    // Layout
    [self.miniPlayerVC.view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(self.view);
    }];
    self.miniPlayerHeightConstraint = [self.miniPlayerVC.view.heightAnchor constraintEqualToConstant:0];
    self.miniPlayerHeightConstraint.active = YES;

    [self.navController.view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self.view);
        make.bottom.equalTo(self.miniPlayerVC.view.mas_top);
    }];
}

#pragma mark - Observers

- (void)addPlayerObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateMiniPlayerVisibility) name:MusicPlayerDidStartPlayingNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateMiniPlayerVisibility) name:MusicPlayerDidStopNotification object:nil];
}

- (void)removePlayerObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateMiniPlayerVisibility {
    MusicPlayerController *player = [MusicPlayerController sharedController];
    BOOL shouldShow = (player.currentTrack != nil);
    CGFloat newHeight = shouldShow ? 80.0 : 0;

    [UIView animateWithDuration:0.3 animations:^{
        self.miniPlayerHeightConstraint.constant = newHeight;
        [self.view layoutIfNeeded];
    }];
}

- (UIImage *)snapshotOfView:(UIView *)view {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, 0.0);
    if ([view respondsToSelector:@selector(drawViewHierarchyInRect:afterScreenUpdates:)]) {
        [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];
    } else {
        [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
@end
