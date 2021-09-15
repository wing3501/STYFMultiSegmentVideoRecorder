//
//  WVRVideoRecordSession.m
//  styf
//
//  Created by styf on 2021/7/20.
//  Copyright © 2021 styf. All rights reserved.
//

#import "WVRVideoRecordSession.h"

@interface WVRVideoRecordSession()
/// 视频配置
@property (nonatomic, strong) WVRVideoConfiguration *videoConfiguration;
/// 音频配置
@property (nonatomic, strong) WVRAudioConfiguration *audioConfiguration;
/// 资源写入器
@property (nonatomic, strong) AVAssetWriter *assetWriter;
/// 视频写入
@property (nonatomic, strong) AVAssetWriterInput *assetWriterVideoInput;
/// 音频写入
@property (nonatomic, strong) AVAssetWriterInput *assetWriterAudioInput;
/// 片段数组
@property (nonatomic, strong) NSMutableArray<WVRRecordSessionSegment *> *segments;
/// 当前片段序号
@property (nonatomic, assign) int currentSegmentCount;
/// 本次片段开始时间
@property (nonatomic, assign) CMTime segmentStartTime;
@end

@implementation WVRVideoRecordSession

#pragma mark - life cycle

- (nonnull instancetype)initWithVideoConfiguration:(WVRVideoConfiguration *_Nullable)videoConfiguration audioConfiguration:(WVRAudioConfiguration *_Nullable)audioConfiguration {
    self = [super init];
    if (self) {
        _videoConfiguration = videoConfiguration;
        _audioConfiguration = audioConfiguration;
        _currentSegmentCount = 0;
        _currentSegmentDuration = kCMTimeZero;
        _segmentsDuration = kCMTimeZero;
        _segments = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc {
    _assetWriterVideoInput = nil;
    _assetWriterAudioInput = nil;
    _assetWriter = nil;
}


#pragma mark - overwrite

#pragma mark - request

#pragma mark - public


/// 初始化视频写入
/// @param videoSettings 设置
- (void)initializeVideo:(NSDictionary *)videoSettings {
    _assetWriterVideoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo
                                                            outputSettings:videoSettings];
    _assetWriterVideoInput.expectsMediaDataInRealTime = YES;//这个输入要针对实时性进行优化
    
//    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
//    _assetWriterVideoInput.transform = WVRTransformForDeviceOrientation(orientation);
}

/// 初始化音频写入
/// @param audioSettings 设置
- (void)initializeAudio:(NSDictionary *)audioSettings {
    _assetWriterAudioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
    _assetWriterAudioInput.expectsMediaDataInRealTime = YES;
}

/// 视频写入是否已经初始化
- (BOOL)videoInitialized {
    return _assetWriterVideoInput != nil;
}

/// 音频写入是否已经初始化
- (BOOL)audioInitialized {
    return _assetWriterAudioInput != nil;
}

/// 写入器是否已经初始化、片段录制是否开始，一个写入器对应一个片段
- (BOOL)recordSegmentBegan {
    return _assetWriter != nil;
}

/// 开始一个片段录制，初始化一个writer
/// @param error 错误
- (void)beginSegment:(NSError**)error {
    _assetWriter = [AVAssetWriter assetWriterWithURL:[self nextFileURL] fileType:self.videoConfiguration.fileType error:error];
    if (!_assetWriter.error) {
        _assetWriter.shouldOptimizeForNetworkUse = YES;
        if ([_assetWriter canAddInput:self.assetWriterVideoInput]) {
            [_assetWriter addInput:self.assetWriterVideoInput];
        }else {
            *error = [NSError errorWithDomain:@"WVRRecordSession" code:200 userInfo:@{NSLocalizedDescriptionKey : @"Cannot add videoInput to the assetWriter with the currently applied settings"}];
        }
        if ([_assetWriter canAddInput:self.assetWriterAudioInput]) {
            [_assetWriter addInput:self.assetWriterAudioInput];
        }else {
            *error = [NSError errorWithDomain:@"WVRRecordSession" code:200 userInfo:@{NSLocalizedDescriptionKey : @"Cannot add audioInput to the assetWriter with the currently applied settings"}];
        }
    }
    if ([_assetWriter startWriting]) {
        _segmentStartTime = kCMTimeInvalid;
        _recordSegmentReady = YES;
    }else {
        _assetWriter = nil;
        *error = _assetWriter.error;
    }
}

/// 写入样本
/// @param sampleBuffer 样本
/// @param isVideoSample 是否视频样本
- (BOOL)writeSample:(CMSampleBufferRef)sampleBuffer isVideoSample:(BOOL)isVideoSample {
    //数据是否准备写入
    if (CMSampleBufferDataIsReady(sampleBuffer)) {
        CMTime timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        CMTime duration = CMSampleBufferGetDuration(sampleBuffer);
        
        //写入失败
        if (_assetWriter.status == AVAssetWriterStatusFailed) {
            NSLog(@"writer error %@", _assetWriter.error);
            return NO;
        }
        if (isVideoSample) {
            //保证优先写入视频帧，以及writer的startSessionAtSourceTime以视频帧为开始
            //Error Domain=AVFoundationErrorDomain Code=-11832 "打不开" UserInfo={NSLocalizedFailureReason=无法使用此媒体。, NSLocalizedDescription=打不开, NSUnderlyingError=0x11f462d60 {Error Domain=NSOSStatusErrorDomain Code=-12431 "(null)"}}
            [self _startSessionIfNeededAtTime:timeStamp];
            
            if (self.assetWriterVideoInput.readyForMoreMediaData) {
                //完成了视频样本的处理
                if (![self.assetWriterVideoInput appendSampleBuffer:sampleBuffer]) {
                    NSLog(@"Error appending pixel buffer.%@",_assetWriter.error);
                    return NO;
                }else {
                    _currentSegmentDuration = CMTimeSubtract(timeStamp, _segmentStartTime);
                    _currentSegmentHasVideo = YES;
                }
            }
        }else {
            //处理音频样本
            if (self.assetWriterAudioInput.isReadyForMoreMediaData && _currentSegmentHasVideo) {//保证优先写入视频
                if (![self.assetWriterAudioInput appendSampleBuffer:sampleBuffer]) {
                    NSLog(@"Error appending audio sample buffer.%@",_assetWriter.error);
                    return NO;
                }else {
                    if (!_currentSegmentHasVideo) {
                        _currentSegmentDuration = CMTimeSubtract(CMTimeAdd(timeStamp, duration), _segmentStartTime);
                    }
                    _currentSegmentHasAudio = YES;
                }
            }
        }
        return YES;
    }else {
        return NO;
    }
}

/// 总时长
- (CMTime)duration {
    return CMTimeAdd(_segmentsDuration, _currentSegmentDuration);
}

/// 结束本次片段录制
/// @param completionHandler 回调
- (void)endSegmentWithCompletionHandler:(void(^__nullable)(WVRRecordSessionSegment *segment, NSError* error))completionHandler {
    if (_recordSegmentReady) {
        _recordSegmentReady = NO;
        if (_assetWriter != nil) {
            BOOL currentSegmentEmpty = (!_currentSegmentHasVideo && !_currentSegmentHasAudio);
            if (currentSegmentEmpty) {
                //本次片段是个空片段，删除空文件
                [_assetWriter cancelWriting];
                [[NSFileManager defaultManager] removeItemAtPath:_assetWriter.outputURL.path error:nil];
                if (completionHandler != nil) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completionHandler(nil, nil);
                    });
                }
            }else {
                [_assetWriter endSessionAtSourceTime:CMTimeAdd(_currentSegmentDuration, _segmentStartTime)];
                [_assetWriter finishWritingWithCompletionHandler:^{
                    [self appendRecordSegmentUrl:self.assetWriter.outputURL error:self.assetWriter.error completionHandler:completionHandler];
                }];
            }
        }
    }else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler != nil) {
                completionHandler(nil, [NSError errorWithDomain:@"WVRRecordSession" code:200 userInfo:@{NSLocalizedDescriptionKey : @"The current record segment is not ready for this operation"}]);
            }
        });
    }
}

/// 取消录制视频并删除已经录制的视频段
/// @param completionHandler 回调
- (void)cancelSession:(void (^__nullable)(void))completionHandler {
    if (_assetWriter == nil) {
        [self removeAllSegments];
        if (completionHandler) {
            dispatch_async(dispatch_get_main_queue(), completionHandler);
        }
    } else {
        [self endSegmentWithCompletionHandler:^(WVRRecordSessionSegment * _Nonnull segment, NSError * _Nonnull error) {
            [self removeAllSegments];
            if (completionHandler) {
                dispatch_async(dispatch_get_main_queue(), completionHandler);
            }
        }];
    }
}

/// 获取代表当前会话的所有视频段文件的 asset
- (AVAsset *)assetRepresentingAllFiles {
    if (_segments.count == 1) {
        WVRRecordSessionSegment *segment = _segments.firstObject;
        return segment.asset;
    } else {
        AVMutableComposition *composition = [AVMutableComposition composition];
        [self appendSegmentsToComposition:composition];
        return composition;
    }
}

#pragma mark - notification


#pragma mark - event response

#pragma mark - private

/// 把所有片段组合到一起
/// @param composition 组合
- (void)appendSegmentsToComposition:(AVMutableComposition * __nonnull)composition {
    AVMutableCompositionTrack *audioTrack = nil;
    AVMutableCompositionTrack *videoTrack = nil;
    
    CMTime currentTime = composition.duration;
    for (WVRRecordSessionSegment *recordSegment in _segments) {
        AVAsset *asset = recordSegment.asset;
        
        NSArray *audioAssetTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
        NSArray *videoAssetTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
        
        CMTime maxBounds = kCMTimeInvalid;
        
        CMTime videoTime = currentTime;
        for (AVAssetTrack *videoAssetTrack in videoAssetTracks) {
            if (videoTrack == nil) {
                NSArray *videoTracks = [composition tracksWithMediaType:AVMediaTypeVideo];
                
                if (videoTracks.count > 0) {
                    videoTrack = [videoTracks firstObject];
                } else {
                    videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
                    videoTrack.preferredTransform = videoAssetTrack.preferredTransform;
                }
            }
            
            videoTime = [self _appendTrack:videoAssetTrack toCompositionTrack:videoTrack atTime:videoTime withBounds:maxBounds];
            maxBounds = videoTime;
        }
        
        CMTime audioTime = currentTime;
        for (AVAssetTrack *audioAssetTrack in audioAssetTracks) {
            if (audioTrack == nil) {
                NSArray *audioTracks = [composition tracksWithMediaType:AVMediaTypeAudio];
                
                if (audioTracks.count > 0) {
                    audioTrack = [audioTracks firstObject];
                } else {
                    audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
                }
            }
            
            audioTime = [self _appendTrack:audioAssetTrack toCompositionTrack:audioTrack atTime:audioTime withBounds:maxBounds];
        }
        
        currentTime = composition.duration;
    }
}

- (CMTime)_appendTrack:(AVAssetTrack *)track toCompositionTrack:(AVMutableCompositionTrack *)compositionTrack atTime:(CMTime)time withBounds:(CMTime)bounds {
    CMTimeRange timeRange = track.timeRange;
    time = CMTimeAdd(time, timeRange.start);
    
    if (CMTIME_IS_VALID(bounds)) {
        CMTime currentBounds = CMTimeAdd(time, timeRange.duration);

        if (CMTIME_COMPARE_INLINE(currentBounds, >, bounds)) {
            timeRange = CMTimeRangeMake(timeRange.start, CMTimeSubtract(timeRange.duration, CMTimeSubtract(currentBounds, bounds)));
        }
    }
    
    if (CMTIME_COMPARE_INLINE(timeRange.duration, >, kCMTimeZero)) {
        NSError *error = nil;
        [compositionTrack insertTimeRange:timeRange ofTrack:track atTime:time error:&error];
        
        if (error != nil) {
            NSLog(@"Failed to insert append %@ track: %@", compositionTrack.mediaType, error);
        } else {
            //        NSLog(@"Inserted %@ at %fs (%fs -> %fs)", track.mediaType, CMTimeGetSeconds(time), CMTimeGetSeconds(timeRange.start), CMTimeGetSeconds(timeRange.duration));
        }
        
        return CMTimeAdd(time, timeRange.duration);
    }
    
    return time;
}

/// 本次片段录制完成，添加片段
/// @param url 录制文件的路径
/// @param error 导出错误
/// @param completionHandler 结束录制的回调
- (void)appendRecordSegmentUrl:(NSURL *)url error:(NSError *)error completionHandler:(void (^)(WVRRecordSessionSegment *, NSError *))completionHandler {
    WVRRecordSessionSegment *segment = nil;
    if (error == nil) {
        segment = [[WVRRecordSessionSegment alloc]initWithUrl:url];
        [self addSegment:segment];
    }
    
    [self _destroyAssetWriter];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (completionHandler != nil) {
            completionHandler(segment, error);
        }
    });
}

- (void)addSegment:(WVRRecordSessionSegment *)segment {
    [_segments addObject:segment];
    _segmentsDuration = CMTimeAdd(_segmentsDuration, segment.duration);
}

/// 删除所有片段
- (void)removeAllSegments {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    while (_segments.count > 0) {
        [fileManager removeItemAtPath:_segments.lastObject.url.path error:nil];
        [_segments removeLastObject];
    }
    _segmentsDuration = kCMTimeZero;
}

- (void)_destroyAssetWriter {
    _currentSegmentHasAudio = NO;
    _currentSegmentHasVideo = NO;
    _assetWriter = nil;
    _currentSegmentDuration = kCMTimeZero;
    _segmentStartTime = kCMTimeInvalid;
}

/// 启动写入会话
/// @param time 时间
- (void)_startSessionIfNeededAtTime:(CMTime)time {
    if (CMTIME_IS_INVALID(_segmentStartTime)) {
        _segmentStartTime = time;
        [_assetWriter startSessionAtSourceTime:time];
    }
}

CGAffineTransform WVRTransformForDeviceOrientation(UIDeviceOrientation orientation) {
    CGAffineTransform result;
    switch (orientation) {
            
        case UIDeviceOrientationLandscapeRight:
            result = CGAffineTransformMakeRotation(M_PI);
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            result = CGAffineTransformMakeRotation((M_PI_2 * 3));
            break;
            
        case UIDeviceOrientationPortrait:
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationFaceDown:
            result = CGAffineTransformMakeRotation(M_PI_2);
            break;
            
        default: // Default orientation of landscape left
            result = CGAffineTransformIdentity;
            break;
    }
    
    return result;
}

/// 视频输出目录
- (NSURL *)nextFileURL {
    NSString *dirPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"recodeVideos"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL existed = [fileManager fileExistsAtPath:dirPath isDirectory:&isDir];
    if (!(isDir == YES && existed == YES)) {
        [fileManager createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSString *filePath = [dirPath stringByAppendingPathComponent:[NSString stringWithFormat:@"WVRVideo.%d.%@",_currentSegmentCount,[self fileType]]];
    NSURL *url = [NSURL fileURLWithPath:filePath];
    if ([fileManager fileExistsAtPath:url.path]) {
        [fileManager removeItemAtURL:url error:nil];
    }
    _currentSegmentCount++;
    return url;
}

- (NSString *)fileType {
    AVFileType fileType = self.videoConfiguration.fileType;
    static NSDictionary *dic = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dic = @{AVFileTypeQuickTimeMovie:@"mov",
                                     AVFileTypeMPEG4:@"mp4",
                                     AVFileTypeAppleM4V:@"m4v",
                                     AVFileTypeAppleM4A:@"m4a",
                                     AVFileType3GPP:@"3gp",
                                     AVFileType3GPP2:@"3g2",
                                     AVFileTypeWAVE:@"wav"
        };
    });
    NSString *result = [dic objectForKey:fileType];
    return result.length > 0 ? result : @"mp4";
}

#pragma mark - getter and setter
@end
