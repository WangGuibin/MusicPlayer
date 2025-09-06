//
//  MusicSettingsManager.m
//  VodTV
//
//  Created by Claude on 2025/9/6.
//

#import "MusicSettingsManager.h"

static NSString * const kMusicDefaultSourceKey = @"MusicDefaultSource";
static NSString * const kMusicGlobalQualityKey = @"MusicGlobalQuality";

@implementation MusicSettingsManager

+ (instancetype)sharedManager {
    static MusicSettingsManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[MusicSettingsManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadSettings];
    }
    return self;
}

#pragma mark - Settings Management

- (void)loadSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Load default source (default: netease)
    NSInteger sourceValue = [defaults integerForKey:kMusicDefaultSourceKey];
    if (sourceValue == 0 && ![defaults objectForKey:kMusicDefaultSourceKey]) {
        // First time, set default
        _defaultSource = MusicSourceNetease;
    } else {
        _defaultSource = (MusicSource)sourceValue;
    }
    
    // Load global quality (default: 999)
    NSInteger qualityValue = [defaults integerForKey:kMusicGlobalQualityKey];
    if (qualityValue == 0 && ![defaults objectForKey:kMusicGlobalQualityKey]) {
        // First time, set default
        _globalQuality = MusicQuality999;
    } else {
        _globalQuality = (MusicQuality)qualityValue;
    }
}

- (void)setDefaultSource:(MusicSource)defaultSource {
    _defaultSource = defaultSource;
    [[NSUserDefaults standardUserDefaults] setInteger:defaultSource forKey:kMusicDefaultSourceKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setGlobalQuality:(MusicQuality)globalQuality {
    _globalQuality = globalQuality;
    [[NSUserDefaults standardUserDefaults] setInteger:globalQuality forKey:kMusicGlobalQualityKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Helper Methods

- (NSString *)defaultSourceString {
    return [self sourceStringForSource:self.defaultSource];
}

- (NSString *)sourceStringForSource:(MusicSource)source {
    switch (source) {
        case MusicSourceNetease:
            return @"netease";
        case MusicSourceKuwo:
            return @"kuwo";
        case MusicSourceJoox:
            return @"joox";
        default:
            return @"netease";
    }
}

- (NSString *)sourceDisplayNameForSource:(MusicSource)source {
    switch (source) {
        case MusicSourceNetease:
            return @"网易云音乐";
        case MusicSourceKuwo:
            return @"酷我音乐";
        case MusicSourceJoox:
            return @"JOOX音乐";
        default:
            return @"网易云音乐";
    }
}

- (NSString *)qualityDisplayNameForQuality:(MusicQuality)quality {
    switch (quality) {
        case MusicQuality128:
            return @"标准音质 (128kbps)";
        case MusicQuality192:
            return @"较高音质 (192kbps)";
        case MusicQuality320:
            return @"高音质 (320kbps)";
        case MusicQuality740:
            return @"无损音质 (740kbps)";
        case MusicQuality999:
            return @"Hi-Fi音质 (999kbps)";
        default:
            return @"Hi-Fi音质 (999kbps)";
    }
}

- (NSArray<NSNumber *> *)availableQualityOptions {
    return @[@(MusicQuality128), @(MusicQuality192), @(MusicQuality320), @(MusicQuality740), @(MusicQuality999)];
}

- (NSArray<NSNumber *> *)availableSourceOptions {
    return @[@(MusicSourceNetease), @(MusicSourceKuwo), @(MusicSourceJoox)];
}

@end