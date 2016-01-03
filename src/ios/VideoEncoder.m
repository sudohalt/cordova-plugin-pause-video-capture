/*  The MIT License (MIT)
*
*  Original work by Geraint Davies on 02/14/2013
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
// VideoEncoder.m
//

#import "VideoEncoder.h"

@implementation VideoEncoder

+ (VideoEncoder*) encoderForPath:(NSString*) path Height:(int) cy width:(int) cx channels: (int) ch samples:(Float64) rate;
{
    VideoEncoder* enc = [VideoEncoder alloc];
    [enc initPath:path Height:cy width:cx channels:ch samples:rate];
    return enc;
}


- (void) initPath:(NSString*)path Height:(int) cy width:(int) cx channels: (int) ch samples:(Float64) rate;
{
    self.path = path;
    
    [[NSFileManager defaultManager] removeItemAtPath:self.path error:nil];
    NSURL* url = [NSURL fileURLWithPath:self.path];
    
    self.writer = [AVAssetWriter assetWriterWithURL:url fileType:AVFileTypeQuickTimeMovie error:nil];
    NSDictionary* settings = [NSDictionary dictionaryWithObjectsAndKeys:
                              AVVideoCodecH264, AVVideoCodecKey,
                              [NSNumber numberWithInt: cx], AVVideoWidthKey,
                              [NSNumber numberWithInt: cy], AVVideoHeightKey,
                              nil];
    self.videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
    self.videoInput.expectsMediaDataInRealTime = YES;
    [self.writer addInput:self.videoInput];
    
    settings = [NSDictionary dictionaryWithObjectsAndKeys:
                                          [ NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                                          [ NSNumber numberWithInt: ch], AVNumberOfChannelsKey,
                                          [ NSNumber numberWithFloat: rate], AVSampleRateKey,
                                          [ NSNumber numberWithInt: 64000 ], AVEncoderBitRateKey,
                nil];
    self.audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:settings];
    self.audioInput.expectsMediaDataInRealTime = YES;
    [self.writer addInput:self.audioInput];
}

- (void) finishWithCompletionHandler:(void (^)(void))handler
{
    [self.writer finishWritingWithCompletionHandler: handler];
}

- (BOOL) encodeFrame:(CMSampleBufferRef) sampleBuffer isVideo:(BOOL)bVideo
{
    if (CMSampleBufferDataIsReady(sampleBuffer)) {
        if (self.writer.status == AVAssetWriterStatusUnknown) {
            CMTime startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            [self.writer startWriting];
            [self.writer startSessionAtSourceTime:startTime];
        }
        if (self.writer.status == AVAssetWriterStatusFailed) {
            NSLog(@"writer error %@", self.writer.error.localizedDescription);
            return NO;
        }
        if (bVideo) {
            if (self.videoInput.readyForMoreMediaData == YES) {
                [self.videoInput appendSampleBuffer:sampleBuffer];
                return YES;
            }
        } else {
            if (self.audioInput.readyForMoreMediaData) {
                [self.audioInput appendSampleBuffer:sampleBuffer];
                return YES;
            }
        }
    }
    return NO;
}

@end
