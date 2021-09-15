//
//  WVRSampleBufferHolder.h
//  styf
//
//  Created by styf on 2021/7/20.
//  Copyright © 2021 styf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
NS_ASSUME_NONNULL_BEGIN

@interface WVRSampleBufferHolder : NSObject

@property (assign, nonatomic) CMSampleBufferRef sampleBuffer;

+ (WVRSampleBufferHolder *)sampleBufferHolderWithSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end

NS_ASSUME_NONNULL_END
