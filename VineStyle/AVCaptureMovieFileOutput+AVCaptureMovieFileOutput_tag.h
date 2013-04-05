//
//  AVCaptureMovieFileOutput+AVCaptureMovieFileOutput_tag.h
//  VineStyle
//
//  Created by Keith Norman on 3/31/13.
//  Copyright (c) 2013 Ditty. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

@interface AVCaptureMovieFileOutput (AVCaptureMovieFileOutput_tag)

@property (nonatomic, strong) NSNumber *index;

-(AVCaptureMovieFileOutput *)initWithTag:(NSNumber *)tag;

@end
