//
//  CurrentPlaylistViewController.m
//  MusicPlayer
//
//  Created by Claude on 2025/9/5.
//

#import "CurrentPlaylistViewController.h"
#import "MusicPlayerController.h"
#import "MusicModel.h"
#import <Masonry/Masonry.h>

#pragma mark - PlaylistCell Interface

@interface PlaylistCell : UITableViewCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) UIImageView *playingIndicator;
- (void)configureWithTrack:(MusicModel *)track isPlaying:(BOOL)isPlaying;
@end

#pragma mark - CurrentPlaylistViewController Implementation

@interface CurrentPlaylistViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<MusicModel *> *songQueue;
@property (nonatomic, strong) UIVisualEffectView *backgroundView;
@property (nonatomic, strong) UIView *grabberHandle;

@end

@implementation CurrentPlaylistViewController

static NSString * const kPlaylistCellIdentifier = @"PlaylistCell";

- (void)viewDidLoad {
    [super viewDidLoad];
    self.songQueue = [MusicPlayerController sharedController].songQueue;
    [self setupUI];
}

- (void)setupUI {
    self.view.backgroundColor = [UIColor clearColor];

    // Background
    self.backgroundView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    [self.view addSubview:self.backgroundView];
    [self.backgroundView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];

    // Grabber Handle
    if (@available(iOS 15.0, *)) {
        self.grabberHandle = nil;
    }else{
        self.grabberHandle = [[UIView alloc] init];
        self.grabberHandle.backgroundColor = [UIColor grayColor];
        self.grabberHandle.layer.cornerRadius = 2.5;
        [self.view addSubview:self.grabberHandle];
        [self.grabberHandle mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.view).offset(10);
            make.centerX.equalTo(self.view);
            make.width.equalTo(@40);
            make.height.equalTo(@5);
        }];
    }

    // Table View
    self.tableView = [[UITableView alloc] init];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:[PlaylistCell class] forCellReuseIdentifier:kPlaylistCellIdentifier];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:self.tableView];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        if (@available(iOS 15.0, *)) {
            make.top.equalTo(self.view.mas_top).offset(10);
        }else{
            make.top.equalTo(self.grabberHandle.mas_bottom).offset(10);
        }
        make.left.right.bottom.equalTo(self.view);
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.songQueue.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PlaylistCell *cell = [tableView dequeueReusableCellWithIdentifier:kPlaylistCellIdentifier forIndexPath:indexPath];
    MusicModel *track = self.songQueue[indexPath.row];
    BOOL isPlaying = (indexPath.row == [MusicPlayerController sharedController].currentIndex);
    [cell configureWithTrack:track isPlaying:isPlaying];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    MusicPlayerController *player = [MusicPlayerController sharedController];
    
    // Only change playback if it's a different track index (the queue should be the same)
    if (player.currentIndex != indexPath.row) {
        [player playTrackAtIndex:indexPath.row];
    }
    // If it's the same track, just dismiss to return to the player view
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60.0;
}

@end

#pragma mark - PlaylistCell Implementation

@implementation PlaylistCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        
        self.playingIndicator = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"waveform"]];
        self.playingIndicator.tintColor = [UIColor colorWithRed:30/255.0 green:215/255.0 blue:96/255.0 alpha:1.0];
        [self.contentView addSubview:self.playingIndicator];

        self.titleLabel = [[UILabel alloc] init];
        [self.contentView addSubview:self.titleLabel];

        self.artistLabel = [[UILabel alloc] init];
        self.artistLabel.font = [UIFont systemFontOfSize:12];
        [self.contentView addSubview:self.artistLabel];

        [self.playingIndicator mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.contentView).offset(20);
            make.centerY.equalTo(self.contentView);
            make.width.height.equalTo(@20);
        }];

        [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.contentView).offset(50);
            make.right.equalTo(self.contentView).offset(-20);
            make.top.equalTo(self.contentView).offset(10);
        }];

        [self.artistLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.right.equalTo(self.titleLabel);
            make.top.equalTo(self.titleLabel.mas_bottom).offset(4);
        }];
    }
    return self;
}

- (void)configureWithTrack:(MusicModel *)track isPlaying:(BOOL)isPlaying {
    self.titleLabel.text = track.name;
    self.artistLabel.text = [track.artist componentsJoinedByString:@", "];
    
    if (isPlaying) {
        self.playingIndicator.hidden = NO;
        self.titleLabel.textColor = [UIColor colorWithRed:30/255.0 green:215/255.0 blue:96/255.0 alpha:1.0];
        self.artistLabel.textColor = [UIColor colorWithRed:30/255.0 green:215/255.0 blue:96/255.0 alpha:0.8];
    } else {
        self.playingIndicator.hidden = YES;
        self.titleLabel.textColor = [UIColor whiteColor];
        self.artistLabel.textColor = [UIColor grayColor];
    }
}

@end