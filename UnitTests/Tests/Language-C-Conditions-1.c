int result = foo ? temp1 : temp2;
int result = foo ? (bar ? temp1 : temp3) : temp2;

-----

<Root>
·  ♢int♢•♢result♢•♢=♢•♢
·  <CConditionalOperator>
·  ·  ♢foo♢•♢|?|♢•♢temp1♢•♢|:|♢•♢temp2♢
·  ♢|;|♢¶♢int♢•♢result♢•♢=♢•♢
·  <CConditionalOperator>
·  ·  ♢foo♢•♢|?|♢•♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢
·  ·  ·  <CConditionalOperator>
·  ·  ·  ·  ♢bar♢•♢|?|♢•♢temp1♢•♢|:|♢•♢temp3♢
·  ·  ·  ♢|)|♢
·  ·  ♢•♢|:|♢•♢temp2♢
·  ♢|;|♢¶♢¶♢
