//
//  BufferedProgressView.h
//  MusicPlayer
//
//  Created by Claude on 2025/9/5.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BufferedProgressViewDelegate <NSObject>
- (void)progressViewDidBeginSeeking:(UIView *)progressView;
- (void)progressViewDidEndSeeking:(UIView *)progressView withProgress:(CGFloat)progress;
- (void)progressViewDidChangeProgress:(UIView *)progressView toProgress:(CGFloat)progress;
@end

@interface BufferedProgressView : UIView

@property (nonatomic, weak) id<BufferedProgressViewDelegate> delegate;
@property (nonatomic, assign) CGFloat progress; // Current playback progress (0.0 - 1.0)
@property (nonatomic, assign) CGFloat bufferedProgress; // Buffered progress (0.0 - 1.0)

// Customization properties
@property (nonatomic, strong) UIColor *trackColor; // Background track color
@property (nonatomic, strong) UIColor *bufferedTrackColor; // Buffered area color
@property (nonatomic, strong) UIColor *progressTrackColor; // Current progress color
@property (nonatomic, strong) UIColor *thumbColor; // Thumb color
@property (nonatomic, assign) CGFloat trackHeight; // Track height
@property (nonatomic, assign) CGFloat thumbSize; // Thumb diameter

@end

NS_ASSUME_NONNULL_END