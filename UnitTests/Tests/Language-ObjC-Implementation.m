@implementation Demo
	
static void LocalFunction(int arg) {
	sleep(arg);
}

@synthesize foo, bar=_bar;

+ (id) uniqueID {
	@synchronized (self) {
    	;
    }
    return nil;
}

- bar {
	return nil;
}

- (BOOL) test:(int)foo bar:(int)bar {
	return NO;
}

@end

-----

<Root>
·  <ObjCImplementation>
·  ·  ♢|@implementation•Demo|♢¶♢|→|♢¶♢
·  ·  <CFunctionDefinition>
·  ·  ·  ♢|static|♢•♢|void|♢•♢|LocalFunction|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|int|♢•♢arg♢|)|♢
·  ·  ·  ♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|→|♢
·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ♢|sleep|♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢arg♢|)|♢
·  ·  ·  ·  ♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCSynthesize>
·  ·  ·  ♢|@synthesize|♢•♢foo,♢•♢bar=_bar♢|;|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢+♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢id♢|)|♢
·  ·  ·  ♢•♢uniqueID♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|→|♢
·  ·  ·  ·  <ObjCSynchronized>
·  ·  ·  ·  ·  ♢|@synchronized|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢|self|♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••→|♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢|nil|♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢-♢•♢bar♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|→|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢|nil|♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢-♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢•♢test♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|int|♢|)|♢
·  ·  ·  ♢foo♢•♢bar♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|int|♢|)|♢
·  ·  ·  ♢bar♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|→|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢NO♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|@end|♢
·  ♢¶♢¶♢
