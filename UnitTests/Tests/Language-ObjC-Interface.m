@protocol Cocoa
- (BOOL) test:(int)foo bar:(int)bar;
@end

@interface Demo : NSObject <Cocoa> {
@private
	int foo;
@public
	int _bar;
}
@property(nonatomic, readonly, getter=isValid)  BOOL valid;
+ (id) sharedInstance;
- (void) run;
- foo:(id)arg;
- bar;
@end

-----

<Root>
·  <ObjCProtocol>
·  ·  ♢@protocol♢•♢Cocoa♢¶♢
·  ·  <ObjCMethodDeclaration>
·  ·  ·  ♢-♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢(♢BOOL♢)♢
·  ·  ·  ♢•♢test♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢(♢int♢)♢
·  ·  ·  ♢foo♢•♢bar♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢(♢int♢)♢
·  ·  ·  ♢bar♢|;|♢
·  ·  ♢¶♢@end♢
·  ♢¶♢¶♢
·  <ObjCInterface>
·  ·  ♢@interface♢•♢Demo♢•♢|:|♢•♢NSObject♢•♢<Cocoa>♢•♢
·  ·  <Braces>
·  ·  ·  ♢{♢¶♢|@private|♢¶♢→♢int♢•♢foo♢|;|♢¶♢|@public|♢¶♢→♢int♢•♢_bar♢|;|♢¶♢}♢
·  ·  ♢¶♢
·  ·  <ObjCProperty>
·  ·  ·  ♢@property♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢(♢nonatomic,♢•♢readonly,♢•♢getter=isValid♢)♢
·  ·  ·  ♢••♢BOOL♢•♢valid♢|;|♢
·  ·  ♢¶♢
·  ·  <ObjCMethodDeclaration>
·  ·  ·  ♢+♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢(♢id♢)♢
·  ·  ·  ♢•♢sharedInstance♢|;|♢
·  ·  ♢¶♢
·  ·  <ObjCMethodDeclaration>
·  ·  ·  ♢-♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢(♢|void|♢)♢
·  ·  ·  ♢•♢run♢|;|♢
·  ·  ♢¶♢
·  ·  <ObjCMethodDeclaration>
·  ·  ·  ♢-♢•♢foo♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢(♢id♢)♢
·  ·  ·  ♢arg♢|;|♢
·  ·  ♢¶♢
·  ·  <ObjCMethodDeclaration>
·  ·  ·  ♢-♢•♢bar♢|;|♢
·  ·  ♢¶♢@end♢
·  ♢¶♢¶♢
