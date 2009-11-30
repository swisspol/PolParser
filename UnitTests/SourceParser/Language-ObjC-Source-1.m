/*
    This file is part of the PolParser library.
    Copyright (C) 2009 Pierre-Olivier Latour <info@pol-online.net>
*/

#import <UIKit/UIKit.h>

extern int main(int argc, char *argv[]);

@interface Main : NSObject
- (int) main:(int)argc :(char*[])argv;
@end

@implementation Main

- (int) main:(int)argc :(char*[])argv {
	return main(argc, argv);
}

@end

int main(int argc, char *argv[]) {
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
    Main* main = [Main new];
	int result = [main main:argc :argv];
	[main release];
    
    [pool release];
    
	return result;
}

<----->

<Root>
·  ♢|/*¶••••This•file•is•part•of•the•PolParser•library.¶••••Copyright•(C)•2009•Pierre-Olivier•Latour•<info@pol-online.net>¶*/|♢¶♢¶♢
·  <ObjCPreprocessorImport>
·  ·  ♢|#import|♢•♢<UIKit/UIKit.h>♢
·  ♢¶♢¶♢
·  <CFunctionPrototype>
·  ·  ♢|extern|♢•♢|int|♢•♢|main|♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢|int|♢•♢argc,♢•♢|char|♢•♢|*|♢argv♢
·  ·  ·  <Brackets>
·  ·  ·  ·  ♢|[|♢|]|♢
·  ·  ·  ♢|)|♢
·  ·  ♢|;|♢
·  ♢¶♢¶♢
·  <ObjCInterface>
·  ·  ♢|@interface•Main•:•NSObject|♢¶♢
·  ·  <ObjCMethodDeclaration>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|int|♢|)|♢
·  ·  ·  ♢•♢main♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|int|♢|)|♢
·  ·  ·  ♢argc♢•♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|char|♢|*|♢
·  ·  ·  ·  <Brackets>
·  ·  ·  ·  ·  ♢|[|♢|]|♢
·  ·  ·  ·  ♢|)|♢
·  ·  ·  ♢argv♢|;|♢
·  ·  ♢¶♢|@end|♢
·  ♢¶♢¶♢
·  <ObjCImplementation>
·  ·  ♢|@implementation•Main|♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|int|♢|)|♢
·  ·  ·  ♢•♢main♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|int|♢|)|♢
·  ·  ·  ♢argc♢•♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|char|♢|*|♢
·  ·  ·  ·  <Brackets>
·  ·  ·  ·  ·  ♢|[|♢|]|♢
·  ·  ·  ·  ♢|)|♢
·  ·  ·  ♢argv♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|→|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢
·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ♢|main|♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢argc,♢•♢argv♢|)|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|@end|♢
·  ♢¶♢¶♢
·  <CFunctionDefinition>
·  ·  ♢|int|♢•♢|main|♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢|int|♢•♢argc,♢•♢|char|♢•♢|*|♢argv♢
·  ·  ·  <Brackets>
·  ·  ·  ·  ♢|[|♢|]|♢
·  ·  ·  ♢|)|♢
·  ·  ♢•♢
·  ·  <Braces>
·  ·  ·  ♢|{|♢¶♢|→|♢NSAutoreleasePool♢|*|♢•♢pool♢•♢=♢•♢
·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|NSAutoreleasePool|♢•♢alloc♢|]|♢
·  ·  ·  ·  ♢•♢init♢|]|♢
·  ·  ·  ♢|;|♢¶♢|→|♢¶♢|••••|♢Main♢|*|♢•♢main♢•♢=♢•♢
·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ♢|[|♢|Main|♢•♢new♢|]|♢
·  ·  ·  ♢|;|♢¶♢|→|♢|int|♢•♢result♢•♢=♢•♢
·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ♢|[|♢|main|♢•♢main♢|:|♢argc♢•♢|:|♢argv♢|]|♢
·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ♢|[|♢|main|♢•♢release♢|]|♢
·  ·  ·  ♢|;|♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ♢|[|♢|pool|♢•♢release♢|]|♢
·  ·  ·  ♢|;|♢¶♢|••••|♢¶♢|→|♢
·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ♢|return|♢•♢result♢|;|♢
·  ·  ·  ♢¶♢|}|♢
·  ♢¶♢¶♢

<----->

[1:34] <Root>
|    [1:4] <CComment> = ♢/*¶••••This•file•is•part•of•the•PolParser•library.¶••••Copyright•(C)•2009•Pierre-Olivier•Latour•<info@pol-online.net>¶*/♢
|    + <cleaned> = ♢¶••••This•file•is•part•of•the•PolParser•library.¶••••Copyright•(C)•2009•Pierre-Olivier•Latour•<info@pol-online.net>¶♢
|    [4:5] <Newline> = ♢¶♢
|    [5:6] <Newline> = ♢¶♢
|    [6:6] <ObjCPreprocessorImport>
|    + <name> = ♢<UIKit/UIKit.h>♢
|    |    [6:6] <Match> = ♢#import♢
|    |    [6:6] <Whitespace> = ♢•♢
|    |    [6:6] <Text> = ♢<UIKit/UIKit.h>♢
|    [6:7] <Newline> = ♢¶♢
|    [7:8] <Newline> = ♢¶♢
|    [8:8] <CFunctionPrototype>
|    + <name> = ♢main♢
|    |    [8:8] <CExtern> = ♢extern♢
|    |    [8:8] <Whitespace> = ♢•♢
|    |    [8:8] <CInt> = ♢int♢
|    |    [8:8] <Whitespace> = ♢•♢
|    |    [8:8] <Match> = ♢main♢
|    |    [8:8] <Parenthesis>
|    |    |    [8:8] <Match> = ♢(♢
|    |    |    [8:8] <CInt> = ♢int♢
|    |    |    [8:8] <Whitespace> = ♢•♢
|    |    |    [8:8] <Text> = ♢argc,♢
|    |    |    [8:8] <Whitespace> = ♢•♢
|    |    |    [8:8] <CChar> = ♢char♢
|    |    |    [8:8] <Whitespace> = ♢•♢
|    |    |    [8:8] <Asterisk> = ♢*♢
|    |    |    [8:8] <Text> = ♢argv♢
|    |    |    [8:8] <Brackets>
|    |    |    |    [8:8] <Match> = ♢[♢
|    |    |    |    [8:8] <Match> = ♢]♢
|    |    |    [8:8] <Match> = ♢)♢
|    |    [8:8] <Semicolon> = ♢;♢
|    [8:9] <Newline> = ♢¶♢
|    [9:10] <Newline> = ♢¶♢
|    [10:12] <ObjCInterface>
|    |    [10:10] <Match> = ♢@interface•Main•:•NSObject♢
|    |    [10:11] <Newline> = ♢¶♢
|    |    [11:11] <ObjCMethodDeclaration>
|    |    + <name> = ♢main::♢
|    |    |    [11:11] <Match> = ♢-♢
|    |    |    [11:11] <Whitespace> = ♢•♢
|    |    |    [11:11] <Parenthesis>
|    |    |    |    [11:11] <Match> = ♢(♢
|    |    |    |    [11:11] <CInt> = ♢int♢
|    |    |    |    [11:11] <Match> = ♢)♢
|    |    |    [11:11] <Whitespace> = ♢•♢
|    |    |    [11:11] <Text> = ♢main♢
|    |    |    [11:11] <Colon> = ♢:♢
|    |    |    [11:11] <Parenthesis>
|    |    |    |    [11:11] <Match> = ♢(♢
|    |    |    |    [11:11] <CInt> = ♢int♢
|    |    |    |    [11:11] <Match> = ♢)♢
|    |    |    [11:11] <Text> = ♢argc♢
|    |    |    [11:11] <Whitespace> = ♢•♢
|    |    |    [11:11] <Colon> = ♢:♢
|    |    |    [11:11] <Parenthesis>
|    |    |    |    [11:11] <Match> = ♢(♢
|    |    |    |    [11:11] <CChar> = ♢char♢
|    |    |    |    [11:11] <Asterisk> = ♢*♢
|    |    |    |    [11:11] <Brackets>
|    |    |    |    |    [11:11] <Match> = ♢[♢
|    |    |    |    |    [11:11] <Match> = ♢]♢
|    |    |    |    [11:11] <Match> = ♢)♢
|    |    |    [11:11] <Text> = ♢argv♢
|    |    |    [11:11] <Semicolon> = ♢;♢
|    |    [11:12] <Newline> = ♢¶♢
|    |    [12:12] <Match> = ♢@end♢
|    [12:13] <Newline> = ♢¶♢
|    [13:14] <Newline> = ♢¶♢
|    [14:20] <ObjCImplementation>
|    |    [14:14] <Match> = ♢@implementation•Main♢
|    |    [14:15] <Newline> = ♢¶♢
|    |    [15:16] <Newline> = ♢¶♢
|    |    [16:18] <ObjCMethodImplementation>
|    |    + <name> = ♢main::♢
|    |    |    [16:16] <Match> = ♢-♢
|    |    |    [16:16] <Whitespace> = ♢•♢
|    |    |    [16:16] <Parenthesis>
|    |    |    |    [16:16] <Match> = ♢(♢
|    |    |    |    [16:16] <CInt> = ♢int♢
|    |    |    |    [16:16] <Match> = ♢)♢
|    |    |    [16:16] <Whitespace> = ♢•♢
|    |    |    [16:16] <Text> = ♢main♢
|    |    |    [16:16] <Colon> = ♢:♢
|    |    |    [16:16] <Parenthesis>
|    |    |    |    [16:16] <Match> = ♢(♢
|    |    |    |    [16:16] <CInt> = ♢int♢
|    |    |    |    [16:16] <Match> = ♢)♢
|    |    |    [16:16] <Text> = ♢argc♢
|    |    |    [16:16] <Whitespace> = ♢•♢
|    |    |    [16:16] <Colon> = ♢:♢
|    |    |    [16:16] <Parenthesis>
|    |    |    |    [16:16] <Match> = ♢(♢
|    |    |    |    [16:16] <CChar> = ♢char♢
|    |    |    |    [16:16] <Asterisk> = ♢*♢
|    |    |    |    [16:16] <Brackets>
|    |    |    |    |    [16:16] <Match> = ♢[♢
|    |    |    |    |    [16:16] <Match> = ♢]♢
|    |    |    |    [16:16] <Match> = ♢)♢
|    |    |    [16:16] <Text> = ♢argv♢
|    |    |    [16:16] <Whitespace> = ♢•♢
|    |    |    [16:18] <Braces>
|    |    |    |    [16:16] <Match> = ♢{♢
|    |    |    |    [16:17] <Newline> = ♢¶♢
|    |    |    |    [17:17] <Indenting> = ♢→♢
|    |    |    |    [17:17] <CFlowReturn>
|    |    |    |    |    [17:17] <Match> = ♢return♢
|    |    |    |    |    [17:17] <Whitespace> = ♢•♢
|    |    |    |    |    [17:17] <CFunctionCall>
|    |    |    |    |    + <name> = ♢main♢
|    |    |    |    |    |    [17:17] <Match> = ♢main♢
|    |    |    |    |    |    [17:17] <Parenthesis>
|    |    |    |    |    |    |    [17:17] <Match> = ♢(♢
|    |    |    |    |    |    |    [17:17] <Text> = ♢argc,♢
|    |    |    |    |    |    |    [17:17] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [17:17] <Text> = ♢argv♢
|    |    |    |    |    |    |    [17:17] <Match> = ♢)♢
|    |    |    |    |    [17:17] <Semicolon> = ♢;♢
|    |    |    |    [17:18] <Newline> = ♢¶♢
|    |    |    |    [18:18] <Match> = ♢}♢
|    |    [18:19] <Newline> = ♢¶♢
|    |    [19:20] <Newline> = ♢¶♢
|    |    [20:20] <Match> = ♢@end♢
|    [20:21] <Newline> = ♢¶♢
|    [21:22] <Newline> = ♢¶♢
|    [22:32] <CFunctionDefinition>
|    + <name> = ♢main♢
|    |    [22:22] <CInt> = ♢int♢
|    |    [22:22] <Whitespace> = ♢•♢
|    |    [22:22] <Match> = ♢main♢
|    |    [22:22] <Parenthesis>
|    |    |    [22:22] <Match> = ♢(♢
|    |    |    [22:22] <CInt> = ♢int♢
|    |    |    [22:22] <Whitespace> = ♢•♢
|    |    |    [22:22] <Text> = ♢argc,♢
|    |    |    [22:22] <Whitespace> = ♢•♢
|    |    |    [22:22] <CChar> = ♢char♢
|    |    |    [22:22] <Whitespace> = ♢•♢
|    |    |    [22:22] <Asterisk> = ♢*♢
|    |    |    [22:22] <Text> = ♢argv♢
|    |    |    [22:22] <Brackets>
|    |    |    |    [22:22] <Match> = ♢[♢
|    |    |    |    [22:22] <Match> = ♢]♢
|    |    |    [22:22] <Match> = ♢)♢
|    |    [22:22] <Whitespace> = ♢•♢
|    |    [22:32] <Braces>
|    |    |    [22:22] <Match> = ♢{♢
|    |    |    [22:23] <Newline> = ♢¶♢
|    |    |    [23:23] <Indenting> = ♢→♢
|    |    |    [23:23] <Text> = ♢NSAutoreleasePool♢
|    |    |    [23:23] <Asterisk> = ♢*♢
|    |    |    [23:23] <Whitespace> = ♢•♢
|    |    |    [23:23] <Text> = ♢pool♢
|    |    |    [23:23] <Whitespace> = ♢•♢
|    |    |    [23:23] <Text> = ♢=♢
|    |    |    [23:23] <Whitespace> = ♢•♢
|    |    |    [23:23] <ObjCMethodCall>
|    |    |    + <name> = ♢init♢
|    |    |    |    [23:23] <Match> = ♢[♢
|    |    |    |    [23:23] <ObjCMethodCall>
|    |    |    |    + <name> = ♢alloc♢
|    |    |    |    |    [23:23] <Match> = ♢[♢
|    |    |    |    |    [23:23] <Match> = ♢NSAutoreleasePool♢
|    |    |    |    |    [23:23] <Whitespace> = ♢•♢
|    |    |    |    |    [23:23] <Text> = ♢alloc♢
|    |    |    |    |    [23:23] <Match> = ♢]♢
|    |    |    |    [23:23] <Whitespace> = ♢•♢
|    |    |    |    [23:23] <Text> = ♢init♢
|    |    |    |    [23:23] <Match> = ♢]♢
|    |    |    [23:23] <Semicolon> = ♢;♢
|    |    |    [23:24] <Newline> = ♢¶♢
|    |    |    [24:24] <Indenting> = ♢→♢
|    |    |    [24:25] <Newline> = ♢¶♢
|    |    |    [25:25] <Indenting> = ♢••••♢
|    |    |    [25:25] <Text> = ♢Main♢
|    |    |    [25:25] <Asterisk> = ♢*♢
|    |    |    [25:25] <Whitespace> = ♢•♢
|    |    |    [25:25] <Text> = ♢main♢
|    |    |    [25:25] <Whitespace> = ♢•♢
|    |    |    [25:25] <Text> = ♢=♢
|    |    |    [25:25] <Whitespace> = ♢•♢
|    |    |    [25:25] <ObjCMethodCall>
|    |    |    + <name> = ♢new♢
|    |    |    |    [25:25] <Match> = ♢[♢
|    |    |    |    [25:25] <Match> = ♢Main♢
|    |    |    |    [25:25] <Whitespace> = ♢•♢
|    |    |    |    [25:25] <Text> = ♢new♢
|    |    |    |    [25:25] <Match> = ♢]♢
|    |    |    [25:25] <Semicolon> = ♢;♢
|    |    |    [25:26] <Newline> = ♢¶♢
|    |    |    [26:26] <Indenting> = ♢→♢
|    |    |    [26:26] <CInt> = ♢int♢
|    |    |    [26:26] <Whitespace> = ♢•♢
|    |    |    [26:26] <Text> = ♢result♢
|    |    |    [26:26] <Whitespace> = ♢•♢
|    |    |    [26:26] <Text> = ♢=♢
|    |    |    [26:26] <Whitespace> = ♢•♢
|    |    |    [26:26] <ObjCMethodCall>
|    |    |    + <name> = ♢main::♢
|    |    |    |    [26:26] <Match> = ♢[♢
|    |    |    |    [26:26] <Match> = ♢main♢
|    |    |    |    [26:26] <Whitespace> = ♢•♢
|    |    |    |    [26:26] <Text> = ♢main♢
|    |    |    |    [26:26] <Colon> = ♢:♢
|    |    |    |    [26:26] <Text> = ♢argc♢
|    |    |    |    [26:26] <Whitespace> = ♢•♢
|    |    |    |    [26:26] <Colon> = ♢:♢
|    |    |    |    [26:26] <Text> = ♢argv♢
|    |    |    |    [26:26] <Match> = ♢]♢
|    |    |    [26:26] <Semicolon> = ♢;♢
|    |    |    [26:27] <Newline> = ♢¶♢
|    |    |    [27:27] <Indenting> = ♢→♢
|    |    |    [27:27] <ObjCMethodCall>
|    |    |    + <name> = ♢release♢
|    |    |    |    [27:27] <Match> = ♢[♢
|    |    |    |    [27:27] <Match> = ♢main♢
|    |    |    |    [27:27] <Whitespace> = ♢•♢
|    |    |    |    [27:27] <Text> = ♢release♢
|    |    |    |    [27:27] <Match> = ♢]♢
|    |    |    [27:27] <Semicolon> = ♢;♢
|    |    |    [27:28] <Newline> = ♢¶♢
|    |    |    [28:28] <Indenting> = ♢••••♢
|    |    |    [28:29] <Newline> = ♢¶♢
|    |    |    [29:29] <Indenting> = ♢••••♢
|    |    |    [29:29] <ObjCMethodCall>
|    |    |    + <name> = ♢release♢
|    |    |    |    [29:29] <Match> = ♢[♢
|    |    |    |    [29:29] <Match> = ♢pool♢
|    |    |    |    [29:29] <Whitespace> = ♢•♢
|    |    |    |    [29:29] <Text> = ♢release♢
|    |    |    |    [29:29] <Match> = ♢]♢
|    |    |    [29:29] <Semicolon> = ♢;♢
|    |    |    [29:30] <Newline> = ♢¶♢
|    |    |    [30:30] <Indenting> = ♢••••♢
|    |    |    [30:31] <Newline> = ♢¶♢
|    |    |    [31:31] <Indenting> = ♢→♢
|    |    |    [31:31] <CFlowReturn>
|    |    |    |    [31:31] <Match> = ♢return♢
|    |    |    |    [31:31] <Whitespace> = ♢•♢
|    |    |    |    [31:31] <Text> = ♢result♢
|    |    |    |    [31:31] <Semicolon> = ♢;♢
|    |    |    [31:32] <Newline> = ♢¶♢
|    |    |    [32:32] <Match> = ♢}♢
|    [32:33] <Newline> = ♢¶♢
|    [33:34] <Newline> = ♢¶♢
