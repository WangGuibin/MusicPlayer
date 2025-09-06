//
//  PlaylistManagementViewController.m
//  MusicPlayer
//
//  Created by Claude on 2025/9/5.
//

#import "PlaylistManagementViewController.h"
#import "PlaylistViewController.h"
#import "MusicStorageManager.h"
#import "PlaylistModel.h"
#import <Masonry/Masonry.h>

@interface PlaylistManagementViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<PlaylistModel *> *playlists;
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@property (nonatomic, strong) UILabel *emptyLabel;

@end

@implementation PlaylistManagementViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self loadPlaylistData];
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
    self.title = @"我的歌单";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    
    // Add create playlist button
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd 
                                                                               target:self 
                                                                               action:@selector(createPlaylistTapped)];
    
    self.navigationItem.rightBarButtonItem = addButton;
    
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
    self.tableView.rowHeight = 70.0;
    [self.view addSubview:self.tableView];
    
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];

    // Empty state label
    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = @"暂无歌单\n点击右上角+创建新歌单";
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
    NSArray<PlaylistModel *> *allPlaylists = [[MusicStorageManager sharedManager] getAllPlaylists];
    self.playlists = [allPlaylists mutableCopy];
    [self.tableView reloadData];
    
    self.emptyLabel.hidden = self.playlists.count > 0;
}

#pragma mark - Actions

- (void)createPlaylistTapped {
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
            [[MusicStorageManager sharedManager] createPlaylistWithName:playlistName];
            [self loadPlaylistData];
        }
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:createAction];
    [self presentViewController:alert animated:YES completion:nil];
}


#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.playlists.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"PlaylistCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    PlaylistModel *playlist = self.playlists[indexPath.row];
    cell.textLabel.text = playlist.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld首 • %@", (long)playlist.totalCount, playlist.createTime];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    PlaylistModel *playlist = self.playlists[indexPath.row];
    PlaylistViewController *playlistVC = [[PlaylistViewController alloc] init];
    playlistVC.playlist = playlist;
    [self.navigationController pushViewController:playlistVC animated:YES];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        PlaylistModel *playlist = self.playlists[indexPath.row];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"删除歌单" 
                                                                       message:[NSString stringWithFormat:@"确定要删除歌单 \"%@\" 吗？", playlist.name]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" 
                                                               style:UIAlertActionStyleCancel 
                                                             handler:nil];
        
        UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"删除" 
                                                               style:UIAlertActionStyleDestructive 
                                                             handler:^(UIAlertAction * _Nonnull action) {
            [[MusicStorageManager sharedManager] deletePlaylist:playlist];
            [self.playlists removeObjectAtIndex:indexPath.row];
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            self.emptyLabel.hidden = self.playlists.count > 0;
        }];
        
        [alert addAction:cancelAction];
        [alert addAction:deleteAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

@end
