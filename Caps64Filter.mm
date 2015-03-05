//
//  Caps64Filter.m
//  Caps64
//
//  Copyright (c) 2015 RJS. All rights reserved.

#import "MFPController.h"



@implementation Caps64Filter
- (void) initPlugin
{
}

- (long) filterImage:(NSString*) menuName
{
    
    //Create the adjustment window
    MFPController *window = [[MFPController alloc] initWithWindowNibName:@"MFPController"];
   
    NSArray *viewers = [ViewerController getDisplayed2DViewers];

    [window initViewerW:viewers ];
    [window showWindow:nil];
    [window.window setLevel: NSMainMenuWindowLevel];
    //adjustment window created
    
    return 0;
}


@end