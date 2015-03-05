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
#include<stdio.h>
#include <fstream>



using namespace std;
using namespace cv;

@interface MFPController : NSWindowController{
    NSArray* Vctrl;
    NSPoint mouseLoc;
    bool useSharp;
    vector<Mat> lungMask;
    vector<Mat> boneMask;
    vector<Mat> softMask;
    vector<Mat> lungborder;
    vector<Mat> orgSeries;
    vector<Mat> orgSeriesSharp;
    IBOutlet NSTextField *LW;
    IBOutlet NSTextField *LL;
    IBOutlet NSTextField *BW;
    IBOutlet NSTextField *BL;
    IBOutlet NSTextField *RW;
    IBOutlet NSTextField *RL;
    
    IBOutlet NSButton *CBL;
    IBOutlet NSButton *CBB;
    IBOutlet NSButton *CBS;

    
    IBOutlet NSPopUpButton *lungPop;
    IBOutlet NSPopUpButton *bonePop;
    IBOutlet NSPopUpButton *restPop;
}
@property(readonly) NSArray* Vctrl;

@property (strong, nonatomic) IBOutlet NSTextField *LW;
@property (strong, nonatomic) IBOutlet NSTextField *LL;
@property (strong, nonatomic) IBOutlet NSTextField *BW;
@property (strong, nonatomic) IBOutlet NSTextField *BL;
@property (strong, nonatomic) IBOutlet NSTextField *RW;
@property (strong, nonatomic) IBOutlet NSTextField *RL;

@property (strong, nonatomic) IBOutlet NSButton *CBL;
@property (strong, nonatomic) IBOutlet NSButton *CBB;
@property (strong, nonatomic) IBOutlet NSButton *CBS;

@property (strong, nonatomic) IBOutlet NSPopUpButton *lungPop;
@property (strong, nonatomic) IBOutlet NSPopUpButton *bonePop;
@property (strong, nonatomic) IBOutlet NSPopUpButton *restPop;




-(void)mouseDown:(NSEvent *)event;
-(void)mouseUp:(NSEvent *)event;
-(void)mouseDragged:(NSEvent *)theEvent;


// GUI functions //
-(void)updateSingle;
-(void)initViewerW:(NSArray*)mViewer; //get pointer of current  viewer
-(void)initMasks; // initilize masks after first load
-(void)UpdateView; //Update current view hybrid with current settings
-(Mat) ApplyHybrid:(int)SliceN; // reads the settings on GUI and returns a hybrid mat file

-(IBAction)PopChanged:(id)pId;

- (IBAction)doSomething:(id)pId; //push button action
- (IBAction)CallUpdate:(id)pId;
-(float) GRYtoDcmPix:(unsigned char)GRY;
-(unsigned char) DcmPixtoGRY:(float)DcmPix;
-(double) findthresh:(Mat)image;


// Segmentation functions //

- (Mat) lung_seg:(Mat)org_img :(int)type;  // lung_seg, returns lung mask
- (Mat) bone_seg:(Mat)org_img;  // bone_seg, returns bone mask
- (Mat) soft_seg:(Mat) slice :(Mat) lungmask :(Mat) bonemask; // soft_seg, returns soft tissue mask
- (Mat) applyWin:(Mat)image :(float) wndw :(float) level; // applies window to a given mat file
//- (Mat) lung_seg_inv:(Mat)org_img;
- (Mat) applyWin:(Mat)image :(float) wndw :(float) level;

@end

