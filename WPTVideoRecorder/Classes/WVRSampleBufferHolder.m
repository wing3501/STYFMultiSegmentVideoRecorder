//
//  WVRSampleBufferHolder.m
//  styf
//
//  Created by styf on 2021/7/20.
//  Copyright © 2021 styf. All rights reserved.
//

#import "WVRSampleBufferHolder.h"

@implementation WVRSampleBufferHolder

- (void)dealloc {
    if (_sampleBuffer != nil) {
        CFRelease(_sampleBuffer);
    }
}

- (void)setSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (_sampleBuffer != nil) {
        CFRelease(_sampleBuffer);
        _sampleBuffer = nil;
    }
    
    _sampleBuffer = sampleBuffer;
    
    if (sampleBuffer != nil) {
        CFRetain(sampleBuffer);
    }
}

+ (WVRSampleBufferHolder *)sampleBufferHolderWithSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    WVRSampleBufferHolder *sampleBufferHolder = [WVRSampleBufferHolder new];
    
    sampleBufferHolder.sampleBuffer = sampleBuffer;
    
    return sampleBufferHolder;
}
@end
