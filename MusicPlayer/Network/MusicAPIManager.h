//
//  MusicAPIManager.h
//  MusicAPI
//
//  Created by Qwen Code on 2025/9/3.
//

#import <Foundation/Foundation.h>
#import "MusicModel.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^SearchCompletionBlock)(NSArray<MusicModel *> * _Nullable results, NSError * _Nullable error);
typedef void(^MusicURLCompletionBlock)(NSString * _Nullable url, NSNumber * _Nullable bitrate, NSNumber * _Nullable size, NSError * _Nullable error);
typedef void(^ImageCompletionBlock)(NSString * _Nullable imageUrl, NSError * _Nullable error);
typedef void(^LyricsCompletionBlock)(NSString * _Nullable lyrics, NSString * _Nullable translatedLyrics, NSError * _Nullable error);

@interface MusicAPIManager : NSObject

+ (instancetype)sharedManager;

// Search for music
- (void)searchMusicWithKeyword:(NSString *)keyword
                      source:(NSString * _Nullable)source
                       count:(NSInteger)count
                       pages:(NSInteger)pages
                  completion:(SearchCompletionBlock)completion;

// Get music URL
- (void)getMusicURLWithTrackId:(NSString *)trackId
                        source:(NSString * _Nullable)source
                      bitrate:(NSInteger)bitrate
                    completion:(MusicURLCompletionBlock)completion;

// Get album image
- (void)getAlbumImageWithPicId:(NSString *)picId
                        source:(NSString * _Nullable)source
                          size:(NSInteger)size
                    completion:(ImageCompletionBlock)completion;

// Get lyrics
- (void)getLyricsWithLyricId:(NSString *)lyricId
                      source:(NSString * _Nullable)source
                  completion:(LyricsCompletionBlock)completion;

// Get lyrics by track ID
- (void)getLyricsWithTrackId:(NSString *)trackId
                      source:(NSString * _Nullable)source
                  completion:(void(^)(NSString * _Nullable lyrics, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END