//
//  HomeCategoryCell.m
//  MusicPlayer
//
//  Created by Gemini on 2025/9/4.
//

#import "HomeCategoryCell.h"
#import <Masonry/Masonry.h>

@interface HomeCategoryCell ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) CAGradientLayer *gradientLayer;

@end

@implementation HomeCategoryCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.layer.cornerRadius = 12.0;
    self.layer.masksToBounds = YES;

    // Gradient Layer for background
    self.gradientLayer = [CAGradientLayer layer];
    [self.contentView.layer insertSublayer:self.gradientLayer atIndex:0];

    // Title Label
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.contentView addSubview:self.titleLabel];

    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.contentView);
        make.left.equalTo(self.contentView).offset(8);
        make.right.equalTo(self.contentView).offset(-8);
    }];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.gradientLayer.frame = self.contentView.bounds;
}

- (void)configureWithTitle:(NSString *)title colorHex:(unsigned int)colorHex {
    self.titleLabel.text = title;
    
    // 根据cell大小自适应字体
    CGFloat cellWidth = self.frame.size.width;
    CGFloat fontSize;
    
    if (cellWidth <= 100) {
        fontSize = 14;
    } else if (cellWidth <= 150) {
        fontSize = 16;
    } else if (cellWidth <= 200) {
        fontSize = 18;
    } else {
        fontSize = 20;
    }
    
    self.titleLabel.font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightBold];
    
    UIColor *baseColor = [self colorFromHex:colorHex];
    UIColor *darkerColor = [self adjustColor:baseColor brightness:-0.2];
    
    self.gradientLayer.colors = @[(id)baseColor.CGColor, (id)darkerColor.CGColor];
    self.gradientLayer.startPoint = CGPointMake(0, 0);
    self.gradientLayer.endPoint = CGPointMake(1, 1);
}

#pragma mark - Helpers

- (UIColor *)colorFromHex:(unsigned int)hex {
    CGFloat red = ((hex & 0xFF0000) >> 16) / 255.0;
    CGFloat green = ((hex & 0x00FF00) >> 8) / 255.0;
    CGFloat blue = (hex & 0x0000FF) / 255.0;
    return [UIColor colorWithRed:red green:green blue:blue alpha:1.0];
}

- (UIColor *)adjustColor:(UIColor *)color brightness:(CGFloat)factor {
    CGFloat hue, saturation, brightness, alpha;
    if ([color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha]) {
        brightness += factor;
        brightness = MAX(0, MIN(1, brightness));
        return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
    }
    return color;
}

@end
