//
//  MusicListViewController.m
//  MusicPlayer
//
//  Created by Gemini on 2025/9/4.
//

#import "MusicListViewController.h"
#import "MusicListCell.h"
#import "PlayerViewController.h"
#import "MusicAPIManager.h"
#import "MusicModel.h"
#import "MusicPlayerController.h"
#import "MusicStorageManager.h"
#import "MusicSettingsManager.h"
#import "PlaylistModel.h"
#import "MusicImageCacheManager.h"
#import <Masonry/Masonry.h>
#import <SDWebImage/UIImageView+WebCache.h>

@interface MusicListViewController () <UITableViewDataSource, UITableViewDelegate, MusicListCellDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<MusicModel *> *musicList; // Changed to mutable for pagination
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) CAGradientLayer *gradientLayer;

// Pagination properties
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) BOOL isLoadingMore;
@property (nonatomic, assign) BOOL hasMoreData;
@property (nonatomic, strong) UIView *footerLoadingView;
@property (nonatomic, strong) UIActivityIndicatorView *footerLoadingIndicator;
@property (nonatomic, strong) UILabel *footerLoadingLabel;
@property (nonatomic, assign) NSInteger itemsPerPage;
@property (nonatomic, copy) NSString *currentSearchKeyword;

@end

@implementation MusicListViewController

static NSString * const kMusicCellIdentifier = @"MusicListCell";

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initializePagination];
    [self setupUI];
    [self fetchInitialMusicList];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // 确保gradient layer的frame正确
    self.gradientLayer.frame = self.view.bounds;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // 确保gradient layer随视图大小变化而调整
    self.gradientLayer.frame = self.view.bounds;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}


#pragma mark - Initialization

- (void)initializePagination {
    self.musicList = [NSMutableArray array];
    self.currentPage = 1;
    self.isLoadingMore = NO;
    self.hasMoreData = YES;
    self.itemsPerPage = 20;
    self.currentSearchKeyword = self.searchKeyword ?: @"热门";
}

#pragma mark - UI Setup

- (void)setupUI {
    // If a search keyword is provided, use it as the title.
    // Otherwise, the title will be the default from HomeViewController.
    if (self.searchKeyword) {
        self.title = self.searchKeyword;
    }
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    
    // 设置暗黑模式样式
    if (@available(iOS 13.0, *)) {
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }
    
    // 确保view有不透明的背景色
    self.view.backgroundColor = [UIColor colorWithRed:22/255.0 green:22/255.0 blue:22/255.0 alpha:1.0];
        
    // Gradient Background
    self.gradientLayer = [CAGradientLayer layer];
    self.gradientLayer.colors = @[
        (id)[UIColor colorWithRed:22/255.0 green:22/255.0 blue:22/255.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:55/255.0 green:25/255.0 blue:77/255.0 alpha:1.0].CGColor
    ];
    self.gradientLayer.startPoint = CGPointMake(0, 0);
    self.gradientLayer.endPoint = CGPointMake(1, 1);
    [self.view.layer insertSublayer:self.gradientLayer atIndex:0];

    // Table View
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.tableView registerClass:[MusicListCell class] forCellReuseIdentifier:kMusicCellIdentifier];
    [self.view addSubview:self.tableView];
    
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];

    // Loading Indicator
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.color = [UIColor whiteColor];
    [self.view addSubview:self.loadingIndicator];
    [self.loadingIndicator mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.view);
    }];
    
    // Setup footer loading view
    [self setupFooterLoadingView];
}

- (void)setupFooterLoadingView {
    self.footerLoadingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 60)];
    self.footerLoadingView.backgroundColor = [UIColor clearColor];
    
    self.footerLoadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.footerLoadingIndicator.color = [UIColor whiteColor];
    [self.footerLoadingView addSubview:self.footerLoadingIndicator];
    
    self.footerLoadingLabel = [[UILabel alloc] init];
    self.footerLoadingLabel.text = @"加载更多...";
    self.footerLoadingLabel.textColor = [UIColor lightGrayColor];
    self.footerLoadingLabel.font = [UIFont systemFontOfSize:14];
    self.footerLoadingLabel.textAlignment = NSTextAlignmentLeft;
    [self.footerLoadingView addSubview:self.footerLoadingLabel];
    
    [self.footerLoadingIndicator mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.footerLoadingView).offset(-30);
        make.centerY.equalTo(self.footerLoadingView);
    }];
    
    [self.footerLoadingLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.footerLoadingIndicator.mas_right).offset(10);
        make.centerY.equalTo(self.footerLoadingView);
        make.right.equalTo(self.footerLoadingView).offset(-20);
    }];
    
    // Initially hidden
    self.footerLoadingView.hidden = YES;
}

#pragma mark - Data Fetching

- (void)fetchInitialMusicList {
    [self resetPagination];
    [self loadMusicDataForPage:1 isInitialLoad:YES];
}

- (void)resetPagination {
    self.currentPage = 1;
    self.isLoadingMore = NO;
    self.hasMoreData = YES;
    [self.musicList removeAllObjects];
    self.tableView.tableFooterView = nil;
}

- (void)performSearchWithKeyword:(NSString *)keyword {
    if (!keyword || keyword.length == 0) {
        [self.musicList removeAllObjects];
        [self.tableView reloadData];
        return;
    }
    
    self.currentSearchKeyword = keyword;
    [self fetchInitialMusicList];
}

- (void)loadMusicDataForPage:(NSInteger)page isInitialLoad:(BOOL)isInitialLoad {
    if (self.isLoadingMore && !isInitialLoad) {
        return; // Prevent multiple simultaneous requests
    }
    
    if (isInitialLoad) {
        [self.loadingIndicator startAnimating];
    } else {
        self.isLoadingMore = YES;
        [self showFooterLoading];
    }
    
    __weak typeof(self) weakSelf = self;
    MusicSettingsManager *settingsManager = [MusicSettingsManager sharedManager];
    NSString *sourceString = [settingsManager defaultSourceString];
    
    [[MusicAPIManager sharedManager] searchMusicWithKeyword:self.currentSearchKeyword
                                                     source:sourceString
                                                      count:self.itemsPerPage
                                                      pages:page
                                                 completion:^(NSArray<MusicModel *> * _Nullable results, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (isInitialLoad) {
            [strongSelf.loadingIndicator stopAnimating];
        } else {
            strongSelf.isLoadingMore = NO;
            [strongSelf hideFooterLoading];
        }
        
        if (error) {
            NSLog(@"Error fetching music: %@", error.localizedDescription);
            [strongSelf handleLoadError:error isInitialLoad:isInitialLoad];
            return;
        }
        
        [strongSelf handleLoadSuccess:results isInitialLoad:isInitialLoad];
    }];
}

- (void)handleLoadSuccess:(NSArray<MusicModel *> *)results isInitialLoad:(BOOL)isInitialLoad {
    if (isInitialLoad) {
        [self.musicList removeAllObjects];
    }
    
    if (results && results.count > 0) {
        [self.musicList addObjectsFromArray:results];
        self.currentPage++;
        
        // Check if we have more data (if returned count is less than requested, assume no more data)
        if (results.count < self.itemsPerPage) {
            self.hasMoreData = NO;
        }
        
        // 预缓存新加载的图片URL
        [[MusicImageCacheManager sharedManager] precacheImageURLsForMusicList:results];
    } else {
        self.hasMoreData = NO;
    }
    
    [self.tableView reloadData];
    
    // Update footer view based on hasMoreData status
    [self updateTableFooterView];
}

- (void)handleLoadError:(NSError *)error isInitialLoad:(BOOL)isInitialLoad {
    if (isInitialLoad) {
        [self.musicList removeAllObjects];
        [self.tableView reloadData];
    }
    
    // Show error message to user
    [self showErrorMessage:error.localizedDescription];
}

- (void)showErrorMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"加载失败" 
                                                                   message:message 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" 
                                                       style:UIAlertActionStyleDefault 
                                                     handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showFooterLoading {
    self.footerLoadingView.hidden = NO;
    [self.footerLoadingIndicator startAnimating];
    self.footerLoadingLabel.text = @"正在加载...";
    self.tableView.tableFooterView = self.footerLoadingView;
}

- (void)hideFooterLoading {
    [self.footerLoadingIndicator stopAnimating];
    [self updateTableFooterView];
}

- (void)updateTableFooterView {
    if (self.hasMoreData) {
        // Show "load more" state
        self.footerLoadingView.hidden = NO;
        [self.footerLoadingIndicator stopAnimating];
        self.footerLoadingLabel.text = @"上拉加载更多";
        self.tableView.tableFooterView = self.footerLoadingView;
    } else if (self.musicList.count > 0) {
        // Show "no more data" state
        self.footerLoadingView.hidden = NO;
        [self.footerLoadingIndicator stopAnimating];
        self.footerLoadingLabel.text = @"没有更多数据了";
        self.tableView.tableFooterView = self.footerLoadingView;
    } else {
        // Hide footer
        self.tableView.tableFooterView = nil;
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.musicList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MusicListCell *cell = [tableView dequeueReusableCellWithIdentifier:kMusicCellIdentifier forIndexPath:indexPath];
    
    MusicModel *track = self.musicList[indexPath.row];
    cell.delegate = self;
    [cell configureWithTrack:track];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 80.0; // Custom cell height
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    MusicModel *selectedTrack = self.musicList[indexPath.row];
    
    // Add to history
    [[MusicStorageManager sharedManager] addToHistory:selectedTrack];
    
    MusicPlayerController *player = [MusicPlayerController sharedController];
    
    // Check if this is the same track that's currently playing
    BOOL isSameTrack = [player isSamePlaylistAndTrack:self.musicList trackIndex:indexPath.row];
    
    if (isSameTrack) {
        // Same track - just update the playlist but keep playing
        [player updatePlaylistOnly:self.musicList currentIndex:indexPath.row];
    } else {
        // Different track - start new playback
        [player setSongQueue:self.musicList];
        [player playTrackAtIndex:indexPath.row];
    }
    
    // Always present the player view controller
    PlayerViewController *playerVC = [[PlayerViewController alloc] init];
    playerVC.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:playerVC animated:YES completion:nil];
}

#pragma mark - Scroll Detection for Pagination

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // Check if we should load more data
    if (self.hasMoreData && !self.isLoadingMore && self.musicList.count > 0) {
        CGFloat offsetY = scrollView.contentOffset.y;
        CGFloat contentHeight = scrollView.contentSize.height;
        CGFloat frameHeight = scrollView.frame.size.height;
        
        // Trigger loading when user scrolls to within 200 points of the bottom
        CGFloat threshold = 200.0;
        if (offsetY > contentHeight - frameHeight - threshold) {
            [self loadMusicDataForPage:self.currentPage isInitialLoad:NO];
        }
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    // Additional check when user finishes dragging
    if (self.hasMoreData && !self.isLoadingMore && self.musicList.count > 0) {
        CGFloat offsetY = scrollView.contentOffset.y;
        CGFloat contentHeight = scrollView.contentSize.height;
        CGFloat frameHeight = scrollView.frame.size.height;
        
        // More aggressive loading when user explicitly pulls to the bottom
        if (offsetY > contentHeight - frameHeight - 50) {
            [self loadMusicDataForPage:self.currentPage isInitialLoad:NO];
        }
    }
}

#pragma mark - MusicListCellDelegate

- (NSArray<PlaylistModel *> *)availablePlaylists {
    return [[MusicStorageManager sharedManager] getAllPlaylists];
}

- (void)addMusic:(MusicModel *)music toPlaylist:(PlaylistModel *)playlist {
    if (!music || !playlist) return;
    
    [[MusicStorageManager sharedManager] addMusic:music toPlaylist:playlist];
    
    // Show success message
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"添加成功" 
                                                                   message:[NSString stringWithFormat:@"已将 \"%@\" 添加到歌单 \"%@\"", music.name, playlist.name]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" 
                                                       style:UIAlertActionStyleDefault 
                                                     handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
