//
//  WVRVideoRecorder.m
//  styf
//
//  Created by styf on 2021/7/15.
//  Copyright © 2021 styf. All rights reserved.
//

#import "WVRVideoRecorder.h"
#import <AVFoundation/AVFoundation.h>

static const NSString *WVRCameraAdjustingExposureContext;
static const NSString *WVRRampingVideoZoomContext;
static const NSString *WVRRampingVideoZoomFactorContext;

@interface WVRVideoRecorder()<AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate,CAAnimationDelegate>
/// 视频配置
@property (nonatomic, strong) WVRVideoConfiguration *videoConfiguration;
/// 音频配置
@property (nonatomic, strong) WVRAudioConfiguration *audioConfiguration;
/// 捕捉会话
@property (nonatomic, strong) AVCaptureSession *captureSession;
/// 当前活跃的设备输入
@property (nonatomic, weak) AVCaptureDeviceInput *activeVideoInput;
/// 视频数据输出(帧处理)
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
/// 音频数据输出
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioDataOutput;
/// 视频录制处理队列
@property (nonatomic, strong) dispatch_queue_t videoRecordQueue;
/// 预览图层
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;
/// 视频写入设置
@property (nonatomic, strong) NSDictionary *videoSettings;
/// 音频写入设置
@property (nonatomic, strong) NSDictionary *audioSettings;
/// 资源写入器
@property (nonatomic, strong) AVAssetWriter *assetWriter;
/// 视频写入
@property (nonatomic, strong) AVAssetWriterInput *assetWriterVideoInput;
/// 音频写入
@property (nonatomic, strong) AVAssetWriterInput *assetWriterAudioInput;
/// 是否正在录制并写入
@property (nonatomic, assign) BOOL isRecording;
/// 是否暂停过写入
@property (nonatomic, assign) BOOL isPauseWriting;
/// 开始录制的时间
@property (nonatomic, assign) CMTime startTime;
/// 上一次视频样本的时间
@property (nonatomic, assign) CMTime lastVideoTime;
/// 上一次音频样本的时间
@property (nonatomic, assign) CMTime lastAudioTime;
/// 累计的时间偏移  每次暂停都累加
@property (nonatomic, assign) CMTime timeOffset;
/// 当前录制时间
@property (nonatomic, assign) CGFloat currentRecordTime;
/// 录制完成的视频文件路径
@property (nonatomic, strong) NSURL *fileUrl;
@end

@implementation WVRVideoRecorder

#pragma mark - life cycle

- (nonnull instancetype)initWithVideoConfiguration:(WVRVideoConfiguration *_Nullable)videoConfiguration audioConfiguration:(WVRAudioConfiguration *_Nullable)audioConfiguration {
    self = [super init];
    if (self) {
        _videoConfiguration = videoConfiguration;
        _audioConfiguration = audioConfiguration;
        _videoRecordQueue = dispatch_queue_create("com.styf.videoRecordQueue", DISPATCH_QUEUE_SERIAL);
        _startTime = kCMTimeZero;
        _timeOffset = kCMTimeZero;
        _maxRecordTime = 15;
        [self commonInit];
    }
    return self;
}

- (void)dealloc {
    [self.captureSession stopRunning];
    _videoRecordQueue = nil;
    _assetWriterVideoInput = nil;
    _assetWriterAudioInput = nil;
    _assetWriter = nil;
    _videoDataOutput = nil;
    _audioDataOutput = nil;
    _captureSession = nil;
}

/// 初始化
- (void)commonInit {
    [self setupSession];
    [self setupVideoWrite];
    [self setupZoomObserver];
}

/// 初始化会话
- (void)setupSession {
    self.captureSession = [[AVCaptureSession alloc]init];
    self.captureSession.sessionPreset = self.videoConfiguration.sessionPreset;
    
    NSError *error;
    //设置默认相机设备
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];//默认后置
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    if (videoInput) {
        if ([self.captureSession canAddInput:videoInput]) {
            [self.captureSession addInput:videoInput];
            self.activeVideoInput = videoInput;
        }else {
            [self showSetupErrorMsg:@"相机设备异常" code:WVRErrorCaptureSession];
        }
    }else{
        [self showSetupErrorMsg:@"相机设备异常" code:WVRErrorCaptureSession];
    }
    
    //设置默认的麦克风设备
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
    if (audioInput) {
        if ([self.captureSession canAddInput:audioInput]) {
            [self.captureSession addInput:audioInput];
        }else {
            [self showSetupErrorMsg:@"麦克风设备异常" code:WVRErrorCaptureSession];
        }
    } else {
        [self showSetupErrorMsg:@"麦克风设备异常" code:WVRErrorCaptureSession];
    }
    
    //设置输出设备
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    self.videoDataOutput.alwaysDiscardsLateVideoFrames = NO;//捕捉全部的可用帧，会增加内存消耗
    self.videoDataOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};//适合OpenGL ES 和CoreImage
    [self.videoDataOutput setSampleBufferDelegate:self queue:self.videoRecordQueue];
    if ([self.captureSession canAddOutput:self.videoDataOutput]) {
        [self.captureSession addOutput:self.videoDataOutput];
    }
    
    self.audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    [self.audioDataOutput setSampleBufferDelegate:self queue:self.videoRecordQueue];
    if ([self.captureSession canAddOutput:self.audioDataOutput]) {
        [self.captureSession addOutput:self.audioDataOutput];
    }
}

/// 初始化视频写入相关
- (void)setupVideoWrite {
    NSString *fileType = self.videoConfiguration.fileType;
    _videoSettings = [self.videoDataOutput recommendedVideoSettingsForAssetWriterWithOutputFileType:fileType];
    _audioSettings = [self.audioDataOutput recommendedAudioSettingsForAssetWriterWithOutputFileType:fileType];
}

/// 缩放监听
- (void)setupZoomObserver {
#warning 测试
//    [self.activeCamera addObserver:self
//                        forKeyPath:@"videoZoomFactor"
//                           options:0
//                           context:&WVRRampingVideoZoomFactorContext];
//    [self.activeCamera addObserver:self
//                        forKeyPath:@"rampingVideoZoom"
//                           options:0
//                           context:&WVRRampingVideoZoomContext];
}

#pragma mark - overwrite

#pragma mark - request

#pragma mark - public

/// 开始音视频采集
- (void)startCaptureSession {
    NSAssert(self.videoSettings != nil, @"先初始化录制器！");
    if (self.previewView) {
        [self.previewView.layer addSublayer:self.videoPreviewLayer];
        self.videoPreviewLayer.frame = self.previewView.bounds;
    }
    if (![self.captureSession isRunning]) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(self.videoRecordQueue, ^{
            [weakSelf.captureSession startRunning];
        });
    }
}

/// 停止音视频采集
- (void)stopCaptureSession {
    if ([self.captureSession isRunning]) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(self.videoRecordQueue, ^{
            [weakSelf.captureSession stopRunning];
        });
    }
}

/// 开始录制视频
- (void)startRecording {
    NSAssert(self.videoSettings != nil, @"先初始化录制器！");
    NSAssert([self.captureSession isRunning], @"先开启音视频采集startCaptureSession！");
    [self startWriting];
}

/// 停止录制视频
- (void)stopRecording {
    _isRecording = NO;
    _isPauseWriting = YES;
}

/// 取消录制视频并删除已经录制的视频段
- (void)cancelRecording {
    [self reset];
    [self.assetWriter cancelWriting];
    _fileUrl = nil;
}

/// 重置
- (void)reset {
    _isRecording = NO;
    _startTime = kCMTimeZero;
    _timeOffset = kCMTimeZero;
    _currentRecordTime = 0;
}

/// 结束录制
- (void)finishRecording {
    _isRecording = NO;
    
    if (_fileUrl) {//已经有录制好的视频文件了
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoRecorder:didFinishRecordingToOutputFileAtURL:error:)]) {
            [self.delegate videoRecorder:self didFinishRecordingToOutputFileAtURL:_fileUrl error:nil];
        }
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [weakSelf.assetWriter finishWritingWithCompletionHandler:^{
            if (weakSelf.assetWriter.status == AVAssetWriterStatusCompleted) {//写入成功
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSURL *fileURL = [weakSelf.assetWriter outputURL];
                    weakSelf.fileUrl = fileURL;
                    if (weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(videoRecorder:didFinishRecordingToOutputFileAtURL:error:)]) {
                        [weakSelf.delegate videoRecorder:weakSelf didFinishRecordingToOutputFileAtURL:fileURL error:nil];
                    }
                });
            } else {
                NSLog(@"Failed to write movie: %@", self.assetWriter.error);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(videoRecorder:didFinishRecordingToOutputFileAtURL:error:)]) {
                        [weakSelf.delegate videoRecorder:weakSelf didFinishRecordingToOutputFileAtURL:nil error:self.assetWriter.error];
                    }
                });
            }
        }];
    });
}

/// 切换前后摄像头
- (void)toggleCamera {
    if ([[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count] > 1) {
        NSError *error;
        AVCaptureDevice *videoDevice = [self inactiveCamera];
        AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        if (videoInput) {
            [self.captureSession stopRunning];
            [self.captureSession beginConfiguration];
            [self.captureSession removeInput:self.activeVideoInput];
            if ([self.captureSession canAddInput:videoInput]) {
                [self changeCameraAnimation];
                [self.captureSession addInput:videoInput];
                self.activeVideoInput = videoInput;
            } else {
                [self changeCameraAnimation];
                [self.captureSession addInput:self.activeVideoInput];
            }
            [self.captureSession commitConfiguration];
        } else {
            [self showSetupErrorMsg:@"摄像头切换失败" code:WVRErrorToggleCamera];
        }
    }
}

#pragma mark - event response

#pragma mark - private

/// 开始写入视频
- (void)startWriting {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.videoRecordQueue, ^{
        if (weakSelf.assetWriter) {
            weakSelf.isRecording = YES;
            NSLog(@"开始写入------");
        }
    });
}

/// 正在使用的摄像头
- (AVCaptureDevice *)activeCamera {
    return self.activeVideoInput.device;
}

/// 视频输出目录
- (NSURL *)outputURL {
    NSString *dirPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"recodeVideos"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL existed = [fileManager fileExistsAtPath:dirPath isDirectory:&isDir];
    if (!(isDir == YES && existed == YES)) {
        [fileManager createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSString *filePath = [dirPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%.0f.%@",[[NSDate date]timeIntervalSince1970],[self fileType]]];
    NSURL *url = [NSURL fileURLWithPath:filePath];
    if ([fileManager fileExistsAtPath:url.path]) {
        [fileManager removeItemAtURL:url error:nil];
    }
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

/// 处理视频和音频样本
/// @param sampleBuffer 样本
- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (!self.isRecording) {
        return;//暂停录制中
    }
    if (self.currentRecordTime > self.maxRecordTime + 0.1) return;//虽然录制满了，但0.1以内，继续往下走，可以更新一下代理的进度
    
    BOOL isVideoSample = YES;
    
    @synchronized(self) {//防止-16364问题：-16364是样本时间戳有误引起的，修改样本的时间戳可能导致写入时时间冲突
        CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer);
        CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDesc);
        isVideoSample = mediaType == kCMMediaType_Video;//是否是视频样本
        
        // 如果是从暂停中恢复的第一帧，则计算暂停时间
        if (_isPauseWriting && isVideoSample) return;//防止-16364问题:取音频样本的时间戳作偏移计算
        [self calculateTimeOffsetIfNeededWithSample:sampleBuffer isVideoSample:isVideoSample];
        // 有时间偏移的就修正一下样本时间
        CFRetain(sampleBuffer);//⚠️注意
        //引起写入失败 Error Domain=AVFoundationErrorDomain Code=-11800 "The operation could not be completed" UserInfo={NSLocalizedFailureReason=An … unknown error occurred (-16364),
        if (_timeOffset.value > 0) {
            CFRelease(sampleBuffer);
            sampleBuffer = [self fixTimeOffsetWithSample:sampleBuffer];
        }
        
        // 记录本次样本时间
        [self recordSampleTimeWithSample:sampleBuffer isVideoSample:isVideoSample];
    }
    
    CMTime timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    // 首次样本时间
    if (self.startTime.value == 0) {
        self.startTime = timeStamp;
    }
    // 更新进度
    [self updateRecordProgress:timeStamp];
    if (self.currentRecordTime > self.maxRecordTime) return;//录制已达最大时长
    //样本帧写入文件
    [self writeSample:sampleBuffer isVideoSample:isVideoSample];
    CFRelease(sampleBuffer);
}

/// 写入样本
/// @param sampleBuffer 样本
/// @param isVideoSample 是否视频样本
- (void)writeSample:(CMSampleBufferRef) sampleBuffer isVideoSample:(BOOL)isVideoSample {
    //数据是否准备写入
    if (CMSampleBufferDataIsReady(sampleBuffer)) {
        
        //写入状态为未知,保证视频先写入
        if (_assetWriter.status == AVAssetWriterStatusUnknown && isVideoSample) {//如果是第一个视频样本，则启动一个新的写入会话
            if ([_assetWriter startWriting]) {
                //获取开始写入的CMTime
                CMTime startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                [_assetWriter startSessionAtSourceTime:startTime];
            }else {
                [self showSetupErrorMsg:@"视频写入失败" code:WVRErrorWriteVideo];
                NSLog(@"Failed to start writing.%@",_assetWriter.error);
            }
        }
        //写入失败
        if (_assetWriter.status == AVAssetWriterStatusFailed) {
            NSLog(@"writer error %@", _assetWriter.error);
            return;
        }
        if (isVideoSample) {
            if (self.assetWriterVideoInput.readyForMoreMediaData) {
                //完成了视频样本的处理
                if (![self.assetWriterVideoInput appendSampleBuffer:sampleBuffer]) {
                    NSLog(@"Error appending pixel buffer.%@",_assetWriter.error);
                }
            }
        }else {
            //处理音频样本
            if (self.assetWriterAudioInput.isReadyForMoreMediaData) {
                if (![self.assetWriterAudioInput appendSampleBuffer:sampleBuffer]) {
                    NSLog(@"Error appending audio sample buffer.%@",_assetWriter.error);
                }
            }
        }
    }
}

/// 更新录制进度
/// @param timeStamp 本次样本
- (void)updateRecordProgress:(CMTime)timeStamp {
    CMTime sub = CMTimeSubtract(timeStamp, self.startTime);
    CGFloat seconds = CMTimeGetSeconds(sub);
    if (self.currentRecordTime >= seconds)return;//个别情况下，新进度反而比旧进度小了
    self.currentRecordTime = seconds;
    if (self.currentRecordTime < self.maxRecordTime || self.currentRecordTime - self.maxRecordTime < 0.1) {
        if (_delegate && [_delegate respondsToSelector:@selector(videoRecorder:recordProgress:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate videoRecorder:self recordProgress:self.currentRecordTime / self.maxRecordTime];
            });
        }
    }
}

/// 记录本次样本时间
/// @param sampleBuffer 样本
/// @param isVideoSample 是否视频样本
- (void)recordSampleTimeWithSample:(CMSampleBufferRef)sampleBuffer isVideoSample:(BOOL)isVideoSample {
    CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    CMTime dur = CMSampleBufferGetDuration(sampleBuffer);
    if (dur.value > 0) {
        pts = CMTimeAdd(pts, dur);
    }
    if (isVideoSample) {
        _lastVideoTime = pts;
    }else {
        _lastAudioTime = pts;
    }
}

/// 有时间偏移的就修正一下样本时间
/// @param sampleBuffer 样本
- (CMSampleBufferRef)fixTimeOffsetWithSample:(CMSampleBufferRef)sampleBuffer  {
    CMItemCount count;
    CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, 0, nil, &count);
    CMSampleTimingInfo* pInfo = malloc(sizeof(CMSampleTimingInfo) * count);
    CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, count, pInfo, &count);
    for (CMItemCount i = 0; i < count; i++) {
        pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, _timeOffset);
        pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, _timeOffset);
    }
    CMSampleBufferRef sout;
    CMSampleBufferCreateCopyWithNewTiming(nil, sampleBuffer, count, pInfo, &sout);
    free(pInfo);
    return sout;
}

/// 如果是从暂停中恢复的第一帧，则计算暂停时间
/// @param sampleBuffer 样本
/// @param isVideoSample 是否视频样本
- (void)calculateTimeOffsetIfNeededWithSample:(CMSampleBufferRef)sampleBuffer isVideoSample:(BOOL)isVideoSample {
    if (_isPauseWriting) {//是否是从暂停恢复到录制 计算偏移时间
        _isPauseWriting = NO;
        CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        CMTime lastTimeStamp = isVideoSample ? _lastVideoTime : _lastAudioTime;
        if (lastTimeStamp.flags & kCMTimeFlags_Valid) {
            //之前已经暂停过了，已经存在偏移了，则减去
            if (_timeOffset.flags & kCMTimeFlags_Valid) {
                timestamp = CMTimeSubtract(timestamp, _timeOffset);
            }
            //本次产生的偏移 累加到之前的偏移上，之后的所有样本以这个总偏移为基础进行修正时间
            CMTime offset = CMTimeSubtract(timestamp, lastTimeStamp);
            if (_timeOffset.value == 0) {
                _timeOffset = offset;
            }else {
                _timeOffset = CMTimeAdd(_timeOffset, offset);
            }
        }
        _lastAudioTime.flags = 0;
        _lastVideoTime.flags = 0;
    }
}

/// 回调或显示默认错误信息
/// @param msg 错误信息
/// @param errorCode 错误码
- (void)showSetupErrorMsg:(NSString *)msg code:(WVRError)errorCode {
    if (_delegate && [_delegate respondsToSelector:@selector(videoRecorder:error:)]) {
        [_delegate videoRecorder:self error:errorCode];
    }else {
        [FancyToast showSad:msg];
    }
}

/// 获取前置或后置摄像头
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}
/// 当前没在使用的摄像头
- (AVCaptureDevice *)inactiveCamera {
    AVCaptureDevice *device = nil;
    if ([[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count] > 1) {
        if ([self activeCamera].position == AVCaptureDevicePositionBack) {
            device = [self cameraWithPosition:AVCaptureDevicePositionFront];
        } else {
            device = [self cameraWithPosition:AVCaptureDevicePositionBack];
        }
    }
    return device;
}

- (void)changeCameraAnimation {
    CATransition *changeAnimation = [CATransition animation];
    changeAnimation.delegate = self;
    changeAnimation.duration = 0.45;
    changeAnimation.type = @"oglFlip";
    changeAnimation.subtype = kCATransitionFromRight;
    changeAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.videoPreviewLayer addAnimation:changeAnimation forKey:@"changeAnimation"];
}

#pragma mark - CAAnimationDelegate

- (void)animationDidStart:(CAAnimation *)anim {
    [self.captureSession startRunning];
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate & AVCaptureAudioDataOutputSampleBufferDelegate

/// 每当有一个新的视频帧写入时该方法会被调用
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    ///写入文件
    [self processSampleBuffer:sampleBuffer];
}

/// 在上一个方法中，消耗了太多处理时间，迟到的帧会在这个方法丢弃
//- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
//
//}

#pragma mark - getter and setter

- (AVCaptureVideoPreviewLayer *)videoPreviewLayer {
    if (!_videoPreviewLayer) {
        _videoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
        [_videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    }
    return _videoPreviewLayer;
}

- (AVAssetWriter *)assetWriter {
    if (!_assetWriter) {
        NSError *error = nil;
        _assetWriter = [AVAssetWriter assetWriterWithURL:[self outputURL] fileType:self.videoConfiguration.fileType error:&error];
        if (error) {
            NSString *formatString = @"Could not create AVAssetWriter: %@";
            NSLog(@"%@", [NSString stringWithFormat:formatString, error]);
            [self showSetupErrorMsg:@"视频创建写入失败" code:WVRErrorCaptureSession];
        }else {
            if ([_assetWriter canAddInput:self.assetWriterVideoInput]) {
                [_assetWriter addInput:self.assetWriterVideoInput];
            } else {
                NSLog(@"Unable to add video input.");
                [self showSetupErrorMsg:@"视频创建写入失败" code:WVRErrorCaptureSession];
            }
            
            if ([_assetWriter canAddInput:self.assetWriterAudioInput]) {
                [_assetWriter addInput:self.assetWriterAudioInput];
            } else {
                NSLog(@"Unable to add audio input.");
                [self showSetupErrorMsg:@"视频创建写入失败" code:WVRErrorCaptureSession];
            }
        }
    }
    return _assetWriter;
}

- (AVAssetWriterInput *)assetWriterVideoInput {
    if (!_assetWriterVideoInput) {
        //可以在推荐配置的基础上，加上其他的配置，例如
//        NSDictionary* settings = [NSDictionary dictionaryWithObjectsAndKeys:
//                                  AVVideoCodecH264, AVVideoCodecKey,
//                                  [NSNumber numberWithInteger: cx], AVVideoWidthKey,
//                                  [NSNumber numberWithInteger: cy], AVVideoHeightKey,
//                                  nil];
        _assetWriterVideoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo
                                                                outputSettings:self.videoSettings];
        _assetWriterVideoInput.expectsMediaDataInRealTime = YES;//这个输入要针对实时性进行优化
        UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
        _assetWriterVideoInput.transform = WVRTransformForDeviceOrientation(orientation);
    }
    return _assetWriterVideoInput;
}

- (AVAssetWriterInput *)assetWriterAudioInput {
    if (!_assetWriterAudioInput) {
        //可以在推荐配置的基础上，加上其他的配置，例如
//        CMFormatDescriptionRef fmt = CMSampleBufferGetFormatDescription(sampleBuffer);
//        const AudioStreamBasicDescription *asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmt);
//        sampleRate = asbd->mSampleRate;
//        channels = asbd->mChannelsPerFrame;
//        NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:
//                                  [ NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
//                                  [ NSNumber numberWithInt: channels], AVNumberOfChannelsKey,
//                                  [ NSNumber numberWithFloat: sampleRate], AVSampleRateKey,
//                                  [ NSNumber numberWithInt: 128000], AVEncoderBitRateKey,
//                                  nil];
        _assetWriterAudioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:self.audioSettings];
        _assetWriterAudioInput.expectsMediaDataInRealTime = YES;
    }
    return _assetWriterAudioInput;
}

@end
