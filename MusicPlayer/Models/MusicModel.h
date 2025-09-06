//
//  MusicModel.h
//  MusicAPI
//
//  Created by Qwen Code on 2025/9/3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MusicModel : NSObject <NSCoding, NSSecureCoding>

@property (nonatomic, copy) NSString *trackId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSArray<NSString *> *artist;
@property (nonatomic, copy) NSString *album;
@property (nonatomic, copy) NSString *picId;
@property (nonatomic, copy) NSString *lyric_id;
@property (nonatomic, copy) NSString *source;

@end

NS_ASSUME_NONNULL_END
