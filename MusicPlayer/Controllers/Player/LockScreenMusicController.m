//
//  LockScreenMusicController.m
//  VodTV
//
//  Created by Claude on 2025/9/7.
//

#import "LockScreenMusicController.h"
#import "MusicPlayerController.h"
#import "MusicAPIManager.h"
#import "MusicImageCacheManager.h"

@interface LockScreenMusicController ()

@property (nonatomic, strong) NSMutableDictionary *nowPlayingInfo;
@property (nonatomic, strong) NSArray<NSDictionary *> *lyricsData;
@property (nonatomic, strong) NSTimer *lyricsUpdateTimer;
@property (nonatomic, assign) NSInteger currentLyricsIndex;

@end

@implementation LockScreenMusicController

#pragma mark - Singleton

+ (instancetype)sharedController {
    static LockScreenMusicController *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[LockScreenMusicController alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        self.nowPlayingInfo = [NSMutableDictionary dictionary];
        self.currentLyricsIndex = -1;
        [self addPlayerObservers];
    }
    return self;
}

- (void)dealloc {
    [self removePlayerObservers];
    [self.lyricsUpdateTimer invalidate];
}

#pragma mark - Remote Controls Setup

- (void)setupRemoteControls {
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    
    // Enable commands
    [commandCenter.playCommand setEnabled:YES];
    [commandCenter.pauseCommand setEnabled:YES];
    [commandCenter.nextTrackCommand setEnabled:YES];
    [commandCenter.previousTrackCommand setEnabled:YES];
    [commandCenter.changePlaybackPositionCommand setEnabled:YES];
    
    // Add handlers
    [commandCenter.playCommand addTarget:self action:@selector(remotePlay:)];
    [commandCenter.pauseCommand addTarget:self action:@selector(remotePause:)];
    [commandCenter.nextTrackCommand addTarget:self action:@selector(remoteNextTrack:)];
    [commandCenter.previousTrackCommand addTarget:self action:@selector(remotePreviousTrack:)];
    [commandCenter.changePlaybackPositionCommand addTarget:self action:@selector(remoteChangePlaybackPosition:)];
    
    // Optional: Skip intervals
    [commandCenter.skipForwardCommand setEnabled:YES];
    [commandCenter.skipBackwardCommand setEnabled:YES];
    [commandCenter.skipForwardCommand setPreferredIntervals:@[@15]]; // 15 seconds forward
    [commandCenter.skipBackwardCommand setPreferredIntervals:@[@15]]; // 15 seconds backward
    [commandCenter.skipForwardCommand addTarget:self action:@selector(remoteSkipForward:)];
    [commandCenter.skipBackwardCommand addTarget:self action:@selector(remoteSkipBackward:)];
    
    // Rating command (like/dislike)
    [commandCenter.likeCommand setEnabled:YES];
    [commandCenter.dislikeCommand setEnabled:YES];
    [commandCenter.likeCommand addTarget:self action:@selector(remoteLike:)];
    [commandCenter.dislikeCommand addTarget:self action:@selector(remoteDislike:)];
    
    NSLog(@"🎵 Lock screen controls enabled");
}

- (void)removeRemoteControls {
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    
    [commandCenter.playCommand setEnabled:NO];
    [commandCenter.pauseCommand setEnabled:NO];
    [commandCenter.nextTrackCommand setEnabled:NO];
    [commandCenter.previousTrackCommand setEnabled:NO];
    [commandCenter.changePlaybackPositionCommand setEnabled:NO];
    [commandCenter.skipForwardCommand setEnabled:NO];
    [commandCenter.skipBackwardCommand setEnabled:NO];
    [commandCenter.likeCommand setEnabled:NO];
    [commandCenter.dislikeCommand setEnabled:NO];
    
    [commandCenter.playCommand removeTarget:self];
    [commandCenter.pauseCommand removeTarget:self];
    [commandCenter.nextTrackCommand removeTarget:self];
    [commandCenter.previousTrackCommand removeTarget:self];
    [commandCenter.changePlaybackPositionCommand removeTarget:self];
    [commandCenter.skipForwardCommand removeTarget:self];
    [commandCenter.skipBackwardCommand removeTarget:self];
    [commandCenter.likeCommand removeTarget:self];
    [commandCenter.dislikeCommand removeTarget:self];
    
    NSLog(@"🎵 Lock screen controls disabled");
}

#pragma mark - Remote Command Handlers

- (MPRemoteCommandHandlerStatus)remotePlay:(MPRemoteCommandEvent *)event {
    [[MusicPlayerController sharedController] play];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)remotePause:(MPRemoteCommandEvent *)event {
    [[MusicPlayerController sharedController] pause];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)remoteNextTrack:(MPRemoteCommandEvent *)event {
    [[MusicPlayerController sharedController] playNextTrack];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)remotePreviousTrack:(MPRemoteCommandEvent *)event {
    [[MusicPlayerController sharedController] playPreviousTrack];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)remoteChangePlaybackPosition:(MPChangePlaybackPositionCommandEvent *)event {
    NSTimeInterval positionTime = event.positionTime;
    [[MusicPlayerController sharedController] seekToTime:positionTime];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)remoteSkipForward:(MPSkipIntervalCommandEvent *)event {
    MusicPlayerController *player = [MusicPlayerController sharedController];
    NSTimeInterval newTime = player.currentTime + event.interval;
    [player seekToTime:MIN(newTime, player.totalTime)];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)remoteSkipBackward:(MPSkipIntervalCommandEvent *)event {
    MusicPlayerController *player = [MusicPlayerController sharedController];
    NSTimeInterval newTime = player.currentTime - event.interval;
    [player seekToTime:MAX(newTime, 0)];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)remoteLike:(MPRemoteCommandEvent *)event {
    // TODO: Implement like functionality
    NSLog(@"🎵 Track liked via lock screen");
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)remoteDislike:(MPRemoteCommandEvent *)event {
    // TODO: Implement dislike functionality
    NSLog(@"🎵 Track disliked via lock screen");
    return MPRemoteCommandHandlerStatusSuccess;
}

#pragma mark - Now Playing Info

- (void)updateNowPlayingInfo {
    MusicPlayerController *player = [MusicPlayerController sharedController];
    
    if (!player.currentTrack) {
        [self clearNowPlayingInfo];
        return;
    }
    
    MusicModel *track = player.currentTrack;
    
    [self.nowPlayingInfo removeAllObjects];
    
    // Basic track information
    NSString *trackInfo = [NSString stringWithFormat:@"%@ - %@",(track.name ?: @"未知歌曲"),([track.artist componentsJoinedByString:@", "] ?: @"未知")];
    self.nowPlayingInfo[MPMediaItemPropertyTitle] = trackInfo;
    self.nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = track.album ?: @"未知专辑";
    
    // Playback information
    self.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(player.currentTime);
    self.nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = @(player.totalTime);
    self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.isPlaying ? @1.0 : @0.0;
    
    // Track number if available
    if (player.currentIndex >= 0) {
        self.nowPlayingInfo[MPMediaItemPropertyAlbumTrackNumber] = @(player.currentIndex + 1);
    }
    
    // Initialize with title and artist info in comments field for lock screen display
    NSString *titleArtistLine = [NSString stringWithFormat:@"%@ - %@", 
                                track.name ?: @"未知歌曲", 
                                [track.artist componentsJoinedByString:@", "] ?: @"未知艺术家"];
    self.nowPlayingInfo[MPMediaItemPropertyComments] = [NSString stringWithFormat:@"%@\n♪ 加载中... ♪", titleArtistLine];
    
    // Load and set album artwork
    [self loadAndSetAlbumArtwork:track];
    
    // Load lyrics for the track
    [self loadLyricsForTrack:track];
    
    // Apply the now playing info
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = self.nowPlayingInfo;
    
    NSLog(@"🎵 Updated lock screen info for: %@ - %@", track.name, [track.artist componentsJoinedByString:@", "]);
}

- (void)updateNowPlayingInfoWithLyrics:(NSString *)lyrics {
    // Format the now playing info with title, artist, and current lyrics
    MusicPlayerController *player = [MusicPlayerController sharedController];
    MusicModel *track = player.currentTrack;
    
    if (!track) return;
    
    ///锁屏展示歌词
    NSString *lyricsLine = lyrics ?: @"♪ ♪ ♪";
    self.nowPlayingInfo[MPMediaItemPropertyArtist] = lyricsLine;
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = self.nowPlayingInfo;
    NSLog(@"🎵 Updated lock screen with lyrics: %@", lyricsLine);
}

- (void)clearNowPlayingInfo {
    [self.nowPlayingInfo removeAllObjects];
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
    [self.lyricsUpdateTimer invalidate];
    self.lyricsUpdateTimer = nil;
    self.lyricsData = nil;
    self.currentLyricsIndex = -1;
    
    NSLog(@"🎵 Cleared lock screen info");
}

- (void)updatePlaybackProgress:(NSTimeInterval)currentTime duration:(NSTimeInterval)duration {
    if (self.nowPlayingInfo.count > 0) {
        self.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(currentTime);
        self.nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = @(duration);
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = self.nowPlayingInfo;
    }
}

#pragma mark - Album Artwork

- (void)loadAndSetAlbumArtwork:(MusicModel *)track {
    if (!track.picId) {
        // Set default artwork
        UIImage *defaultImage = [UIImage systemImageNamed:@"music.note"];
        if (defaultImage) {
            MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:CGSizeMake(512, 512) requestHandler:^UIImage * _Nonnull(CGSize size) {
                return defaultImage;
            }];
            self.nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork;
            [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = self.nowPlayingInfo;
        }
        return;
    }
    
    [[MusicImageCacheManager sharedManager] getImageURLWithPicId:track.picId 
                                                           source:track.source 
                                                             size:MusicImageSizeLarge 
                                                       completion:^(NSString * _Nullable imageUrl, NSError * _Nullable error) {
        if (imageUrl) {
            // Download the image
            NSURL *url = [NSURL URLWithString:imageUrl];
            NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (data && !error) {
                    UIImage *image = [UIImage imageWithData:data];
                    if (image) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:image.size requestHandler:^UIImage * _Nonnull(CGSize size) {
                                return image;
                            }];
                            
                            // Only update if we're still playing the same track
                            MusicPlayerController *player = [MusicPlayerController sharedController];
                            if (player.currentTrack && [player.currentTrack.trackId isEqualToString:track.trackId]) {
                                self.nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork;
                                [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = self.nowPlayingInfo;
                            }
                        });
                    }
                }
            }];
            [task resume];
        }
    }];
}

#pragma mark - Lyrics Management

- (void)loadLyricsForTrack:(MusicModel *)track {
    [[MusicAPIManager sharedManager] getLyricsWithTrackId:track.trackId 
                                                   source:track.source 
                                               completion:^(NSString * _Nullable lyrics, NSError * _Nullable error) {
        if (lyrics && lyrics.length > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self parseLyrics:lyrics];
                [self startLyricsUpdateTimer];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                // Update with "no lyrics" message in proper format
                [self updateNowPlayingInfoWithLyrics:@"♪ 暂无歌词 ♪"];
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
    
    NSLog(@"🎵 Parsed %ld lyrics lines for lock screen", (long)parsedLyrics.count);
}

- (void)startLyricsUpdateTimer {
    [self.lyricsUpdateTimer invalidate];
    self.lyricsUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 
                                                              target:self 
                                                            selector:@selector(updateLyricsOnLockScreen) 
                                                            userInfo:nil 
                                                             repeats:YES];
}

- (void)updateLyricsOnLockScreen {
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
        
        [self updateNowPlayingInfoWithLyrics:lyricsText];
    }
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
    [self setupRemoteControls];
    [self updateNowPlayingInfo];
}

- (void)playerDidChangeProgress:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSNumber *currentTimeNumber = userInfo[MusicPlayerCurrentTimeUserInfoKey];
    NSNumber *totalTimeNumber = userInfo[MusicPlayerTotalTimeUserInfoKey];
    
    if (currentTimeNumber && totalTimeNumber) {
        [self updatePlaybackProgress:currentTimeNumber.doubleValue duration:totalTimeNumber.doubleValue];
    }
}

- (void)playerDidPause:(NSNotification *)notification {
    self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = @0.0;
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = self.nowPlayingInfo;
}

- (void)playerDidResume:(NSNotification *)notification {
    self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = @1.0;
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = self.nowPlayingInfo;
}

- (void)playerDidStop:(NSNotification *)notification {
    [self removeRemoteControls];
    [self clearNowPlayingInfo];
}

@end
