/*  The MIT License (MIT)
*
*  Original work by Geraint Davies on 02/19/2013
*
*  Copyright (c) 2015 Umayah Abdennabi
*
*  Permission is hereby granted, free of charge, to any person obtaining a copy
*  of this software and associated documentation files (the "Software"), to deal
*  in the Software without restriction, including without limitation the rights
*  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
*  copies of the Software, and to permit persons to whom the Software is
*  furnished to do so, subject to the following conditions:
*
*  The above copyright notice and this permission notice shall be included in all
*  copies or substantial portions of the Software.
*
*  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
*  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
*  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
*  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
*  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
*  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
*  SOFTWARE.
*/

//
// CameraEngine.h
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
