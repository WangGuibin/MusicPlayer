//
//  HomeViewController.m
//  MusicPlayer
//
//  Created by Gemini on 2025/9/4.
//

#import "HomeViewController.h"
#import "HomeCategoryCell.h"
#import "MusicListViewController.h"
#import "HistoryViewController.h"
#import "PlaylistManagementViewController.h"
#import "MusicSettingsViewController.h"
#import <Masonry/Masonry.h>

@interface HomeViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UISearchBarDelegate>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<NSDictionary *> *categories;
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) UIButton *exitButton;
@property (nonatomic, strong) UIButton *settingsButton;

@end

@implementation HomeViewController

static NSString * const kCategoryCellIdentifier = @"HomeCategoryCell";

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupData];
    [self setupUI];
    [self setupSearchController];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    // 设置状态栏样式为白色内容
    if (@available(iOS 13.0, *)) {
        [self setNeedsStatusBarAppearanceUpdate];
    } else {
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
    }

}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.gradientLayer.frame = self.view.bounds;
}


- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent; // iOS 13+ 白色内容的状态栏
}

- (BOOL)prefersStatusBarHidden {
    return NO; // 确保状态栏显示
}

#pragma mark - Setup

- (void)setupData {
    // Data based on the user's screenshot, adding history and playlist entries
    self.categories = @[
        @{@"title": @"播放历史", @"keyword": @"history", @"color": @(0x9B59B6), @"type": @"system"},
        @{@"title": @"我的歌单", @"keyword": @"playlist", @"color": @(0x3498DB), @"type": @"system"},
        @{@"title": @"飙升榜", @"keyword": @"飙升榜", @"color": @(0xAC4545), @"type": @"music"},
        @{@"title": @"新歌榜", @"keyword": @"新歌榜", @"color": @(0x349E9C), @"type": @"music"},
        @{@"title": @"热歌榜", @"keyword": @"热歌榜", @"color": @(0xC85A5A), @"type": @"music"},
        @{@"title": @"古典榜", @"keyword": @"古典音乐", @"color": @(0xBF8E6A), @"type": @"music"},
        @{@"title": @"电音榜", @"keyword": @"电子音乐", @"color": @(0x7F62B3), @"type": @"music"},
        @{@"title": @"ACG榜", @"keyword": @"ACG", @"color": @(0xE67C7C), @"type": @"music"},
        @{@"title": @"欧美热歌榜", @"keyword": @"欧美", @"color": @(0xB34D6C), @"type": @"music"},
        @{@"title": @"日语榜", @"keyword": @"日语", @"color": @(0xD96464), @"type": @"music"},
        @{@"title": @"韩语榜", @"keyword": @"韩语", @"color": @(0x627EB3), @"type": @"music"}
    ];
}

- (void)setupUI {
    // Set modal presentation background color
    if (@available(iOS 13.0, *)) {
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }

    self.title = @"GD音乐台 for iOS";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    // Add navigation buttons
    [self setupNavigationButtons];

    // 确保view有不透明的背景色
    self.view.backgroundColor = [UIColor colorWithRed:55/255.0 green:25/255.0 blue:77/255.0 alpha:1.0];

    // Gradient Background
    self.gradientLayer = [CAGradientLayer layer];
    self.gradientLayer.colors = @[
        (id)[UIColor colorWithRed:55/255.0 green:25/255.0 blue:77/255.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:22/255.0 green:22/255.0 blue:22/255.0 alpha:1.0].CGColor
    ];
    self.gradientLayer.startPoint = CGPointMake(0, 0);
    self.gradientLayer.endPoint = CGPointMake(1, 1);
    [self.view.layer insertSublayer:self.gradientLayer atIndex:0];

    // Collection View Layout
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.sectionInset = UIEdgeInsetsMake(20, 20, 20, 20);
    layout.minimumInteritemSpacing = 15;
    layout.minimumLineSpacing = 20;

    // Collection View
    self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    [self.collectionView registerClass:[HomeCategoryCell class] forCellWithReuseIdentifier:kCategoryCellIdentifier];
    [self.view addSubview:self.collectionView];

    [self.collectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
}

- (void)setupNavigationButtons {    
    // 设置按钮（右侧）
    self.settingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.settingsButton setImage:[UIImage systemImageNamed:@"gearshape"] forState:UIControlStateNormal];
    [self.settingsButton addTarget:self action:@selector(showMusicSettings) forControlEvents:UIControlEventTouchUpInside];
    self.settingsButton.tintColor = [UIColor whiteColor];
    
    UIBarButtonItem *settingsItem = [[UIBarButtonItem alloc] initWithCustomView:self.settingsButton];
    self.navigationItem.rightBarButtonItem = settingsItem;
}

- (void)exitButtonTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showMusicSettings {
    MusicSettingsViewController *settingsVC = [[MusicSettingsViewController alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)setupSearchController {
    MusicListViewController *searchResultsVC = [[MusicListViewController alloc] init];
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:searchResultsVC];
    self.searchController.searchBar.delegate = self; // Set delegate for search button click
    self.searchController.obscuresBackgroundDuringPresentation = NO; // 改为NO，避免透明问题
    self.searchController.searchBar.placeholder = @"搜索歌曲或歌手";
    self.searchController.searchBar.barStyle = UIBarStyleBlack;
    // 确保搜索栏显示
    if (@available(iOS 11.0, *)) {
        self.navigationItem.searchController = self.searchController;
        self.navigationItem.hidesSearchBarWhenScrolling = NO; // 始终显示搜索栏
    } else {
        self.navigationItem.titleView = self.searchController.searchBar;
    }
    
    self.definesPresentationContext = YES;
}

#pragma mark - UISearchBarDelegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    NSString *searchText = searchBar.text;
    if (searchText && searchText.length > 0) {
        MusicListViewController *resultsVC = (MusicListViewController *)self.searchController.searchResultsController;
        resultsVC.title = [NSString stringWithFormat:@"'%@' 的搜索结果", searchText];
        [resultsVC performSearchWithKeyword:searchText];
    }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.categories.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    HomeCategoryCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kCategoryCellIdentifier forIndexPath:indexPath];
    NSDictionary *category = self.categories[indexPath.item];
    [cell configureWithTitle:category[@"title"] colorHex:[category[@"color"] unsignedIntValue]];
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *category = self.categories[indexPath.item];
    NSString *type = category[@"type"];
    
    if ([type isEqualToString:@"system"]) {
        NSString *keyword = category[@"keyword"];
        if ([keyword isEqualToString:@"history"]) {
            HistoryViewController *historyVC = [[HistoryViewController alloc] init];
            [self.navigationController pushViewController:historyVC animated:YES];
        } else if ([keyword isEqualToString:@"playlist"]) {
            PlaylistManagementViewController *playlistVC = [[PlaylistManagementViewController alloc] init];
            [self.navigationController pushViewController:playlistVC animated:YES];
        }
    } else {
        MusicListViewController *listVC = [[MusicListViewController alloc] init];
        listVC.searchKeyword = category[@"keyword"];
        listVC.title = category[@"title"];
        
        [self.navigationController pushViewController:listVC animated:YES];
    }
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat screenWidth = self.view.bounds.size.width;
    CGFloat padding = 20.0;
    CGFloat itemSpacing = 15.0;
    
    CGFloat numberOfItemsPerRow;
    
    // 根据屏幕宽度自适应列数
    if (screenWidth <= 390) { // iPhone 
        numberOfItemsPerRow = 2.0;
    } else if (screenWidth <= 834) { // iPad Mini, iPhone Plus
        numberOfItemsPerRow = 3.0;
    } else if (screenWidth <= 1080) { // iPad
        numberOfItemsPerRow = 4.0;
    } else { // iPad Pro, Mac
        numberOfItemsPerRow = 5.0;
    }
    
    CGFloat totalPadding = padding * 2; // 左右边距
    CGFloat totalSpacing = itemSpacing * (numberOfItemsPerRow - 1); // 项目间距
    CGFloat itemWidth = (screenWidth - totalPadding - totalSpacing) / numberOfItemsPerRow;
    
    return CGSizeMake(itemWidth - 1, itemWidth);
}

@end
