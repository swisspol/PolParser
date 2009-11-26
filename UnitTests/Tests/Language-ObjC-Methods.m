SEL temp = @selector(test:bar:);

NSString* string1 = [NSString stringWithFormat:@"%@-%@", @"foo", @"bar"];

NSString* string2 = [NSString stringWithContentsOfFile:[@"~/foo.bar" stringByExpandingTildeInPath] encoding:NSUTF8StringEncoding error:GetDefaultEncoding()];

NSString* string3 = [NSUserName() lowercaseString];

NSString* string4 = [[@"~/foo.bar" stringByExpandingTildeInPath] stringByDeletingLastPathComponent];

NSDictionary* dictionary = [[NSProcessInfo processInfo] environment];

[super test:foo bar:bar];

-----

<Root>
·  ♢SEL♢•♢temp♢•♢=♢•♢
·  <ObjCSelector>
·  ·  ♢@selector♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢test♢|:|♢bar♢|:|♢|)|♢
·  ♢|;|♢¶♢¶♢NSString♢|*|♢•♢string1♢•♢=♢•♢
·  <ObjCMethodCall>
·  ·  ♢|[|♢NSString♢•♢stringWithFormat♢|:|♢|@"%@-%@"|♢,♢•♢|@"foo"|♢,♢•♢|@"bar"|♢|]|♢
·  ♢|;|♢¶♢¶♢NSString♢|*|♢•♢string2♢•♢=♢•♢
·  <ObjCMethodCall>
·  ·  ♢|[|♢NSString♢•♢stringWithContentsOfFile♢|:|♢
·  ·  <ObjCMethodCall>
·  ·  ·  ♢|[|♢|@"~/foo.bar"|♢•♢stringByExpandingTildeInPath♢|]|♢
·  ·  ♢•♢encoding♢|:|♢NSUTF8StringEncoding♢•♢error♢|:|♢
·  ·  <CFunctionCall>
·  ·  ·  ♢GetDefaultEncoding♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ♢|]|♢
·  ♢|;|♢¶♢¶♢NSString♢|*|♢•♢string3♢•♢=♢•♢
·  <ObjCMethodCall>
·  ·  ♢|[|♢
·  ·  <CFunctionCall>
·  ·  ·  ♢NSUserName♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ♢•♢lowercaseString♢|]|♢
·  ♢|;|♢¶♢¶♢NSString♢|*|♢•♢string4♢•♢=♢•♢
·  <ObjCMethodCall>
·  ·  ♢|[|♢
·  ·  <ObjCMethodCall>
·  ·  ·  ♢|[|♢|@"~/foo.bar"|♢•♢stringByExpandingTildeInPath♢|]|♢
·  ·  ♢•♢stringByDeletingLastPathComponent♢|]|♢
·  ♢|;|♢¶♢¶♢NSDictionary♢|*|♢•♢dictionary♢•♢=♢•♢
·  <ObjCMethodCall>
·  ·  ♢|[|♢
·  ·  <ObjCMethodCall>
·  ·  ·  ♢|[|♢NSProcessInfo♢•♢processInfo♢|]|♢
·  ·  ♢•♢environment♢|]|♢
·  ♢|;|♢¶♢¶♢
·  <ObjCMethodCall>
·  ·  ♢|[|♢|super|♢•♢test♢|:|♢foo♢•♢bar♢|:|♢bar♢|]|♢
·  ♢|;|♢¶♢¶♢
