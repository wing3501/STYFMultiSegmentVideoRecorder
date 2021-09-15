//
//  WVRRecordSessionSegment.h
//  styf
//
//  Created by styf on 2021/7/21.
//  Copyright © 2021 styf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WVRRecordSessionSegment : NSObject
/// 文件路径
@property (nonatomic, strong) NSURL *url;
/// 资源
@property (nonatomic, strong, readonly) AVAsset *asset;
/// 持续时间
@property (nonatomic, assign, readonly) CMTime duration;

- (instancetype)initWithUrl:(NSURL *)url;
@end

NS_ASSUME_NONNULL_END
