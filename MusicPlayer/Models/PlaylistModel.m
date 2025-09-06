//
//  PlaylistModel.m
//  MusicPlayer
//
//  Created by Claude on 2025/9/5.
//

#import "PlaylistModel.h"

@implementation PlaylistModel

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithName:(NSString *)name {
    self = [super init];
    if (self) {
        _playlistId = [[NSUUID UUID] UUIDString];
        _name = [name copy];
        _createTime = [NSDateFormatter localizedStringFromDate:[NSDate date] 
                                                     dateStyle:NSDateFormatterShortStyle 
                                                     timeStyle:NSDateFormatterShortStyle];
        _musicList = [NSMutableArray array];
        _totalCount = 0;
    }
    return self;
}

- (void)addMusic:(MusicModel *)music {
    if (!music || !music.trackId) return;
    
    // Check if music already exists
    for (MusicModel *existingMusic in self.musicList) {
        if ([existingMusic.trackId isEqualToString:music.trackId]) {
            return; // Already exists, don't add duplicate
        }
    }
    
    [self.musicList addObject:music];
    self.totalCount = self.musicList.count;
}

- (void)removeMusic:(MusicModel *)music {
    if (!music || !music.trackId) return;
    
    for (NSInteger i = 0; i < self.musicList.count; i++) {
        MusicModel *existingMusic = self.musicList[i];
        if ([existingMusic.trackId isEqualToString:music.trackId]) {
            [self.musicList removeObjectAtIndex:i];
            break;
        }
    }
    self.totalCount = self.musicList.count;
}

- (void)removeMusicAtIndex:(NSInteger)index {
    if (index >= 0 && index < self.musicList.count) {
        [self.musicList removeObjectAtIndex:index];
        self.totalCount = self.musicList.count;
    }
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.playlistId forKey:@"playlistId"];
    [encoder encodeObject:self.name forKey:@"name"];
    [encoder encodeObject:self.createTime forKey:@"createTime"];
    [encoder encodeObject:self.musicList forKey:@"musicList"];
    [encoder encodeInteger:self.totalCount forKey:@"totalCount"];
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if (self) {
        _playlistId = [decoder decodeObjectOfClass:[NSString class] forKey:@"playlistId"];
        _name = [decoder decodeObjectOfClass:[NSString class] forKey:@"name"];
        _createTime = [decoder decodeObjectOfClass:[NSString class] forKey:@"createTime"];
        _musicList = [decoder decodeObjectOfClasses:[NSSet setWithArray:@[[NSMutableArray class], [NSArray class], [MusicModel class]]] forKey:@"musicList"] ?: [NSMutableArray array];
        _totalCount = [decoder decodeIntegerForKey:@"totalCount"];
    }
    return self;
}

@end