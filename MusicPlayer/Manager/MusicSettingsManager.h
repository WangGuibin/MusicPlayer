//
//  MusicSettingsManager.h
//  VodTV
//
//  Created by Claude on 2025/9/6.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MusicSource) {
    MusicSourceNetease = 0,
    MusicSourceKuwo = 1,
    MusicSourceJoox = 2
};

typedef NS_ENUM(NSInteger, MusicQuality) {
    MusicQuality128 = 128,
    MusicQuality192 = 192,
    MusicQuality320 = 320,
    MusicQuality740 = 740,
    MusicQuality999 = 999
};

@interface MusicSettingsManager : NSObject

+ (instancetype)sharedManager;

// Default source
@property (nonatomic, assign) MusicSource defaultSource;
@property (nonatomic, readonly) NSString *defaultSourceString;

// Global quality
@property (nonatomic, assign) MusicQuality globalQuality;

// Helper methods
- (NSString *)sourceStringForSource:(MusicSource)source;
- (NSString *)sourceDisplayNameForSource:(MusicSource)source;
- (NSString *)qualityDisplayNameForQuality:(MusicQuality)quality;
- (NSArray<NSNumber *> *)availableQualityOptions;
- (NSArray<NSNumber *> *)availableSourceOptions;

@end

NS_ASSUME_NONNULL_END