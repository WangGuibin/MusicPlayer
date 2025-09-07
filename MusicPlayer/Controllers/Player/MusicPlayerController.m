//
//  MusicPlayerController.m
//  MusicAPI
//
//  Created by Qwen Code on 2025/9/3.
//

#import "MusicPlayerController.h"
#import "MusicAPIManager.h"
#import "MusicSettingsManager.h"
#import "LockScreenMusicController.h"
#import "PiPLyricsViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <KTVHTTPCache/KTVHTTPCache.h>

// Notification Names
NSNotificationName const MusicPlayerDidStartPlayingNotification = @"MusicPlayerDidStartPlayingNotification";
NSNotificationName const MusicPlayerDidChangeProgressNotification = @"MusicPlayerDidChangeProgressNotification";
NSNotificationName const MusicPlayerDidPauseNotification = @"MusicPlayerDidPauseNotification";
NSNotificationName const MusicPlayerDidResumeNotification = @"MusicPlayerDidResumeNotification";
NSNotificationName const MusicPlayerDidStopNotification = @"MusicPlayerDidStopNotification";
NSNotificationName const MusicPlayerDidFinishPlayingNotification = @"MusicPlayerDidFinishPlayingNotification";

// Notification UserInfo Keys
NSString * const MusicPlayerTrackUserInfoKey = @"track";
NSString * const MusicPlayerProgressUserInfoKey = @"progress";
NSString * const MusicPlayerCurrentTimeUserInfoKey = @"currentTime";
NSString * const MusicPlayerTotalTimeUserInfoKey = @"totalTime";
NSString * const MusicPlayerBufferedProgressUserInfoKey = @"bufferedProgress";


@interface MusicPlayerController()

@property (nonatomic, strong) AVPlayer *audioPlayer;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) NSTimer *progressTimer;

// Redefine readonly properties for internal writing
@property (nonatomic, strong, readwrite, nullable) MusicModel *currentTrack;
@property (nonatomic, assign, readwrite) NSInteger currentIndex;
@property (nonatomic, assign, readwrite) BOOL isPlaying;
@property (nonatomic, assign, readwrite) CGFloat progress;
@property (nonatomic, assign, readwrite) NSTimeInterval currentTime;
@property (nonatomic, assign, readwrite) NSTimeInterval totalTime;
@property (nonatomic, assign, readwrite) CGFloat bufferedProgress;


@end

@implementation MusicPlayerController

#pragma mark - Singleton

+ (instancetype)sharedController {
    static MusicPlayerController *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[MusicPlayerController alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentIndex = -1;
        _playbackMode = PlaybackModeSequential;
        
        // Configure audio session for music playback with proper error handling
        NSError *audioSessionError = nil;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        
        if (![session setCategory:AVAudioSessionCategoryPlayback error:&audioSessionError]) {
            NSLog(@"Failed to set audio session category: %@", audioSessionError.localizedDescription);
        }
        
        if (![session setActive:YES error:&audioSessionError]) {
            NSLog(@"Failed to activate audio session: %@", audioSessionError.localizedDescription);
        }
        
        // Add audio session interruption handling
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(handleAudioSessionInterruption:) 
                                                     name:AVAudioSessionInterruptionNotification 
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(handleSeekToTime:) 
                                                     name:@"SeekToTime" 
                                                   object:nil];
        
        // Initialize lock screen controller to ensure it starts observing
        [LockScreenMusicController sharedController];
    }
    return self;
}

- (void)dealloc {
    [self stop];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Playlist Management
- (void)playTrackAtIndex:(NSInteger)index {
    if (!self.songQueue || index < 0 || index >= self.songQueue.count) {
        return;
    }
    self.currentIndex = index;
    MusicModel *track = self.songQueue[index];
    [self playTrack:track];
}

- (void)playNextTrack {
    if (!self.songQueue.count) return;
    NSInteger nextIndex = self.currentIndex;
    if (self.playbackMode == PlaybackModeShuffle) {
        nextIndex = arc4random_uniform((u_int32_t)self.songQueue.count);
    } else {
        nextIndex++;
    }
    if (nextIndex >= self.songQueue.count) {
        nextIndex = 0;
    }
    [self playTrackAtIndex:nextIndex];
}

- (void)playPreviousTrack {
    if (!self.songQueue.count) return;
    NSInteger prevIndex = self.currentIndex;
    if (self.playbackMode == PlaybackModeShuffle) {
        prevIndex = arc4random_uniform((u_int32_t)self.songQueue.count);
    } else {
        prevIndex--;
    }
    if (prevIndex < 0) {
        prevIndex = self.songQueue.count - 1;
    }
    [self playTrackAtIndex:prevIndex];
}

- (BOOL)isSamePlaylistAndTrack:(NSArray<MusicModel *> *)playlist trackIndex:(NSInteger)index {
    // Check if we have a current track and valid index
    if (!self.currentTrack || self.currentIndex < 0 || !self.songQueue || !playlist) {
        return NO;
    }
    
    // Check if the index is valid
    if (index >= playlist.count || self.currentIndex >= self.songQueue.count) {
        return NO;
    }
    
    // Check if the track IDs match
    MusicModel *newTrack = playlist[index];
    if (![self.currentTrack.trackId isEqualToString:newTrack.trackId]) {
        return NO;
    }
    
    return YES;  // 简化逻辑：只要是同一首歌就不重新播放
}

- (void)updatePlaylistOnly:(NSArray<MusicModel *> *)playlist currentIndex:(NSInteger)index {
    self.songQueue = playlist;
    self.currentIndex = index;
    
    // 发送通知更新UI，但不改变播放状态
    NSDictionary *userInfo = @{MusicPlayerTrackUserInfoKey: self.currentTrack};
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MusicPlayerPlaylistUpdatedNotification" object:self userInfo:userInfo];
}

#pragma mark - Playback Control

- (void)play {
    if (self.audioPlayer && !self.isPlaying) {
        [self.audioPlayer play];
        self.isPlaying = YES;
        [self startProgressTimer];
        [[NSNotificationCenter defaultCenter] postNotificationName:MusicPlayerDidResumeNotification object:self];
    }
}

- (void)pause {
    if (self.audioPlayer && self.isPlaying) {
        [self.audioPlayer pause];
        self.isPlaying = NO;
        [self stopProgressTimer];
        [[NSNotificationCenter defaultCenter] postNotificationName:MusicPlayerDidPauseNotification object:self];
    }
}

- (void)stop {
    if (self.audioPlayer) {
        [self.audioPlayer pause];
        self.audioPlayer = nil;
        self.playerItem = nil;
        [self stopProgressTimer];
        self.isPlaying = NO;
        self.currentTrack = nil;
        self.currentIndex = -1;
        self.progress = 0;
        self.currentTime = 0;
        self.totalTime = 0;
        
        // Deactivate audio session when stopping to allow other audio sources
        NSError *error = nil;
        if (![[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error]) {
            NSLog(@"Failed to deactivate audio session: %@", error.localizedDescription);
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:MusicPlayerDidStopNotification object:self];
    }
}

- (void)seekToProgress:(CGFloat)progress {
    if (self.audioPlayer && self.playerItem) {
        CMTime duration = self.playerItem.duration;
        if (CMTIME_IS_VALID(duration)) {
            CMTime targetTime = CMTimeMakeWithSeconds(CMTimeGetSeconds(duration) * progress, duration.timescale);
            if (CMTIME_IS_VALID(targetTime)) {
                [self.audioPlayer seekToTime:targetTime];
            }
        }
    }
}

- (void)seekToTime:(NSTimeInterval)time {
    if (self.audioPlayer && self.playerItem) {
        CMTime duration = self.playerItem.duration;
        if (CMTIME_IS_VALID(duration)) {
            CMTime targetTime = CMTimeMakeWithSeconds(time, duration.timescale);
            if (CMTIME_IS_VALID(targetTime)) {
                [self.audioPlayer seekToTime:targetTime];
            }
        }
    }
}

- (void)handleSeekToTime:(NSNotification *)notification {
    NSNumber *timeNumber = notification.userInfo[@"time"];
    if (timeNumber) {
        NSTimeInterval time = timeNumber.doubleValue;
        [self seekToTime:time];
    }
}

- (void)handleAudioSessionInterruption:(NSNotification *)notification {
    NSNumber *interruptionType = notification.userInfo[AVAudioSessionInterruptionTypeKey];
    
    switch (interruptionType.unsignedIntegerValue) {
        case AVAudioSessionInterruptionTypeBegan:
            // Audio session interrupted (e.g., phone call, video playback)
            if (self.isPlaying) {
                [self pause];
                NSLog(@"Music playback paused due to audio session interruption");
            }
            break;
            
        case AVAudioSessionInterruptionTypeEnded: {
            // Audio session interruption ended
            NSNumber *interruptionOptions = notification.userInfo[AVAudioSessionInterruptionOptionKey];
            if (interruptionOptions.unsignedIntegerValue == AVAudioSessionInterruptionOptionShouldResume) {
                // Only resume if the system suggests we should and if we have a current track
                if (self.currentTrack) {
                    NSError *error = nil;
                    if ([[AVAudioSession sharedInstance] setActive:YES error:&error]) {
                        [self play];
                        NSLog(@"Music playback resumed after interruption ended");
                    } else {
                        NSLog(@"Failed to reactivate audio session after interruption: %@", error.localizedDescription);
                    }
                }
            }
            break;
        }
            
        default:
            break;
    }
}

#pragma mark - Private Playback Logic

- (void)playTrack:(MusicModel *)track {
    if (!track) return;
    [self stopInternal];
    self.currentTrack = track;
    
    MusicSettingsManager *settingsManager = [MusicSettingsManager sharedManager];
    NSInteger globalQuality = settingsManager.globalQuality;
    NSString *sourceString = [settingsManager sourceStringForSource:MusicSourceNetease]; // Use source from track or default
    
    if (track.source && track.source.length > 0) {
        sourceString = track.source;
    }
    
    [[MusicAPIManager sharedManager] getMusicURLWithTrackId:track.trackId source:sourceString bitrate:globalQuality completion:^(NSString * _Nullable url, NSNumber * _Nullable bitrate, NSNumber * _Nullable size, NSError * _Nullable error) {
        if (error || !url) {
            NSLog(@"Error getting music URL: %@", error.localizedDescription);
            return;
        }
        
        NSURL *playURL = [NSURL URLWithString:url];
        //使用代理链接
        self.playerItem = [AVPlayerItem playerItemWithURL:[KTVHTTPCache proxyURLWithOriginalURL:playURL]];
        self.audioPlayer = [AVPlayer playerWithPlayerItem:self.playerItem];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerDidFinishPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.playerItem];
        
        [self.audioPlayer play];
        self.isPlaying = YES;
        [self startProgressTimer];
        
        NSDictionary *userInfo = @{MusicPlayerTrackUserInfoKey: self.currentTrack};
        [[NSNotificationCenter defaultCenter] postNotificationName:MusicPlayerDidStartPlayingNotification object:self userInfo:userInfo];
    }];
}

- (void)stopInternal {
    if (self.audioPlayer) {
        [self.audioPlayer pause];
        self.audioPlayer = nil;
        self.playerItem = nil;
        [self stopProgressTimer];
        self.isPlaying = NO;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
}

#pragma mark - Timer and Progress

- (void)startProgressTimer {
    [self stopProgressTimer];
    self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(updateProgress) userInfo:nil repeats:YES];
}

- (void)stopProgressTimer {
    if (self.progressTimer) {
        [self.progressTimer invalidate];
        self.progressTimer = nil;
    }
}

- (void)updateProgress {
    if (self.audioPlayer && self.playerItem && self.isPlaying) {
        CMTime cmCurrentTime = self.playerItem.currentTime;
        CMTime cmTotalTime = self.playerItem.duration;
        
        if (CMTIME_IS_VALID(cmTotalTime)) {
            self.currentTime = CMTimeGetSeconds(cmCurrentTime);
            self.totalTime = CMTimeGetSeconds(cmTotalTime);
            self.progress = (self.totalTime > 0) ? (CGFloat)(self.currentTime / self.totalTime) : 0;
            
            // Calculate buffered progress
            CGFloat bufferedProgress = 0;
            NSArray *loadedTimeRanges = self.playerItem.loadedTimeRanges;
            if (loadedTimeRanges.count > 0) {
                NSValue *timeRangeValue = loadedTimeRanges.firstObject;
                CMTimeRange timeRange = [timeRangeValue CMTimeRangeValue];
                CMTime bufferedTime = CMTimeAdd(timeRange.start, timeRange.duration);
                if (CMTIME_IS_VALID(bufferedTime) && self.totalTime > 0) {
                    bufferedProgress = (CGFloat)(CMTimeGetSeconds(bufferedTime) / self.totalTime);
                    bufferedProgress = MIN(1.0, MAX(0.0, bufferedProgress));
                }
            }
            self.bufferedProgress = bufferedProgress;
            
            NSDictionary *userInfo = @{
                MusicPlayerProgressUserInfoKey: @(self.progress),
                MusicPlayerCurrentTimeUserInfoKey: @(self.currentTime),
                MusicPlayerTotalTimeUserInfoKey: @(self.totalTime),
                MusicPlayerBufferedProgressUserInfoKey: @(self.bufferedProgress)
            };
            [[NSNotificationCenter defaultCenter] postNotificationName:MusicPlayerDidChangeProgressNotification object:self userInfo:userInfo];
        }
    }
}

#pragma mark - Notifications

- (void)playerDidFinishPlaying:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] postNotificationName:MusicPlayerDidFinishPlayingNotification object:self];
    
    switch (self.playbackMode) {
        case PlaybackModeSequential:
            if (self.currentIndex < self.songQueue.count - 1) {
                [self playNextTrack];
            } else {
                [self stop];
            }
            break;
        case PlaybackModeRepeatAll:
            [self playNextTrack];
            break;
        case PlaybackModeRepeatOne:
            [self playTrackAtIndex:self.currentIndex];
            break;
        case PlaybackModeShuffle:
            [self playNextTrack];
            break;
    }
}

#pragma mark - Picture-in-Picture Controls

- (void)enablePiPMode {
    [[PiPLyricsViewController sharedController] startPiPMode];
    NSLog(@"🎵 Picture-in-Picture mode enabled");
}

- (void)disablePiPMode {
    [[PiPLyricsViewController sharedController] stopPiPMode];
    NSLog(@"🎵 Picture-in-Picture mode disabled");
}

- (BOOL)isPiPModeActive {
    return [[PiPLyricsViewController sharedController] isPiPActive];
}

@end
