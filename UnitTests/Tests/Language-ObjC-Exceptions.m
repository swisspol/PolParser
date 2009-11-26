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
·  ·  ·  ♢{♢¶♢••••♢|@throw|♢|;|♢¶♢••••♢
·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ♢NSBeep♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢(♢)♢
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
·  ·  ·  ♢{♢¶♢••••♢
·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ♢NSLog♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢(♢|@"%@"|♢,♢•♢e♢)♢
·  ·  ·  ♢|;|♢¶♢}♢
·  ♢¶♢
·  <ObjCFinally>
·  ·  ♢@finally♢•♢
·  ·  <Braces>
·  ·  ·  ♢{♢¶♢••••♢
·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ♢NSLog♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢(♢|@"Done"|♢)♢
·  ·  ·  ♢|;|♢¶♢}♢
·  ♢¶♢¶♢
