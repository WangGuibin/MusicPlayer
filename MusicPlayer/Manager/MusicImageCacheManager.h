//
//  MusicImageCacheManager.h
//  MusicPlayer
//
//  Created by Claude on 2025/9/6.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MusicImageSize) {
    MusicImageSizeSmall = 300,   // 用于列表显示
    MusicImageSizeLarge = 500    // 用于播放器详情
};

@interface MusicImageCacheManager : NSObject

+ (instancetype)sharedManager;

/**
 * 获取图片URL，优先从缓存获取，缓存未命中时请求接口
 * @param picId 图片ID
 * @param source 音乐源
 * @param size 图片尺寸
 * @param completion 完成回调，返回图片URL
 */
- (void)getImageURLWithPicId:(NSString *)picId 
                      source:(NSString *)source 
                        size:(MusicImageSize)size
                  completion:(void (^)(NSString * _Nullable imageUrl, NSError * _Nullable error))completion;

/**
 * 预缓存图片URL（批量缓存）
 */
- (void)precacheImageURLsForMusicList:(NSArray *)musicList;

/**
 * 清理过期缓存
 */
- (void)cleanExpiredCache;

/**
 * 清空所有缓存
 */
- (void)clearAllCache;

/**
 * 获取缓存统计信息
 */
- (NSDictionary *)getCacheStatistics;

@end

NS_ASSUME_NONNULL_END