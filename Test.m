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

extern int main(int argc, char* argv[])		;

const struct sockaddr*		address;;

typedef void (*SourceNodeApplierFunction)(SourceNode* node, void* context);

#define FOO 1	
#undef FOO

@interface Demo : NSObject <NSCopying> {
@private
	int foo;
@public
	int _bar;
}
@property(nonatomic, readonly, getter=isValid)  BOOL valid;//
	+ (id) sharedInstance;
- (void) run; //  
- (BOOL) test:(int)foo bar:(int)bar;
- foo:(id)arg;
@end
;
;
struct temp {
    int   foo;
    int bar;
};

typedef union {
	int temp1;
    long    temp2;
} boom;

@implementation Demo//First pass
	
- (BOOL) test:(int)foo bar:(int)bar {
	for(int i = foo; i < bar; ++i)
    	printf("%i", i);
    for(;; ++i)
    	printf("%i", i);
    return NO;
}

static void Foo(int arg) {
	switch (arg) {
        case 1:
            printf("1");
            ;break;
        case 2:
        case 3:
            printf("2-3");
            break;
        case 4:
            printf("4");
            break;
        case 5:
        	printf("5");
        default:
        	printf("0");
            break;
    }
    
    printf("hello");
}

Bar() {
	if(1) {
        ;
    }
    else if(2) {
        if(3) {
            ;
        }
        else if(4) {
            ;
        }
        else
            break;
    }
    else {
        ;
    }
    return(0);
}

- test {
	return nil;
}

#if 1
#warning Foobar

- (BOOL) isValid {
    int temp1 = sizeof(long);
    SEL temp2 = @selector(foo:);
    
    ;
    
    goto Temp;
    
    if(0) goto Temp;
    
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
    
    if(1)
    	foo();
    else if(2)
    	bar();
    else
    	temp();
    
    while  (true) {
        ;
    }
    
    @try {
        @throw;
        NSBeep();
        @throw foo;
        if(0) @throw bar	;
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

#error Foobar

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
	return;
    NSLog(@"Running!");
    return  ;
}

@end

#pragma mark Label


	//The main function	
int main(int argc, char* argv[])
{
	return NSApplicationMain(argc, (const char**)argv); //Call this thing
}
