/*  The MIT License (MIT)
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
// PauseVideoCapture.m
//

#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import "CameraEngine.h"
#import "CDVFile.h"
#import <Cordova/CDV.h>
#import <Cordova/CDVPlugin.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "PauseVideoCapture.h"

@interface PauseVideoCapture ()

// Received from js side
@property NSString *callbackId;
@property NSNumber *duration;
@property BOOL decrementTime;

// Video recorder
@property (strong, nonatomic) UIImagePickerController *recorder;
@property (strong, nonatomic) AVPlayerViewController *playerViewController;

// views
@property (strong, nonatomic) UIView *buttonView;
@property (strong, nonatomic) UIView *timerView;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer* preview;

// buttons
@property (strong, nonatomic) UIButton *startButton;
@property (strong, nonatomic) UIButton *stopButton;
@property (strong, nonatomic) UIButton *pauseButton;
@property (strong, nonatomic) UIButton *resumeButton;
@property (strong, nonatomic) UIButton *cancelButton;
@property (strong, nonatomic) UIButton *toggleFlashButton;
@property (strong, nonatomic) UIButton *replayButton;
@property (strong, nonatomic) UIButton *retakeButton;
@property (strong, nonatomic) UIButton *continueButton;
@property UIButton *toggleCameraButton;

// labels
@property (strong, nonatomic) UILabel *timerLabel;

// timers
@property (weak, nonatomic) NSTimer *timer;

// Keep track of current AV orientation
@property AVCaptureVideoOrientation previousAVDeviceOrientation;

// String to newly recorded video
@property (strong, nonatomic) NSString *videoPath;

// primitives
@property int backCamera;
@property int buttonWidth;
@property int buttonHeight;
@property int elapsedTime;
@property BOOL flashState;
@property int timeLeft;

@end

@implementation PauseVideoCapture


-(BOOL)prefersStatusBarHidden
{
    return YES;
}

// This function allows us to use the new bounds of the view
- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    // this is not the most beautiful animation...
    AVCaptureVideoPreviewLayer* preview = [[CameraEngine engine] getPreviewLayer];
    preview.frame = self.cameraView.bounds;
    
    // Reorient buttons after rotation
    [self orientButtons];
    
    [[preview connection] setVideoOrientation:[self convertInterfaceOrientation2AV:toInterfaceOrientation]];
    
}

// Converts seconds into a string in the following format min:sec (ex. 2:32)
- (NSString *) sec2min:(int) seconds
{
    int min =  seconds / 60;
    int sec = seconds % 60;
    
    NSString *timeStr = @"";
    NSString *secStr = @"";
    
    // Make
    if (seconds % 60 == 0) { // Add two zeros if only minutes
        secStr = @":00";
        timeStr = [NSString stringWithFormat:@"%d%@", min, secStr];
        return timeStr;
    }
    else if (seconds < 10) { // Add leading 0 if under 10 seconds
        secStr = @"0";
    }
    secStr = [NSString stringWithFormat:@":%@%d", secStr, sec];
    timeStr = [NSString stringWithFormat:@"%d%@", min, secStr];
    return timeStr;
}

// NSTimer will use this function to update the timer label
- (void) updateTimer
{
    NSLog(@"state of paused: %d", [[CameraEngine engine] isPaused]);
    if (![[CameraEngine engine] isPaused]) {
        self.elapsedTime++;
        self.timeLeft--;
        if (!self.decrementTime) {
            self.timerLabel.text = [self sec2min:self.timeLeft];
        } else {
            self.timerLabel.text = [self sec2min:self.elapsedTime];
        }
    }
}


- (AVCaptureVideoOrientation) convertDeviceOrientation2AV:(UIDeviceOrientation)orientaiton {
    switch(orientaiton) {
        case UIDeviceOrientationLandscapeLeft:
            return AVCaptureVideoOrientationLandscapeLeft;
        case UIDeviceOrientationLandscapeRight:
            return AVCaptureVideoOrientationLandscapeRight;
        case UIDeviceOrientationPortrait:
            return AVCaptureVideoOrientationPortrait;
        case UIDeviceOrientationPortraitUpsideDown:
            return AVCaptureVideoOrientationPortrait;
        default:
            return [self convertInterfaceOrientation2AV:[UIApplication sharedApplication].statusBarOrientation];
    }
}

- (AVCaptureVideoOrientation) convertInterfaceOrientation2AV:(UIInterfaceOrientation)orientaiton {
    switch(orientaiton) {
        case UIInterfaceOrientationLandscapeLeft:
            NSLog(@"Landcsape left");
            return AVCaptureVideoOrientationLandscapeLeft;
        case UIInterfaceOrientationLandscapeRight:
            NSLog(@"Landscape right");
            return AVCaptureVideoOrientationLandscapeRight;
        case UIInterfaceOrientationPortrait:
            NSLog(@"Por. Portrait");
            return AVCaptureVideoOrientationPortrait;
        case UIInterfaceOrientationPortraitUpsideDown:
            NSLog(@"Por. Upsidedown");
            return AVCaptureVideoOrientationPortraitUpsideDown;
        case UIDeviceOrientationUnknown:
            NSLog(@"Unknown");
            return [self convertInterfaceOrientation2AV:[UIApplication sharedApplication].statusBarOrientation];
            
    }
}


// Orient the buttons correctly depending on the orientation
- (void) orientButtons
{
    // Set the coordinates and colors for buttons and labels
    float width = self.cameraView ? self.cameraView.bounds.size.width : 0;
    float height = self.cameraView ? self.cameraView.bounds.size.height : 0;
    
    // Initialize view container for start, stop, pause, resume, and cancel buttons)
    if (self.buttonView)
        self.buttonView.frame = CGRectMake(0, height - 80, width, 80);
    float buttonViewWidth = self.buttonView ? self.buttonView.bounds.size.width : 0;
    float buttonViewHeight = self.buttonView ? self.buttonView.bounds.size.height : 0;
    float buttonViewCenterX = buttonViewWidth / 2.0;
    float buttonViewCenterY = buttonViewHeight / 2.0;
    
    // Initialize view container for toggleFlash and timer
    if (self.timerView)
        self.timerView.frame = CGRectMake(0, 0, width, 40);
    float timerViewWidth = self.timerView ? self.timerView.bounds.size.width : 0;
    float timerViewCenterX = timerViewWidth / 2.0;
    
    // Set the coordinatesfor buttons and labels
    if (self.startButton)
        self.startButton.frame = CGRectMake(buttonViewCenterX - self.buttonWidth/2, buttonViewCenterY, self.buttonWidth, self.buttonHeight);
    if (self.stopButton)
        self.stopButton.frame = CGRectMake(buttonViewWidth - 70, buttonViewCenterY, self.buttonWidth, self.buttonHeight);
    if (self.pauseButton)
        self.pauseButton.frame = CGRectMake(buttonViewCenterX - self.buttonWidth/2, buttonViewCenterY, self.buttonWidth, self.buttonHeight);
    if (self.resumeButton)
        self.resumeButton.frame = CGRectMake(buttonViewCenterX - self.buttonWidth/2, buttonViewCenterY, self.buttonWidth, self.buttonHeight);
    if (self.cancelButton)
        self.cancelButton.frame = CGRectMake(0, buttonViewCenterY, self.buttonWidth, self.buttonHeight);
    if (self.toggleFlashButton)
        self.toggleFlashButton.frame = CGRectMake(0, 0, self.buttonWidth, self.buttonHeight);
    if (self.timerLabel)
        self.timerLabel.frame = CGRectMake(timerViewCenterX - self.buttonWidth/2, 0, self.buttonWidth, self.buttonHeight);
    if (self.toggleCameraButton)
        self.toggleCameraButton.frame = CGRectMake(timerViewWidth - 70, 0, self.buttonWidth, self.buttonHeight);
    if (self.retakeButton)
        self.retakeButton.frame = CGRectMake(0, buttonViewCenterY, self.buttonWidth, self.buttonHeight);
    if (self.replayButton)
        self.replayButton.frame = CGRectMake(buttonViewCenterX - self.buttonWidth/2, buttonViewCenterY, self.buttonWidth, self.buttonHeight);
    if (self.continueButton)
        self.continueButton.frame = CGRectMake(buttonViewWidth - 70, buttonViewCenterY, self.buttonWidth, self.buttonHeight);
}

// Initializes all the buttons and labels, and where their placement
- (void) cameraControlsInit:(NSNumber *)duration decrement:(BOOL)decrement
{
    // Set height and width of all buttons
    self.buttonWidth = 70;
    self.buttonHeight = 40;
    
    self.flashState = NO;
    
    float width = self.cameraView.bounds.size.width;
    float height = self.cameraView.bounds.size.height;
    
    // Initialize view container for start, stop, pause, resume, and cancel buttons)
    self.buttonView = [[UIView alloc] initWithFrame:CGRectMake(0, height - 80, width, 80)];
    self.buttonView.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.70];
    
    // Initialize view container for toggleFlash and timer
    self.timerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 40)];
    self.timerView.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.70];
    
    // Initialize buttons and labels
    self.startButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.startButton addTarget:self action:@selector(startRecording) forControlEvents:UIControlEventTouchUpInside];
    [self.startButton setTitle:@"Start" forState:UIControlStateNormal];
    [self.startButton.titleLabel setTextAlignment: NSTextAlignmentCenter];
    [self.startButton setTitleColor:[UIColor colorWithRed:0.02 green:0.55 blue:0.96 alpha:1.0] forState:UIControlStateNormal];
    
    self.stopButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.stopButton addTarget:self action:@selector(stopRecording) forControlEvents:UIControlEventTouchUpInside];
    [self.stopButton setTitle:@"Stop" forState:UIControlStateNormal];
    [self.stopButton.titleLabel setTextAlignment: NSTextAlignmentCenter];
    [self.stopButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    
    self.pauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.pauseButton addTarget:self action:@selector(pauseRecording) forControlEvents:UIControlEventTouchUpInside];
    [self.pauseButton setTitle:@"Pause" forState:UIControlStateNormal];
    [self.pauseButton.titleLabel setTextAlignment: NSTextAlignmentCenter];
    [self.pauseButton setTitleColor:[UIColor colorWithRed:0.02 green:0.55 blue:0.96 alpha:1.0] forState:UIControlStateNormal];
    
    self.resumeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.resumeButton addTarget:self action:@selector(resumeRecording) forControlEvents:UIControlEventTouchUpInside];
    [self.resumeButton setTitle:@"Resume" forState:UIControlStateNormal];
    [self.resumeButton.titleLabel setTextAlignment: NSTextAlignmentCenter];
    [self.resumeButton setTitleColor:[UIColor colorWithRed:0.02 green:0.55 blue:0.96 alpha:1.0] forState:UIControlStateNormal];
    
    self.cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.cancelButton addTarget:self action:@selector(cancelRecording) forControlEvents:UIControlEventTouchUpInside];
    [self.cancelButton setTitle:@"Cancel" forState:UIControlStateNormal];
    [self.cancelButton.titleLabel setTextAlignment: NSTextAlignmentCenter];
    [self.cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    self.toggleFlashButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.toggleFlashButton addTarget:self action:@selector(toggleFlash) forControlEvents:UIControlEventTouchUpInside];
    [self.toggleFlashButton setTitle:@"Flash" forState:UIControlStateNormal];
    [self.toggleFlashButton.titleLabel setTextAlignment: NSTextAlignmentCenter];
    [self.toggleFlashButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    self.toggleCameraButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.toggleCameraButton addTarget:self action:@selector(toggleCamera) forControlEvents:UIControlEventTouchUpInside];
    [self.toggleCameraButton setTitle:@"Camera" forState:UIControlStateNormal];
    [self.toggleCameraButton.titleLabel setTextAlignment: NSTextAlignmentCenter];
    [self.toggleCameraButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    self.timerLabel = [[UILabel alloc] init];
    
    // Add buttons to buttonView
    [self.buttonView addSubview:self.startButton];
    [self.buttonView addSubview:self.stopButton];
    [self.buttonView addSubview:self.pauseButton];
    [self.buttonView addSubview:self.resumeButton];
    [self.buttonView addSubview:self.cancelButton];
    
    // Add timer, flash, and camera toggle to timerView
    [self.timerView addSubview:self.toggleFlashButton];
    [self.timerView addSubview:self.timerLabel];
    [self.timerView addSubview:self.toggleCameraButton];
    
    // Add timer and buttonView to main camera view
    [self.cameraView addSubview:self.buttonView];
    [self.cameraView addSubview:self.timerView];
    
    // Set the coordinatesfor buttons and labels
    [self orientButtons];
    
    if (decrement) {
        self.timerLabel.text = [self sec2min:duration.intValue];
    } else {
        self.timerLabel.text = @"0:00";
    }
    self.timerLabel.textColor = [UIColor whiteColor];
    [self.timerLabel setTextAlignment:NSTextAlignmentCenter];
    
    // Show correct video control buttons on start
    self.startButton.hidden = NO;
    self.stopButton.hidden = YES;
    self.pauseButton.hidden = YES;
    self.resumeButton.hidden = YES;
    self.cancelButton.hidden = NO;
}

- (void) retakeReplayControlsInit
{
    // Initialize buttons and labels
    self.retakeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.retakeButton addTarget:self action:@selector(retakeVideo) forControlEvents:UIControlEventTouchUpInside];
    [self.retakeButton setTitle:@"Retake" forState:UIControlStateNormal];
    [self.retakeButton.titleLabel setTextAlignment: NSTextAlignmentCenter];
    [self.retakeButton setTitleColor:[UIColor colorWithRed:0.02 green:0.55 blue:0.96 alpha:1.0] forState:UIControlStateNormal];
    
    self.replayButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.replayButton addTarget:self action:@selector(replayVideo) forControlEvents:UIControlEventTouchUpInside];
    [self.replayButton setTitle:@"Replay" forState:UIControlStateNormal];
    [self.replayButton.titleLabel setTextAlignment: NSTextAlignmentCenter];
    [self.replayButton setTitleColor:[UIColor colorWithRed:0.02 green:0.55 blue:0.96 alpha:1.0] forState:UIControlStateNormal];
    
    self.continueButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.continueButton addTarget:self action:@selector(return2Cordova) forControlEvents:UIControlEventTouchUpInside];
    [self.continueButton setTitle:@"Save" forState:UIControlStateNormal];
    [self.continueButton.titleLabel setTextAlignment: NSTextAlignmentCenter];
    [self.continueButton setTitleColor:[UIColor colorWithRed:0.02 green:0.55 blue:0.96 alpha:1.0] forState:UIControlStateNormal];
    
    // Create a white background
    UIView *whiteView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.cameraView.bounds.size.width, self.cameraView.bounds.size.height)];
    [whiteView setBackgroundColor:[UIColor whiteColor]];
    
    float width = self.cameraView.bounds.size.width;
    float height = self.cameraView.bounds.size.height;
    self.buttonView = [[UIView alloc] initWithFrame:CGRectMake(0, height - 80, width, 80)];
    self.buttonView.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.70];
    
    // Add buttons to buttonView
    [self.buttonView addSubview:self.retakeButton];
    [self.buttonView addSubview:self.replayButton];
    [self.buttonView addSubview:self.continueButton];
    
    [whiteView addSubview:self.buttonView];
    [self.cameraView addSubview:whiteView];
    
    [self orientButtons];
    
}

- (void) setupCameraView
{
    self.backCamera = YES;
    self.toggleCameraButton.hidden = NO;
    
    float width = self.viewController.view.bounds.size.width;
    float height = self.viewController.view.bounds.size.height;
    
    // Initial camera engine startup that must be done
    [[CameraEngine engine] startup:self.backCamera];
    
    // Set up the camera view needs to be reallocated everytime
    self.cameraView = [[UIView alloc] init];
    [self.viewController.view addSubview:self.cameraView];
    
    self.cameraView.frame = CGRectMake(0, 0, width, height);
    self.cameraView.hidden = NO;
    
    self.preview = [[CameraEngine engine] getPreviewLayer];
    [self.preview removeFromSuperlayer];
    self.preview.frame = self.cameraView.bounds;
    [[self.preview connection] setVideoOrientation:[self convertDeviceOrientation2AV:[[UIDevice currentDevice] orientation]]];
    // Allows the cameraView to rezie accordingly to the full width and height of the current orientation
    self.cameraView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.cameraView.layer addSublayer:self.preview];
    [self cameraControlsInit:self.duration decrement:YES];
}

- (void) pauseVideoCapture:(CDVInvokedUrlCommand *)command
{
    self.callbackId = command.callbackId;
    NSDictionary *options = [command argumentAtIndex:0];

    if ([options isKindOfClass:[NSNull class]]) {
        options = [NSDictionary dictionary];
    }

    // options could contain duration in seconds, whether time is decrementing
    self.duration = [options objectForKey:@"duration"];
    self.decrementTime = [options objectForKey:@"decrement"];
    if (self.duration == nil) 
        self.duration = 0;
    if (self.decrementTime == nil)
        self.decrementTime = false;

    [self.commandDelegate runInBackground:^{
        [self setupCameraView];
    }];
}

// Starts recording a video
- (void) startRecording
{
    [[CameraEngine engine] startCapture:[self convertInterfaceOrientation2AV:[UIApplication sharedApplication].statusBarOrientation]];
    
    // Start timer
    self.elapsedTime = 0;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateTimer) userInfo:nil repeats:YES];
    
    self.startButton.hidden = YES;
    self.resumeButton.hidden = YES;
    self.pauseButton.hidden = NO;
    self.stopButton.hidden = NO;
    self.toggleCameraButton.hidden = YES;
}

// Stops recording and closes the camera returning the video data
- (void) stopRecording
{
    [self.timer invalidate];
    self.timer = nil;
    [[CameraEngine engine] turnOffFlash:YES];
    self.videoPath = [[CameraEngine engine] stopCapture];
    
    // After saving the video we want to be able to replay the video and remake
    // it if necessary.  So we will programmatically create a new replay/retake view
    [self.cameraView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    // Add retake/replay video
    [self retakeReplayControlsInit];
    
    NSURL *urlVideoFile = [NSURL fileURLWithPath:self.videoPath];
    self.playerViewController = [[AVPlayerViewController alloc] init];
    self.playerViewController.player = [AVPlayer playerWithURL:urlVideoFile];
    self.playerViewController.view.frame = self.viewController.view.bounds;
    self.playerViewController.showsPlaybackControls = YES;
    [self.playerViewController setTabBarItem:[[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemContacts tag:1]];
    //[self.view addSubview:_playerViewController.view];
    //self.viewController.view.autoresizesSubviews = YES;
    [self.viewController presentViewController:self.playerViewController animated:YES completion:nil];
    //[self dismissViewControllerAnimated:YES completion:nil];
}

// Pauses the current video recording
- (void) pauseRecording
{
    [[CameraEngine engine] pauseCapture];
    
    // Show correct buttons
    self.pauseButton.hidden = YES;
    self.resumeButton.hidden = NO;
}

// Resumes recording after user paused recording (continues recording from where user paused)
- (void) resumeRecording
{
    [[CameraEngine engine] resumeCapture];
    
    // Show correct buttons
    self.resumeButton.hidden = YES;
    self.pauseButton.hidden = NO;
}

// Cancel and close the camera, does not return a video
- (void) cancelRecording
{
    [self.timer invalidate];
    self.timer = nil;
    self.videoPath = nil;
    [[CameraEngine engine] turnOffFlash:YES];
    [[CameraEngine engine] shutdown];
    //[self dismissViewControllerAnimated:YES completion:nil];
    self.cameraView.hidden = YES;
}

// Toggle between front and back camera
- (void) toggleCamera
{
    self.backCamera = !self.backCamera;
    [[CameraEngine engine] toggleCamera:self.backCamera];
}

// Turn camera flash (also known as torch) on/off
- (void) toggleFlash
{
    self.flashState = !self.flashState;
    [[CameraEngine engine] turnOffFlash:self.flashState];
}

// Deletes video that was previously taken and opens back the camer to allow user to retake video
- (void) retakeVideo
{
    [[CameraEngine engine] removeCapture];
    self.videoPath = nil;
    self.cameraView = nil;
    self.playerViewController = nil;
    [self setupCameraView];
}

// Replays the video that was just recorded
- (void) replayVideo
{
    NSLog(@"Replaying the video: %@", self.videoPath);
    [self.viewController presentViewController:self.playerViewController animated:YES completion:nil];
}

- (NSDictionary*)getMediaDictionaryFromPath:(NSString*)fullPath ofType:(NSString*)type
{
    NSFileManager* fileMgr = [[NSFileManager alloc] init];
    NSMutableDictionary* fileDict = [NSMutableDictionary dictionaryWithCapacity:5];

    CDVFile *fs = [self.commandDelegate getCommandInstance:@"File"];

    // Get canonical version of localPath
    NSURL *fileURL = [NSURL URLWithString:[NSString stringWithFormat:@"file://%@", fullPath]];
    NSURL *resolvedFileURL = [fileURL URLByResolvingSymlinksInPath];
    NSString *path = [resolvedFileURL path];

    CDVFilesystemURL *url = [fs fileSystemURLforLocalPath:path];

    [fileDict setObject:[fullPath lastPathComponent] forKey:@"name"];
    [fileDict setObject:fullPath forKey:@"fullPath"];
    if (url) {
        [fileDict setObject:[url absoluteURL] forKey:@"localURL"];
    }
    // determine type
    if (!type) {
        id command = [self.commandDelegate getCommandInstance:@"File"];
        if ([command isKindOfClass:[CDVFile class]]) {
            CDVFile* cdvFile = (CDVFile*)command;
            NSString* mimeType = [cdvFile getMimeTypeFromPath:fullPath];
            [fileDict setObject:(mimeType != nil ? (NSObject*)mimeType : [NSNull null]) forKey:@"type"];
        }
    }
    NSDictionary* fileAttrs = [fileMgr attributesOfItemAtPath:fullPath error:nil];
    [fileDict setObject:[NSNumber numberWithUnsignedLongLong:[fileAttrs fileSize]] forKey:@"size"];
    NSDate* modDate = [fileAttrs fileModificationDate];
    NSNumber* msDate = [NSNumber numberWithDouble:[modDate timeIntervalSince1970] * 1000];
    [fileDict setObject:msDate forKey:@"lastModifiedDate"];

    return fileDict;
}

- (CDVPluginResult*)processVideo:(NSString*)moviePath forCallbackId:(NSString*)callbackId
{
    // save the movie to photo album (only avail as of iOS 3.1)

    // create MediaFile object
    NSDictionary* fileDict = [self getMediaDictionaryFromPath:moviePath ofType:nil];
    NSArray* fileArray = [NSArray arrayWithObject:fileDict];
    
    return [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:fileArray];
}

- (void) nillify
{
    self.recorder = nil;
    self.playerViewController = nil;
    self.buttonView = nil;
    self.timerView = nil;
    self.preview = nil;
    self.startButton = nil;
    self.stopButton = nil;
    self.pauseButton = nil;
    self.resumeButton = nil;
    self.cancelButton = nil;
    self.toggleFlashButton = nil;
    self.replayButton = nil;
    self.retakeButton = nil;
    self.continueButton = nil;
    self.toggleCameraButton = nil;
    self.timerLabel = nil;
    self.timer = nil;
    self.videoPath = nil;
}

// Returns the video back to Cordova app
- (void) return2Cordova
{
    NSLog(@"Saving the video");
    //[[CameraEngine engine] saveCapture];
    CDVPluginResult *result = [self processVideo:self.videoPath forCallbackId:self.callbackId];
    if (!result) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageToErrorObject:CAPTURE_INTERNAL_ERR];
    }

    self.cameraView.hidden = YES;
    [self nillify];
    return [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
}

@end
