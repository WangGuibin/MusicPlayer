//
//  PlaylistViewController.h
//  MusicPlayer
//
//  Created by Gemini on 2025/9/5.
//

#import <UIKit/UIKit.h>
#import "PlaylistModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface PlaylistViewController : UIViewController

@property (nonatomic, strong) PlaylistModel *playlist;

@end

NS_ASSUME_NONNULL_END
