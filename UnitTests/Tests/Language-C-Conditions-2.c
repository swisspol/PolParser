if(1)
    foo();
else
    bar();

if(1)
    foo();
else if(2)
    bar();
else
    temp();

if(0) return NULL;

-----

<Root>
·  <CConditionIf>
·  ·  ♢if♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢1♢|)|♢
·  ·  ♢¶♢|••••|♢
·  ·  <CFunctionCall>
·  ·  ·  ♢foo♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ♢|;|♢
·  ♢¶♢
·  <CConditionElse>
·  ·  ♢else♢¶♢|••••|♢
·  ·  <CFunctionCall>
·  ·  ·  ♢bar♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ♢|;|♢
·  ♢¶♢¶♢
·  <CConditionIf>
·  ·  ♢if♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢1♢|)|♢
·  ·  ♢¶♢|••••|♢
·  ·  <CFunctionCall>
·  ·  ·  ♢foo♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ♢|;|♢
·  ♢¶♢
·  <CConditionElseIf>
·  ·  ♢else♢•♢if♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢2♢|)|♢
·  ·  ♢¶♢|••••|♢
·  ·  <CFunctionCall>
·  ·  ·  ♢bar♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ♢|;|♢
·  ♢¶♢
·  <CConditionElse>
·  ·  ♢else♢¶♢|••••|♢
·  ·  <CFunctionCall>
·  ·  ·  ♢temp♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ♢|;|♢
·  ♢¶♢¶♢
·  <CConditionIf>
·  ·  ♢if♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢0♢|)|♢
·  ·  ♢•♢
·  ·  <CFlowReturn>
·  ·  ·  ♢return♢•♢|NULL|♢|;|♢
·  ♢¶♢¶♢
