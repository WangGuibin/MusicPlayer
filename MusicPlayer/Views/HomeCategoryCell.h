//
//  HomeCategoryCell.h
//  MusicPlayer
//
//  Created by Gemini on 2025/9/4.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HomeCategoryCell : UICollectionViewCell

- (void)configureWithTitle:(NSString *)title colorHex:(unsigned int)colorHex;

@end

NS_ASSUME_NONNULL_END
