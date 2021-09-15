//
//  WVRVideoRecordSession.h
//  styf
//
//  Created by styf on 2021/7/20.
//  Copyright © 2021 styf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WVRVideoConfiguration.h"
#import "WVRAudioConfiguration.h"
#import "WVRRecordSessionSegment.h"

NS_ASSUME_NONNULL_BEGIN

@interface WVRVideoRecordSession : NSObject
/// 已录制片段总时间
@property (atomic, assign, readonly) CMTime segmentsDuration;
/// 当前片段时长
@property (atomic, assign, readonly) CMTime currentSegmentDuration;
/// 总时长  已录制时长+当前片段时长
@property (nonatomic, assign, readonly) CMTime duration;
/// 本次片段录制准备完毕
@property (nonatomic, assign, readonly) BOOL recordSegmentReady;
/// 本次片段里已经写入视频帧
@property (nonatomic, assign, readonly) BOOL currentSegmentHasVideo;
/// 本次片段里已经写入音频帧
@property (nonatomic, assign, readonly) BOOL currentSegmentHasAudio;


/// 初始化
/// @param videoConfiguration 视频配置
/// @param audioConfiguration 音频配置
- (nonnull instancetype)initWithVideoConfiguration:(WVRVideoConfiguration *_Nullable)videoConfiguration audioConfiguration:(WVRAudioConfiguration *_Nullable)audioConfiguration;

/// 初始化视频写入
/// @param videoSettings 设置
- (void)initializeVideo:(NSDictionary *)videoSettings;

/// 初始化音频写入
/// @param audioSettings 设置
- (void)initializeAudio:(NSDictionary *)audioSettings;

/// 视频写入是否已经初始化
- (BOOL)videoInitialized;

/// 音频写入是否已经初始化
- (BOOL)audioInitialized;

/// 写入器是否已经初始化、片段录制是否开始，一个写入器对应一个片段
- (BOOL)recordSegmentBegan;

/// 开始一个片段录制，初始化一个writer
/// @param error 错误
- (void)beginSegment:(NSError**)error;

/// 写入样本
/// @param sampleBuffer 样本
/// @param isVideoSample 是否视频样本
- (BOOL)writeSample:(CMSampleBufferRef)sampleBuffer isVideoSample:(BOOL)isVideoSample;

/// 结束本次片段录制
/// @param completionHandler 回调
- (void)endSegmentWithCompletionHandler:(void(^__nullable)(WVRRecordSessionSegment *segment, NSError* error))completionHandler;

/// 取消录制视频并删除已经录制的视频段
/// @param completionHandler 回调
- (void)cancelSession:(void (^__nullable)(void))completionHandler;

/// 获取代表当前会话的所有视频段文件的 asset
- (AVAsset *)assetRepresentingAllFiles;
@end

NS_ASSUME_NONNULL_END
