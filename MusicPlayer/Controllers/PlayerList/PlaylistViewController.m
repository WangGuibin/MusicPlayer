//
//  PlaylistViewController.m
//  MusicPlayer
//
//  Created by Gemini on 2025/9/5.
//

#import "PlaylistViewController.h"
#import "MusicListCell.h"
#import "PlayerViewController.h"
#import "MusicStorageManager.h"
#import "MusicPlayerController.h"
#import <Masonry/Masonry.h>

@interface PlaylistViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@property (nonatomic, strong) UILabel *emptyLabel;

@end

@implementation PlaylistViewController

static NSString * const kMusicCellIdentifier = @"MusicListCell";

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self loadPlaylistData];
    // Set modal presentation background color
    if (@available(iOS 13.0, *)) {
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadPlaylistData];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.gradientLayer.frame = self.view.bounds;
}

#pragma mark - UI Setup

- (void)setupUI {
    self.title = self.playlist ? self.playlist.name : @"播放列表";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    
    // Add play all button if playlist has songs
    if (self.playlist && self.playlist.musicList.count > 0) {
        UIBarButtonItem *playAllButton = [[UIBarButtonItem alloc] initWithTitle:@"播放全部" 
                                                                          style:UIBarButtonItemStylePlain 
                                                                         target:self 
                                                                         action:@selector(playAllTapped)];
        self.navigationItem.rightBarButtonItem = playAllButton;
    }
    
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
    self.emptyLabel.text = @"暂无歌曲\n可以从搜索结果添加歌曲到此歌单";
    self.emptyLabel.textColor = [UIColor lightGrayColor];
    self.emptyLabel.font = [UIFont systemFontOfSize:16];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];
    
    [self.emptyLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.view);
    }];
}

#pragma mark - Data Loading

- (void)loadPlaylistData {
    if (!self.playlist) return;
    
    [self.tableView reloadData];
    
    BOOL hasMusic = self.playlist.musicList.count > 0;
    self.emptyLabel.hidden = hasMusic;
    self.navigationItem.rightBarButtonItem.enabled = hasMusic;
}

#pragma mark - Actions

- (void)playAllTapped {
    if (self.playlist && self.playlist.musicList.count > 0) {
        MusicModel *firstTrack = self.playlist.musicList.firstObject;
        
        // Add first track to history
        [[MusicStorageManager sharedManager] addToHistory:firstTrack];
        
        PlayerViewController *playerVC = [[PlayerViewController alloc] init];
        
        [[MusicPlayerController sharedController] setSongQueue:self.playlist.musicList];
        [[MusicPlayerController sharedController] playTrackAtIndex:0];

        playerVC.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:playerVC animated:YES completion:nil];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.playlist ? self.playlist.musicList.count : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MusicListCell *cell = [tableView dequeueReusableCellWithIdentifier:kMusicCellIdentifier forIndexPath:indexPath];
    
    if (self.playlist && indexPath.row < self.playlist.musicList.count) {
        MusicModel *track = self.playlist.musicList[indexPath.row];
        [cell configureWithTrack:track];
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 80.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (self.playlist && indexPath.row < self.playlist.musicList.count) {
        MusicModel *selectedTrack = self.playlist.musicList[indexPath.row];
        
        // Add to history
        [[MusicStorageManager sharedManager] addToHistory:selectedTrack];
        
        MusicPlayerController *player = [MusicPlayerController sharedController];
        
        // Check if this is the same track that's currently playing
        BOOL isSameTrack = [player isSamePlaylistAndTrack:self.playlist.musicList trackIndex:indexPath.row];
        
        if (isSameTrack) {
            // Same track - just update the playlist but keep playing
            [player updatePlaylistOnly:self.playlist.musicList currentIndex:indexPath.row];
        } else {
            // Different track - start new playback
            [player setSongQueue:self.playlist.musicList];
            [player playTrackAtIndex:indexPath.row];
        }
        
        // Always present the player view controller
        PlayerViewController *playerVC = [[PlayerViewController alloc] init];
        playerVC.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:playerVC animated:YES completion:nil];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete && self.playlist) {
        [self.playlist removeMusicAtIndex:indexPath.row];
        [[MusicStorageManager sharedManager] updatePlaylist:self.playlist];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        [self loadPlaylistData];
    }
}

@end
