//
//  WVRVideoConfiguration.h
//  styf
//
//  Created by styf on 2021/7/15.
//  Copyright © 2021 styf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WVRVideoConfiguration : NSObject
/// 采集的视频的 sessionPreset，默认为 AVCaptureSessionPreset1920x1080
@property (nonatomic, copy) NSString *sessionPreset;
/// 输入文件类型 默认为AVFileTypeMPEG4
@property (nonatomic, copy) AVFileType fileType;
/// 默认实例
+ (instancetype)defaultConfiguration;
@end

NS_ASSUME_NONNULL_END
