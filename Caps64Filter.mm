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
    [window initViewerW:viewerController ];
  //  window.Vctrl=viewerController;
    [window showWindow:nil];
    //adjustment window created
  /*
    while(1){
        sleep(1);
        if(FilterReady){
            [self applyFilterToSeries];
            FilterReady=0;
        }
    }
*/
    return 0;
}


@end