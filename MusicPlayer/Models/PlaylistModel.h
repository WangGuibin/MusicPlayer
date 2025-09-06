//
//  PlaylistModel.h
//  MusicPlayer
//
//  Created by Claude on 2025/9/5.
//

#import <Foundation/Foundation.h>
#import "MusicModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface PlaylistModel : NSObject <NSCoding, NSSecureCoding>

@property (nonatomic, copy) NSString *playlistId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *createTime;
@property (nonatomic, strong) NSMutableArray<MusicModel *> *musicList;
@property (nonatomic, assign) NSInteger totalCount;

- (instancetype)initWithName:(NSString *)name;
- (void)addMusic:(MusicModel *)music;
- (void)removeMusic:(MusicModel *)music;
- (void)removeMusicAtIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END