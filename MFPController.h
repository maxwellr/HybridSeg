//
//  MFPController.h
//  Caps64
//
//  Created by Capstone Group 64 on 2015-01-16.
//
//

#import <Cocoa/Cocoa.h>
#import "Caps64Filter.h"
#include <opencv2/core/core.hpp>
#include <opencv2/highgui/highgui.hpp>
#include<opencv2/imgproc/imgproc.hpp>
#include<stdlib.h>
using namespace std;
using namespace cv;

@interface MFPController : NSWindowController{
    ViewerController* Vctrl;
}
@property(readonly) ViewerController* Vctrl;
-(void)initViewerW:(ViewerController*)mViewer;
- (IBAction)doSomething:(id)pId;
- (void) applyFilterToSeries;
- (Mat) lung_seg:(Mat)org_img;

@end

