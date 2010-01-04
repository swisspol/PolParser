#include <iostream>

using namespace std;

namespace foo {
namespace bar {

class SubTest;

}
}

namespace foo {
namespace bar {

class Test {
public:
    Test();
    
    Test(int value)
    	: value_(value) {}
    
    ~Test() {}
    
    int value() { return value_; }
    
    virtual void Compute() = 0;
    
private:
	int value_;
};

Test::Test() {
    cout << "Hello World" << endl;
}

class SubTest : public Test {
public:
	SubTest() {};
    ~SubTest() {};
    
    void Compute() {
    	try {
        	if(value())
            	cout << 2 * value() << endl;
            else
            	throw("Value is undefined");
        }
        catch(string error) {
            cerr << error << endl;
        }
    }
};

}    
}

using foo::bar::SubTest;

/*
* The main function
*/
int main(int argc, char * const argv[]) {
    
    //Run dummy test
    SubTest* test = new SubTest();
    test->Compute(); // FIXME: We ignore any failures
    delete test;
    
    return 0;
}

<----->

<Root>
·  <CPreprocessorInclude>
·  ·  ♢|#include|♢•♢<iostream>♢
·  ♢¶♢¶♢|using|♢•♢|namespace|♢•♢std♢|;|♢¶♢¶♢
·  <CPPNamespace>
·  ·  ♢|namespace|♢•♢foo♢•♢
·  ·  <Braces>
·  ·  ·  ♢|{|♢¶♢
·  ·  ·  <CPPNamespace>
·  ·  ·  ·  ♢|namespace|♢•♢bar♢•♢
·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ♢|{|♢¶♢¶♢|class|♢•♢SubTest♢|;|♢¶♢¶♢|}|♢
·  ·  ·  ♢¶♢|}|♢
·  ♢¶♢¶♢
·  <CPPNamespace>
·  ·  ♢|namespace|♢•♢foo♢•♢
·  ·  <Braces>
·  ·  ·  ♢|{|♢¶♢
·  ·  ·  <CPPNamespace>
·  ·  ·  ·  ♢|namespace|♢•♢bar♢•♢
·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ♢|{|♢¶♢¶♢
·  ·  ·  ·  ·  <CPPClass>
·  ·  ·  ·  ·  ·  ♢|class|♢•♢Test♢•♢
·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢
·  ·  ·  ·  ·  ·  ·  <CPPPublic>
·  ·  ·  ·  ·  ·  ·  ·  ♢|public|♢|:|♢¶♢|••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CFunctionPrototype>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|Test|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CFunctionDefinition>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|Test|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|int|♢•♢value♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|••••→|♢|:|♢•♢|value_|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢value♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CFunctionDefinition>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|~|♢|Test|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CFunctionDefinition>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|int|♢•♢|value|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|return|♢•♢value_♢|;|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CPPVirtual>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|virtual|♢•♢|void|♢•♢|Compute|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢=♢•♢0♢|;|♢
·  ·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢¶♢
·  ·  ·  ·  ·  ·  ·  <CPPPrivate>
·  ·  ·  ·  ·  ·  ·  ·  ♢|private|♢|:|♢¶♢|→|♢|int|♢•♢value_♢|;|♢
·  ·  ·  ·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ·  ♢¶♢¶♢
·  ·  ·  ·  ·  <CFunctionDefinition>
·  ·  ·  ·  ·  ·  ♢Test♢|::|♢|Test|♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••|♢cout♢•♢<<♢•♢|"Hello•World"|♢•♢<<♢•♢endl♢|;|♢¶♢|}|♢
·  ·  ·  ·  ·  ♢¶♢¶♢
·  ·  ·  ·  ·  <CPPClass>
·  ·  ·  ·  ·  ·  ♢|class|♢•♢
·  ·  ·  ·  ·  ·  <CFlowLabel>
·  ·  ·  ·  ·  ·  ·  ♢SubTest♢•♢|:|♢
·  ·  ·  ·  ·  ·  ♢•♢|public|♢•♢Test♢•♢
·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢
·  ·  ·  ·  ·  ·  ·  <CPPPublic>
·  ·  ·  ·  ·  ·  ·  ·  ♢|public|♢|:|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  ·  ·  <CFunctionDefinition>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|SubTest|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CFunctionDefinition>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|~|♢|SubTest|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CFunctionDefinition>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|void|♢•♢|Compute|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CPPTry>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|try|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|if|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|value|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|••••••••••••→|♢cout♢•♢<<♢•♢2♢•♢|*|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|value|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢<<♢•♢endl♢|;|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|••••••••••••|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CConditionElse>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|else|♢¶♢|••••••••••••→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CPPThrow>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|throw|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|"Value•is•undefined"|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|••••••••|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CPPCatch>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|catch|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢string♢•♢error♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••••••|♢cerr♢•♢<<♢•♢error♢•♢<<♢•♢endl♢|;|♢¶♢|••••••••|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ·  ♢¶♢¶♢|}|♢
·  ·  ·  ♢••••♢¶♢|}|♢
·  ♢¶♢¶♢|using|♢•♢foo♢|::|♢bar♢|::|♢SubTest♢|;|♢¶♢¶♢|/*¶*•The•main•function¶*/|♢¶♢
·  <CFunctionDefinition>
·  ·  ♢|int|♢•♢|main|♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢|int|♢•♢argc,♢•♢|char|♢•♢|*|♢•♢|const|♢•♢argv♢
·  ·  ·  <Brackets>
·  ·  ·  ·  ♢|[|♢|]|♢
·  ·  ·  ♢|)|♢
·  ·  ♢•♢
·  ·  <Braces>
·  ·  ·  ♢|{|♢¶♢|••••|♢¶♢|••••|♢|//Run•dummy•test|♢¶♢|••••|♢SubTest♢|*|♢•♢test♢•♢=♢•♢
·  ·  ·  <CPPNew>
·  ·  ·  ·  ♢|new|♢•♢
·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ♢|SubTest|♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ·  ·  ♢|;|♢
·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  <CPPFunctionCall>
·  ·  ·  ·  ♢test♢|->|♢|Compute|♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢|(|♢|)|♢
·  ·  ·  ♢|;|♢•♢|//•FIXME:•We•ignore•any•failures|♢¶♢|••••|♢
·  ·  ·  <CPPDelete>
·  ·  ·  ·  ♢|delete|♢•♢test♢|;|♢
·  ·  ·  ♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ♢|return|♢•♢0♢|;|♢
·  ·  ·  ♢¶♢|}|♢
·  ♢¶♢¶♢

<----->

[1:73] <Root>
|    [1:1] <CPreprocessorInclude>
|    + <name> = ♢<iostream>♢
|    |    [1:1] <Match> = ♢#include♢
|    |    [1:1] <Whitespace> = ♢•♢
|    |    [1:1] <Text> = ♢<iostream>♢
|    [1:2] <Newline> = ♢¶♢
|    [2:3] <Newline> = ♢¶♢
|    [3:3] <CPPUsing> = ♢using♢
|    [3:3] <Whitespace> = ♢•♢
|    [3:3] <CPPNamespace> = ♢namespace♢
|    [3:3] <Whitespace> = ♢•♢
|    [3:3] <Text> = ♢std♢
|    [3:3] <Semicolon> = ♢;♢
|    [3:4] <Newline> = ♢¶♢
|    [4:5] <Newline> = ♢¶♢
|    [5:11] <CPPNamespace>
|    |    [5:5] <Match> = ♢namespace♢
|    |    [5:5] <Whitespace> = ♢•♢
|    |    [5:5] <Text> = ♢foo♢
|    |    [5:5] <Whitespace> = ♢•♢
|    |    [5:11] <Braces>
|    |    |    [5:5] <Match> = ♢{♢
|    |    |    [5:6] <Newline> = ♢¶♢
|    |    |    [6:10] <CPPNamespace>
|    |    |    |    [6:6] <Match> = ♢namespace♢
|    |    |    |    [6:6] <Whitespace> = ♢•♢
|    |    |    |    [6:6] <Text> = ♢bar♢
|    |    |    |    [6:6] <Whitespace> = ♢•♢
|    |    |    |    [6:10] <Braces>
|    |    |    |    |    [6:6] <Match> = ♢{♢
|    |    |    |    |    [6:7] <Newline> = ♢¶♢
|    |    |    |    |    [7:8] <Newline> = ♢¶♢
|    |    |    |    |    [8:8] <CPPClass> = ♢class♢
|    |    |    |    |    [8:8] <Whitespace> = ♢•♢
|    |    |    |    |    [8:8] <Text> = ♢SubTest♢
|    |    |    |    |    [8:8] <Semicolon> = ♢;♢
|    |    |    |    |    [8:9] <Newline> = ♢¶♢
|    |    |    |    |    [9:10] <Newline> = ♢¶♢
|    |    |    |    |    [10:10] <Match> = ♢}♢
|    |    |    [10:11] <Newline> = ♢¶♢
|    |    |    [11:11] <Match> = ♢}♢
|    [11:12] <Newline> = ♢¶♢
|    [12:13] <Newline> = ♢¶♢
|    [13:56] <CPPNamespace>
|    |    [13:13] <Match> = ♢namespace♢
|    |    [13:13] <Whitespace> = ♢•♢
|    |    [13:13] <Text> = ♢foo♢
|    |    [13:13] <Whitespace> = ♢•♢
|    |    [13:56] <Braces>
|    |    |    [13:13] <Match> = ♢{♢
|    |    |    [13:14] <Newline> = ♢¶♢
|    |    |    [14:55] <CPPNamespace>
|    |    |    |    [14:14] <Match> = ♢namespace♢
|    |    |    |    [14:14] <Whitespace> = ♢•♢
|    |    |    |    [14:14] <Text> = ♢bar♢
|    |    |    |    [14:14] <Whitespace> = ♢•♢
|    |    |    |    [14:55] <Braces>
|    |    |    |    |    [14:14] <Match> = ♢{♢
|    |    |    |    |    [14:15] <Newline> = ♢¶♢
|    |    |    |    |    [15:16] <Newline> = ♢¶♢
|    |    |    |    |    [16:31] <CPPClass>
|    |    |    |    |    |    [16:16] <Match> = ♢class♢
|    |    |    |    |    |    [16:16] <Whitespace> = ♢•♢
|    |    |    |    |    |    [16:16] <Text> = ♢Test♢
|    |    |    |    |    |    [16:16] <Whitespace> = ♢•♢
|    |    |    |    |    |    [16:31] <Braces>
|    |    |    |    |    |    |    [16:16] <Match> = ♢{♢
|    |    |    |    |    |    |    [16:17] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [17:27] <CPPPublic>
|    |    |    |    |    |    |    |    [17:17] <Match> = ♢public♢
|    |    |    |    |    |    |    |    [17:17] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [17:18] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [18:18] <Indenting> = ♢••••♢
|    |    |    |    |    |    |    |    [18:18] <CFunctionPrototype>
|    |    |    |    |    |    |    |    + <name> = ♢Test♢
|    |    |    |    |    |    |    |    |    [18:18] <Match> = ♢Test♢
|    |    |    |    |    |    |    |    |    [18:18] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [18:18] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [18:18] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [18:18] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [18:19] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [19:19] <Indenting> = ♢••••♢
|    |    |    |    |    |    |    |    [19:20] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [20:20] <Indenting> = ♢••••♢
|    |    |    |    |    |    |    |    [20:21] <CFunctionDefinition>
|    |    |    |    |    |    |    |    + <name> = ♢Test♢
|    |    |    |    |    |    |    |    |    [20:20] <Match> = ♢Test♢
|    |    |    |    |    |    |    |    |    [20:20] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [20:20] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [20:20] <CInt> = ♢int♢
|    |    |    |    |    |    |    |    |    |    [20:20] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [20:20] <Text> = ♢value♢
|    |    |    |    |    |    |    |    |    |    [20:20] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [20:21] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    [21:21] <Indenting> = ♢••••→♢
|    |    |    |    |    |    |    |    |    [21:21] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [21:21] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [21:21] <Match> = ♢value_♢
|    |    |    |    |    |    |    |    |    [21:21] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [21:21] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [21:21] <Text> = ♢value♢
|    |    |    |    |    |    |    |    |    |    [21:21] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [21:21] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [21:21] <Braces>
|    |    |    |    |    |    |    |    |    |    [21:21] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    [21:21] <Match> = ♢}♢
|    |    |    |    |    |    |    |    [21:22] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [22:22] <Indenting> = ♢••••♢
|    |    |    |    |    |    |    |    [22:23] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [23:23] <Indenting> = ♢••••♢
|    |    |    |    |    |    |    |    [23:23] <CFunctionDefinition>
|    |    |    |    |    |    |    |    + <name> = ♢Test♢
|    |    |    |    |    |    |    |    |    [23:23] <Tilde> = ♢~♢
|    |    |    |    |    |    |    |    |    [23:23] <Match> = ♢Test♢
|    |    |    |    |    |    |    |    |    [23:23] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [23:23] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [23:23] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [23:23] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [23:23] <Braces>
|    |    |    |    |    |    |    |    |    |    [23:23] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    [23:23] <Match> = ♢}♢
|    |    |    |    |    |    |    |    [23:24] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [24:24] <Indenting> = ♢••••♢
|    |    |    |    |    |    |    |    [24:25] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [25:25] <Indenting> = ♢••••♢
|    |    |    |    |    |    |    |    [25:25] <CFunctionDefinition>
|    |    |    |    |    |    |    |    + <name> = ♢value♢
|    |    |    |    |    |    |    |    |    [25:25] <CInt> = ♢int♢
|    |    |    |    |    |    |    |    |    [25:25] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [25:25] <Match> = ♢value♢
|    |    |    |    |    |    |    |    |    [25:25] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [25:25] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [25:25] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [25:25] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [25:25] <Braces>
|    |    |    |    |    |    |    |    |    |    [25:25] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    [25:25] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [25:25] <CFlowReturn>
|    |    |    |    |    |    |    |    |    |    |    [25:25] <Match> = ♢return♢
|    |    |    |    |    |    |    |    |    |    |    [25:25] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [25:25] <Text> = ♢value_♢
|    |    |    |    |    |    |    |    |    |    |    [25:25] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    [25:25] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [25:25] <Match> = ♢}♢
|    |    |    |    |    |    |    |    [25:26] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [26:26] <Indenting> = ♢••••♢
|    |    |    |    |    |    |    |    [26:27] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [27:27] <Indenting> = ♢••••♢
|    |    |    |    |    |    |    |    [27:27] <CPPVirtual>
|    |    |    |    |    |    |    |    |    [27:27] <Match> = ♢virtual♢
|    |    |    |    |    |    |    |    |    [27:27] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [27:27] <CVoid> = ♢void♢
|    |    |    |    |    |    |    |    |    [27:27] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [27:27] <Match> = ♢Compute♢
|    |    |    |    |    |    |    |    |    [27:27] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [27:27] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [27:27] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [27:27] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [27:27] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    [27:27] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [27:27] <Text> = ♢0♢
|    |    |    |    |    |    |    |    |    [27:27] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    [27:28] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [28:28] <Indenting> = ♢••••♢
|    |    |    |    |    |    |    [28:29] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [29:30] <CPPPrivate>
|    |    |    |    |    |    |    |    [29:29] <Match> = ♢private♢
|    |    |    |    |    |    |    |    [29:29] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [29:30] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [30:30] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [30:30] <CInt> = ♢int♢
|    |    |    |    |    |    |    |    [30:30] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [30:30] <Text> = ♢value_♢
|    |    |    |    |    |    |    |    [30:30] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    [30:31] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [31:31] <Match> = ♢}♢
|    |    |    |    |    |    [31:31] <Semicolon> = ♢;♢
|    |    |    |    |    [31:32] <Newline> = ♢¶♢
|    |    |    |    |    [32:33] <Newline> = ♢¶♢
|    |    |    |    |    [33:35] <CFunctionDefinition>
|    |    |    |    |    + <name> = ♢Test♢
|    |    |    |    |    |    [33:33] <Text> = ♢Test♢
|    |    |    |    |    |    [33:33] <DoubleSemicolon> = ♢::♢
|    |    |    |    |    |    [33:33] <Match> = ♢Test♢
|    |    |    |    |    |    [33:33] <Parenthesis>
|    |    |    |    |    |    |    [33:33] <Match> = ♢(♢
|    |    |    |    |    |    |    [33:33] <Match> = ♢)♢
|    |    |    |    |    |    [33:33] <Whitespace> = ♢•♢
|    |    |    |    |    |    [33:35] <Braces>
|    |    |    |    |    |    |    [33:33] <Match> = ♢{♢
|    |    |    |    |    |    |    [33:34] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [34:34] <Indenting> = ♢••••♢
|    |    |    |    |    |    |    [34:34] <Text> = ♢cout♢
|    |    |    |    |    |    |    [34:34] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [34:34] <Text> = ♢<<♢
|    |    |    |    |    |    |    [34:34] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [34:34] <CString> = ♢"Hello•World"♢
|    |    |    |    |    |    |    + <cleaned> = ♢Hello•World♢
|    |    |    |    |    |    |    [34:34] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [34:34] <Text> = ♢<<♢
|    |    |    |    |    |    |    [34:34] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [34:34] <Text> = ♢endl♢
|    |    |    |    |    |    |    [34:34] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    [34:35] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [35:35] <Match> = ♢}♢
|    |    |    |    |    [35:36] <Newline> = ♢¶♢
|    |    |    |    |    [36:37] <Newline> = ♢¶♢
|    |    |    |    |    [37:53] <CPPClass>
|    |    |    |    |    |    [37:37] <Match> = ♢class♢
|    |    |    |    |    |    [37:37] <Whitespace> = ♢•♢
|    |    |    |    |    |    [37:37] <CFlowLabel>
|    |    |    |    |    |    |    [37:37] <Text> = ♢SubTest♢
|    |    |    |    |    |    |    [37:37] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [37:37] <Colon> = ♢:♢
|    |    |    |    |    |    [37:37] <Whitespace> = ♢•♢
|    |    |    |    |    |    [37:37] <CPPPublic> = ♢public♢
|    |    |    |    |    |    [37:37] <Whitespace> = ♢•♢
|    |    |    |    |    |    [37:37] <Text> = ♢Test♢
|    |    |    |    |    |    [37:37] <Whitespace> = ♢•♢
|    |    |    |    |    |    [37:53] <Braces>
|    |    |    |    |    |    |    [37:37] <Match> = ♢{♢
|    |    |    |    |    |    |    [37:38] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [38:52] <CPPPublic>
|    |    |    |    |    |    |    |    [38:38] <Match> = ♢public♢
|    |    |    |    |    |    |    |    [38:38] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [38:39] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [39:39] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [39:39] <CFunctionDefinition>
|    |    |    |    |    |    |    |    + <name> = ♢SubTest♢
|    |    |    |    |    |    |    |    |    [39:39] <Match> = ♢SubTest♢
|    |    |    |    |    |    |    |    |    [39:39] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [39:39] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [39:39] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [39:39] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [39:39] <Braces>
|    |    |    |    |    |    |    |    |    |    [39:39] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    [39:39] <Match> = ♢}♢
|    |    |    |    |    |    |    |    [39:39] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [39:40] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [40:40] <Indenting> = ♢••••♢
|    |    |    |    |    |    |    |    [40:40] <CFunctionDefinition>
|    |    |    |    |    |    |    |    + <name> = ♢SubTest♢
|    |    |    |    |    |    |    |    |    [40:40] <Tilde> = ♢~♢
|    |    |    |    |    |    |    |    |    [40:40] <Match> = ♢SubTest♢
|    |    |    |    |    |    |    |    |    [40:40] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [40:40] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [40:40] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [40:40] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [40:40] <Braces>
|    |    |    |    |    |    |    |    |    |    [40:40] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    [40:40] <Match> = ♢}♢
|    |    |    |    |    |    |    |    [40:40] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [40:41] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [41:41] <Indenting> = ♢••••♢
|    |    |    |    |    |    |    |    [41:42] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [42:42] <Indenting> = ♢••••♢
|    |    |    |    |    |    |    |    [42:52] <CFunctionDefinition>
|    |    |    |    |    |    |    |    + <name> = ♢Compute♢
|    |    |    |    |    |    |    |    |    [42:42] <CVoid> = ♢void♢
|    |    |    |    |    |    |    |    |    [42:42] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [42:42] <Match> = ♢Compute♢
|    |    |    |    |    |    |    |    |    [42:42] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [42:42] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [42:42] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [42:42] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [42:52] <Braces>
|    |    |    |    |    |    |    |    |    |    [42:42] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    [42:43] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [43:43] <Indenting> = ♢••••→♢
|    |    |    |    |    |    |    |    |    |    [43:48] <CPPTry>
|    |    |    |    |    |    |    |    |    |    |    [43:43] <Match> = ♢try♢
|    |    |    |    |    |    |    |    |    |    |    [43:43] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [43:48] <Braces>
|    |    |    |    |    |    |    |    |    |    |    |    [43:43] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    |    |    [43:44] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    [44:44] <Indenting> = ♢••••••••→♢
|    |    |    |    |    |    |    |    |    |    |    |    [44:45] <CConditionIf>
|    |    |    |    |    |    |    |    |    |    |    |    |    [44:44] <Match> = ♢if♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [44:44] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [44:44] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [44:44] <CFunctionCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    + <name> = ♢value♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [44:44] <Match> = ♢value♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [44:44] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [44:44] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [44:44] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [44:44] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [44:45] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [45:45] <Indenting> = ♢••••••••••••→♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [45:45] <Text> = ♢cout♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [45:45] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [45:45] <Text> = ♢<<♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [45:45] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [45:45] <Text> = ♢2♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [45:45] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [45:45] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [45:45] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [45:45] <CFunctionCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    + <name> = ♢value♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [45:45] <Match> = ♢value♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [45:45] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [45:45] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [45:45] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [45:45] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [45:45] <Text> = ♢<<♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [45:45] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [45:45] <Text> = ♢endl♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [45:45] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    |    [45:46] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    [46:46] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    |    |    |    |    [46:47] <CConditionElse>
|    |    |    |    |    |    |    |    |    |    |    |    |    [46:46] <Match> = ♢else♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [46:47] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [47:47] <Indenting> = ♢••••••••••••→♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [47:47] <CPPThrow>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [47:47] <Match> = ♢throw♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [47:47] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [47:47] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [47:47] <CString> = ♢"Value•is•undefined"♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    + <cleaned> = ♢Value•is•undefined♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [47:47] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [47:47] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    |    [47:48] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    [48:48] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    |    |    |    |    |    |    [48:48] <Match> = ♢}♢
|    |    |    |    |    |    |    |    |    |    [48:49] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [49:49] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    |    |    |    |    [49:51] <CPPCatch>
|    |    |    |    |    |    |    |    |    |    |    [49:49] <Match> = ♢catch♢
|    |    |    |    |    |    |    |    |    |    |    [49:49] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    [49:49] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    [49:49] <Text> = ♢string♢
|    |    |    |    |    |    |    |    |    |    |    |    [49:49] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [49:49] <Text> = ♢error♢
|    |    |    |    |    |    |    |    |    |    |    |    [49:49] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    [49:49] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [49:51] <Braces>
|    |    |    |    |    |    |    |    |    |    |    |    [49:49] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    |    |    [49:50] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    [50:50] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    |    |    |    |    [50:50] <Text> = ♢cerr♢
|    |    |    |    |    |    |    |    |    |    |    |    [50:50] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [50:50] <Text> = ♢<<♢
|    |    |    |    |    |    |    |    |    |    |    |    [50:50] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [50:50] <Text> = ♢error♢
|    |    |    |    |    |    |    |    |    |    |    |    [50:50] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [50:50] <Text> = ♢<<♢
|    |    |    |    |    |    |    |    |    |    |    |    [50:50] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [50:50] <Text> = ♢endl♢
|    |    |    |    |    |    |    |    |    |    |    |    [50:50] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    |    [50:51] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    [51:51] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    |    |    |    |    |    |    [51:51] <Match> = ♢}♢
|    |    |    |    |    |    |    |    |    |    [51:52] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [52:52] <Indenting> = ♢••••♢
|    |    |    |    |    |    |    |    |    |    [52:52] <Match> = ♢}♢
|    |    |    |    |    |    |    [52:53] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [53:53] <Match> = ♢}♢
|    |    |    |    |    |    [53:53] <Semicolon> = ♢;♢
|    |    |    |    |    [53:54] <Newline> = ♢¶♢
|    |    |    |    |    [54:55] <Newline> = ♢¶♢
|    |    |    |    |    [55:55] <Match> = ♢}♢
|    |    |    [55:55] <Whitespace> = ♢••••♢
|    |    |    [55:56] <Newline> = ♢¶♢
|    |    |    [56:56] <Match> = ♢}♢
|    [56:57] <Newline> = ♢¶♢
|    [57:58] <Newline> = ♢¶♢
|    [58:58] <CPPUsing> = ♢using♢
|    [58:58] <Whitespace> = ♢•♢
|    [58:58] <Text> = ♢foo♢
|    [58:58] <DoubleSemicolon> = ♢::♢
|    [58:58] <Text> = ♢bar♢
|    [58:58] <DoubleSemicolon> = ♢::♢
|    [58:58] <Text> = ♢SubTest♢
|    [58:58] <Semicolon> = ♢;♢
|    [58:59] <Newline> = ♢¶♢
|    [59:60] <Newline> = ♢¶♢
|    [60:62] <CComment> = ♢/*¶*•The•main•function¶*/♢
|    + <cleaned> = ♢¶*•The•main•function¶♢
|    [62:63] <Newline> = ♢¶♢
|    [63:71] <CFunctionDefinition>
|    + <name> = ♢main♢
|    |    [63:63] <CInt> = ♢int♢
|    |    [63:63] <Whitespace> = ♢•♢
|    |    [63:63] <Match> = ♢main♢
|    |    [63:63] <Parenthesis>
|    |    |    [63:63] <Match> = ♢(♢
|    |    |    [63:63] <CInt> = ♢int♢
|    |    |    [63:63] <Whitespace> = ♢•♢
|    |    |    [63:63] <Text> = ♢argc,♢
|    |    |    [63:63] <Whitespace> = ♢•♢
|    |    |    [63:63] <CChar> = ♢char♢
|    |    |    [63:63] <Whitespace> = ♢•♢
|    |    |    [63:63] <Asterisk> = ♢*♢
|    |    |    [63:63] <Whitespace> = ♢•♢
|    |    |    [63:63] <CConst> = ♢const♢
|    |    |    [63:63] <Whitespace> = ♢•♢
|    |    |    [63:63] <Text> = ♢argv♢
|    |    |    [63:63] <Brackets>
|    |    |    |    [63:63] <Match> = ♢[♢
|    |    |    |    [63:63] <Match> = ♢]♢
|    |    |    [63:63] <Match> = ♢)♢
|    |    [63:63] <Whitespace> = ♢•♢
|    |    [63:71] <Braces>
|    |    |    [63:63] <Match> = ♢{♢
|    |    |    [63:64] <Newline> = ♢¶♢
|    |    |    [64:64] <Indenting> = ♢••••♢
|    |    |    [64:65] <Newline> = ♢¶♢
|    |    |    [65:65] <Indenting> = ♢••••♢
|    |    |    [65:65] <CPPComment> = ♢//Run•dummy•test♢
|    |    |    + <cleaned> = ♢Run•dummy•test♢
|    |    |    [65:66] <Newline> = ♢¶♢
|    |    |    [66:66] <Indenting> = ♢••••♢
|    |    |    [66:66] <Text> = ♢SubTest♢
|    |    |    [66:66] <Asterisk> = ♢*♢
|    |    |    [66:66] <Whitespace> = ♢•♢
|    |    |    [66:66] <Text> = ♢test♢
|    |    |    [66:66] <Whitespace> = ♢•♢
|    |    |    [66:66] <Text> = ♢=♢
|    |    |    [66:66] <Whitespace> = ♢•♢
|    |    |    [66:66] <CPPNew>
|    |    |    |    [66:66] <Match> = ♢new♢
|    |    |    |    [66:66] <Whitespace> = ♢•♢
|    |    |    |    [66:66] <CFunctionCall>
|    |    |    |    + <name> = ♢SubTest♢
|    |    |    |    |    [66:66] <Match> = ♢SubTest♢
|    |    |    |    |    [66:66] <Parenthesis>
|    |    |    |    |    |    [66:66] <Match> = ♢(♢
|    |    |    |    |    |    [66:66] <Match> = ♢)♢
|    |    |    |    [66:66] <Semicolon> = ♢;♢
|    |    |    [66:67] <Newline> = ♢¶♢
|    |    |    [67:67] <Indenting> = ♢••••♢
|    |    |    [67:67] <CPPFunctionCall>
|    |    |    |    [67:67] <Text> = ♢test♢
|    |    |    |    [67:67] <Arrow> = ♢->♢
|    |    |    |    [67:67] <Match> = ♢Compute♢
|    |    |    |    [67:67] <Parenthesis>
|    |    |    |    |    [67:67] <Match> = ♢(♢
|    |    |    |    |    [67:67] <Match> = ♢)♢
|    |    |    [67:67] <Semicolon> = ♢;♢
|    |    |    [67:67] <Whitespace> = ♢•♢
|    |    |    [67:67] <CPPComment> = ♢//•FIXME:•We•ignore•any•failures♢
|    |    |    + <cleaned> = ♢FIXME:•We•ignore•any•failures♢
|    |    |    [67:68] <Newline> = ♢¶♢
|    |    |    [68:68] <Indenting> = ♢••••♢
|    |    |    [68:68] <CPPDelete>
|    |    |    |    [68:68] <Match> = ♢delete♢
|    |    |    |    [68:68] <Whitespace> = ♢•♢
|    |    |    |    [68:68] <Text> = ♢test♢
|    |    |    |    [68:68] <Semicolon> = ♢;♢
|    |    |    [68:69] <Newline> = ♢¶♢
|    |    |    [69:69] <Indenting> = ♢••••♢
|    |    |    [69:70] <Newline> = ♢¶♢
|    |    |    [70:70] <Indenting> = ♢••••♢
|    |    |    [70:70] <CFlowReturn>
|    |    |    |    [70:70] <Match> = ♢return♢
|    |    |    |    [70:70] <Whitespace> = ♢•♢
|    |    |    |    [70:70] <Text> = ♢0♢
|    |    |    |    [70:70] <Semicolon> = ♢;♢
|    |    |    [70:71] <Newline> = ♢¶♢
|    |    |    [71:71] <Match> = ♢}♢
|    [71:72] <Newline> = ♢¶♢
|    [72:73] <Newline> = ♢¶♢
