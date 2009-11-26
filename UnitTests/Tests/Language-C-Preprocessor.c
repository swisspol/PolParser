#include <stdlib.h>

#pragma mark Label

#define FOO 1	

#if 1
#warning Foobar

int main() { return 0; }

#else

int main() { return 1; }

#endif

#undef FOO

#define TEST_FUNCTION(arg) CHECK((arg) == true)

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
·  ·  ·  ·  ·  ♢return♢•♢0♢|;|♢
·  ·  ·  ·  ♢•♢}♢
·  ·  ♢¶♢¶♢
·  ♢
·  <CPreprocessorConditionElse>
·  ·  ♢#else♢¶♢¶♢
·  ·  <CFunctionDefinition>
·  ·  ·  ♢int♢•♢main♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢(♢)♢
·  ·  ·  ♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢{♢•♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢return♢•♢1♢|;|♢
·  ·  ·  ·  ♢•♢}♢
·  ·  ♢¶♢¶♢#endif♢
·  ♢¶♢¶♢
·  <CPreprocessorUndefine>
·  ·  ♢#undef♢•♢FOO♢
·  ♢¶♢¶♢
·  <CPreprocessorDefine>
·  ·  ♢#define♢•♢TEST_FUNCTION♢
·  ·  <Parenthesis>
·  ·  ·  ♢(♢arg♢)♢
·  ·  ♢•♢CHECK♢
·  ·  <Parenthesis>
·  ·  ·  ♢(♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢(♢arg♢)♢
·  ·  ·  ♢•♢==♢•♢true♢)♢
·  ♢¶♢¶♢
