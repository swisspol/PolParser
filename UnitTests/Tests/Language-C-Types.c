typedef void (*SourceNodeApplierFunction)(SourceNode* node, void* context);

const struct sockaddr* address;

struct temp {
    int   foo;
    int bar;
};

typedef union {
	int temp1;
    long temp2;
} boom;

static int foo = sizeof(long);

-----

<Root>
·  <CTypedef>
·  ·  ♢typedef♢•♢|void|♢•♢
·  ·  <Parenthesis>
·  ·  ·  ♢(♢|*|♢SourceNodeApplierFunction♢)♢
·  ·  ♢
·  ·  <Parenthesis>
·  ·  ·  ♢(♢SourceNode♢|*|♢•♢node,♢•♢|void|♢|*|♢•♢context♢)♢
·  ·  ♢|;|♢
·  ♢¶♢¶♢|const|♢•♢|struct|♢•♢sockaddr♢|*|♢•♢address♢|;|♢¶♢¶♢
·  <CTypeStruct>
·  ·  ♢struct♢•♢temp♢•♢
·  ·  <Braces>
·  ·  ·  ♢{♢¶♢••••♢int♢•••♢foo♢|;|♢¶♢••••♢int♢•♢bar♢|;|♢¶♢}♢
·  ·  ♢|;|♢
·  ♢¶♢¶♢
·  <CTypedef>
·  ·  ♢typedef♢•♢
·  ·  <CTypeUnion>
·  ·  ·  ♢union♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢{♢¶♢→♢int♢•♢temp1♢|;|♢¶♢••••♢long♢•♢temp2♢|;|♢¶♢}♢
·  ·  ·  ♢•♢boom♢|;|♢
·  ♢¶♢¶♢|static|♢•♢int♢•♢foo♢•♢=♢•♢
·  <CTypeSizeOf>
·  ·  ♢sizeof♢
·  ·  <Parenthesis>
·  ·  ·  ♢(♢long♢)♢
·  ♢|;|♢¶♢¶♢
