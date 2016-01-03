//
//  CameraEngine.h
//
//  Created by Geraint Davies on 19/02/2013.
//  Copyright (c) 2013 GDCL http://www.gdcl.co.uk/license.htm
//

#import <Foundation/Foundation.h>
#import "AVFoundation/AVCaptureSession.h"
#import "AVFoundation/AVCaptureOutput.h"
#import "AVFoundation/AVCaptureDevice.h"
#import "AVFoundation/AVCaptureInput.h"
#import "AVFoundation/AVCaptureVideoPreviewLayer.h"
#import "AVFoundation/AVMediaFormat.h"

@interface CameraEngine : NSObject

+ (CameraEngine *) engine;
- (void) startup:(BOOL)backCamera;
- (void) shutdown;
- (AVCaptureVideoPreviewLayer *) getPreviewLayer;

- (void) startCapture:(AVCaptureVideoOrientation)videoOrientation;
- (void) pauseCapture;
- (NSString *) stopCapture;
- (void) resumeCapture;
- (void) turnOffFlash:(BOOL) toggle;
- (void) removeCapture;
- (void) saveCapture;
- (void) toggleCamera:(BOOL)backCamera;

@property (atomic, readwrite) BOOL isCapturing;
@property (atomic, readwrite) BOOL isPaused;
@property (atomic, readwrite) BOOL enableSaveRemove;

@end
