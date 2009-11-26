static void Foo(int arg) {
    goto Temp;
    
Temp:
    return;
    
    return(NULL);
    
    return *string != '\\';
}

-----

<Root>
·  <CFunctionDefinition>
·  ·  ♢|static|♢•♢|void|♢•♢Foo♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢int♢•♢arg♢|)|♢
·  ·  ♢•♢
·  ·  <Braces>
·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  <CFlowGoto>
·  ·  ·  ·  ♢goto♢•♢Temp♢|;|♢
·  ·  ·  ♢¶♢|••••|♢¶♢
·  ·  ·  <CFlowLabel>
·  ·  ·  ·  ♢Temp♢|:|♢
·  ·  ·  ♢¶♢|••••|♢|return|♢|;|♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ♢return♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢|(|♢|NULL|♢|)|♢
·  ·  ·  ·  ♢|;|♢
·  ·  ·  ♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ♢return♢•♢|*|♢string♢•♢|!|♢=♢•♢|'\\'|♢|;|♢
·  ·  ·  ♢¶♢|}|♢
·  ♢¶♢¶♢
