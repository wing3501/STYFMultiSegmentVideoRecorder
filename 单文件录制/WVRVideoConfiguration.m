//
//  WVRVideoConfiguration.m
//  styf
//
//  Created by styf on 2021/7/15.
//  Copyright © 2021 styf. All rights reserved.
//

#import "WVRVideoConfiguration.h"
#import <AVFoundation/AVFoundation.h>

@implementation WVRVideoConfiguration

/// 默认实例
+ (instancetype)defaultConfiguration {
    WVRVideoConfiguration *config = [[WVRVideoConfiguration alloc]init];
    config.sessionPreset = AVCaptureSessionPreset1920x1080;
    config.fileType = AVFileTypeMPEG4;
    return config;
}

@end
