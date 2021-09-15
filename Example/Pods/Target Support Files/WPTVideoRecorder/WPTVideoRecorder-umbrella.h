#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "WVRAudioConfiguration.h"
#import "WVRDef.h"
#import "WVRRecordSessionSegment.h"
#import "WVRSampleBufferHolder.h"
#import "WVRVideoConfiguration.h"
#import "WVRVideoRecorder.h"
#import "WVRVideoRecordSession.h"

FOUNDATION_EXPORT double WPTVideoRecorderVersionNumber;
FOUNDATION_EXPORT const unsigned char WPTVideoRecorderVersionString[];

