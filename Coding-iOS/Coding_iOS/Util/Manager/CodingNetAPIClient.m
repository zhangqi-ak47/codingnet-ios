//
//  CodingNetAPIClient.m
//  Coding_iOS
//
//  Created by 王 原闯 on 14-7-30.
//  Copyright (c) 2014年 Coding. All rights reserved.
//

#define kNetworkMethodName @[@"Get", @"Post", @"Put", @"Delete"]

#import "CodingNetAPIClient.h"
#import "Login.h"

@implementation CodingNetAPIClient

static CodingNetAPIClient *_sharedClient = nil;
static CodingNetAPIClient *_eClient = nil;
static dispatch_once_t onceToken;
static dispatch_once_t e_Token;

+ (CodingNetAPIClient *)sharedJsonClient {
    dispatch_once(&onceToken, ^{
        _sharedClient = [[CodingNetAPIClient alloc] initWithBaseURL:[NSURL URLWithString:[NSObject baseURLStr]]];
    });
    return _sharedClient;
}

+ (id)changeJsonClient{
    _sharedClient = [[CodingNetAPIClient alloc] initWithBaseURL:[NSURL URLWithString:[NSObject baseURLStr]]];
    return _sharedClient;
}

+ (id)changeSharedJsonClient{
    _sharedClient = [[CodingNetAPIClient alloc] initWithBaseURL:[NSURL URLWithString:[NSObject baseURLStr]]];
    return _sharedClient;
}

+ (CodingNetAPIClient *)e_JsonClient {
    dispatch_once(&e_Token, ^{
        _eClient = [[CodingNetAPIClient alloc] initWithBaseURL:[NSURL URLWithString:[NSObject e_URLStr]]];
    });
    return _eClient;
}

+ (id)changeE_JsonClient{
    _eClient = [[CodingNetAPIClient alloc] initWithBaseURL:[NSURL URLWithString:[NSObject e_URLStr]]];
    return _eClient;
}

- (id)initWithBaseURL:(NSURL *)url {
    self = [super initWithBaseURL:url];
    if (!self) {
        return nil;
    }
    self.responseSerializer = [AFJSONResponseSerializer serializer];
    self.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/plain", @"text/javascript", @"text/json", @"text/html", nil];
    
    [self.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [self.requestSerializer setValue:url.absoluteString forHTTPHeaderField:@"Referer"];
    
    self.securityPolicy.allowInvalidCertificates = YES;
    
    return self;
}

- (void)requestJsonDataWithPath:(NSString *)aPath
                     withParams:(NSDictionary*)params
                 withMethodType:(NetworkMethod)method
                       andBlock:(void (^)(id data, NSError *error))block{
    [self requestJsonDataWithPath:aPath withParams:params withMethodType:method autoShowError:YES andBlock:block];
}

- (void)requestJsonDataWithPath:(NSString *)aPath
                     withParams:(NSDictionary*)params
                 withMethodType:(NetworkMethod)method
                  autoShowError:(BOOL)autoShowError
                       andBlock:(void (^)(id data, NSError *error))block{
    if (!aPath || aPath.length <= 0) {
        return;
    }
    //CSRF - 跨站请求伪造
    NSHTTPCookie *_CSRF = nil;
    for (NSHTTPCookie *tempC in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        if ([tempC.name isEqualToString:@"XSRF-TOKEN"]) {
            _CSRF = tempC;
        }
    }
    if (_CSRF) {
        [self.requestSerializer setValue:_CSRF.value forHTTPHeaderField:@"X-XSRF-TOKEN"];
    }
    //log请求数据
    DebugLog(@"\n===========request===========\n%@\n%@:\n%@", kNetworkMethodName[method], aPath, params);
    aPath = [aPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];//卧槽了，有些把 params 放在 path 里面的 GET 方法
//    aPath = [aPath stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];
//    发起请求
    switch (method) {
        case Get:{
            //所有 Get 请求，增加缓存机制
            NSMutableString *localPath = [aPath mutableCopy];
            if (params) {
                [localPath appendString:params.description];
            }
            [self GET:aPath parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
                DebugLog(@"\n===========response===========\n%@:\n%@", aPath, responseObject);
                id error = [self handleResponse:responseObject autoShowError:autoShowError];
                if (error) {
                    responseObject = [NSObject loadResponseWithPath:localPath];
                    block(responseObject, error);
                }else{
                    if ([responseObject isKindOfClass:[NSDictionary class]]) {
                        //判断数据是否符合预期，给出提示
                        if ([responseObject[@"data"] isKindOfClass:[NSDictionary class]]) {
                            if (responseObject[@"data"][@"too_many_files"]) {
                                if (autoShowError) {
                                    [NSObject showHudTipStr:@"文件太多，不能正常显示"];
                                }
                            }
                        }
                        [NSObject saveResponseData:responseObject toPath:localPath];
                    }
                    block(responseObject, nil);
                }
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                DebugLog(@"\n===========response===========\n%@:\n%@\n%@", aPath, error, operation.responseString);
                id responseObject = [NSObject loadResponseWithPath:localPath];
                !autoShowError || (error.code == NSURLErrorNotConnectedToInternet && responseObject != nil) || [NSObject showError:error];
                block(responseObject, error);
            }];
            break;}
        case Post:{
            [self POST:aPath parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
                DebugLog(@"\n===========response===========\n%@:\n%@", aPath, responseObject);
                id error = [self handleResponse:responseObject autoShowError:autoShowError];
                if (error) {
                    block(nil, error);
                }else{
                    block(responseObject, nil);
                }
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                DebugLog(@"\n===========response===========\n%@:\n%@\n%@", aPath, error, operation.responseString);
                !autoShowError || [NSObject showError:error];
                block(nil, error);
            }];
            break;}
        case Put:{
            [self PUT:aPath parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
                DebugLog(@"\n===========response===========\n%@:\n%@", aPath, responseObject);
                id error = [self handleResponse:responseObject autoShowError:autoShowError];
                if (error) {
                    block(nil, error);
                }else{
                    block(responseObject, nil);
                }
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                DebugLog(@"\n===========response===========\n%@:\n%@\n%@", aPath, error, operation.responseString);
                !autoShowError || [NSObject showError:error];
                block(nil, error);
            }];
            break;}
        case Delete:{
            [self DELETE:aPath parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
                DebugLog(@"\n===========response===========\n%@:\n%@", aPath, responseObject);
                id error = [self handleResponse:responseObject autoShowError:autoShowError];
                if (error) {
                    block(nil, error);
                }else{
                    block(responseObject, nil);
                }
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                DebugLog(@"\n===========response===========\n%@:\n%@\n%@", aPath, error, operation.responseString);
                !autoShowError || [NSObject showError:error];
                block(nil, error);
            }];
            break;}
        default:
            break;
    }
    
}

-(void)requestJsonDataWithPath:(NSString *)aPath file:(NSDictionary *)file withParams:(NSDictionary *)params withMethodType:(NetworkMethod)method andBlock:(void (^)(id, NSError *))block{
    //log请求数据
    DebugLog(@"\n===========request===========\n%@:\n%@", aPath, params);
//    aPath = [aPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    aPath = [aPath stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];

    // Data
    NSData *data;
    NSString *name, *fileName;
    
    if (file) {
        UIImage *image = file[@"image"];
        // 压缩
        data = [image dataForCodingUpload];
        name = file[@"name"];
        fileName = file[@"fileName"];
    }
    
    switch (method) {
        case Post:{
            
            AFHTTPRequestOperation *operation = [self POST:aPath parameters:params constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
                if (file) {
                    [formData appendPartWithFileData:data name:name fileName:fileName mimeType:@"image/jpeg"];
                }
            } success:^(AFHTTPRequestOperation *operation, id responseObject) {
                DebugLog(@"\n===========response===========\n%@:\n%@", aPath, responseObject);
                id error = [self handleResponse:responseObject];
                if (error) {
                    block(nil, error);
                }else{
                    block(responseObject, nil);
                }

            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                DebugLog(@"\n===========response===========\n%@:\n%@\n%@", aPath, error, operation.responseString);
                [NSObject showError:error];
                block(nil, error);
            }];
            [operation start];
            
            break;
        }
        default:
            break;
    }
}

- (void)reportIllegalContentWithType:(IllegalContentType)type
                          withParams:(NSDictionary*)params{
    NSString *aPath;
    switch (type) {
        case IllegalContentTypeTweet:
            aPath = @"/api/inform/tweet";
            break;
        case IllegalContentTypeTopic:
            aPath = @"/api/inform/topic";
            break;
        case IllegalContentTypeProject:
            aPath = @"/api/inform/project";
            break;
        case IllegalContentTypeWebsite:
            aPath = @"/api/inform/website";
            break;
        default:
            aPath = @"/api/inform/tweet";
            break;
    }
    DebugLog(@"\n===========request===========\n%@:\n%@", aPath, params);
    [self POST:aPath parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        DebugLog(@"\n===========response===========\n%@:\n%@", aPath, responseObject);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DebugLog(@"\n===========response===========\n%@:\n%@\n%@", aPath, error, operation.responseString);
    }];
}

- (void)uploadImage:(UIImage *)image path:(NSString *)path name:(NSString *)name
       successBlock:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
       failureBlock:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
      progerssBlock:(void (^)(CGFloat progressValue))progress{
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [image dataForCodingUpload];
        [self p_uploadImageData:data path:path name:name successBlock:success failureBlock:failure progerssBlock:progress];
    });
    
//    NSData *data = [image dataForCodingUpload];
//    NSString *fileName = [NSString stringWithFormat:@"%@_%@.jpg", [Login curLoginUser].global_key, [NSUUID UUID].UUIDString];
//    DebugLog(@"\nuploadImageSize\n%@ : %.0f", fileName, (float)data.length/1024);
//
//    __weak typeof(self) weakSelf = self;
//    void (^uploadBlock)(NSDictionary *) = ^(NSDictionary *uploadParams){
//        AFHTTPRequestOperation *operation = [weakSelf POST:path parameters:uploadParams constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
//            [formData appendPartWithFileData:data name:name fileName:fileName mimeType:@"image/jpeg"];
//        } success:^(AFHTTPRequestOperation *operation, id responseObject) {
//            DebugLog(@"Success: %@ ***** %@", operation.responseString, responseObject);
//            id error = [self handleResponse:responseObject];
//            if (error && failure) {
//                failure(operation, error);
//            }else{
//                success(operation, responseObject);
//            }
//        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
//            DebugLog(@"Error: %@ ***** %@", operation.responseString, error);
//            if (failure) {
//                failure(operation, error);
//            }
//        }];
//        [operation setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
//            CGFloat progressValue = (float)totalBytesWritten/(float)totalBytesExpectedToWrite;
//            if (progress) {
//                progress(progressValue);
//            }
//        }];
//        [operation start];
//    };
//    if ([path isEqualToString:@"https://up.qbox.me/"]) {//先拿 token
//        NSDictionary *params = @{
//                                 @"fileName": fileName,
//                                 @"fileSize": @(data.length)
//                                 };
//        [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/upload_token/public/images" withParams:params withMethodType:Get andBlock:^(id data, NSError *error) {
//            if (data) {
//                NSDictionary *result = data[@"data"];
//                NSMutableDictionary *uploadParams = @{}.mutableCopy;
//                uploadParams[@"token"] = result[@"uptoken"];
//                uploadParams[@"x:time"] = result[@"time"];
//                uploadParams[@"x:authToken"] = result[@"authToken"];
//                uploadParams[@"x:userId"] = result[@"userId"];
//                uploadParams[@"key"] = fileName;
//                uploadBlock(uploadParams);
//            }
//        }];
//    }else{
//        uploadBlock(nil);
//    }
}

- (void)p_uploadImageData:(NSData *)data path:(NSString *)path name:(NSString *)name
       successBlock:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
       failureBlock:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
      progerssBlock:(void (^)(CGFloat progressValue))progress{
    
    NSString *fileName = [NSString stringWithFormat:@"%@_%@.jpg", [Login curLoginUser].global_key, [NSUUID UUID].UUIDString];
    DebugLog(@"\nuploadImageSize\n%@ : %.0f", fileName, (float)data.length/1024);
    
    __weak typeof(self) weakSelf = self;
    void (^uploadBlock)(NSDictionary *) = ^(NSDictionary *uploadParams){
        AFHTTPRequestOperation *operation = [weakSelf POST:path parameters:uploadParams constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
            [formData appendPartWithFileData:data name:name fileName:fileName mimeType:@"image/jpeg"];
        } success:^(AFHTTPRequestOperation *operation, id responseObject) {
            DebugLog(@"Success: %@ ***** %@", operation.responseString, responseObject);
            id error = [self handleResponse:responseObject];
            if (error && failure) {
                failure(operation, error);
            }else{
                success(operation, responseObject);
            }
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            DebugLog(@"Error: %@ ***** %@", operation.responseString, error);
            if (failure) {
                failure(operation, error);
            }
        }];
        [operation setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
            CGFloat progressValue = (float)totalBytesWritten/(float)totalBytesExpectedToWrite;
            if (progress) {
                progress(progressValue);
            }
        }];
        [operation start];
    };
    if ([path isEqualToString:@"https://up.qbox.me/"]) {//先拿 token
        NSDictionary *params = @{
                                 @"fileName": fileName,
                                 @"fileSize": @(data.length)
                                 };
        [[CodingNetAPIClient sharedJsonClient] requestJsonDataWithPath:@"api/upload_token/public/images" withParams:params withMethodType:Get andBlock:^(id data, NSError *error) {
            if (data) {
                NSDictionary *result = data[@"data"];
                NSMutableDictionary *uploadParams = @{}.mutableCopy;
                uploadParams[@"token"] = result[@"uptoken"];
                uploadParams[@"x:time"] = result[@"time"];
                uploadParams[@"x:authToken"] = result[@"authToken"];
                uploadParams[@"x:userId"] = result[@"userId"];
                uploadParams[@"key"] = fileName;
                uploadBlock(uploadParams);
            }
        }];
    }else{
        uploadBlock(nil);
    }
}

- (void)uploadAssets:(NSArray *)assets
                path:(NSString *)path
                name:(NSString *)name
              params:(NSDictionary *)params
        successBlock:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
        failureBlock:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
       progerssBlock:(void (^)(CGFloat progressValue))progress{
    AFHTTPRequestOperation *operation = [self POST:path parameters:params constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        for (PHAsset *asset in assets) {
            NSString *fileName = asset.fileName;;
            NSData *data = [asset.loadImage dataForCodingUpload];
            [formData appendPartWithFileData:data name:name fileName:fileName mimeType:@"image/jpeg"];
        }
    } success:^(AFHTTPRequestOperation *operation, id responseObject) {
        DebugLog(@"Success: %@ ***** %@", operation.responseString, responseObject);
        id error = [self handleResponse:responseObject];
        if (error && failure) {
            failure(operation, error);
        }else{
            success(operation, responseObject);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DebugLog(@"Error: %@ ***** %@", operation.responseString, error);
        if (failure) {
            failure(operation, error);
        }
    }];
    
    [operation setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        CGFloat progressValue = (float)totalBytesWritten/(float)totalBytesExpectedToWrite;
        if (progress) {
            progress(progressValue);
        }
    }];
    [operation start];
}

- (void)uploadVoice:(NSString *)file
           withPath:(NSString *)path
         withParams:(NSDictionary*)params
           andBlock:(void (^)(id data, NSError *error))block {
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:file]) {
        return;
    }
    
    NSData *data = [NSData dataWithContentsOfFile:file];
    NSString *fileName = [file lastPathComponent];

    DebugLog(@"\nuploadVoiceSize\n%@ : %.0f", fileName, (float)data.length/1024);
    
    AFHTTPRequestOperation *operation = [self POST:path parameters:params constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        [formData appendPartWithFileData:data name:@"file" fileName:fileName mimeType:@"audio/amr"];
    } success:^(AFHTTPRequestOperation *operation, id responseObject) {
        DebugLog(@"\n===========response===========\n%@:\n%@", path, responseObject);
        id error = [self handleResponse:responseObject autoShowError:YES];
        if (error) {
            block(nil, error);
        }else{
            block(responseObject, nil);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DebugLog(@"\n===========response===========\n%@:\n%@", path, error);
        [NSObject showError:error];
        block(nil, error);
    }];
    
    [operation start];
}
@end