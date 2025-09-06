//
//  MusicImageCacheManager.m
//  MusicPlayer
//
//  Created by Claude on 2025/9/6.
//

#import "MusicImageCacheManager.h"
#import <UIKit/UIKit.h>
#import "MusicAPIManager.h"
#import "MusicModel.h"

@interface MusicImageCacheManager ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *imageUrlCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *cacheTimestamps;
@property (nonatomic, strong) dispatch_queue_t cacheQueue;
@property (nonatomic, strong) NSString *cacheFilePath;

@end

@implementation MusicImageCacheManager

#pragma mark - Singleton

+ (instancetype)sharedManager {
    static MusicImageCacheManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[MusicImageCacheManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _imageUrlCache = [NSMutableDictionary dictionary];
        _cacheTimestamps = [NSMutableDictionary dictionary];
        _cacheQueue = dispatch_queue_create("com.musicplayer.imagecache", DISPATCH_QUEUE_CONCURRENT);
        
        [self setupCacheFilePath];
        [self loadCacheFromDisk];
        
        // 应用进入后台时保存缓存
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(saveCache) 
                                                     name:UIApplicationDidEnterBackgroundNotification 
                                                   object:nil];
        
        // 内存警告时清理部分缓存
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(handleMemoryWarning) 
                                                     name:UIApplicationDidReceiveMemoryWarningNotification 
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self saveCache];
}

#pragma mark - Cache File Management

- (void)setupCacheFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    self.cacheFilePath = [documentsDirectory stringByAppendingPathComponent:@"MusicImageCache.plist"];
}

- (void)loadCacheFromDisk {
    dispatch_async(self.cacheQueue, ^{
        if ([[NSFileManager defaultManager] fileExistsAtPath:self.cacheFilePath]) {
            NSDictionary *cacheData = [NSDictionary dictionaryWithContentsOfFile:self.cacheFilePath];
            if (cacheData) {
                dispatch_barrier_async(self.cacheQueue, ^{
                    self.imageUrlCache = [cacheData[@"urls"] mutableCopy] ?: [NSMutableDictionary dictionary];
                    self.cacheTimestamps = [cacheData[@"timestamps"] mutableCopy] ?: [NSMutableDictionary dictionary];
                    
                    // 清理过期缓存（7天过期）
                    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
                    NSTimeInterval expireDuration = 7 * 24 * 60 * 60; // 7天
                    
                    NSMutableArray *expiredKeys = [NSMutableArray array];
                    for (NSString *key in self.cacheTimestamps.allKeys) {
                        NSTimeInterval cacheTime = [self.cacheTimestamps[key] doubleValue];
                        if (now - cacheTime > expireDuration) {
                            [expiredKeys addObject:key];
                        }
                    }
                    
                    for (NSString *key in expiredKeys) {
                        [self.imageUrlCache removeObjectForKey:key];
                        [self.cacheTimestamps removeObjectForKey:key];
                    }
                    
                    NSLog(@"📸 [ImageCache] Loaded %lu cached URLs, removed %lu expired", 
                          (unsigned long)self.imageUrlCache.count, (unsigned long)expiredKeys.count);
                });
            }
        }
    });
}

- (void)saveCache {
    dispatch_async(self.cacheQueue, ^{
        NSDictionary *cacheData = @{
            @"urls": self.imageUrlCache.copy,
            @"timestamps": self.cacheTimestamps.copy
        };
        
        BOOL success = [cacheData writeToFile:self.cacheFilePath atomically:YES];
        if (success) {
            NSLog(@"📸 [ImageCache] Saved %lu cached URLs to disk", (unsigned long)self.imageUrlCache.count);
        } else {
            NSLog(@"📸 [ImageCache] Failed to save cache to disk");
        }
    });
}

- (void)handleMemoryWarning {
    dispatch_barrier_async(self.cacheQueue, ^{
        // 清理最旧的50%缓存
        NSArray *sortedKeys = [self.cacheTimestamps keysSortedByValueUsingComparator:^NSComparisonResult(NSNumber *obj1, NSNumber *obj2) {
            return [obj1 compare:obj2];
        }];
        
        NSUInteger countToRemove = sortedKeys.count / 2;
        for (NSUInteger i = 0; i < countToRemove && i < sortedKeys.count; i++) {
            NSString *key = sortedKeys[i];
            [self.imageUrlCache removeObjectForKey:key];
            [self.cacheTimestamps removeObjectForKey:key];
        }
        
        NSLog(@"📸 [ImageCache] Memory warning: removed %lu old cached URLs", (unsigned long)countToRemove);
    });
}

#pragma mark - Public Methods

- (void)getImageURLWithPicId:(NSString *)picId 
                      source:(NSString *)source 
                        size:(MusicImageSize)size
                  completion:(void (^)(NSString * _Nullable, NSError * _Nullable))completion {
    
    if (!picId || !source || !completion) {
        completion(nil, [NSError errorWithDomain:@"MusicImageCache" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid parameters"}]);
        return;
    }
    
    NSString *cacheKey = [self cacheKeyForPicId:picId source:source size:size];
    
    // 先同步检查缓存
    __block BOOL cacheHit = NO;
    dispatch_sync(self.cacheQueue, ^{
        NSString *cachedUrl = self.imageUrlCache[cacheKey];
        if (cachedUrl && cachedUrl.length > 0) {
            // 更新访问时间
            self.cacheTimestamps[cacheKey] = @([[NSDate date] timeIntervalSince1970]);
            NSLog(@"📸 [ImageCache] Cache hit for key: %@", cacheKey);
            cacheHit = YES;
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(cachedUrl, nil);
            });
        }
    });
    
    // 如果缓存命中，直接返回
    if (cacheHit) {
        return;
    }
    
    // 缓存未命中，直接请求API
    NSLog(@"📸 [ImageCache] Cache miss, requesting from API for key: %@", cacheKey);
    [[MusicAPIManager sharedManager] getAlbumImageWithPicId:picId 
                                                     source:source 
                                                       size:(NSInteger)size 
                                                 completion:^(NSString * _Nullable imageUrl, NSError * _Nullable error) {
        if (imageUrl && !error && imageUrl.length > 0) {
            // 异步缓存成功的URL
            dispatch_async(self.cacheQueue, ^{
                if (cacheKey && imageUrl) {
                    self.imageUrlCache[cacheKey] = imageUrl;
                    self.cacheTimestamps[cacheKey] = @([[NSDate date] timeIntervalSince1970]);
                }
                NSLog(@"📸 [ImageCache] Cached new URL for key: %@, URL: %@", cacheKey, imageUrl);
            });
            
            // 立即回调
            completion(imageUrl, nil);
        } else {
            NSLog(@"📸 [ImageCache] API request failed for key: %@, error: %@", cacheKey, error.localizedDescription ?: @"No URL returned");
            completion(nil, error ?: [NSError errorWithDomain:@"MusicImageCache" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"No image URL returned"}]);
        }
    }];
}

- (void)precacheImageURLsForMusicList:(NSArray *)musicList {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        for (MusicModel *music in musicList) {
            if ([music isKindOfClass:[MusicModel class]] && music.picId) {
                // 预缓存小尺寸图片
                [self getImageURLWithPicId:music.picId 
                                    source:music.source 
                                      size:MusicImageSizeSmall 
                                completion:^(NSString * _Nullable imageUrl, NSError * _Nullable error) {
                    // 静默缓存，不处理结果
                }];
            }
        }
    });
}

- (void)cleanExpiredCache {
    dispatch_barrier_async(self.cacheQueue, ^{
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        NSTimeInterval expireDuration = 7 * 24 * 60 * 60; // 7天
        
        NSMutableArray *expiredKeys = [NSMutableArray array];
        for (NSString *key in self.cacheTimestamps.allKeys) {
            NSTimeInterval cacheTime = [self.cacheTimestamps[key] doubleValue];
            if (now - cacheTime > expireDuration) {
                [expiredKeys addObject:key];
            }
        }
        
        for (NSString *key in expiredKeys) {
            [self.imageUrlCache removeObjectForKey:key];
            [self.cacheTimestamps removeObjectForKey:key];
        }
        
        NSLog(@"📸 [ImageCache] Cleaned %lu expired cache entries", (unsigned long)expiredKeys.count);
        
        [self saveCache];
    });
}

- (void)clearAllCache {
    dispatch_barrier_async(self.cacheQueue, ^{
        [self.imageUrlCache removeAllObjects];
        [self.cacheTimestamps removeAllObjects];
        
        [[NSFileManager defaultManager] removeItemAtPath:self.cacheFilePath error:nil];
        NSLog(@"📸 [ImageCache] Cleared all cache");
    });
}

- (NSDictionary *)getCacheStatistics {
    __block NSDictionary *stats;
    dispatch_sync(self.cacheQueue, ^{
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        NSInteger expiredCount = 0;
        NSTimeInterval expireDuration = 7 * 24 * 60 * 60; // 7天
        
        for (NSString *key in self.cacheTimestamps.allKeys) {
            NSTimeInterval cacheTime = [self.cacheTimestamps[key] doubleValue];
            if (now - cacheTime > expireDuration) {
                expiredCount++;
            }
        }
        
        stats = @{
            @"totalCached": @(self.imageUrlCache.count),
            @"expiredCount": @(expiredCount),
            @"cacheFilePath": self.cacheFilePath ?: @""
        };
    });
    return stats;
}

#pragma mark - Private Methods

- (NSString *)cacheKeyForPicId:(NSString *)picId source:(NSString *)source size:(MusicImageSize)size {
    return [NSString stringWithFormat:@"%@_%@_%ld", source, picId, (long)size];
}

@end
