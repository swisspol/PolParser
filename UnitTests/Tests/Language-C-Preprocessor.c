#include <stdlib.h>

#pragma mark Label

#define FOO 1	

#if 1
#warning Foobar

int main() { return 0; }

#else
#error Foobar

int main() { return 1; }

#endif

#undef FOO

-----

<Root>
·  <CPreprocessorInclude>
·  ·  ♢#include♢•♢<stdlib.h>♢
·  ♢¶♢¶♢
·  <CPreprocessorPragma>
·  ·  ♢#pragma♢•♢mark♢•♢Label♢
·  ♢¶♢¶♢
·  <CPreprocessorDefine>
·  ·  ♢#define♢•♢FOO♢•♢1♢
·  ♢→♢¶♢¶♢
·  <CPreprocessorConditionIf>
·  ·  ♢#if♢•♢1♢¶♢
·  ·  <CPreprocessorWarning>
·  ·  ·  ♢#warning♢•♢Foobar♢
·  ·  ♢¶♢¶♢
·  ·  <CFunctionDefinition>
·  ·  ·  ♢int♢•♢main♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢(♢)♢
·  ·  ·  ♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢{♢•♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢return♢•♢0♢;♢
·  ·  ·  ·  ♢•♢}♢
·  ·  ♢¶♢¶♢
·  ♢
·  <CPreprocessorConditionElse>
·  ·  ♢#else♢¶♢
·  ·  <CPreprocessorError>
·  ·  ·  ♢#error♢•♢Foobar♢
·  ·  ♢¶♢¶♢
·  ·  <CFunctionDefinition>
·  ·  ·  ♢int♢•♢main♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢(♢)♢
·  ·  ·  ♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢{♢•♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢return♢•♢1♢;♢
·  ·  ·  ·  ♢•♢}♢
·  ·  ♢¶♢¶♢#endif♢
·  ♢¶♢¶♢
·  <CPreprocessorUndefine>
·  ·  ♢#undef♢•♢FOO♢
·  ♢¶♢¶♢
