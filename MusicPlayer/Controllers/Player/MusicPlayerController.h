//
//  MusicPlayerController.h
//  MusicAPI
//
//  Created by Qwen Code on 2025/9/3.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "MusicModel.h"

NS_ASSUME_NONNULL_BEGIN

// Notification Names
extern NSNotificationName const MusicPlayerDidStartPlayingNotification;
extern NSNotificationName const MusicPlayerDidChangeProgressNotification;
extern NSNotificationName const MusicPlayerDidPauseNotification;
extern NSNotificationName const MusicPlayerDidResumeNotification;
extern NSNotificationName const MusicPlayerDidStopNotification;
extern NSNotificationName const MusicPlayerDidFinishPlayingNotification;

// Notification UserInfo Keys
extern NSString * const MusicPlayerTrackUserInfoKey;
extern NSString * const MusicPlayerProgressUserInfoKey;
extern NSString * const MusicPlayerCurrentTimeUserInfoKey;
extern NSString * const MusicPlayerTotalTimeUserInfoKey;
extern NSString * const MusicPlayerBufferedProgressUserInfoKey;

// Playback Mode Enum
typedef NS_ENUM(NSInteger, PlaybackMode) {
    PlaybackModeSequential,
    PlaybackModeRepeatAll,
    PlaybackModeRepeatOne,
    PlaybackModeShuffle
};

@interface MusicPlayerController : NSObject

@property (nonatomic, strong, readonly, nullable) MusicModel *currentTrack;
@property (nonatomic, strong, nullable) NSArray<MusicModel *> *songQueue;
@property (nonatomic, assign, readonly) NSInteger currentIndex;
@property (nonatomic, assign) PlaybackMode playbackMode;

@property (nonatomic, assign, readonly) BOOL isPlaying;
@property (nonatomic, assign, readonly) CGFloat progress;
@property (nonatomic, assign, readonly) NSTimeInterval currentTime;
@property (nonatomic, assign, readonly) NSTimeInterval totalTime;
@property (nonatomic, assign, readonly) CGFloat bufferedProgress;


+ (instancetype)sharedController;

// Playlist Management
- (void)playTrackAtIndex:(NSInteger)index;
- (void)playNextTrack;
- (void)playPreviousTrack;
- (BOOL)isSamePlaylistAndTrack:(NSArray<MusicModel *> *)playlist trackIndex:(NSInteger)index;
- (void)updatePlaylistOnly:(NSArray<MusicModel *> *)playlist currentIndex:(NSInteger)index;

// Playback Control
- (void)play;
- (void)pause;
- (void)stop;
- (void)seekToProgress:(CGFloat)progress;
- (void)seekToTime:(NSTimeInterval)time;

// Picture-in-Picture Controls
- (void)enablePiPMode;
- (void)disablePiPMode;
- (BOOL)isPiPModeActive;

@end

NS_ASSUME_NONNULL_END
