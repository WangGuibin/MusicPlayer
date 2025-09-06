//
//  MusicStorageManager.h
//  MusicPlayer
//
//  Created by Claude on 2025/9/5.
//

#import <Foundation/Foundation.h>
#import "MusicModel.h"
#import "PlaylistModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface MusicStorageManager : NSObject

+ (instancetype)sharedManager;

// History management (max 100 items, FIFO)
- (void)addToHistory:(MusicModel *)music;
- (NSArray<MusicModel *> *)getHistoryList;
- (void)clearHistory;

// Playlist management
- (NSArray<PlaylistModel *> *)getAllPlaylists;
- (PlaylistModel *)createPlaylistWithName:(NSString *)name;
- (void)deletePlaylist:(PlaylistModel *)playlist;
- (void)updatePlaylist:(PlaylistModel *)playlist;
- (void)addMusic:(MusicModel *)music toPlaylist:(PlaylistModel *)playlist;
- (void)removeMusic:(MusicModel *)music fromPlaylist:(PlaylistModel *)playlist;

// Cache management
- (void)clearAllCache;

@end

NS_ASSUME_NONNULL_END