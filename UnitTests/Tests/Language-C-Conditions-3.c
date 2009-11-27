if (1) {
    printf("1");
}
else if (2) {
    if (3) {
        printf("3");
    }
    else if (4) {
        printf("4");
    }
    else
        printf("5");
}
else {
    printf("6");
}

-----

<Root>
·  <CConditionIf>
·  ·  ♢|if|♢•♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢1♢|)|♢
·  ·  ♢•♢
·  ·  <Braces>
·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ♢|printf|♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢|(|♢|"1"|♢|)|♢
·  ·  ·  ♢|;|♢¶♢|}|♢
·  ♢¶♢
·  <CConditionElseIf>
·  ·  ♢|else•if|♢•♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢2♢|)|♢
·  ·  ♢•♢
·  ·  <Braces>
·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  <CConditionIf>
·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢|(|♢3♢|)|♢
·  ·  ·  ·  ♢•♢
·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ♢|printf|♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢|"3"|♢|)|♢
·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  <CConditionElseIf>
·  ·  ·  ·  ♢|else•if|♢•♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢|(|♢4♢|)|♢
·  ·  ·  ·  ♢•♢
·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ♢|printf|♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢|"4"|♢|)|♢
·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  <CConditionElse>
·  ·  ·  ·  ♢|else|♢¶♢|••••••••|♢
·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ♢|printf|♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢|"5"|♢|)|♢
·  ·  ·  ·  ♢|;|♢
·  ·  ·  ♢¶♢|}|♢
·  ♢¶♢
·  <CConditionElse>
·  ·  ♢|else|♢•♢
·  ·  <Braces>
·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ♢|printf|♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢|(|♢|"6"|♢|)|♢
·  ·  ·  ♢|;|♢¶♢|}|♢
·  ♢¶♢¶♢
