//
//  Caps64Filter.h
//  Caps64
//
//  Copyright (c) 2015 RJS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OsiriXAPI/PluginFilter.h>
@interface Caps64Filter : PluginFilter {

}

- (long) filterImage:(NSString*) menuName;
@end
