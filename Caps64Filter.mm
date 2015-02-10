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
    [window showWindow:nil];
    //adjustment window created
    
    return 0;
}


@end