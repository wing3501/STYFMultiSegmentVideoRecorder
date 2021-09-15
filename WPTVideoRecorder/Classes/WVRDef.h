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
    WVRErrorCaptureSession,//采集设备初始化异常
    WVRErrorWirteSession,//写入设备初始化异常
    WVRErrorWrite,//音视频写入失败
    WVRErrorToggleCamera,//切换前后摄像头
    WVRErrorZoom,//缩放
};


#endif /* WVRDef_h */
