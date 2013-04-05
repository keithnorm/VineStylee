//
//  AVCaptureMovieFileOutput+AVCaptureMovieFileOutput_tag.m
//  VineStyle
//
//  Created by Keith Norman on 3/31/13.
//  Copyright (c) 2013 Ditty. All rights reserved.
//

#import "AVCaptureMovieFileOutput+AVCaptureMovieFileOutput_tag.h"
#import <objc/runtime.h>

static char *kAVCaptureKey = "kAVCaptureKey";

@implementation AVCaptureMovieFileOutput (AVCaptureMovieFileOutput_tag)

-(NSNumber *)index {
  return objc_getAssociatedObject(self, kAVCaptureKey);
}

-(void)setIndex:(NSNumber *)index {
  objc_setAssociatedObject(self, kAVCaptureKey, index, OBJC_ASSOCIATION_COPY);
}

-(AVCaptureMovieFileOutput *)initWithTag:(NSNumber *)tag {
  self.index = tag;
  return [self init];
}

@end
