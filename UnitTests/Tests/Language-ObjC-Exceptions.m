@try {
    @throw;
    NSBeep();
    @throw foo;
    
    if(0) @throw bar;
}
@catch (NSException * e)
{
    NSLog(@"%@", e);
}
@finally {
    NSLog(@"Done");
}

-----

<Root>
·  <ObjCTry>
·  ·  ♢@try♢•♢
·  ·  <Braces>
·  ·  ·  ♢{♢¶♢••••♢|@throw|♢|;|♢¶♢••••♢NSBeep♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢(♢)♢
·  ·  ·  ♢|;|♢¶♢••••♢
·  ·  ·  <ObjCThrow>
·  ·  ·  ·  ♢@throw♢•♢foo♢|;|♢
·  ·  ·  ♢¶♢••••♢¶♢••••♢
·  ·  ·  <CConditionIf>
·  ·  ·  ·  ♢if♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢(♢0♢)♢
·  ·  ·  ·  ♢•♢
·  ·  ·  ·  <ObjCThrow>
·  ·  ·  ·  ·  ♢@throw♢•♢bar♢|;|♢
·  ·  ·  ♢¶♢}♢
·  ♢¶♢
·  <ObjCCatch>
·  ·  ♢@catch♢•♢
·  ·  <Parenthesis>
·  ·  ·  ♢(♢NSException♢•♢|*|♢•♢e♢)♢
·  ·  ♢¶♢
·  ·  <Braces>
·  ·  ·  ♢{♢¶♢••••♢NSLog♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢(♢|@"%@"|♢,♢•♢e♢)♢
·  ·  ·  ♢|;|♢¶♢}♢
·  ♢¶♢
·  <ObjCFinally>
·  ·  ♢@finally♢•♢
·  ·  <Braces>
·  ·  ·  ♢{♢¶♢••••♢NSLog♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢(♢|@"Done"|♢)♢
·  ·  ·  ♢|;|♢¶♢}♢
·  ♢¶♢¶♢
