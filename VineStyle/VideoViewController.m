//
//  VideoViewController.m
//  VineStyle
//
//  Created by Keith Norman on 3/18/13.
//  Copyright (c) 2013 Ditty. All rights reserved.
//

#import "VideoViewController.h"
#import "AVCaptureMovieFileOutput+AVCaptureMovieFileOutput_tag.h"

@interface VideoViewController () {
  int completed;
  int inProcess;
  int ticker;
  NSMutableArray *instructions;
  UIActivityIndicatorView *spinner;
}

@property (nonatomic, strong) AVCaptureMovieFileOutput *currentMovieFileOutput;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureSession *recordingSession;
@property (nonatomic, strong) AVAssetExportSession *exportSession;
@property (nonatomic, strong) NSMutableArray *outputHandlers;
@property (nonatomic, strong) NSMutableArray *movFiles;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSTimer *exportTimer;
@property (nonatomic, strong) UIView *loadingView;
@property (nonatomic, strong) UIProgressView *progressBar;

@end

@implementation VideoViewController

- (void)viewDidLoad {
  self.outputHandlers = [NSMutableArray new];
  completed = ticker = inProcess = 0;
  self.movFiles = [NSMutableArray new];
  instructions = [NSMutableArray new];
  [super viewDidLoad];
  [self setupAVCapture];
}

-(void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self.view bringSubviewToFront:self.tickerLabel];
  [self.view bringSubviewToFront:self.tapToRecordLabel];
  [self.saveBtn addTarget:self action:@selector(onTouchSave:) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.saveBtn];
}

- (BOOL)setupAVCapture {
	NSError *error = nil;
	
  self.session = [AVCaptureSession new];
  self.recordingSession = [AVCaptureSession new];
	[self.session setSessionPreset:AVCaptureSessionPresetHigh];
  [self.recordingSession setSessionPreset:AVCaptureSessionPresetHigh];
	
	// Select a video device, make an input
	AVCaptureDevice *backCamera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
  AVCaptureDevice *frontCamera;
  AVCaptureDevice *audioCapture = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
  
  NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
  for (AVCaptureDevice *device in devices) {
    if ([device position] == AVCaptureDevicePositionFront) {
      frontCamera = device;
    }
  }
	AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];
  AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioCapture error:&error];
	if (error)
		return NO;
	if ([self.session canAddInput:input]) {
		[self.session addInput:input];
    //[self.recordingSession addInput:input];
  }
  
  if([self.session canAddInput:audioInput]) {
    NSLog(@"YEAH ADDING AUDIO");
    [self.session addInput:audioInput];
    //[self.recordingSession addInput:audioInput];
  }
	
	// Make a preview layer so we can see the visual output of an AVCaptureSession
	AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
	[previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
	[previewLayer setFrame:[self.view bounds]];
	
  // add the preview layer to the hierarchy
  CALayer *rootLayer = self.view.layer;
	[rootLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
	[rootLayer insertSublayer:previewLayer atIndex:1];
	
  // start the capture session running, note this is an async operation
  // status is provided via notifications such as AVCaptureSessionDidStartRunningNotification/AVCaptureSessionDidStopRunningNotification
  [self.session startRunning];
	
	return YES;
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
  NSLog(@"TOUCHES BEGAN");
  self.tapToRecordLabel.layer.opacity = 0;
  self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateTicker:) userInfo:nil repeats:YES];
  NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
  
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
	NSString *destinationPath = [documentsDirectory stringByAppendingFormat:@"/output_%@.mov", [dateFormatter stringFromDate:[NSDate date]]];
  
  NSURL *outputFileURL = [NSURL fileURLWithPath:destinationPath];
  
  NSLog(@"CLAIMING URL IS %@", outputFileURL);
  AVCaptureMovieFileOutput *movieFileOutput;
  for(AVCaptureOutput *output in self.session.outputs) {
    NSLog(@"OUTPUT IS %@", output);
    if([output isKindOfClass:[AVCaptureMovieFileOutput class]]) {
      NSLog(@"USING OLD ONE");
      movieFileOutput = (AVCaptureMovieFileOutput *) output;
      movieFileOutput.index = [NSNumber numberWithInt:([movieFileOutput.index intValue] + 1)];
    }
  }
  if(!movieFileOutput) {
    NSLog(@"CREATING NEW ONE");
    movieFileOutput = [[AVCaptureMovieFileOutput alloc] initWithTag:[NSNumber numberWithInt:(completed + inProcess)]];
    [self.session addOutput:movieFileOutput];
  }
  NSLog(@"CREATED FILE OUTPUT");
  NSLog(@"ADDED TO SESSION");
  self.currentMovieFileOutput = movieFileOutput;
  NSLog(@"SAVED IT OFF");
  [movieFileOutput startRecordingToOutputFileURL:outputFileURL recordingDelegate:self];
  inProcess++;
  NSLog(@"STARTED RECORDING");
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
  NSLog(@"TOUCHES ENDED");
  [self.timer invalidate];
  [self.currentMovieFileOutput stopRecording];
}

-(void)updateTicker:(NSTimer *)sender {
  NSLog(@"CALLED TIMER TICKER");
  self.tickerLabel.text = [NSString stringWithFormat:@"%d", ++ticker];
}

# pragma mark AVCaptureOutputDelegate

-(void)captureOutput:(AVCaptureMovieFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error {
  if(error)
    NSLog(@"FINISHED WITH ERROR %@", [error localizedDescription]);
  else {
    completed++;
    inProcess--;
    NSLog(@"SUCCEEDED %@", captureOutput.index);
    // if the output's index is less than the movFiles array length
    // then this file is an earlier clip
    // and gets inserted at the right position
    if(captureOutput.index.integerValue < self.movFiles.count) {
      [self.movFiles insertObject:outputFileURL atIndex:[captureOutput.index integerValue]];
    }
    // otherwise just add it to the end of the array
    else {
      [self.movFiles addObject:outputFileURL];
    }
    // this good for memory management?
    for(AVCaptureMovieFileOutput *mvFileOutput in self.outputHandlers) {
      if(mvFileOutput == captureOutput) {
        [self.outputHandlers removeObject:mvFileOutput];
      }
    }
  }
}

# pragma mark UIControlEvents

-(void)onTouchSave:(UIButton *)sender {
  NSLog(@"PUSHED SAVE %d", self.movFiles.count);
  [self startLoading];
  AVMutableComposition *videoComposition = [AVMutableComposition new];
  CMTime time = kCMTimeZero;
  AVMutableCompositionTrack *compositionTrack = [videoComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
  AVMutableCompositionTrack *audioCompositionTrack = [videoComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
  for(NSURL *clipURL in self.movFiles) {
    NSError *error = nil;
    NSLog(@"MOV FILE %@", clipURL);
//    AVMutableCompositionTrack *compositionVideoTrack = [self.mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
//    [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, trimmedDuration) ofTrack:assetVideoTrack atTime:insertionPoint error:&error];
    AVAsset *track = [AVAsset assetWithURL:clipURL];
    if([[track tracksWithMediaType:AVMediaTypeVideo] count] > 0) {
      AVAssetTrack *videoTrack = [[track tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
      AVAssetTrack *audioTrack = [[track tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
      NSLog(@"THE DURATION IS %f", CMTimeGetSeconds(track.duration));
      
      
      AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
      AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionTrack];
      
      //
      // Apply a transformation to the video if one has been given. If a transformation is given it is combined
      // with the preferred transform contained in the incoming video track.
      //
//      if(transformToApply)
//      {
//        [layerInstruction setTransform:CGAffineTransformConcat(videoTrack.preferredTransform, transformToApply(videoTrack))
//                                atTime:kCMTimeZero];
//      }
//      else
//      {
      
      
      CGFloat ratioW = 200 / videoTrack.naturalSize.width;
      CGFloat ratioH = 200 / videoTrack.naturalSize.height;
      CGAffineTransform transform;
      if(ratioW < ratioH)
      {
        // When the ratios are larger than one, we must flip the translation.
        float neg = (ratioH > 1.0) ? 1.0 : -1.0;
        CGFloat diffH = videoTrack.naturalSize.height - (videoTrack.naturalSize.height * ratioH);
        transform = CGAffineTransformConcat( CGAffineTransformMakeTranslation(0, neg*diffH/2.0), CGAffineTransformMakeScale(ratioH, ratioH) );
      }
      else
      {
        // When the ratios are larger than one, we must flip the translation.
        float neg = (ratioW > 1.0) ? 1.0 : -1.0;
        CGFloat diffW = videoTrack.naturalSize.width - (videoTrack.naturalSize.width * ratioW);
        transform = CGAffineTransformConcat( CGAffineTransformMakeTranslation(neg*diffW/2.0, 0), CGAffineTransformMakeScale(ratioW, ratioW) );
      }

      
      [layerInstruction setTransform:transform
                              atTime:kCMTimeZero];
      
      instruction.layerInstructions = @[layerInstruction];
      
      __block CMTime startTime = kCMTimeZero;
      [instructions enumerateObjectsUsingBlock:^(AVMutableVideoCompositionInstruction *previousInstruction, NSUInteger idx, BOOL *stop) {
        startTime = CMTimeAdd(startTime, previousInstruction.timeRange.duration);
      }];
      instruction.timeRange = CMTimeRangeMake(startTime, track.duration);
      
      [instructions addObject:instruction];
      
      [compositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, track.duration)
                                ofTrack:videoTrack
                                 atTime:time
                                  error:&error];
      [audioCompositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, track.duration)
                                ofTrack:audioTrack
                                 atTime:time
                                  error:&error];
      if(error){
        NSLog(@"DID GET ERROR HERE %@", error.localizedDescription);
      }
      NSLog(@"THE TIME IS %f", CMTimeGetSeconds(time));
      time = CMTimeAdd(time, track.duration);
    }
  };
  
  // compositionTrack.preferredTransform = CGAffineTransformMakeRotation(M_PI_2);
  
  // Step 1
	// Create an outputURL to which the exported movie will be saved
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *outputURL = paths[0];
	NSFileManager *manager = [NSFileManager defaultManager];
	[manager createDirectoryAtPath:outputURL withIntermediateDirectories:YES attributes:nil error:nil];
	outputURL = [outputURL stringByAppendingPathComponent:@"output.mp4"];
	// Remove Existing File
	[manager removeItemAtPath:outputURL error:nil];
  
	NSLog(@"SAVING %d tracks", videoComposition.tracks.count);
	// Step 2
	// Create an export session with the composition and write the exported movie to the photo library
	self.exportSession = [[AVAssetExportSession alloc] initWithAsset:videoComposition presetName:AVAssetExportPresetHighestQuality];
  
  
	//exportSession.audioMix = self.mutableAudioMix;
  AVMutableVideoComposition *mutableVideoComp = [AVMutableVideoComposition new];
  AVMutableVideoCompositionInstruction *lastInstruction = ((AVMutableVideoCompositionInstruction *)instructions.lastObject);
  mutableVideoComp.frameDuration = CMTimeAdd(lastInstruction.timeRange.start, lastInstruction.timeRange.duration);
  mutableVideoComp.renderSize = CGSizeMake(200, 200);
  mutableVideoComp.instructions = instructions;
  
	self.exportSession.outputURL = [NSURL fileURLWithPath:outputURL];
	self.exportSession.outputFileType = AVFileTypeQuickTimeMovie;
  self.exportSession.videoComposition = mutableVideoComp;
  
	[self.exportSession exportAsynchronouslyWithCompletionHandler:^(void){
		switch (self.exportSession.status) {
			case AVAssetExportSessionStatusCompleted:
				[self writeVideoToPhotoLibrary:[NSURL fileURLWithPath:outputURL]];
        NSLog(@"WRITE TO LIB");
				break;
			case AVAssetExportSessionStatusFailed:
				NSLog(@"Failed:%@", self.exportSession.error);
				break;
			case AVAssetExportSessionStatusCancelled:
				NSLog(@"Canceled:%@", self.exportSession.error);
				break;
			default:
				break;
		}
	}];
  
  [self.movFiles removeAllObjects];
}

- (void)writeVideoToPhotoLibrary:(NSURL *)url
{
	ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
  AVAsset *asset = [AVAsset assetWithURL:url];
  float duration = CMTimeGetSeconds(asset.duration);
	NSLog(@"BOUT TO WRITE TRACK OF DURATION %f", duration);
	[library writeVideoAtPathToSavedPhotosAlbum:url completionBlock:^(NSURL *assetURL, NSError *error){
		if (error) {
			NSLog(@"Video could not be saved");
		}
    else {
      [self stopLoading];
      ticker = 0;
      self.tickerLabel.text = [NSString stringWithFormat:@"%d", ticker];
      self.tapToRecordLabel.layer.opacity = 1;
      NSLog(@"TOTALLY SAVED IT ALL GOOD");
      
      MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
      picker.mailComposeDelegate = self;
      [picker setSubject:@"Check out this image!"];
      
      // Set up recipients
      NSArray *toRecipients = [NSArray arrayWithObject:@"keithnorm@gmail.com"];
      // NSArray *ccRecipients = [NSArray arrayWithObjects:@"second@example.com", @"third@example.com", nil];
      // NSArray *bccRecipients = [NSArray arrayWithObject:@"fourth@example.com"];
      
      [picker setToRecipients:toRecipients];
      // [picker setCcRecipients:ccRecipients];
      // [picker setBccRecipients:bccRecipients];
      
      // Attach an image to the email
      NSData *vidData = [NSData dataWithContentsOfURL:url];
      NSLog(@"attached data of size %d", vidData.length);
      [picker addAttachmentData:vidData mimeType:@"video/quicktime" fileName:@"stuff.mov"];
      
      // Fill out the email body text
      NSString *emailBody = @"My cool image is attached";
      [picker setMessageBody:emailBody isHTML:NO];
      [self presentViewController:picker animated:YES completion:^{
        NSLog(@"DOINE MAILING IT");
      }];
    }
	}];
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
  // Notifies users about errors associated with the interface
  switch (result)
  {
    case MFMailComposeResultCancelled:
      NSLog(@"Result: canceled");
      break;
    case MFMailComposeResultSaved:
      NSLog(@"Result: saved");
      break;
    case MFMailComposeResultSent:
      NSLog(@"Result: sent");
      break;
    case MFMailComposeResultFailed:
      NSLog(@"Result: failed");
      break;
    default:
      NSLog(@"Result: not sent");
      break;
  }
  [self dismissViewControllerAnimated:YES completion:^{
    NSLog(@"dismissed controller");
  }];
}

-(void)startLoading {
//  spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
//  spinner.center=self.view.center;
//  [spinner startAnimating];
//  [self.view insertSubview:spinner atIndex:100];
//  [self.view bringSubviewToFront:spinner];
  self.loadingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
  self.progressBar = [[UIProgressView alloc] init];
  self.progressBar.frame = CGRectMake(0, 0, self.view.bounds.size.width - 140, 20);
  self.progressBar.center = self.view.center;
  CALayer *bgLayer = [[CALayer alloc] init];
  bgLayer.frame = self.loadingView.frame;
  bgLayer.backgroundColor = [[UIColor blackColor] CGColor];
  bgLayer.opacity = .5;
  [self.loadingView.layer addSublayer:bgLayer];
  [self.loadingView addSubview:self.progressBar];
  [self.view addSubview:self.loadingView];
  self.progressBar.progress = self.exportSession.progress;
  [self.view bringSubviewToFront:self.loadingView];
  self.exportTimer = [NSTimer scheduledTimerWithTimeInterval:.1 target:self selector:@selector(onExportTimer:) userInfo:nil repeats:YES];
  NSLog(@"SHOULD BE SPINNER SPINNIN");
}

-(void)stopLoading {
  NSLog(@"CALLED STOP LOADING");
  self.loadingView.hidden = YES;
  NSLog(@"HID THE VIEW");
  [self.loadingView removeFromSuperview];
  [self.view setNeedsDisplay];
  NSLog(@"FINISHED REMOVING VIEW");
//  [spinner stopAnimating];
//  [spinner removeFromSuperview];
}

-(void)onExportTimer:(NSTimer *)timer {
  self.progressBar.progress = self.exportSession.progress;
  if(self.exportSession.progress > .99) {
    [self.exportTimer invalidate];
  }
}

@end
