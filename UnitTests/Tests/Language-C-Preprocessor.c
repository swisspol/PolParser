#include <stdlib.h>

#pragma mark Label

#define FOO 1	

#if 1
#warning Foobar

int main() { return 0; }

#elseif 2

int main() { return 1; }

#else

int main() { return 2; }

#endif

#undef FOO /* We're done */

#define TEST_FUNCTION(arg) \
	CHECK((arg) == true)

-----

<Root>
·  <CPreprocessorInclude>
·  ·  ♢|#include|♢•♢<stdlib.h>♢
·  ♢¶♢¶♢
·  <CPreprocessorPragma>
·  ·  ♢|#pragma|♢•♢mark♢•♢Label♢
·  ♢¶♢¶♢
·  <CPreprocessorDefine>
·  ·  ♢|#define|♢•♢FOO♢•♢1♢
·  ♢→♢¶♢¶♢
·  <CPreprocessorConditionIf>
·  ·  ♢|#if•1|♢¶♢
·  ·  <CPreprocessorWarning>
·  ·  ·  ♢|#warning|♢•♢Foobar♢
·  ·  ♢¶♢¶♢
·  ·  <CFunctionDefinition>
·  ·  ·  ♢|int|♢•♢main♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ·  ♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢•♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢0♢|;|♢
·  ·  ·  ·  ♢•♢|}|♢
·  ·  ♢¶♢¶♢
·  ♢
·  <CPreprocessorConditionElseif>
·  ·  ♢|#elseif•2|♢¶♢¶♢
·  ·  <CFunctionDefinition>
·  ·  ·  ♢|int|♢•♢main♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ·  ♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢•♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢1♢|;|♢
·  ·  ·  ·  ♢•♢|}|♢
·  ·  ♢¶♢¶♢
·  ♢
·  <CPreprocessorConditionElse>
·  ·  ♢|#else|♢¶♢¶♢
·  ·  <CFunctionDefinition>
·  ·  ·  ♢|int|♢•♢main♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ·  ♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢•♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢2♢|;|♢
·  ·  ·  ·  ♢•♢|}|♢
·  ·  ♢¶♢¶♢|#endif|♢
·  ♢¶♢¶♢
·  <CPreprocessorUndefine>
·  ·  ♢|#undef|♢•♢FOO♢
·  ♢•♢|/*•We're•done•*/|♢¶♢¶♢
·  <CPreprocessorDefine>
·  ·  ♢|#define|♢•♢TEST_FUNCTION♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢arg♢|)|♢
·  ·  ♢•♢\♢¶♢|→|♢CHECK♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢arg♢|)|♢
·  ·  ·  ♢•♢==♢•♢true♢|)|♢
·  ♢¶♢¶♢
