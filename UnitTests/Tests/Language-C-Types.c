typedef void (*SourceNodeApplierFunction)(SourceNode* node, void* context);

const struct sockaddr* address;

enum {
	kFoo = 1,
    kBar = 2
};

struct temp {
    int   foo;
    int bar;
};

typedef union {
	int temp1;
    struct temp temp2;
    struct {
    	double foo;
        long bar;
    } temp3;
} boom;

static int foo = sizeof(long);

-----

<Root>
·  <CTypedef>
·  ·  ♢|typedef|♢•♢|void|♢•♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢|*|♢SourceNodeApplierFunction♢|)|♢
·  ·  ♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢SourceNode♢|*|♢•♢node,♢•♢|void|♢|*|♢•♢context♢|)|♢
·  ·  ♢|;|♢
·  ♢¶♢¶♢|const|♢•♢|struct|♢•♢sockaddr♢|*|♢•♢address♢|;|♢¶♢¶♢
·  <CTypeEnum>
·  ·  ♢|enum|♢•♢
·  ·  <Braces>
·  ·  ·  ♢|{|♢¶♢|→|♢kFoo♢•♢=♢•♢1,♢¶♢|••••|♢kBar♢•♢=♢•♢2♢¶♢|}|♢
·  ·  ♢|;|♢
·  ♢¶♢¶♢
·  <CTypeStruct>
·  ·  ♢|struct|♢•♢temp♢•♢
·  ·  <Braces>
·  ·  ·  ♢|{|♢¶♢|••••|♢|int|♢•••♢foo♢|;|♢¶♢|••••|♢|int|♢•♢bar♢|;|♢¶♢|}|♢
·  ·  ♢|;|♢
·  ♢¶♢¶♢
·  <CTypedef>
·  ·  ♢|typedef|♢•♢
·  ·  <CTypeUnion>
·  ·  ·  ♢|union|♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|→|♢|int|♢•♢temp1♢|;|♢¶♢|••••|♢|struct|♢•♢temp♢•♢temp2♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CTypeStruct>
·  ·  ·  ·  ·  ♢|struct|♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••→|♢|double|♢•♢foo♢|;|♢¶♢|••••••••|♢|long|♢•♢bar♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ·  ♢•♢temp3♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ·  ♢•♢boom♢|;|♢
·  ♢¶♢¶♢|static|♢•♢|int|♢•♢foo♢•♢=♢•♢
·  <CSizeOf>
·  ·  ♢|sizeof|♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢|long|♢|)|♢
·  ♢|;|♢¶♢¶♢
