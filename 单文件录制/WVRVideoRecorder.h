//
//  WVRVideoRecorder.h
//  styf
//
//  Created by styf on 2021/7/15.
//  Copyright © 2021 styf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WVRVideoConfiguration.h"
#import "WVRAudioConfiguration.h"
#import "WVRDef.h"

NS_ASSUME_NONNULL_BEGIN
@class WVRVideoRecorder;
@protocol WVRVideoRecorderDelegate <NSObject>
@optional
/// 错误回调
/// @param recorder 录制器
/// @param errorCode 错误号
- (void)videoRecorder:(WVRVideoRecorder *__nonnull)recorder error:(WVRError)errorCode;

/// 视频录制结束
/// @param recorder 录制器
/// @param fileURL 视频文件路径
/// @param error 错误
- (void)videoRecorder:(WVRVideoRecorder *__nonnull)recorder didFinishRecordingToOutputFileAtURL:(NSURL *__nullable)fileURL error:(NSError *__nullable)error;

/// 视频录制进度
/// @param recorder 录制器
/// @param progress 录制进度
- (void)videoRecorder:(WVRVideoRecorder *__nonnull)recorder recordProgress:(CGFloat)progress;
@end

@interface WVRVideoRecorder : NSObject

/// 代理
@property (nonatomic, weak) id<WVRVideoRecorderDelegate> delegate;
/// 视频预览容器
@property (nonatomic, strong) UIView *previewView;
/// 是否正在录制并写入
@property (nonatomic, assign, readonly) BOOL isRecording;
/// 当前录制时间
@property (nonatomic, assign, readonly) CGFloat currentRecordTime;
/// 最长录制时间 默认15秒
@property (nonatomic, assign) CGFloat maxRecordTime;

/// 初始化
/// @param videoConfiguration 视频配置
/// @param audioConfiguration 音频配置
- (nonnull instancetype)initWithVideoConfiguration:(WVRVideoConfiguration *_Nullable)videoConfiguration audioConfiguration:(WVRAudioConfiguration *_Nullable)audioConfiguration;

/// 开始音视频采集
- (void)startCaptureSession;
/// 停止音视频采集
- (void)stopCaptureSession;
/// 开始录制视频
- (void)startRecording;
/// 停止录制视频
- (void)stopRecording;
/// 取消录制视频并删除已经录制的视频段
- (void)cancelRecording;
/// 结束录制
- (void)finishRecording;

/// 切换前后摄像头
- (void)toggleCamera;
@end

NS_ASSUME_NONNULL_END
