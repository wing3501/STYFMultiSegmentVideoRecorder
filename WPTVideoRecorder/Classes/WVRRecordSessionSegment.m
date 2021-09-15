//
//  WVRRecordSessionSegment.m
//  styf
//
//  Created by styf on 2021/7/21.
//  Copyright © 2021 styf. All rights reserved.
//

#import "WVRRecordSessionSegment.h"

@interface WVRRecordSessionSegment(){
    AVAsset *_asset;
}
@end

@implementation WVRRecordSessionSegment

- (instancetype)initWithUrl:(NSURL *)url {
    self = [super init];
    if (self) {
        _url = url;
    }
    return self;
}

- (AVAsset *)asset {
    if (!_asset) {
        _asset = [AVAsset assetWithURL:_url];
    }
    return _asset;
}

- (CMTime)duration {
    return [self asset].duration;
}

@end
