//
//  SpectrumView.h
//  MusicPlayer
//
//  Created by Gemini on 2025/9/5.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SpectrumView : UIView

@property (nonatomic, strong) UIColor *barColor;
@property (nonatomic, assign) CGFloat barSpacing;
@property (nonatomic, assign) NSInteger numberOfBars;

- (void)updateWithLevels:(float *)levels;

@end

NS_ASSUME_NONNULL_END
