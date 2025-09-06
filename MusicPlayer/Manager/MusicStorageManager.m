//
//  MusicStorageManager.m
//  MusicPlayer
//
//  Created by Claude on 2025/9/5.
//

#import "MusicStorageManager.h"

static NSString * const kHistoryKey = @"com.musicplayer.history";
static NSString * const kPlaylistsKey = @"com.musicplayer.playlists";
static const NSInteger kMaxHistoryCount = 100;

@interface MusicStorageManager ()
@property (nonatomic, strong) NSMutableArray<MusicModel *> *historyList;
@property (nonatomic, strong) NSMutableArray<PlaylistModel *> *playlists;
@end

@implementation MusicStorageManager

+ (instancetype)sharedManager {
    static MusicStorageManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MusicStorageManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadData];
    }
    return self;
}

#pragma mark - Data Loading/Saving

- (void)loadData {
    [self loadHistory];
    [self loadPlaylists];
}

- (void)loadHistory {
    NSData *historyData = [[NSUserDefaults standardUserDefaults] objectForKey:kHistoryKey];
    if (historyData) {
        NSError *error = nil;
        NSSet *classes = [NSSet setWithArray:@[[NSMutableArray class], [NSArray class], [MusicModel class], [NSString class]]];
        NSMutableArray *decodedHistory = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                                            fromData:historyData
                                                                               error:&error];
        if (!error && decodedHistory) {
            self.historyList = decodedHistory;
        } else {
            NSLog(@"Error loading history: %@", error.localizedDescription);
            NSLog(@"Clearing corrupted history data...");
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:kHistoryKey];
            self.historyList = [NSMutableArray array];
        }
    } else {
        self.historyList = [NSMutableArray array];
    }
}

- (void)loadPlaylists {
    NSData *playlistsData = [[NSUserDefaults standardUserDefaults] objectForKey:kPlaylistsKey];
    if (playlistsData) {
        NSError *error = nil;
        NSSet *classes = [NSSet setWithArray:@[
            [NSMutableArray class], 
            [NSArray class], 
            [PlaylistModel class], 
            [MusicModel class], 
            [NSString class]
        ]];
        NSMutableArray *decodedPlaylists = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                                              fromData:playlistsData
                                                                                 error:&error];
        if (!error && decodedPlaylists) {
            self.playlists = decodedPlaylists;
        } else {
            NSLog(@"Error loading playlists: %@", error.localizedDescription);
            NSLog(@"Clearing corrupted playlists data...");
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:kPlaylistsKey];
            self.playlists = [NSMutableArray array];
        }
    } else {
        self.playlists = [NSMutableArray array];
    }
}

- (void)saveHistory {
    NSError *error = nil;
    NSData *encodedData = [NSKeyedArchiver archivedDataWithRootObject:self.historyList
                                               requiringSecureCoding:YES
                                                               error:&error];
    if (!error) {
        [[NSUserDefaults standardUserDefaults] setObject:encodedData forKey:kHistoryKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else {
        NSLog(@"Error saving history: %@", error.localizedDescription);
    }
}

- (void)savePlaylists {
    NSError *error = nil;
    NSData *encodedData = [NSKeyedArchiver archivedDataWithRootObject:self.playlists
                                               requiringSecureCoding:YES
                                                               error:&error];
    if (!error) {
        [[NSUserDefaults standardUserDefaults] setObject:encodedData forKey:kPlaylistsKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else {
        NSLog(@"Error saving playlists: %@", error.localizedDescription);
    }
}

#pragma mark - History Management

- (void)addToHistory:(MusicModel *)music {
    if (!music || !music.trackId) return;
    
    // Remove if already exists
    for (NSInteger i = self.historyList.count - 1; i >= 0; i--) {
        MusicModel *existingMusic = self.historyList[i];
        if ([existingMusic.trackId isEqualToString:music.trackId]) {
            [self.historyList removeObjectAtIndex:i];
            break;
        }
    }
    
    // Add to beginning (most recent first)
    [self.historyList insertObject:music atIndex:0];
    
    // Maintain max count (remove oldest if needed)
    while (self.historyList.count > kMaxHistoryCount) {
        [self.historyList removeLastObject];
    }
    
    [self saveHistory];
}

- (NSArray<MusicModel *> *)getHistoryList {
    return [self.historyList copy];
}

- (void)clearHistory {
    [self.historyList removeAllObjects];
    [self saveHistory];
}

#pragma mark - Playlist Management

- (NSArray<PlaylistModel *> *)getAllPlaylists {
    return [self.playlists copy];
}

- (PlaylistModel *)createPlaylistWithName:(NSString *)name {
    if (!name || name.length == 0) return nil;
    
    PlaylistModel *playlist = [[PlaylistModel alloc] initWithName:name];
    [self.playlists addObject:playlist];
    [self savePlaylists];
    return playlist;
}

- (void)deletePlaylist:(PlaylistModel *)playlist {
    if (!playlist) return;
    
    [self.playlists removeObject:playlist];
    [self savePlaylists];
}

- (void)updatePlaylist:(PlaylistModel *)playlist {
    if (!playlist) return;
    
    // Find and update existing playlist
    for (NSInteger i = 0; i < self.playlists.count; i++) {
        PlaylistModel *existingPlaylist = self.playlists[i];
        if ([existingPlaylist.playlistId isEqualToString:playlist.playlistId]) {
            [self.playlists replaceObjectAtIndex:i withObject:playlist];
            break;
        }
    }
    [self savePlaylists];
}

- (void)addMusic:(MusicModel *)music toPlaylist:(PlaylistModel *)playlist {
    if (!music || !playlist) return;
    
    [playlist addMusic:music];
    [self updatePlaylist:playlist];
}

- (void)removeMusic:(MusicModel *)music fromPlaylist:(PlaylistModel *)playlist {
    if (!music || !playlist) return;
    
    [playlist removeMusic:music];
    [self updatePlaylist:playlist];
}

#pragma mark - Cache Management

- (void)clearAllCache {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kHistoryKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kPlaylistsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    self.historyList = [NSMutableArray array];
    self.playlists = [NSMutableArray array];
    
    NSLog(@"All cache cleared successfully");
}

@end