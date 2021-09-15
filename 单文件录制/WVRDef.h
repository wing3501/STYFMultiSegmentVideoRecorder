//
//  WVRDef.h
//  styf
//
//  Created by styf on 2021/7/15.
//  Copyright © 2021 styf. All rights reserved.
//

#ifndef WVRDef_h
#define WVRDef_h

typedef NS_ENUM(NSUInteger, WVRError) {
    WVRErrorCaptureSession,//设备初始化相关异常
    WVRErrorWriteVideo,//视频写入失败
    WVRErrorToggleCamera,//切换前后摄像头
};


#endif /* WVRDef_h */
