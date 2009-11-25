@implementation Demo
	
- bar {
	SEL temp = @selector(test:bar:);
    
    return nil;
}

- (BOOL) test:(int)foo bar:(int)bar {
	@synchronized ([self class]) {
    	self + 2;
    }
    return [super test:foo bar:bar];
}

@end

-----

<Root>
·  <ObjCImplementation>
·  ·  ♢@implementation♢•♢Demo♢¶♢→♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢-♢•♢bar♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢{♢¶♢→♢SEL♢•♢temp♢•♢=♢•♢
·  ·  ·  ·  <ObjCSelector>
·  ·  ·  ·  ·  ♢@selector♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢(♢test♢:♢bar♢:♢)♢
·  ·  ·  ·  ♢;♢¶♢••••♢¶♢••••♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢return♢•♢nil♢;♢
·  ·  ·  ·  ♢¶♢}♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢-♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢(♢BOOL♢)♢
·  ·  ·  ♢•♢test♢:♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢(♢int♢)♢
·  ·  ·  ♢foo♢•♢bar♢:♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢(♢int♢)♢
·  ·  ·  ♢bar♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢{♢¶♢→♢
·  ·  ·  ·  <ObjCSynchronized>
·  ·  ·  ·  ·  ♢@synchronized♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢(♢
·  ·  ·  ·  ·  ·  <Brackets>
·  ·  ·  ·  ·  ·  ·  ♢[♢self♢•♢class♢]♢
·  ·  ·  ·  ·  ·  ♢)♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢{♢¶♢••••→♢self♢•♢+♢•♢2♢;♢¶♢••••♢}♢
·  ·  ·  ·  ♢¶♢••••♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢return♢•♢
·  ·  ·  ·  ·  <Brackets>
·  ·  ·  ·  ·  ·  ♢[♢super♢•♢test♢:♢foo♢•♢bar♢:♢bar♢]♢
·  ·  ·  ·  ·  ♢;♢
·  ·  ·  ·  ♢¶♢}♢
·  ·  ♢¶♢¶♢@end♢
·  ♢¶♢¶♢
