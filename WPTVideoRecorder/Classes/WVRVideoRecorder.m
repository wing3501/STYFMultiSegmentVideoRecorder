//
//  WVRVideoRecorder.m
//  styf
//
//  Created by styf on 2021/7/15.
//  Copyright © 2021 styf. All rights reserved.
//

#import "WVRVideoRecorder.h"
#import <AVFoundation/AVFoundation.h>
#import "WVRVideoRecordSession.h"
#import "WVRSampleBufferHolder.h"

static const NSString *WVRCameraAdjustingExposureContext;
static const NSString *WVRRampingVideoZoomContext;
static const NSString *WVRRampingVideoZoomFactorContext;

@interface WVRVideoRecorder()<AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate>
/// 视频配置
@property (nonatomic, strong) WVRVideoConfiguration *videoConfiguration;
/// 音频配置
@property (nonatomic, strong) WVRAudioConfiguration *audioConfiguration;
/// 捕捉会话
@property (nonatomic, strong) AVCaptureSession *captureSession;
/// 当前活跃的设备输入
@property (nonatomic, weak) AVCaptureDeviceInput *activeCaptureDeviceInput;
/// 视频数据输出(帧处理)
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
/// 音频数据输出
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioDataOutput;
/// 视频方向
@property (nonatomic, assign) AVCaptureVideoOrientation videoOrientation;
/// 视频录制处理队列
@property (nonatomic, strong) dispatch_queue_t videoRecordQueue;
/// 预览图层
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;
/// 录制会话
@property (nonatomic, strong) WVRVideoRecordSession *recordSession;
/// 上一个音频样本
@property (nonatomic, strong) WVRSampleBufferHolder *lastAudioBuffer;
/// 是否正在录制并写入
@property (nonatomic, assign) BOOL isRecording;

@end

@implementation WVRVideoRecorder

#pragma mark - life cycle

- (nonnull instancetype)initWithVideoConfiguration:(WVRVideoConfiguration *_Nullable)videoConfiguration audioConfiguration:(WVRAudioConfiguration *_Nullable)audioConfiguration {
    self = [super init];
    if (self) {
        _videoConfiguration = videoConfiguration;
        _audioConfiguration = audioConfiguration;
        _videoRecordQueue = dispatch_queue_create("com.styf.videoRecordQueue", DISPATCH_QUEUE_SERIAL);
        _lastAudioBuffer = [WVRSampleBufferHolder new];
        _maxRecordTime = 15;
        _previewMirrorFrontFacing = YES;
        _videoOrientation = AVCaptureVideoOrientationPortrait;
        _recordSession = [[WVRVideoRecordSession alloc]initWithVideoConfiguration:videoConfiguration audioConfiguration:audioConfiguration];
        [self commonInit];
    }
    return self;
}

- (void)dealloc {
    [self.captureSession stopRunning];
    _videoRecordQueue = nil;
    _videoDataOutput = nil;
    _audioDataOutput = nil;
    _captureSession = nil;
}

/// 初始化
- (void)commonInit {
    [self setupSession];
    
}

/// 初始化会话
- (void)setupSession {
    self.captureSession = [[AVCaptureSession alloc]init];
    self.captureSession.sessionPreset = self.videoConfiguration.sessionPreset;
    
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
    
    NSError *error;
    //设置默认相机设备
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];//默认后置
    [self configureVideoDevice:videoDevice];
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    
    if (videoInput) {
        if ([self.captureSession canAddInput:videoInput]) {
            [self.captureSession addInput:videoInput];
            self.activeCaptureDeviceInput = videoInput;
            [self configureVideoDeviceInput:videoInput];
            [self updateVideoOrientation];
        }else {
            [self showErrorMsg:@"相机设备异常" code:WVRErrorCaptureSession];
        }
    }else{
        [self showErrorMsg:@"相机设备异常" code:WVRErrorCaptureSession];
    }
    
    //设置默认的麦克风设备
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
    if (audioInput) {
        if ([self.captureSession canAddInput:audioInput]) {
            [self.captureSession addInput:audioInput];
        }else {
            [self showErrorMsg:@"麦克风设备异常" code:WVRErrorCaptureSession];
        }
    } else {
        [self showErrorMsg:@"麦克风设备异常" code:WVRErrorCaptureSession];
    }
}

#pragma mark - overwrite

#pragma mark - request

#pragma mark - public

/// 开始音视频采集
- (void)startCaptureSession {
    NSAssert(self.recordSession != nil, @"先初始化录制器！");
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
    NSAssert(self.recordSession != nil, @"先初始化录制器！");
    NSAssert([self.captureSession isRunning], @"先开启音视频采集startCaptureSession！");
    _isRecording = YES;
}

/// 停止录制视频,并生成当前录制片段文件
/// @param completionHandler 生成完毕回调
- (void)stopRecording:(void(^__nullable)(void))completionHandler {
    _isRecording = NO;
    WVRVideoRecordSession *recordSession = self.recordSession;
    if (recordSession != nil) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(_videoRecordQueue, ^{
            if (recordSession.recordSegmentReady) {
                [recordSession endSegmentWithCompletionHandler:^(WVRRecordSessionSegment * _Nonnull segment, NSError * _Nonnull error) {
                    if (weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(videoRecorder:didFinishRecordingToOutputFileAtURL:error:)]) {
                        [weakSelf.delegate videoRecorder:weakSelf didFinishRecordingToOutputFileAtURL:segment.url error:nil];
                    }
                    !completionHandler ?: completionHandler();
                }];
            } else {
                dispatch_async(dispatch_get_main_queue(),completionHandler);
            }
        });
    } else {
        dispatch_async(dispatch_get_main_queue(),completionHandler);
    }
}

/// 取消录制视频并删除已经录制的视频段
/// @param completionHandler 回调
- (void)cancelRecording:(void (^__nullable)(void))completionHandler {
    _isRecording = NO;
    __weak typeof(self) weakSelf = self;
    dispatch_async(_videoRecordQueue, ^{
        [weakSelf.recordSession cancelSession:completionHandler];
    });
}

- (CGFloat)currentRecordTime {
    return CMTimeGetSeconds(self.recordSession.duration);
}

/// 获取代表当前会话的所有视频段文件的 asset
- (AVAsset *)assetRepresentingAllFiles {
    return self.recordSession.assetRepresentingAllFiles;
}

/// 切换前后摄像头
- (void)toggleCamera {
    if ([[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count] > 1) {
        NSError *error;
        AVCaptureDevice *videoDevice = [self inactiveCamera];
        [self configureVideoDevice:videoDevice];
        AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        if (videoInput) {
            [self.captureSession beginConfiguration];
            [self.captureSession removeInput:self.activeCaptureDeviceInput];
            if ([self.captureSession canAddInput:videoInput]) {
                [self.captureSession addInput:videoInput];
                self.activeCaptureDeviceInput = videoInput;
                [self configureVideoDeviceInput:videoInput];
                [self updateVideoOrientation];
            } else {
                [self.captureSession addInput:self.activeCaptureDeviceInput];
            }
            [self.captureSession commitConfiguration];
        } else {
            [self showErrorMsg:@"摄像头切换失败" code:WVRErrorToggleCamera];
        }
    }
}

#pragma mark - event response

#pragma mark - private

- (void)updateVideoOrientation {
    AVCaptureVideoOrientation videoOrientation = _videoOrientation;
    AVCaptureConnection *videoConnection = [_videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    
    if ([videoConnection isVideoOrientationSupported]) {
        videoConnection.videoOrientation = videoOrientation;
    }
    if ([self.videoPreviewLayer.connection isVideoOrientationSupported]) {
        self.videoPreviewLayer.connection.videoOrientation = videoOrientation;
    }
}

- (void)configureVideoDevice:(AVCaptureDevice *)videoDevice {
    NSError *error;
    if ([videoDevice lockForConfiguration:&error]) {
        if (videoDevice.isSmoothAutoFocusSupported) {
            videoDevice.smoothAutoFocusEnabled = YES;
        }
        videoDevice.subjectAreaChangeMonitoringEnabled = true;
        
        if (videoDevice.isLowLightBoostSupported) {
            videoDevice.automaticallyEnablesLowLightBoostWhenAvailable = YES;
        }
        [videoDevice unlockForConfiguration];
    } else {
        NSLog(@"Failed to configure device: %@", error);
    }
}

- (void)configureVideoDeviceInput:(AVCaptureDeviceInput *)videoInput {
    [self _configureVideoStabilization];
    [self _configureFrontCameraMirroring:_previewMirrorFrontFacing && videoInput.device.position == AVCaptureDevicePositionFront];
}

/// 平滑稳定设置
- (void)_configureVideoStabilization {
    AVCaptureConnection *videoConnection = [self videoConnection];
    if ([videoConnection isVideoStabilizationSupported]) {//是否支持视频稳定功能，可以显著提高视频质量
        if ([videoConnection respondsToSelector:@selector(setPreferredVideoStabilizationMode:)]) {
            videoConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
        }
    }
}
/// 前置摄像头的镜像设置
- (void)_configureFrontCameraMirroring:(BOOL)videoMirrored {
    AVCaptureConnection *videoConnection = [self videoConnection];
    if ([videoConnection isVideoMirroringSupported]) {
        if ([videoConnection respondsToSelector:@selector(setVideoMirrored:)]) {
            videoConnection.videoMirrored = videoMirrored;
        }
    }
}

- (AVCaptureConnection*)videoConnection {
    for (AVCaptureConnection * connection in _videoDataOutput.connections) {
        for (AVCaptureInputPort * port in connection.inputPorts) {
            if ([port.mediaType isEqual:AVMediaTypeVideo]) {
                return connection;
            }
        }
    }
    return nil;
}

/// 正在使用的摄像头
- (AVCaptureDevice *)activeCamera {
    return self.activeCaptureDeviceInput.device;
}

/// 更新录制进度
- (void)updateRecordProgress {
    CGFloat seconds = CMTimeGetSeconds(self.recordSession.duration);
//    if (self.currentRecordTime >= seconds)return;//个别情况下，新进度反而比旧进度小了
    if (seconds < self.maxRecordTime || seconds - self.maxRecordTime < 0.1) {
        _recordProgress = self.currentRecordTime / self.maxRecordTime;
        if (_delegate && [_delegate respondsToSelector:@selector(videoRecorder:recordProgress:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate videoRecorder:self recordProgress:self.recordProgress];
            });
        }
    }
}

/// 回调或显示默认错误信息
/// @param msg 错误信息
/// @param errorCode 错误码
- (void)showErrorMsg:(NSString *)msg code:(WVRError)errorCode {
    if (_delegate && [_delegate respondsToSelector:@selector(videoRecorder:error:)]) {
        [_delegate videoRecorder:self error:errorCode];
    }else {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        }]];
        [[UIApplication sharedApplication].keyWindow.rootViewController  presentViewController:alertController animated:YES completion:nil];
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
    
/// 处理视频样本
/// @param sampleBuffer 样本
- (void)_handleVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    WVRVideoRecordSession *recordSession = self.recordSession;
    if (!recordSession.videoInitialized) {
        NSString *fileType = self.videoConfiguration.fileType;
        NSDictionary *videoSettings = [self.videoDataOutput recommendedVideoSettingsForAssetWriterWithOutputFileType:fileType];
        [recordSession initializeVideo:videoSettings];
    }
    if (recordSession.audioInitialized) {
        [self beginRecordSegmentIfNeeded];
        
        if (recordSession.recordSegmentReady) {
            BOOL isFirstVideoBuffer = !recordSession.currentSegmentHasVideo;
            BOOL success = [recordSession writeSample:sampleBuffer isVideoSample:YES];
            if (success) {
                //更新进度
                [self updateRecordProgress];
                //检查是否录制满时间
                [self checkRecordSessionDuration:recordSession];
            }
            if (isFirstVideoBuffer && !recordSession.currentSegmentHasAudio) {
                CMSampleBufferRef audioBuffer = _lastAudioBuffer.sampleBuffer;
                if (audioBuffer != nil) {
                    CMTime lastAudioEndTime = CMTimeAdd(CMSampleBufferGetPresentationTimeStamp(audioBuffer), CMSampleBufferGetDuration(audioBuffer));
                    CMTime videoStartTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                    // If the end time of the last audio buffer is after this video buffer, we need to re-use it,
                    // since it was skipped on the last cycle to wait until the video becomes ready.
                    if (CMTIME_COMPARE_INLINE(lastAudioEndTime, >, videoStartTime)) {
                        [self _handleAudioSampleBuffer:audioBuffer];
                    }
                }
            }
        }
    }
}

/// 处理音频样本
/// @param sampleBuffer 样本
- (void)_handleAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    WVRVideoRecordSession *recordSession = self.recordSession;
    if (!recordSession.audioInitialized) {
        NSString *fileType = self.videoConfiguration.fileType;
        NSDictionary *audioSettings = [self.audioDataOutput recommendedAudioSettingsForAssetWriterWithOutputFileType:fileType];
        [recordSession initializeAudio:audioSettings];
    }
    if (recordSession.videoInitialized) {
        [self beginRecordSegmentIfNeeded];
        if (recordSession.recordSegmentReady) {
            BOOL success = [recordSession writeSample:sampleBuffer isVideoSample:NO];
            if (success) {
                //更新进度
                [self updateRecordProgress];
                //检查是否录制满时间
                [self checkRecordSessionDuration:recordSession];
            }
        }
    }
}
    
///  有必要的话，开始片段录制（新建writer）
- (void)beginRecordSegmentIfNeeded {
    if (!self.recordSession.recordSegmentBegan) {
        NSError *error = nil;
        [self.recordSession beginSegment:&error];
        if (error) [self showErrorMsg:@"视频写入创建失败" code:WVRErrorWirteSession];
    }
}

/// 检查是否录制满时间，时间满了就结束本次片段录制
/// @param recordSession 录制会话
- (void)checkRecordSessionDuration:(WVRVideoRecordSession *)recordSession {
    double currentRecordDuration = CMTimeGetSeconds(recordSession.duration);
    
    if (currentRecordDuration >= _maxRecordTime) {
        _isRecording = NO;
        dispatch_async(_videoRecordQueue, ^{
            [recordSession endSegmentWithCompletionHandler:^(WVRRecordSessionSegment * _Nonnull segment, NSError * _Nonnull error) {
                if (self.delegate && [self.delegate respondsToSelector:@selector(videoRecorder:didFinishRecordingToOutputFileAtURL:error:)]) {
                    [self.delegate videoRecorder:self didFinishRecordingToOutputFileAtURL:segment.url error:nil];
                }
            }];
        });
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate & AVCaptureAudioDataOutputSampleBufferDelegate

/// 每当有一个新的视频帧写入时该方法会被调用
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (!_isRecording) {
        return;
    }
    if (output == _videoDataOutput) {
        [self _handleVideoSampleBuffer:sampleBuffer];
    }else {
        _lastAudioBuffer.sampleBuffer = sampleBuffer;
        [self _handleAudioSampleBuffer:sampleBuffer];
    }
}

/// 在上一个方法中，消耗了太多处理时间，迟到的帧会在这个方法丢弃
//- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
//
//}

#pragma mark - Zoom

/// 当前摄像头是否支持缩放
- (BOOL)cameraSupportsZoom {
    return self.activeCamera.activeFormat.videoMaxZoomFactor > 1.0f;
}
/// 最大的缩放因子
- (CGFloat)maxZoomFactor {
    return self.activeCamera.activeFormat.videoMaxZoomFactor;
}

/// 设置缩放
/// @param videoZoomFactor 缩放因子
- (void)setVideoZoomFactor:(CGFloat)videoZoomFactor {
    if (!self.activeCamera.isRampingVideoZoom) {
        NSError *error;
        if ([self.activeCamera lockForConfiguration:&error]) {
            self.activeCamera.videoZoomFactor = videoZoomFactor;
            [self.activeCamera unlockForConfiguration];
        } else {
            [self showErrorMsg:@"缩放失败" code:WVRErrorZoom];
        }
    }
}

#pragma mark - exposure & focus
/// 是否支持曝光
- (BOOL)exposureSupported {
    return self.activeCamera.isExposurePointOfInterestSupported;
}
/// 是否支持聚焦
- (BOOL)focusSupported {
    return self.activeCamera.isFocusPointOfInterestSupported;
}

- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates {
    return [self.videoPreviewLayer captureDevicePointOfInterestForPoint:viewCoordinates];
}

/// 聚焦一个点
/// @param point 位置
- (void)autoFocusAtPoint:(CGPoint)point {
    [self _applyPointOfInterest:point continuousMode:NO];
}


/// 自动聚焦一个点
/// @param point 位置
- (void)continuousFocusAtPoint:(CGPoint)point {
    [self _applyPointOfInterest:point continuousMode:YES];
}

- (void)_applyPointOfInterest:(CGPoint)point continuousMode:(BOOL)continuousMode {
    AVCaptureDevice *device = self.activeCamera;
    AVCaptureFocusMode focusMode = continuousMode ? AVCaptureFocusModeContinuousAutoFocus : AVCaptureFocusModeAutoFocus;
    AVCaptureExposureMode exposureMode = continuousMode ? AVCaptureExposureModeContinuousAutoExposure : AVCaptureExposureModeAutoExpose;
    AVCaptureWhiteBalanceMode whiteBalanceMode = continuousMode ? AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance : AVCaptureWhiteBalanceModeAutoWhiteBalance;
    
    NSError *error;
    if ([device lockForConfiguration:&error]) {
        if (device.isFocusPointOfInterestSupported) {
            device.focusPointOfInterest = point;
        }
        if ([device isFocusModeSupported:focusMode]) {
            device.focusMode = focusMode;
        }
        if (device.isExposurePointOfInterestSupported) {
            device.exposurePointOfInterest = point;
        }
        if ([device isExposureModeSupported:exposureMode]) {
            device.exposureMode = exposureMode;
        }
        if ([device isWhiteBalanceModeSupported:whiteBalanceMode]) {
            device.whiteBalanceMode = whiteBalanceMode;
        }
        device.subjectAreaChangeMonitoringEnabled = !continuousMode;
        [device unlockForConfiguration];
    }
}

#pragma mark - getter and setter

- (AVCaptureVideoPreviewLayer *)videoPreviewLayer {
    if (!_videoPreviewLayer) {
        _videoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
        [_videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    }
    return _videoPreviewLayer;
}

@end
