//
//  MusicListViewController.h
//  MusicPlayer
//
//  Created by Gemini on 2025/9/4.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MusicListViewController : UIViewController

@property (nonatomic, copy) NSString *searchKeyword;

- (void)performSearchWithKeyword:(NSString *)keyword;

@end

NS_ASSUME_NONNULL_END
