for(int i = foo; i < bar; ++i)
    printf("Counter = \"%i\"", i);

for(;; ++i) {
    printf("%i", i);
    continue;
}

while(true) {
    break;
}

do {
    --foo;
} while (*foo) ;

<----->

<Root>
·  <CFlowFor>
·  ·  ♢|for|♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢|int|♢•♢i♢•♢=♢•♢foo♢|;|♢•♢i♢•♢<♢•♢bar♢|;|♢•♢++i♢|)|♢
·  ·  ♢¶♢|••••|♢
·  ·  <CFunctionCall>
·  ·  ·  ♢|printf|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|"Counter•=•\"%i\""|♢,♢•♢i♢|)|♢
·  ·  ♢|;|♢
·  ♢¶♢¶♢
·  <CFlowFor>
·  ·  ♢|for|♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢|;|♢|;|♢•♢++i♢|)|♢
·  ·  ♢•♢
·  ·  <Braces>
·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ♢|printf|♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢|(|♢|"%i"|♢,♢•♢i♢|)|♢
·  ·  ·  ♢|;|♢¶♢|••••|♢|continue|♢|;|♢¶♢|}|♢
·  ♢¶♢¶♢
·  <CFlowWhile>
·  ·  ♢|while|♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢true♢|)|♢
·  ·  ♢•♢
·  ·  <Braces>
·  ·  ·  ♢|{|♢¶♢|••••|♢|break|♢|;|♢¶♢|}|♢
·  ♢¶♢¶♢
·  <CFlowDoWhile>
·  ·  ♢|do|♢•♢
·  ·  <Braces>
·  ·  ·  ♢|{|♢¶♢|••••|♢--foo♢|;|♢¶♢|}|♢
·  ·  ♢•♢|while|♢•♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢|*|♢foo♢|)|♢
·  ♢•♢|;|♢¶♢¶♢
