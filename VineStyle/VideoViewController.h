//
//  VideoViewController.h
//  VineStyle
//
//  Created by Keith Norman on 3/18/13.
//  Copyright (c) 2013 Ditty. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>
#import "AVCamCaptureManager.h"

@class AVCamCaptureManager, AVCamPreviewView, AVCaptureVideoPreviewLayer;

@interface VideoViewController : UIViewController <AVCaptureFileOutputRecordingDelegate, MFMailComposeViewControllerDelegate>

@property (nonatomic, retain) IBOutlet UIProgressView *progressView;
@property (nonatomic, retain) IBOutlet UILabel *tickerLabel;
@property (nonatomic, retain) IBOutlet UILabel *tapToRecordLabel;
@property (nonatomic, retain) IBOutlet UIButton *saveBtn;

@property (nonatomic,retain) AVCamCaptureManager *captureManager;
@property (nonatomic,retain) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;

@end
