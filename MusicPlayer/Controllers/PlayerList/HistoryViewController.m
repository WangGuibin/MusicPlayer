//
//  HistoryViewController.m
//  MusicPlayer
//
//  Created by Claude on 2025/9/5.
//

#import "HistoryViewController.h"
#import "MusicListCell.h"
#import "PlayerViewController.h"
#import "MusicStorageManager.h"
#import "MusicPlayerController.h"
#import <Masonry/Masonry.h>

@interface HistoryViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<MusicModel *> *historyList;
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@property (nonatomic, strong) UILabel *emptyLabel;

@end

@implementation HistoryViewController

static NSString * const kMusicCellIdentifier = @"MusicListCell";

- (void)viewDidLoad {
    [super viewDidLoad];
    // Set modal presentation background color
    if (@available(iOS 13.0, *)) {
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }

    [self setupUI];
    [self loadHistoryData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadHistoryData];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.gradientLayer.frame = self.view.bounds;
}

#pragma mark - UI Setup

- (void)setupUI {
    self.title = @"播放历史";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    
    // Add clear history button
    UIBarButtonItem *clearButton = [[UIBarButtonItem alloc] initWithTitle:@"清空" 
                                                                    style:UIBarButtonItemStylePlain 
                                                                   target:self 
                                                                   action:@selector(clearHistoryTapped)];
    self.navigationItem.rightBarButtonItem = clearButton;
    
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

    // Empty state label
    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = @"暂无播放历史";
    self.emptyLabel.textColor = [UIColor lightGrayColor];
    self.emptyLabel.font = [UIFont systemFontOfSize:16];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];
    
    [self.emptyLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.view);
    }];
}

#pragma mark - Data Loading

- (void)loadHistoryData {
    self.historyList = [[MusicStorageManager sharedManager] getHistoryList];
    [self.tableView reloadData];
    
    self.emptyLabel.hidden = self.historyList.count > 0;
    self.navigationItem.rightBarButtonItem.enabled = self.historyList.count > 0;
}

#pragma mark - Actions

- (void)clearHistoryTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清空历史" 
                                                                   message:@"确定要清空所有播放历史吗？" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" 
                                                           style:UIAlertActionStyleCancel 
                                                         handler:nil];
    
    UIAlertAction *clearAction = [UIAlertAction actionWithTitle:@"清空" 
                                                          style:UIAlertActionStyleDestructive 
                                                        handler:^(UIAlertAction * _Nonnull action) {
        [[MusicStorageManager sharedManager] clearHistory];
        [self loadHistoryData];
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:clearAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.historyList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MusicListCell *cell = [tableView dequeueReusableCellWithIdentifier:kMusicCellIdentifier forIndexPath:indexPath];
    
    MusicModel *track = self.historyList[indexPath.row];
    [cell configureWithTrack:track];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 80.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    MusicModel *selectedTrack = self.historyList[indexPath.row];
    
    // Add to history (will move it to top)
    [[MusicStorageManager sharedManager] addToHistory:selectedTrack];
    
    MusicPlayerController *player = [MusicPlayerController sharedController];
    
    // Check if this is the same track that's currently playing
    BOOL isSameTrack = [player isSamePlaylistAndTrack:self.historyList trackIndex:indexPath.row];
    
    if (isSameTrack) {
        // Same track - just update the playlist but keep playing
        [player updatePlaylistOnly:self.historyList currentIndex:indexPath.row];
    } else {
        // Different track - start new playback
        [player setSongQueue:self.historyList];
        [player playTrackAtIndex:indexPath.row];
    }
    
    // Always present the player view controller
    PlayerViewController *playerVC = [[PlayerViewController alloc] init];
    playerVC.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:playerVC animated:YES completion:nil];
}

@end
