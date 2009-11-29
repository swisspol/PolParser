/*
    This file is part of the PolParser library.
    Copyright (C) 2009 Pierre-Olivier Latour <info@pol-online.net>
*/

#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[]) {
    return NSApplicationMain(argc, (const char**)argv);
}

<----->

<Root>
·  ♢|/*¶••••This•file•is•part•of•the•PolParser•library.¶••••Copyright•(C)•2009•Pierre-Olivier•Latour•<info@pol-online.net>¶*/|♢¶♢¶♢
·  <ObjCPreprocessorImport>
·  ·  ♢|#import|♢•♢<Cocoa/Cocoa.h>♢
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
·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ♢|return|♢•♢
·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ♢|NSApplicationMain|♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢argc,♢•♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢|const|♢•♢|char|♢|*|♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ♢argv♢|)|♢
·  ·  ·  ·  ♢|;|♢
·  ·  ·  ♢¶♢|}|♢
·  ♢¶♢¶♢

<----->

[1:12] <Root>
|    [1:4] <CComment> = ♢/*¶••••This•file•is•part•of•the•PolParser•library.¶••••Copyright•(C)•2009•Pierre-Olivier•Latour•<info@pol-online.net>¶*/♢
|    + <cleaned> = ♢¶••••This•file•is•part•of•the•PolParser•library.¶••••Copyright•(C)•2009•Pierre-Olivier•Latour•<info@pol-online.net>¶♢
|    [4:5] <Newline> = ♢¶♢
|    [5:6] <Newline> = ♢¶♢
|    [6:6] <ObjCPreprocessorImport>
|    + <name> = ♢<Cocoa/Cocoa.h>♢
|    |    [6:6] <Match> = ♢#import♢
|    |    [6:6] <Whitespace> = ♢•♢
|    |    [6:6] <Text> = ♢<Cocoa/Cocoa.h>♢
|    [6:7] <Newline> = ♢¶♢
|    [7:8] <Newline> = ♢¶♢
|    [8:10] <CFunctionDefinition>
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
|    |    [8:8] <Whitespace> = ♢•♢
|    |    [8:10] <Braces>
|    |    |    [8:8] <Match> = ♢{♢
|    |    |    [8:9] <Newline> = ♢¶♢
|    |    |    [9:9] <Indenting> = ♢••••♢
|    |    |    [9:9] <CFlowReturn>
|    |    |    |    [9:9] <Match> = ♢return♢
|    |    |    |    [9:9] <Whitespace> = ♢•♢
|    |    |    |    [9:9] <CFunctionCall>
|    |    |    |    |    [9:9] <Match> = ♢NSApplicationMain♢
|    |    |    |    |    [9:9] <Parenthesis>
|    |    |    |    |    |    [9:9] <Match> = ♢(♢
|    |    |    |    |    |    [9:9] <Text> = ♢argc,♢
|    |    |    |    |    |    [9:9] <Whitespace> = ♢•♢
|    |    |    |    |    |    [9:9] <Parenthesis>
|    |    |    |    |    |    |    [9:9] <Match> = ♢(♢
|    |    |    |    |    |    |    [9:9] <CConst> = ♢const♢
|    |    |    |    |    |    |    [9:9] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [9:9] <CChar> = ♢char♢
|    |    |    |    |    |    |    [9:9] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    [9:9] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    [9:9] <Match> = ♢)♢
|    |    |    |    |    |    [9:9] <Text> = ♢argv♢
|    |    |    |    |    |    [9:9] <Match> = ♢)♢
|    |    |    |    [9:9] <Semicolon> = ♢;♢
|    |    |    [9:10] <Newline> = ♢¶♢
|    |    |    [10:10] <Match> = ♢}♢
|    [10:11] <Newline> = ♢¶♢
|    [11:12] <Newline> = ♢¶♢
