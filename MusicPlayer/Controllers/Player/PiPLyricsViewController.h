//
//  PiPLyricsViewController.h
//  VodTV
//
//  Created by Claude on 2025/9/7.
//

#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PiPLyricsViewController : UIViewController

+ (instancetype)sharedController;

// System Picture-in-Picture control methods
- (void)startPiPMode;
- (void)stopPiPMode;
- (BOOL)isPiPActive;
- (BOOL)isPiPSupported;

// Lyrics control methods
- (void)updateCurrentLyrics:(NSString *)lyrics;
- (void)setLyricsData:(NSArray<NSDictionary *> *)lyricsData;

@end

NS_ASSUME_NONNULL_END