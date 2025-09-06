//
//  MusicListCell.h
//  MusicPlayer
//
//  Created by Gemini on 2025/9/4.
//

#import <UIKit/UIKit.h>
@class MusicModel, PlaylistModel;

NS_ASSUME_NONNULL_BEGIN

@protocol MusicListCellDelegate <NSObject>
- (void)addMusic:(MusicModel *)music toPlaylist:(PlaylistModel *)playlist;
- (NSArray<PlaylistModel *> *)availablePlaylists;
@end

@interface MusicListCell : UITableViewCell

@property (nonatomic, weak) id<MusicListCellDelegate> delegate;

- (void)configureWithTrack:(MusicModel *)track;

@end

NS_ASSUME_NONNULL_END
