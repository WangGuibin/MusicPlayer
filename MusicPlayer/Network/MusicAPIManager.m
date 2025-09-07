//
//  MusicAPIManager.m
//  MusicAPI
//
//  Created by Qwen Code on 2025/9/3.
//

#import "MusicAPIManager.h"
#import "YYModel.h"

static NSString * const kBaseURL = @"https://music-api.gdstudio.xyz/api.php";

@interface MusicAPIManager()

@property (nonatomic, strong) NSURLSession *session;

@end

@implementation MusicAPIManager

+ (instancetype)sharedManager {
    static MusicAPIManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[MusicAPIManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _session = [NSURLSession sharedSession];
    }
    return self;
}

#pragma mark - Search

- (void)searchMusicWithKeyword:(NSString *)keyword
                        source:(NSString *)source
                         count:(NSInteger)count
                         pages:(NSInteger)pages
                    completion:(SearchCompletionBlock)completion {
    // Validate parameters
    if (!keyword || keyword.length == 0) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"MusicAPIErrorDomain" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Keyword is required"}]);
        }
        return;
    }
    
    // Build URL
    NSString *encodedKeyword = [keyword stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *sourceParam = source ?: @"netease";
    NSString *urlString = [NSString stringWithFormat:@"%@?types=search&source=%@&name=%@&count=%ld&pages=%ld",
                           kBaseURL, sourceParam, encodedKeyword, (long)count, (long)pages];
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error);
            });
            return;
        }
        
        NSError *jsonError;
        NSArray *jsonArray = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (jsonError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, jsonError);
            });
            return;
        }
        
        NSArray<MusicModel *> *results = [NSArray yy_modelArrayWithClass:[MusicModel class] json:jsonArray];
 
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion([results copy], nil);
        });
    }];
    
    [task resume];
}

#pragma mark - Get Music URL

- (void)getMusicURLWithTrackId:(NSString *)trackId
                        source:(NSString *)source
                       bitrate:(NSInteger)bitrate
                    completion:(MusicURLCompletionBlock)completion {
    // Validate parameters
    if (!trackId || trackId.length == 0) {
        if (completion) {
            completion(nil, nil, nil, [NSError errorWithDomain:@"MusicAPIErrorDomain" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Track ID is required"}]);
        }
        return;
    }
    
    // Build URL
    NSString *sourceParam = source ?: @"netease";
    NSString *urlString = [NSString stringWithFormat:@"%@?types=url&source=%@&id=%@&br=%ld",
                           kBaseURL, sourceParam, trackId, (long)bitrate];
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, nil, nil, error);
            });
            return;
        }
        
        NSError *jsonError;
        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (jsonError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, nil, nil, jsonError);
            });
            return;
        }
        
        NSString *musicURL = [jsonDict objectForKey:@"url"];
        NSNumber *br = [jsonDict objectForKey:@"br"];
        NSNumber *size = [jsonDict objectForKey:@"size"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(musicURL, br, size, nil);
        });
    }];
    
    [task resume];
}

#pragma mark - Get Album Image

- (void)getAlbumImageWithPicId:(NSString *)picId
                        source:(NSString *)source
                          size:(NSInteger)size
                    completion:(ImageCompletionBlock)completion {
    // Validate parameters
    if (!picId || picId.length == 0) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"MusicAPIErrorDomain" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Pic ID is required"}]);
        }
        return;
    }
    
    // Build URL
    NSString *sourceParam = source ?: @"netease";
    NSInteger sizeParam = (size == 500) ? 500 : 300; // Only allow 300 or 500
    NSString *urlString = [NSString stringWithFormat:@"%@?types=pic&source=%@&id=%@&size=%ld",
                           kBaseURL, sourceParam, picId, (long)sizeParam];
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error);
            });
            return;
        }
        
        NSError *jsonError;
        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (jsonError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, jsonError);
            });
            return;
        }
        
        NSString *imageUrl = [jsonDict objectForKey:@"url"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(imageUrl, nil);
        });
    }];
    
    [task resume];
}

#pragma mark - Get Lyrics

- (void)getLyricsWithLyricId:(NSString *)lyricId
                      source:(NSString *)source
                  completion:(LyricsCompletionBlock)completion {
    // Validate parameters
    if (!lyricId || lyricId.length == 0) {
        if (completion) {
            completion(nil, nil, [NSError errorWithDomain:@"MusicAPIErrorDomain" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Lyric ID is required"}]);
        }
        return;
    }
    
    // Build URL
    NSString *sourceParam = source ?: @"netease";
    NSString *urlString = [NSString stringWithFormat:@"%@?types=lyric&source=%@&id=%@",
                           kBaseURL, sourceParam, lyricId];
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, nil, error);
            });
            return;
        }
        
        NSError *jsonError;
        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (jsonError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, nil, jsonError);
            });
            return;
        }
        
        NSString *lyrics = [jsonDict objectForKey:@"lyric"];
        NSString *translatedLyrics = [jsonDict objectForKey:@"tlyric"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(lyrics, translatedLyrics, nil);
        });
    }];
    
    [task resume];
}

- (void)getLyricsWithTrackId:(NSString *)trackId
                      source:(NSString *)source
                  completion:(void(^)(NSString * _Nullable lyrics, NSError * _Nullable error))completion {
    // For simplicity, use trackId as lyricId since they're often the same in music APIs
    [self getLyricsWithLyricId:trackId source:source completion:^(NSString * _Nullable lyrics, NSString * _Nullable translatedLyrics, NSError * _Nullable error) {
        if (completion) {
            completion(lyrics, error);
        }
    }];
}

@end
