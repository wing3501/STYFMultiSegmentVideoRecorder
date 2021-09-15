//
//  WVRAudioConfiguration.m
//  styf
//
//  Created by styf on 2021/7/15.
//  Copyright © 2021 styf. All rights reserved.
//

#import "WVRAudioConfiguration.h"
#import <AVFoundation/AVFoundation.h>

@implementation WVRAudioConfiguration
/// 默认实例
+ (instancetype)defaultConfiguration {
    WVRAudioConfiguration *config = [[WVRAudioConfiguration alloc]init];
    
    return config;
}
@end
