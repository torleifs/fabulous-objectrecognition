//
//  ImageConverter.h
//  ObjectDetector2
//
//  Created by Torleif Sandnes on 14/12/2017.
//  Copyright © 2017 Telenor Capture AS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
@interface ImageConverter : NSObject
+ (CVPixelBufferRef) pixelBufferFromImage: (CGImageRef) image;
@end
