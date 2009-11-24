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

typedef void (*SourceNodeApplierFunction)(SourceNode* node, void* context);

extern int main(int argc, char* argv[]);
extern Bar();

const char* multiline = "foo\	
 b\\ar\  
  boom";

static inline BOOL _IsRealLineBreak(const unichar* string) {
	if(!IsNewline(*string) > 0)
        return NO  ;
    do {
    	--string;
    } while  (IsWhiteSpaceOrNewline(*string))	;
    return *string != '\\';
}

@protocol Temp
+ (void) temp2;
- (void) temp1;
@end


#define FOO 1	
#undef FOO

@interface Demo : NSObject <NSCopying> {
@private
	int foo;
@public
	int _bar;
}
@property(nonatomic, readonly, getter=isValid) BOOL valid;//
	+ (id) sharedInstance;
- (void) run; //  
- (BOOL) test:(int)foo bar:(int)bar;
- foo:(id)arg;
@end

struct temp {
    int foo;
    int bar;
};

typedef union {
	int temp1;
    long temp2;
} boom;

@implementation Demo//First pass
	
- (BOOL) test:(int)foo bar:(int)bar {
	return NO;
}

static void Foo() {
	printf("hello");
}

Bar() {
	return 0;
}

- test {
	return nil;
}

#if 1

- (BOOL) isValid {
    int temp1 = sizeof(long);
    SEL temp2 = @selector(foo:);
    
    ;
    
    if(1) {
    	foo();
    } else if(2) {
    	bar();
    } else {
    	temp();
    }
    
    if(1)
    	foo();
    else
    	bar();
    
    while  (true) {
        ;
    }
    
    @try {
        @throw;
        NSBeep();
        @throw exception;
    }
    @catch (NSException * e)
    {
        NSLog(@"%@", e);
    }
    @finally {
        NSLog(@"Done");
    }
	return [super isValid];
}

#else

- (BOOL) isValid
{
	{
    	subblock();
    }
    
    for(int i = 2; i < 10; ++i)
    
    
    
    {
    	NSLog("PING");
    }
    @synchronized ([self class]){
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
