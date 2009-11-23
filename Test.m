/*
	This file is part of the PolParser library.
	Copyright (C) 2009 Pierre-Olivier Latour <info@pol-online.net>
*/

#import <Foundation/Foundation.h>	
#import <AppKit/AppKit.h> //  FIXME: Don't include this	

#if OBJC_EXPORT
#include "Foobar.h"	
#endif

//This is a \   
multiline comment	

#define IsWhiteSpaceOrNewline(C) ((C == ' ') || (C == '\t') || (C == '\n')) //Very cool!

#define multiline(x, y) \  
	(x + y)     

#define IS_MATCHING_PREFIX_METHOD(__PREFIX__) \
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    IS_MATCHING(__PREFIX__, false, 0, string, maxLength) \
    return _matching; \
}

const char* multiline = "foo\	
 b\\ar\  
  boom";

static inline BOOL _IsRealLineBreak(const unichar* string) {
	if(!IsNewline(*string) > 0)
        return NO;
    do {
    	--string;
    } while(IsWhiteSpaceOrNewline(*string));
    return *string != '\\';
}

#define FOO 1	
#undef FOO

@interface Demo : NSObject <NSCopying> {
@private
	int foo;
@public
	int _bar;
}
@property(nonatomic, readonly, getter=isValid) BOOL valid;
- (void) run;
@end

@implementation Demo

#if 1

- (BOOL) isValid {
    int temp;
    
    ;
    
    @try {
        @throw;
        NSBeep();
        @throw exception;
    }
    @catch (NSException * e) {
        NSLog(@"%@", e);
    }
    @finally {
        NSLog(@"Done");
    }
	return NO;
}

#else

- (BOOL) isValid {
	@synchronized ([self class]) {
    	self + 2;
    }
    return YES;
}

#endif

- (void) run {
	NSLog(@"Running!");
}

@end

#pragma mark Label


//The main function	
int main(int argc, char* argv[])
{
	return NSApplicationMain(argc, (const char**)argv); //Call this thing
}