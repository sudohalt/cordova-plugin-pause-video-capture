//
//  CameraEngine.m
//
//  Created by Geraint Davies on 02/19/2013.
//  Copyright (c) 2013 GDCL http://www.gdcl.co.uk/license.htm
//

#import "CameraEngine.h"
#import "VideoEncoder.h"
#import "AssetsLibrary/ALAssetsLibrary.h"

static CameraEngine* theEngine;

@interface CameraEngine  () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>

@property AVCaptureSession *session;
@property AVCaptureVideoPreviewLayer *preview;
@property dispatch_queue_t captureQueue;
@property AVCaptureConnection *audioConnection;
@property AVCaptureConnection *videoConnection;

@property VideoEncoder *encoder;

@property BOOL discont;
@property int currentFile;
@property CMTime timeOffset;
@property CMTime lastVideo;
@property CMTime lastAudio;

@property int cx;
@property int cy;
@property int channels;
@property Float64 samplerate;

@end


@implementation CameraEngine

+ (void) initialize
{
    // test recommended to avoid duplicate init via subclass
    if (self == [CameraEngine class]) {
        theEngine = [[CameraEngine alloc] init];
    }
}

+ (CameraEngine *) engine
{
    return theEngine;
}

- (void) startup:(BOOL)backCamera
{
    if (self.session == nil) {
        NSLog(@"Starting up server");

        self.isCapturing = NO;
        self.isPaused = NO;
        self.enableSaveRemove = NO;
        self.currentFile = 0;
        self.discont = NO;

        // create capture device with video input
        self.session = [[AVCaptureSession alloc] init];
        AVCaptureDevice *camera;
        // Choose the correct camera to use (front/back)
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in devices) {
            if (!backCamera && [device position] == AVCaptureDevicePositionFront) {
                camera = device;
                break;
            } else if (backCamera && ([device position] == AVCaptureDevicePositionBack)) {
                camera = device;
                break;
            }
        }
        if (camera == nil)
            camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:camera error:nil];
        [self.session addInput:input];

        
        // audio input from default mic
        AVCaptureDevice *mic = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        AVCaptureDeviceInput *micinput = [AVCaptureDeviceInput deviceInputWithDevice:mic error:nil];
        [self.session addInput:micinput];
        
        // create an output for YUV output with self as delegate
        self.captureQueue = dispatch_queue_create("PauseVideoCapture.CameraEngine.captureQueue", DISPATCH_QUEUE_SERIAL);
        AVCaptureVideoDataOutput *videoout = [[AVCaptureVideoDataOutput alloc] init];
        [videoout setSampleBufferDelegate:self queue:self.captureQueue];
        NSDictionary *setcapSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange], kCVPixelBufferPixelFormatTypeKey,
                                        nil];
        videoout.videoSettings = setcapSettings;
        [self.session addOutput:videoout];
        self.videoConnection = [videoout connectionWithMediaType:AVMediaTypeVideo];
        // find the actual dimensions used so we can set up the encoder to the same.
        NSDictionary *actual = videoout.videoSettings;
        self.cy = [[actual objectForKey:@"Height"] integerValue];
        self.cx = [[actual objectForKey:@"Width"] integerValue];
        
        AVCaptureAudioDataOutput *audioout = [[AVCaptureAudioDataOutput alloc] init];
        [audioout setSampleBufferDelegate:self queue:self.captureQueue];
        [self.session addOutput:audioout];
        self.audioConnection = [audioout connectionWithMediaType:AVMediaTypeAudio];
        // for audio, we want the channels and sample rate, but we can't get those from audioout.audiosettings on ios, so
        // we need to wait for the first sample
        
        // start capture and a preview layer
        [self.session startRunning];

        self.preview = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
        self.preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    }
}

- (void) startCapture:(AVCaptureVideoOrientation)videoOrientation
{
    @synchronized(self) {
        if (!self.isCapturing) {
            NSLog(@"starting capture");
            [self.videoConnection setVideoOrientation:videoOrientation];
            // If the video is in portrait we have to switch up cx and cy
            if (videoOrientation ==  AVCaptureVideoOrientationPortrait || videoOrientation == AVCaptureVideoOrientationPortraitUpsideDown) {
                int prevCy = self.cy;
                self.cy = self.cx;
                self.cx = prevCy;
            }
            // create the encoder once we have the audio params
            self.encoder = nil;
            self.isPaused = NO;
            self.discont = NO;
            self.timeOffset = CMTimeMake(0, 0);
            self.isCapturing = YES;
        }
    }
}

- (NSString *) stopCapture
{
    @synchronized(self) {
        if (self.isCapturing) {
            NSString *filename = [NSString stringWithFormat:@"capture%d.mp4", self.currentFile];
            NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
            self.isCapturing = NO;
            self.enableSaveRemove = YES;
            dispatch_async(self.captureQueue, ^{
                [self.encoder finishWithCompletionHandler:^{
                    self.isCapturing = NO;
                    self.enableSaveRemove = YES;
                    self.encoder = nil;
                }];
            });
            return path;
        }
    }
    return @"";
}

- (void) saveCapture
{
    @synchronized(self) {
        if (self.enableSaveRemove) {
            self.enableSaveRemove = NO;
            NSString *filename = [NSString stringWithFormat:@"capture%d.mp4", self.currentFile];
            NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
            NSURL *url = [NSURL fileURLWithPath:path];

            // serialize with audio and video capture
            dispatch_async(self.captureQueue, ^{
                ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
                [library writeVideoAtPathToSavedPhotosAlbum:url completionBlock:^(NSURL *assetURL, NSError *error){
                    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
                }];
            });
        }
    }
}

- (void) removeCapture
{
    @synchronized(self) {
        if (self.enableSaveRemove) {
            self.enableSaveRemove = NO;
            NSString *filename = [NSString stringWithFormat:@"capture%d.mp4", self.currentFile];
            NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
            // serialize with audio and video capture
            dispatch_async(self.captureQueue, ^{
                [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            });
        }
    }
}

- (void) pauseCapture
{
    @synchronized(self) {
        if (self.isCapturing) {
            NSLog(@"Pausing capture");
            self.isPaused = YES;
            self.discont = YES;
        }
    }
}

- (void) resumeCapture
{
    @synchronized(self) {
        if (self.isPaused) {
            NSLog(@"Resuming capture");
            self.isPaused = NO;
        }
    }
}

- (void) turnOffFlash:(BOOL)toggle
{
        // check if flashlight available
        Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
        if (captureDeviceClass != nil) {
            AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
            if ([device hasTorch] && [device hasFlash]){
                [device lockForConfiguration:nil];
                if (!toggle) {
                    [device setTorchMode:AVCaptureTorchModeOn];
                    [device setFlashMode:AVCaptureFlashModeOn];
                } else {
                    [device setTorchMode:AVCaptureTorchModeOff];
                    [device setFlashMode:AVCaptureFlashModeOff];
                }
                [device unlockForConfiguration];
            }
        }
}

- (void) toggleCamera:(BOOL)backCamera
{
    @synchronized(self) {
        [self.session stopRunning];
        
        AVCaptureDevice *camera;
        // Choose the correct camera to use (front/back)
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in devices) {
            if (!backCamera && [device position] == AVCaptureDevicePositionFront) {
                camera = device;
                break;
            } else if (backCamera && ([device position] == AVCaptureDevicePositionBack)) {
                camera = device;
                break;
            }
        }
        if (camera == nil)
            camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        AVCaptureDeviceInput *input = [[AVCaptureDeviceInput  alloc] initWithDevice:camera error:nil];
        NSLog(@"Amount of inputs %luu", (unsigned long)[self.session.inputs count]);
        for (AVCaptureInput *input in self.session.inputs) {
            [self.session removeInput:input];
        }
        [self.session addInput:input];
        
        // audio input from default mic
        AVCaptureDevice *mic = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        AVCaptureDeviceInput *micinput = [[AVCaptureDeviceInput alloc] initWithDevice:mic error:nil];
        [self.session addInput:micinput];
        
        for (AVCaptureOutput *output in self.session.outputs) {
            [self.session removeOutput:output];
        }
        
        // create an output for YUV output with self as delegate
        AVCaptureVideoDataOutput *videoout = [[AVCaptureVideoDataOutput alloc] init];
        [videoout setSampleBufferDelegate:self queue:self.captureQueue];
        NSDictionary *setcapSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange], kCVPixelBufferPixelFormatTypeKey,
                                        nil];
        videoout.videoSettings = setcapSettings;
        [self.session addOutput:videoout];
        self.videoConnection = [videoout connectionWithMediaType:AVMediaTypeVideo];
        // find the actual dimensions used so we can set up the encoder to the same.
        NSDictionary *actual = videoout.videoSettings;
        self.cy = [[actual objectForKey:@"Height"] integerValue];
        self.cx = [[actual objectForKey:@"Width"] integerValue];
        
        AVCaptureAudioDataOutput *audioout = [[AVCaptureAudioDataOutput alloc] init];
        [audioout setSampleBufferDelegate:self queue:self.captureQueue];
        [self.session addOutput:audioout];
        self.audioConnection = [audioout connectionWithMediaType:AVMediaTypeAudio];
        // for audio, we want the channels and sample rate, but we can't get those from audioout.audiosettings on ios, so
        // we need to wait for the first sample
        
        [self.session startRunning];
        
    }
}

- (CMSampleBufferRef) adjustTime:(CMSampleBufferRef) sample by:(CMTime) offset
{
    CMItemCount count;
    CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &count);
    CMSampleTimingInfo *pInfo = malloc(sizeof(CMSampleTimingInfo) * count);
    CMSampleBufferGetSampleTimingInfoArray(sample, count, pInfo, &count);
    for (CMItemCount i = 0; i < count; i++) {
        pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, offset);
        pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, offset);
    }
    CMSampleBufferRef sout;
    CMSampleBufferCreateCopyWithNewTiming(nil, sample, count, pInfo, &sout);
    free(pInfo);
    return sout;
}

- (void) setAudioFormat:(CMFormatDescriptionRef) fmt
{
    const AudioStreamBasicDescription *asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmt);
    self.samplerate = asbd->mSampleRate;
    self.channels = asbd->mChannelsPerFrame;
}

- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    BOOL bVideo = YES;
    
    @synchronized(self) {
        if (!self.isCapturing  || self.isPaused) {
            return;
        }
        if (connection != self.videoConnection) {
            bVideo = NO;
        }
        if ((self.encoder == nil) && !bVideo) {
            CMFormatDescriptionRef fmt = CMSampleBufferGetFormatDescription(sampleBuffer);
            [self setAudioFormat:fmt];
            NSString *filename = [NSString stringWithFormat:@"capture%d.mp4", self.currentFile];
            NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
            self.encoder = [VideoEncoder encoderForPath:path Height:self.cy width:self.cx channels:self.channels samples:self.samplerate];
        }
        if (self.discont) {
            if (bVideo) {
                return;
            }
            self.discont = NO;
            // calc adjustment
            CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            CMTime last = bVideo ? self.lastVideo : self.lastAudio;
            if (last.flags & kCMTimeFlags_Valid) {
                if (self.timeOffset.flags & kCMTimeFlags_Valid) {
                    pts = CMTimeSubtract(pts, self.timeOffset);
                }
                CMTime offset = CMTimeSubtract(pts, last);
                NSLog(@"Setting offset from %s", bVideo?"video": "audio");
                NSLog(@"Adding %f to %f (pts %f)", ((double)offset.value)/offset.timescale, ((double)self.timeOffset.value)/self.timeOffset.timescale, ((double)pts.value/pts.timescale));
                
                // this stops us having to set a scale for _timeOffset before we see the first video time
                if (self.timeOffset.value == 0) {
                    self.timeOffset = offset;
                } else {
                    self.timeOffset = CMTimeAdd(self.timeOffset, offset);
                }
            }
            _lastVideo.flags = 0;
            _lastAudio.flags = 0;
        }
        
        // retain so that we can release either this or modified one
        CFRetain(sampleBuffer);
        
        if (self.timeOffset.value > 0) {
            CFRelease(sampleBuffer);
            sampleBuffer = [self adjustTime:sampleBuffer by:self.timeOffset];
        }
        
        // record most recent time so we know the length of the pause
        CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        CMTime dur = CMSampleBufferGetDuration(sampleBuffer);
        if (dur.value > 0) {
            pts = CMTimeAdd(pts, dur);
        }
        if (bVideo) {
            self.lastVideo = pts;
        } else {
            self.lastAudio = pts;
        }
    }

    // pass frame to encoder
    [self.encoder encodeFrame:sampleBuffer isVideo:bVideo];
    CFRelease(sampleBuffer);
}

- (void) shutdown
{
    NSLog(@"shutting down server");
    if (self.session) {
        [self.session stopRunning];
        self.session = nil;
    }
    [self.encoder finishWithCompletionHandler:^{
        NSLog(@"Capture completed");
    }];
}


- (AVCaptureVideoPreviewLayer *) getPreviewLayer
{
    return self.preview;
}

@end
