switch (arg) {
    case 1:
        printf("1");
        break;
    case 2:
    case 3:
        printf("2-3");
        break;
    case 4:
        printf("4");
        break;
    case 5:
        printf("5");
    default:
        printf("0");
}

-----

<Root>
·  <CFlowSwitch>
·  ·  ♢switch♢•♢
·  ·  <Parenthesis>
·  ·  ·  ♢(♢arg♢)♢
·  ·  ♢•♢
·  ·  <Braces>
·  ·  ·  ♢{♢¶♢••••♢
·  ·  ·  <CFlowCase>
·  ·  ·  ·  ♢case♢•♢1♢:♢¶♢••••••••♢printf♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢(♢"1"♢)♢
·  ·  ·  ·  ♢;♢¶♢••••••••♢break♢;♢
·  ·  ·  ♢¶♢••••♢
·  ·  ·  <CFlowCase>
·  ·  ·  ·  ♢case♢•♢2♢:♢¶♢••••♢
·  ·  ·  ♢
·  ·  ·  <CFlowCase>
·  ·  ·  ·  ♢case♢•♢3♢:♢¶♢••••••••♢printf♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢(♢"2-3"♢)♢
·  ·  ·  ·  ♢;♢¶♢••••••••♢break♢;♢
·  ·  ·  ♢¶♢••••♢
·  ·  ·  <CFlowCase>
·  ·  ·  ·  ♢case♢•♢4♢:♢¶♢••••••••♢printf♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢(♢"4"♢)♢
·  ·  ·  ·  ♢;♢¶♢••••••••♢break♢;♢
·  ·  ·  ♢¶♢••••♢
·  ·  ·  <CFlowCase>
·  ·  ·  ·  ♢case♢•♢5♢:♢¶♢••••••••♢printf♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢(♢"5"♢)♢
·  ·  ·  ·  ♢;♢¶♢••••♢
·  ·  ·  ♢
·  ·  ·  <CFlowDefault>
·  ·  ·  ·  ♢default♢:♢¶♢••••••••♢printf♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢(♢"0"♢)♢
·  ·  ·  ·  ♢;♢¶♢}♢
·  ♢¶♢¶♢
