//
//  SpectrumView.m
//  MusicPlayer
//
//  Created by Gemini on 2025/9/5.
//

#import "SpectrumView.h"

@interface SpectrumView ()
@property (nonatomic, strong) NSMutableArray<CAShapeLayer *> *bars;
@end

@implementation SpectrumView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _numberOfBars = 8;
        _barSpacing = 2.0;
        _barColor = [UIColor colorWithRed:30/255.0 green:215/255.0 blue:96/255.0 alpha:1.0];
        _bars = [NSMutableArray array];
        [self setupBars];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateBarFrames];
}

- (void)setupBars {
    // Clear existing bars
    for (CAShapeLayer *bar in self.bars) {
        [bar removeFromSuperlayer];
    }
    [self.bars removeAllObjects];

    // Create new bars
    for (int i = 0; i < self.numberOfBars; i++) {
        CAShapeLayer *bar = [CAShapeLayer layer];
        bar.backgroundColor = self.barColor.CGColor;
        [self.layer addSublayer:bar];
        [self.bars addObject:bar];
    }
    [self updateBarFrames];
}

- (void)updateBarFrames {
    CGFloat totalSpacing = (self.numberOfBars - 1) * self.barSpacing;
    CGFloat barWidth = (self.bounds.size.width - totalSpacing) / self.numberOfBars;

    for (int i = 0; i < self.bars.count; i++) {
        CAShapeLayer *bar = self.bars[i];
        CGFloat x = i * (barWidth + self.barSpacing);
        bar.frame = CGRectMake(x, self.bounds.size.height, barWidth, 0);
    }
}

- (void)updateWithLevels:(float *)levels {
    if (!levels) return;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (int i = 0; i < self.bars.count; i++) {
        CAShapeLayer *bar = self.bars[i];
        float level = MIN(1.0, MAX(0.0, levels[i])); // Clamp between 0 and 1
        CGFloat barHeight = self.bounds.size.height * level;
        CGRect frame = bar.frame;
        frame.size.height = barHeight;
        frame.origin.y = self.bounds.size.height - barHeight;
        bar.frame = frame;
    }
    [CATransaction commit];
}

#pragma mark - Setters

- (void)setNumberOfBars:(NSInteger)numberOfBars {
    if (_numberOfBars != numberOfBars) {
        _numberOfBars = numberOfBars;
        [self setupBars];
    }
}

- (void)setBarSpacing:(CGFloat)barSpacing {
    if (_barSpacing != barSpacing) {
        _barSpacing = barSpacing;
        [self updateBarFrames];
    }
}

- (void)setBarColor:(UIColor *)barColor {
    _barColor = barColor;
    for (CAShapeLayer *bar in self.bars) {
        bar.backgroundColor = barColor.CGColor;
    }
}

@end
