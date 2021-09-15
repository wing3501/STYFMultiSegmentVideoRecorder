//
//  WPTViewController.m
//  WPTVideoRecorder
//
//  Created by styf on 07/22/2021.
//  Copyright (c) 2021 styf. All rights reserved.
//

#import "WPTViewController.h"
#import "WVRVideoRecorder.h"
#import <Masonry/Masonry.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

static CGFloat const kMinRecordTime = 3;

@interface WPTViewController ()<WVRVideoRecorderDelegate>
/// 短视频录制
@property (nonatomic, strong) WVRVideoRecorder *videoRecorder;
/// 拍摄预览图层
@property (nonatomic, strong) UIView *cameraLayerBackgroundView;
/// 切换摄像头按钮
@property (nonatomic, strong) UIButton *switchCameraButton;
/// 录制按钮
@property (nonatomic, strong) UIButton *recordButton;
/// 重拍按钮
@property (nonatomic, strong) UIButton *reShootButton;
/// 重拍文本
@property (nonatomic, strong) UILabel *reShootLabel;
/// 下一步按钮
@property (nonatomic, strong) UIButton *nextStepButton;
/// 下一步文本
@property (nonatomic, strong) UILabel *nextStepLabel;
/// 红点
@property (nonatomic, strong) UIView *redView;
/// 录制时间
@property (nonatomic, strong) UILabel *recordTimeLabel;
/// 底部视图
@property (nonatomic, strong) UIView *bottomView;
/// 进度动画
@property (nonatomic, strong) CAShapeLayer *shapeLayer;
/// 聚焦、曝光手势
@property (nonatomic, strong) UITapGestureRecognizer *tapToFocusGesture;
/// 双击聚焦、曝光手势
@property (nonatomic, strong) UITapGestureRecognizer *doubleTapToResetFocusGesture;
/// 缩放手势
@property (nonatomic, strong) UIPinchGestureRecognizer *zoomGestureRecognizer;
/// 上一次的缩放比例
@property (nonatomic, assign) CGFloat lastZoomScale;
/// 临时判断缩放比例的view
@property (nonatomic, strong) UIView *zoomTempView;
/// 聚焦图
@property (nonatomic, strong) UIImageView *focusView;

@end

@implementation WPTViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self commonInit];
}

- (void)dealloc {
    self.videoRecorder.delegate = nil;
    self.videoRecorder = nil;
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.videoRecorder startCaptureSession];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.videoRecorder stopCaptureSession];
}

/**
 初始化
 */
- (void)commonInit {
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    //初始化界面
    [self resetUIAndTranscribe];
    [self setupUI];
    [self autoLayout];
    [self setupShortVideoRecorder];
}

/**
 设置视图
 */
- (void)setupUI {
    [self.view addSubview:self.cameraLayerBackgroundView];
    [self.view addSubview:self.switchCameraButton];
    [self.view addSubview:self.bottomView];
    
    [self.bottomView addSubview:self.recordButton];
    [self.recordButton.layer addSublayer:self.shapeLayer];
    [self.bottomView addSubview:self.reShootButton];
    [self.bottomView addSubview:self.nextStepButton];
    [self.bottomView addSubview:self.reShootLabel];
    [self.bottomView addSubview:self.nextStepLabel];
    [self.bottomView addSubview:self.redView];
    [self.bottomView addSubview:self.recordTimeLabel];
}

- (void)autoLayout {
    
    [self.cameraLayerBackgroundView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(self.view);
    }];
    
    [self.switchCameraButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.mas_equalTo(self.view).offset(-15);
        make.top.mas_equalTo(self.view).offset(50);
    }];
    
    [self.bottomView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.bottom.right.mas_equalTo(self.view);
        make.height.mas_equalTo(200);
    }];
    
    [self.recordButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.bottomView).offset(20);
        make.centerX.mas_equalTo(self.bottomView);
    }];
    
    [self.reShootButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.mas_equalTo(self.recordButton);
        make.left.mas_equalTo(self.view).offset(50);
    }];
    
    [self.nextStepButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.mas_equalTo(self.recordButton);
        make.right.mas_equalTo(self.view).offset(-50);
    }];
    
    [self.reShootLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(self.reShootButton);
        make.top.mas_equalTo(self.reShootButton.mas_bottom).offset(4);
    }];
    
    [self.nextStepLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(self.nextStepButton);
        make.top.mas_equalTo(self.nextStepButton.mas_bottom).offset(4);
    }];
    
    [self.recordTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(self.recordButton);
        make.bottom.mas_equalTo(self.bottomView).offset(-36);
    }];
    
    [self.redView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.mas_equalTo(5);
        make.right.mas_equalTo(self.recordTimeLabel.mas_left).offset(-10);
        make.centerY.mas_equalTo(self.recordTimeLabel);
    }];
}

- (void)setupShortVideoRecorder {
    WVRVideoConfiguration *videoConfiguration = [WVRVideoConfiguration defaultConfiguration];
    WVRAudioConfiguration *audioConfiguration = [WVRAudioConfiguration defaultConfiguration];
    _videoRecorder = [[WVRVideoRecorder alloc]initWithVideoConfiguration:videoConfiguration audioConfiguration:audioConfiguration];
    _videoRecorder.maxRecordTime = 15;
    _videoRecorder.delegate = self;
    _videoRecorder.previewView = [[UIView alloc]initWithFrame:[UIScreen mainScreen].bounds];
    [self.cameraLayerBackgroundView addSubview:self.videoRecorder.previewView];
    [self addZoomGesture];  //添加缩放
    [self addFocusExposure];//添加聚焦曝光手势
}

/**
 初始化界面和录制状态
 */
- (void)resetUIAndTranscribe {
    //进度重置
    [self setupProgress:0];
    
    //重置下一步按钮
    self.nextStepButton.enabled = NO;
    [self setupUIStyle:NO];
    _recordTimeLabel.text = @"0.0秒";
    
    //重置录制按钮
    self.recordButton.hidden = NO;
    self.recordButton.selected = NO;
    
    //重置缩放
    self.videoRecorder.videoZoomFactor = 1;
    [self resetZoomGesture];
}

/**
 设置进度

 @param progress 进度
 */
- (void)setupProgress:(float)progress {
    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:[self layerCenter:self.shapeLayer] radius:[self layerCenter:self.shapeLayer].x - 6 startAngle:-M_PI_2 endAngle:-M_PI_2 + M_PI * 2 * progress clockwise:YES];
    self.shapeLayer.path = path.CGPath;
}

- (CGPoint)layerCenter:(CALayer *)layer {
    return CGPointMake(layer.frame.origin.x + layer.frame.size.width * 0.5,
                       layer.frame.origin.y + layer.frame.size.height * 0.5);
}

/**
 设置UI样式

 @param recording 是否正在录制
 */
- (void)setupUIStyle:(BOOL)recording {
    self.reShootButton.hidden = !recording;
    self.nextStepButton.hidden = !recording;
    self.nextStepLabel.hidden = !recording;
    self.reShootLabel.hidden = !recording;
    self.recordTimeLabel.hidden = !recording;
    self.redView.hidden = !recording;
    self.bottomView.backgroundColor = recording ? [UIColor clearColor] : [[UIColor blackColor]colorWithAlphaComponent:0.5];
}

/// 添加聚焦曝光手势
- (void)addFocusExposure {
    _tapToFocusGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapToAutoFocus:)];
    [self.cameraLayerBackgroundView addGestureRecognizer:_tapToFocusGesture];
    
    _doubleTapToResetFocusGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapToContinouslyAutoFocus:)];
    _doubleTapToResetFocusGesture.numberOfTapsRequired = 2;
    [_tapToFocusGesture requireGestureRecognizerToFail:_doubleTapToResetFocusGesture];
    [self.cameraLayerBackgroundView addGestureRecognizer:_doubleTapToResetFocusGesture];
}

// Auto focus at a particular point. The focus mode will change to locked once the auto focus happens.
- (void)tapToAutoFocus:(UIGestureRecognizer *)gestureRecognizer {
    CGPoint tapPoint = [gestureRecognizer locationInView:self.cameraLayerBackgroundView];
    CGPoint convertedFocusPoint = [self.videoRecorder convertToPointOfInterestFromViewCoordinates:tapPoint];
    [self.videoRecorder autoFocusAtPoint:convertedFocusPoint];
    [self focusAnimateAtPoint:tapPoint];
}

- (void)focusAnimateAtPoint:(CGPoint)location {
    [self.focusView.layer removeAllAnimations];
    self.focusView.center = location;
    self.focusView.transform = CGAffineTransformMakeScale(1.3, 1.3);
    self.focusView.alpha = 1.0;
    [UIView animateWithDuration:0.3 animations:^{
        self.focusView.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        if (finished){
            self.focusView.alpha=0;
        }
    }];
}

// Change to continuous auto focus. The camera will constantly focus at the point choosen.
- (void)tapToContinouslyAutoFocus:(UIGestureRecognizer *)gestureRecognizer {
    if (self.videoRecorder.focusSupported) {
        [self.videoRecorder continuousFocusAtPoint:CGPointMake(.5f, .5f)];
    }
}

/**
 添加缩放手势
 */
- (void)addZoomGesture {
    //镜头拉远、缩放
    [self.cameraLayerBackgroundView addGestureRecognizer:self.zoomGestureRecognizer];
}

/**
 重设缩放手势
 */
- (void)resetZoomGesture {
    [self.cameraLayerBackgroundView removeGestureRecognizer:self.zoomGestureRecognizer];
    [self.zoomTempView removeFromSuperview];
    [self.zoomTempView.layer removeFromSuperlayer];
    self.zoomTempView = nil;
    [self addZoomGesture];
}

/**
 缩放手势

 */
-(void)zoomPinches:(UIPinchGestureRecognizer *)gestureRecognizer {
    if([gestureRecognizer state] == UIGestureRecognizerStateBegan) {
        // Reset the last scale, necessary if there are multiple objects with different scales
        self.lastZoomScale = [gestureRecognizer scale];
    }

    if ([gestureRecognizer state] == UIGestureRecognizerStateBegan ||
        [gestureRecognizer state] == UIGestureRecognizerStateChanged) {

        CGFloat cameraZoomScale = [[self.zoomTempView.layer valueForKeyPath:@"transform.scale"] floatValue];

        self.videoRecorder.videoZoomFactor = cameraZoomScale;

        CGFloat newScale = 1 -  (self.lastZoomScale - [gestureRecognizer scale]);
        newScale = MIN(newScale, 5 / cameraZoomScale);//最大缩放为5
        newScale = MAX(newScale, 1 / cameraZoomScale);

        CGAffineTransform transform = CGAffineTransformScale([self.zoomTempView transform], newScale, newScale);
        self.zoomTempView.transform = transform;

        self.lastZoomScale = [gestureRecognizer scale];  // Store the previous scale factor for the next pinch gesture call
    }
}

/**
 切换摄像头
 */
- (void)switchCameraButtonClick:(UIButton *)button {
    button.enabled = NO;
    [self.videoRecorder toggleCamera];
    [self resetZoomGesture];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        button.enabled = YES;
    });
}

/**
 录制按钮点击
 */
- (void)recordBtnclick:(UIButton *)sender {
    
    if (self.videoRecorder.isRecording) {
        //录制中-->暂停
        [self pauseTranscribe];
        
        if (self.videoRecorder.currentRecordTime < kMinRecordTime) {
            NSLog(@"最少拍摄3秒");
        }
    }else{
        //开始录制
        NSLog(@"开始录制");
        self.recordButton.selected = YES;
        [self.videoRecorder startRecording];
    }
}

//暂停录制 (手动暂停、前后台切换)
- (void)pauseTranscribe {
    NSLog(@"暂停录制");
    if (self.videoRecorder.isRecording) {
        self.recordButton.selected = NO;
        [self.videoRecorder stopRecording:nil];
    }
}

/**
 重拍
 */
- (void)reShoot {
    //取消拍摄
    [self cancelRecording:^{
        //初始化界面
        [self resetUIAndTranscribe];
    }];
}

/// 取消拍摄
- (void)cancelRecording:(void (^__nullable)(void))completionHandler {
    self.recordButton.selected = NO;
    [self.videoRecorder cancelRecording:completionHandler];
}

/**
 下一步按钮点击
 */
- (void)nextStepButtonClick:(UIButton *)button {
    
    [self endrecording];
}

//结束录制 （录制时间满了触发、点击了下一步）
- (void)endrecording {
    self.recordButton.selected = NO;
    __weak typeof(self) weakSelf = self;
    [self.videoRecorder stopRecording:^{
        [weakSelf playVideo];
    }];
}

- (void)playVideo {
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:self.videoRecorder.assetRepresentingAllFiles];
    AVPlayerViewController *controller = [[AVPlayerViewController alloc]init];
    controller.modalPresentationStyle = UIModalPresentationFullScreen;
    controller.player = [AVPlayer playerWithPlayerItem:item];
    [self presentViewController:controller animated:YES completion:nil];
    
}

/// 更新时间
- (void)updateTime {
    //显示重拍按钮、下一步按钮、进度文字
    if (self.reShootButton.hidden) {
        [self setupUIStyle:YES];
    }
    NSString *timeStr = [NSString stringWithFormat:@"%f",self.videoRecorder.currentRecordTime];
    timeStr = [timeStr substringToIndex:[timeStr rangeOfString:@"."].location + 2];
    _recordTimeLabel.text = [NSString stringWithFormat:@"%@秒",timeStr];
    
    //设置下一步按钮是否可以点击
    if (self.videoRecorder.currentRecordTime > kMinRecordTime) {
        self.nextStepButton.enabled = YES;
    } else {
        self.nextStepButton.enabled = NO;
    }
}

#pragma mark - WVRVideoRecorderDelegate

/// 错误回调
/// @param recorder 录制器
/// @param errorCode 错误号
- (void)videoRecorder:(WVRVideoRecorder *__nonnull)recorder error:(WVRError)errorCode {
    
}

/// 视频录制结束
/// @param recorder 录制器
/// @param fileURL 视频文件路径
/// @param error 错误
- (void)videoRecorder:(WVRVideoRecorder *__nonnull)recorder didFinishRecordingToOutputFileAtURL:(NSURL *__nullable)fileURL error:(NSError *__nullable)error {
    if (error) {
        NSLog(@"片段录制失败---->%@",error);
    }else {
        NSLog(@"片段录制成功---->%@",fileURL);
    }
    if (recorder.recordProgress >= 1) {
        //进度已满，结束录制
        [self endrecording];
    }
}

/// 视频录制进度
/// @param recorder 录制器
/// @param progress 录制进度
- (void)videoRecorder:(WVRVideoRecorder *__nonnull)recorder recordProgress:(CGFloat)progress {
    [self updateTime];
    [self setupProgress:progress];
}



- (UIView *)cameraLayerBackgroundView {
    if (!_cameraLayerBackgroundView) {
        _cameraLayerBackgroundView = [[UIView alloc]init];
        _cameraLayerBackgroundView.backgroundColor = [UIColor blackColor];
    }
    return _cameraLayerBackgroundView;
}

- (UIButton *)switchCameraButton {
    if (!_switchCameraButton) {
        _switchCameraButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_switchCameraButton setImage:[UIImage imageNamed:@"ImageVideoPicker_SwitchCamera"] forState:UIControlStateNormal];
        [_switchCameraButton addTarget:self action:@selector(switchCameraButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _switchCameraButton;
}

- (UIButton *)recordButton {
    if (!_recordButton) {
        _recordButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_recordButton setImage:[UIImage imageNamed:@"ImageVideoPicker_StopShooting"] forState:UIControlStateNormal];
        [_recordButton setImage:[UIImage imageNamed:@"ImageVideoPicker_StopShooting"] forState:UIControlStateHighlighted];
        [_recordButton setImage:[UIImage imageNamed:@"ImageVideoPicker_Shooting"] forState:UIControlStateSelected];
        [_recordButton addTarget:self action:@selector(recordBtnclick:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _recordButton;
}

- (UIButton *)reShootButton {
    if (!_reShootButton) {
        _reShootButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_reShootButton setImage:[UIImage imageNamed:@"ImageVideoPicker_ReShoot"] forState:UIControlStateNormal];
        [_reShootButton setImage:[UIImage imageNamed:@"ImageVideoPicker_ReShoot"] forState:UIControlStateHighlighted];
        [_reShootButton addTarget:self action:@selector(reShoot) forControlEvents:UIControlEventTouchUpInside];
    }
    return _reShootButton;
}

- (UIButton *)nextStepButton {
    if (!_nextStepButton) {
        _nextStepButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_nextStepButton setImage:[UIImage imageNamed:@"ImageVideoPicker_Next"] forState:UIControlStateNormal];
        [_nextStepButton setImage:[UIImage imageNamed:@"ImageVideoPicker_Next"] forState:UIControlStateHighlighted];
        [_nextStepButton setImage:[UIImage imageNamed:@"ImageVideoPicker_Next_Disable"] forState:UIControlStateDisabled];
        [_nextStepButton addTarget:self action:@selector(nextStepButtonClick:) forControlEvents:UIControlEventTouchUpInside];
        _nextStepButton.enabled = NO;
    }
    return _nextStepButton;
}

- (UILabel *)reShootLabel {
    if (!_reShootLabel) {
        _reShootLabel = [[UILabel alloc]init];
        _reShootLabel.textColor = [UIColor whiteColor];
        _reShootLabel.text = @"重拍";
        _reShootLabel.font = [UIFont systemFontOfSize:13];
    }
    return _reShootLabel;
}

- (UILabel *)nextStepLabel {
    if (!_nextStepLabel) {
        _nextStepLabel = [[UILabel alloc]init];
        _nextStepLabel.textColor = [UIColor whiteColor];
        _nextStepLabel.text = @"下一步";
        _nextStepLabel.font = [UIFont systemFontOfSize:13];
    }
    return _nextStepLabel;
}

- (UIView *)redView {
    if (!_redView) {
        _redView = [[UIView alloc]init];
        _redView.backgroundColor = UIColor.redColor;
        _redView.layer.cornerRadius = 2.5;
        _redView.layer.masksToBounds = YES;
        _redView.hidden = YES;
    }
    return _redView;
}

- (UILabel *)recordTimeLabel {
    if (!_recordTimeLabel) {
        _recordTimeLabel = [[UILabel alloc]init];
        _recordTimeLabel.font = [UIFont systemFontOfSize:13];
        _recordTimeLabel.textColor = [UIColor whiteColor];
        _recordTimeLabel.hidden = YES;
    }
    return _recordTimeLabel;
}

- (UIView *)bottomView {
    if (!_bottomView) {
        _bottomView = [[UIView alloc]init];
        _bottomView.backgroundColor = [[UIColor blackColor]colorWithAlphaComponent:0.5];
    }
    return _bottomView;
}

- (CAShapeLayer *)shapeLayer {
    if (!_shapeLayer) {
        _shapeLayer = [CAShapeLayer layer];
        _shapeLayer.strokeColor = [UIColor whiteColor].CGColor;
        _shapeLayer.lineWidth = 2;
        _shapeLayer.frame = CGRectMake(0, 0, 61, 61);
        _shapeLayer.fillColor = [UIColor clearColor].CGColor;
    }
    return _shapeLayer;
}

- (UIPinchGestureRecognizer *)zoomGestureRecognizer {
    if (!_zoomGestureRecognizer) {
        _zoomGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(zoomPinches:)];
    }
    return _zoomGestureRecognizer;
}

- (UIView *)zoomTempView {
    if (!_zoomTempView) {
        _zoomTempView = [[UIView alloc]initWithFrame:CGRectMake(-1000, -1000, 10, 10)];
        _zoomTempView.backgroundColor = [UIColor clearColor];
        [self.view addSubview:_zoomTempView];
    }
    return _zoomTempView;
}

-(UIImageView *)focusView {
    if (!_focusView) {
        _focusView = [[UIImageView alloc]initWithFrame:CGRectMake(-60, -200, 60, 60)];
        _focusView.image = [UIImage imageNamed:@"Transcribe_focusView_icon"];
        _focusView.alpha = 0;
        [self.cameraLayerBackgroundView addSubview:_focusView];
    }
    return _focusView;
}
@end
