#include <stdlib.h>

#pragma mark Label

#define FOO 1	

#if 1
#warning Foobar

int main() { return 0; }

#elseif 2

#ifdef NDEBUG
int main() { return 1; }
#else
int main() { return 2; }
#endif

#else

int main() { return 3; }

#endif

#undef FOO

#define TEST_FUNCTION(arg) CHECK((arg) == true)

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
·  <CCPreprocessorIf>
·  ·  ♢|#if|♢•♢1♢¶♢
·  ·  <CPreprocessorWarning>
·  ·  ·  ♢|#warning|♢•♢Foobar♢
·  ·  ♢¶♢¶♢
·  ·  <CFunctionDefinition>
·  ·  ·  ♢int♢•♢main♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ·  ♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢•♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢return♢•♢0♢|;|♢
·  ·  ·  ·  ♢•♢|}|♢
·  ·  ♢¶♢¶♢
·  ♢
·  <CPreprocessorElseif>
·  ·  ♢|#elseif|♢•♢2♢¶♢¶♢
·  ·  <CFunctionDefinition>
·  ·  ·  ♢int♢•♢main♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ·  ♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢•♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢return♢•♢1♢|;|♢
·  ·  ·  ·  ♢•♢|}|♢
·  ·  ♢¶♢¶♢
·  ♢
·  <CCPreprocessorElse>
·  ·  ♢|#else|♢¶♢¶♢
·  ·  <CFunctionDefinition>
·  ·  ·  ♢int♢•♢main♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ·  ♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢•♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢return♢•♢2♢|;|♢
·  ·  ·  ·  ♢•♢|}|♢
·  ·  ♢¶♢¶♢|#endif|♢
·  ♢¶♢¶♢
·  <CPreprocessorUndefine>
·  ·  ♢|#undef|♢•♢FOO♢
·  ♢¶♢¶♢
·  <CPreprocessorDefine>
·  ·  ♢|#define|♢•♢TEST_FUNCTION♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢arg♢|)|♢
·  ·  ♢•♢CHECK♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢arg♢|)|♢
·  ·  ·  ♢•♢==♢•♢true♢|)|♢
·  ♢¶♢¶♢
