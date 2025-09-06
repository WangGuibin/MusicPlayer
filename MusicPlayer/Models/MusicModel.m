//
//  MusicModel.m
//  MusicAPI
//
//  Created by Gemini on 2025/9/5.
//

#import "MusicModel.h"

@implementation MusicModel

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSDictionary<NSString *,id> *)modelCustomPropertyMapper {
    return @{@"picId": @"pic_id",
             @"trackId": @"id",
             @"lyric_id": @"lyric_id"};
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.trackId forKey:@"trackId"];
    [encoder encodeObject:self.name forKey:@"name"];
    [encoder encodeObject:self.artist forKey:@"artist"];
    [encoder encodeObject:self.album forKey:@"album"];
    [encoder encodeObject:self.picId forKey:@"picId"];
    [encoder encodeObject:self.lyric_id forKey:@"lyric_id"];
    [encoder encodeObject:self.source forKey:@"source"];
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if (self) {
        _trackId = [decoder decodeObjectOfClass:[NSString class] forKey:@"trackId"];
        _name = [decoder decodeObjectOfClass:[NSString class] forKey:@"name"];
        _artist = [decoder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [NSString class]]] forKey:@"artist"];
        _album = [decoder decodeObjectOfClass:[NSString class] forKey:@"album"];
        _picId = [decoder decodeObjectOfClass:[NSString class] forKey:@"picId"];
        _lyric_id = [decoder decodeObjectOfClass:[NSString class] forKey:@"lyric_id"];
        _source = [decoder decodeObjectOfClass:[NSString class] forKey:@"source"];
    }
    return self;
}

@end