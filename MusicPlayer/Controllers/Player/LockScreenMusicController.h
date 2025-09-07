//
//  LockScreenMusicController.h
//  VodTV
//
//  Created by Claude on 2025/9/7.
//

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

NS_ASSUME_NONNULL_BEGIN

@interface LockScreenMusicController : NSObject

+ (instancetype)sharedController;

// Lock screen control setup
- (void)setupRemoteControls;
- (void)removeRemoteControls;

// Now playing info updates
- (void)updateNowPlayingInfo;
- (void)updateNowPlayingInfoWithLyrics:(NSString * _Nullable)lyrics;
- (void)clearNowPlayingInfo;

// Progress updates
- (void)updatePlaybackProgress:(NSTimeInterval)currentTime duration:(NSTimeInterval)duration;

@end

NS_ASSUME_NONNULL_END