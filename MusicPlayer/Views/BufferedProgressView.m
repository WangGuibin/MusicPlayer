//
//  BufferedProgressView.m
//  MusicPlayer
//
//  Created by Claude on 2025/9/5.
//

#import "BufferedProgressView.h"

@interface BufferedProgressView ()
@property (nonatomic, assign) BOOL isTracking;
@property (nonatomic, strong) CALayer *trackLayer;
@property (nonatomic, strong) CALayer *bufferedTrackLayer;
@property (nonatomic, strong) CALayer *progressTrackLayer;
@property (nonatomic, strong) CALayer *thumbLayer;
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;
@end

@implementation BufferedProgressView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    // Set default values
    _trackHeight = 4.0;
    _thumbSize = 20.0;
    _trackColor = [UIColor colorWithWhite:1.0 alpha:0.3];
    _bufferedTrackColor = [UIColor colorWithWhite:1.0 alpha:0.5];
    _progressTrackColor = [UIColor colorWithRed:30/255.0 green:215/255.0 blue:96/255.0 alpha:1.0];
    _thumbColor = [UIColor whiteColor];
    
    // Create layers
    self.trackLayer = [CALayer layer];
    self.trackLayer.cornerRadius = _trackHeight / 2;
    [self.layer addSublayer:self.trackLayer];
    
    self.bufferedTrackLayer = [CALayer layer];
    self.bufferedTrackLayer.cornerRadius = _trackHeight / 2;
    [self.layer addSublayer:self.bufferedTrackLayer];
    
    self.progressTrackLayer = [CALayer layer];
    self.progressTrackLayer.cornerRadius = _trackHeight / 2;
    [self.layer addSublayer:self.progressTrackLayer];
    
    self.thumbLayer = [CALayer layer];
    self.thumbLayer.cornerRadius = _thumbSize / 2;
    self.thumbLayer.shadowColor = [UIColor blackColor].CGColor;
    self.thumbLayer.shadowOffset = CGSizeMake(0, 2);
    self.thumbLayer.shadowOpacity = 0.3;
    self.thumbLayer.shadowRadius = 4;
    [self.layer addSublayer:self.thumbLayer];
    
    // Add gestures
    self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self addGestureRecognizer:self.panGesture];
    
    self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [self addGestureRecognizer:self.tapGesture];
    
    [self updateLayers];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateLayers];
}

- (void)updateLayers {
    CGRect bounds = self.bounds;
    CGFloat centerY = bounds.size.height / 2;
    CGFloat trackY = centerY - self.trackHeight / 2;
    CGFloat usableWidth = bounds.size.width - self.thumbSize;
    CGFloat trackStartX = self.thumbSize / 2;
    
    // Update track layer (background)
    self.trackLayer.frame = CGRectMake(trackStartX, trackY, usableWidth, self.trackHeight);
    self.trackLayer.backgroundColor = self.trackColor.CGColor;
    
    // Update buffered track layer
    CGFloat bufferedWidth = usableWidth * self.bufferedProgress;
    self.bufferedTrackLayer.frame = CGRectMake(trackStartX, trackY, bufferedWidth, self.trackHeight);
    self.bufferedTrackLayer.backgroundColor = self.bufferedTrackColor.CGColor;
    
    // Update progress track layer
    CGFloat progressWidth = usableWidth * self.progress;
    self.progressTrackLayer.frame = CGRectMake(trackStartX, trackY, progressWidth, self.trackHeight);
    self.progressTrackLayer.backgroundColor = self.progressTrackColor.CGColor;
    
    // Update thumb layer
    CGFloat thumbX = trackStartX + progressWidth - self.thumbSize / 2;
    CGFloat thumbY = centerY - self.thumbSize / 2;
    self.thumbLayer.frame = CGRectMake(thumbX, thumbY, self.thumbSize, self.thumbSize);
    self.thumbLayer.backgroundColor = self.thumbColor.CGColor;
}

#pragma mark - Gesture Handling

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:self];
    CGFloat usableWidth = self.bounds.size.width - self.thumbSize;
    CGFloat trackStartX = self.thumbSize / 2;
    
    // Calculate progress based on touch location
    CGFloat newProgress = (location.x - trackStartX) / usableWidth;
    newProgress = MAX(0.0, MIN(1.0, newProgress));
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            self.isTracking = YES;
            [self.delegate progressViewDidBeginSeeking:self];
            // Add scale animation for thumb
            [CATransaction begin];
            [CATransaction setDisableActions:NO];
            [CATransaction setAnimationDuration:0.1];
            self.thumbLayer.transform = CATransform3DMakeScale(1.2, 1.2, 1.0);
            [CATransaction commit];
            break;
            
        case UIGestureRecognizerStateChanged:
            self.progress = newProgress;
            [self updateLayers];
            [self.delegate progressViewDidChangeProgress:self toProgress:newProgress];
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
            self.isTracking = NO;
            [self.delegate progressViewDidEndSeeking:self withProgress:newProgress];
            // Remove scale animation
            [CATransaction begin];
            [CATransaction setDisableActions:NO];
            [CATransaction setAnimationDuration:0.1];
            self.thumbLayer.transform = CATransform3DIdentity;
            [CATransaction commit];
            break;
            
        default:
            break;
    }
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    if (self.isTracking) return;
    
    CGPoint location = [gesture locationInView:self];
    CGFloat usableWidth = self.bounds.size.width - self.thumbSize;
    CGFloat trackStartX = self.thumbSize / 2;
    
    CGFloat newProgress = (location.x - trackStartX) / usableWidth;
    newProgress = MAX(0.0, MIN(1.0, newProgress));
    
    self.progress = newProgress;
    [self updateLayers];
    [self.delegate progressViewDidEndSeeking:self withProgress:newProgress];
}

#pragma mark - Setters

- (void)setProgress:(CGFloat)progress {
    _progress = MAX(0.0, MIN(1.0, progress));
    if (!self.isTracking) {
        [self updateLayers];
    }
}

- (void)setBufferedProgress:(CGFloat)bufferedProgress {
    _bufferedProgress = MAX(0.0, MIN(1.0, bufferedProgress));
    [self updateLayers];
}

- (void)setTrackColor:(UIColor *)trackColor {
    _trackColor = trackColor;
    [self updateLayers];
}

- (void)setBufferedTrackColor:(UIColor *)bufferedTrackColor {
    _bufferedTrackColor = bufferedTrackColor;
    [self updateLayers];
}

- (void)setProgressTrackColor:(UIColor *)progressTrackColor {
    _progressTrackColor = progressTrackColor;
    [self updateLayers];
}

- (void)setThumbColor:(UIColor *)thumbColor {
    _thumbColor = thumbColor;
    [self updateLayers];
}

- (void)setTrackHeight:(CGFloat)trackHeight {
    _trackHeight = trackHeight;
    self.trackLayer.cornerRadius = trackHeight / 2;
    self.bufferedTrackLayer.cornerRadius = trackHeight / 2;
    self.progressTrackLayer.cornerRadius = trackHeight / 2;
    [self updateLayers];
}

- (void)setThumbSize:(CGFloat)thumbSize {
    _thumbSize = thumbSize;
    self.thumbLayer.cornerRadius = thumbSize / 2;
    [self updateLayers];
}

@end