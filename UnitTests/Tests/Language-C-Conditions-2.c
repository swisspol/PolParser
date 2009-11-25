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
·  ·  ·  ♢(♢1♢)♢
·  ·  ♢¶♢••••♢foo♢
·  ·  <Parenthesis>
·  ·  ·  ♢(♢)♢
·  ·  ♢|;|♢
·  ♢¶♢
·  <CConditionElse>
·  ·  ♢else♢¶♢••••♢bar♢
·  ·  <Parenthesis>
·  ·  ·  ♢(♢)♢
·  ·  ♢|;|♢
·  ♢¶♢¶♢
·  <CConditionIf>
·  ·  ♢if♢
·  ·  <Parenthesis>
·  ·  ·  ♢(♢1♢)♢
·  ·  ♢¶♢••••♢foo♢
·  ·  <Parenthesis>
·  ·  ·  ♢(♢)♢
·  ·  ♢|;|♢
·  ♢¶♢
·  <CConditionElseIf>
·  ·  ♢else♢•♢if♢
·  ·  <Parenthesis>
·  ·  ·  ♢(♢2♢)♢
·  ·  ♢¶♢••••♢bar♢
·  ·  <Parenthesis>
·  ·  ·  ♢(♢)♢
·  ·  ♢|;|♢
·  ♢¶♢
·  <CConditionElse>
·  ·  ♢else♢¶♢••••♢temp♢
·  ·  <Parenthesis>
·  ·  ·  ♢(♢)♢
·  ·  ♢|;|♢
·  ♢¶♢¶♢
·  <CConditionIf>
·  ·  ♢if♢
·  ·  <Parenthesis>
·  ·  ·  ♢(♢0♢)♢
·  ·  ♢•♢
·  ·  <CFlowReturn>
·  ·  ·  ♢return♢•♢|NULL|♢|;|♢
·  ♢¶♢¶♢
