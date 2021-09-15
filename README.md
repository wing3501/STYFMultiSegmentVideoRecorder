<img src="/Users/styf/Downloads/ruby_app/STYFMultiSegmentVideoRecorder/IMG_0632.PNG" alt="IMG_0632" style="zoom: 25%;" />

#### 短视频分段录制功能设计

主要参考了以下两个开源库的代码。仅供学习参考。

两种方案的代码都有。demo中是以第二种方式实现的。推荐第二种。

## 方案一：录制成一个文件

思路：基于AVAssetWriter的视频帧音频帧的写入，每次把样本（CMSampleBufferRef）写入文件后，记录下样本当前时间。

用户点击暂停按钮，用一个变量（isRecording）在代理方法（captureOutput:didOutputSampleBuffer:fromConnection:）中控制停止写入。

用户点击继续按钮，继续采集到的第一个样本，与暂停前的最后一个样本进行比较，计算出中间的暂停时间。

之后的每一个样本都需要进行时间调整，即在样本本身的真实时间基础上，减去暂停时间。



缺陷：**结束录制，导出文件后。进入编辑页面，再返回，无法在原视频基础上继续录制。**

**谨慎处理偏移计算，一旦样本时间计算有误，会引起写入错误。** 视频帧与音频帧的时间CMTime不一致，其中一个有取整(round)处理。一旦时间出现错误，之后的所有帧都会进入丢弃的代理回调中（captureOutput: didDropSampleBuffer:fromConnection:）

Error Domain=AVFoundationErrorDomain Code=-11800 "The operation could not be completed" UserInfo={NSLocalizedFailureReason=An … unknown error occurred (-16364)

参考案例：https://github.com/imwcl/WCLRecordVideo

## 方案二：录制成多个文件

思路：可基于AVAssetWriter，也可以用AVCaptureMovieFileOutput。每次暂停都单独导出一个文件。当用户需要进入下一步编辑页面时，

SDK提供一个AVAsset，把一组录制好的文件，组合在一起(AVMutableComposition)，返回给用户。猜测七牛也是采用这种方式。

首帧黑屏、生成缩略图失败问题：

**Error Domain=AVFoundationErrorDomain Code=-11832 "****打不开****" UserInfo={NSLocalizedFailureReason=****无法使用此媒体。****, NSLocalizedDescription=****打不开****, NSUnderlyingError=0x11f462d60 {Error Domain=NSOSStatusErrorDomain Code=-12431 "(null)"}}**

**务必保证AVAssetWriter的startSessionAtSourceTime以视频帧开始，并保证写入的第一个是视频帧。**

前置摄像头录制镜像问题：

切换到前置摄像头时，开启AVCaptureConnection的videoMirrored。同时更新AVCaptureConnection的videoOrientation为竖屏。

解决录制视频翻转问题，尝试修改AVCaptureConnection的videoOrientation。而不是去改AVAssetWriterInput的transform。

参考案例：https://github.com/rFlex/SCRecorder
