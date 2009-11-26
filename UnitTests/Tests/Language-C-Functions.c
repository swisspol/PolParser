static void Foo(int arg1, int arg2);

extern int Bar();

static inline void Foo(int arg1, int arg2) {
    int foo = (1 + Bar() + 2);
    void* ptr = realloc(malloc(1024), 2048);
    free(ptr);
}

int* Bar() {
	return 0;
}

-----

<Root>
·  <CFunctionPrototype>
·  ·  ♢|static|♢•♢|void|♢•♢Foo♢
·  ·  <Parenthesis>
·  ·  ·  ♢(♢int♢•♢arg1,♢•♢int♢•♢arg2♢)♢
·  ·  ♢|;|♢
·  ♢¶♢¶♢
·  <CFunctionPrototype>
·  ·  ♢|extern|♢•♢int♢•♢Bar♢
·  ·  <Parenthesis>
·  ·  ·  ♢(♢)♢
·  ·  ♢|;|♢
·  ♢¶♢¶♢
·  <CFunctionDefinition>
·  ·  ♢|static|♢•♢|inline|♢•♢|void|♢•♢Foo♢
·  ·  <Parenthesis>
·  ·  ·  ♢(♢int♢•♢arg1,♢•♢int♢•♢arg2♢)♢
·  ·  ♢•♢
·  ·  <Braces>
·  ·  ·  ♢{♢¶♢••••♢int♢•♢foo♢•♢=♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢(♢1♢•♢+♢•♢
·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ♢Bar♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢(♢)♢
·  ·  ·  ·  ♢•♢+♢•♢2♢)♢
·  ·  ·  ♢|;|♢¶♢••••♢|void|♢|*|♢•♢ptr♢•♢=♢•♢
·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ♢realloc♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢(♢
·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ♢malloc♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢(♢1024♢)♢
·  ·  ·  ·  ·  ♢,♢•♢2048♢)♢
·  ·  ·  ♢|;|♢¶♢••••♢
·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ♢free♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢(♢ptr♢)♢
·  ·  ·  ♢|;|♢¶♢}♢
·  ♢¶♢¶♢
·  <CFunctionDefinition>
·  ·  ♢int♢|*|♢•♢Bar♢
·  ·  <Parenthesis>
·  ·  ·  ♢(♢)♢
·  ·  ♢•♢
·  ·  <Braces>
·  ·  ·  ♢{♢¶♢→♢
·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ♢return♢•♢0♢|;|♢
·  ·  ·  ♢¶♢}♢
·  ♢¶♢¶♢
