/*
    This file is part of the PolParser library.
    Copyright (C) 2009 Pierre-Olivier Latour <info@pol-online.net>
    
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    
    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#import "Parser_Internal.h"
#import "ParserLanguage_C.h"

@interface ParserLanguageC : ParserLanguage <ParserLanguageCTopLevelNodeClasses> {
@private
	NSMutableDictionary* _topLevelNodeClasses;
}
@end

@implementation ParserLanguageC

+ (NSSet*) languageReservedKeywords {
	return [NSSet setWithObjects:@"auto", @"break", @"case", @"char", @"const", @"continue", @"default", @"do", @"double",
    	@"else", @"enum", @"inline", @"extern", @"float", @"for", @"goto", @"if", @"int", @"long", @"register", @"return", @"short",
        @"signed", @"sizeof", @"static", @"struct", @"switch", @"typedef", @"union", @"unsigned", @"void", @"volatile", @"while",
        @"NULL", nil]; //Not "true" keywords
}

+ (NSArray*) languageNodeClasses {
	NSMutableArray* classes = [NSMutableArray array];
    
    [classes addObject:[ParserNodeNewline class]];
    [classes addObject:[ParserNodeIndenting class]]; //Must be before ParserNodeWhitespace
    [classes addObject:[ParserNodeWhitespace class]];
    [classes addObject:[ParserNodeBraces class]];
    [classes addObject:[ParserNodeParenthesis class]];
    [classes addObject:[ParserNodeBrackets class]];
    [classes addObject:[ParserNodeColon class]];
    [classes addObject:[ParserNodeSemicolon class]];
    [classes addObject:[ParserNodeQuestionMark class]];
    [classes addObject:[ParserNodeExclamationMark class]];
    [classes addObject:[ParserNodeTilda class]];
    [classes addObject:[ParserNodeCaret class]];
    [classes addObject:[ParserNodeAmpersand class]];
    [classes addObject:[ParserNodeAsterisk class]];
    
    [classes addObject:[ParserNodeCComment class]];
    [classes addObject:[ParserNodeCPreprocessorConditionIf class]];
    [classes addObject:[ParserNodeCPreprocessorConditionIfdef class]];
    [classes addObject:[ParserNodeCPreprocessorConditionIfndef class]];
    [classes addObject:[ParserNodeCPreprocessorConditionElse class]];
    [classes addObject:[ParserNodeCPreprocessorConditionElseif class]];
    [classes addObject:[ParserNodeCPreprocessorDefine class]];
    [classes addObject:[ParserNodeCPreprocessorUndefine class]];
    [classes addObject:[ParserNodeCPreprocessorPragma class]];
    [classes addObject:[ParserNodeCPreprocessorWarning class]];
    [classes addObject:[ParserNodeCPreprocessorError class]];
    [classes addObject:[ParserNodeCPreprocessorInclude class]];
    [classes addObject:[ParserNodeCCharacterLiteral class]];
    [classes addObject:[ParserNodeCString class]];
    [classes addObject:[ParserNodeCConditionalOperator class]];
    [classes addObject:[ParserNodeCConditionIf class]];
    [classes addObject:[ParserNodeCConditionElseIf class]]; //Must be before ParserNodeCConditionElse
    [classes addObject:[ParserNodeCConditionElse class]];
    [classes addObject:[ParserNodeCFlowBreak class]];
    [classes addObject:[ParserNodeCFlowContinue class]];
    [classes addObject:[ParserNodeCFlowSwitch class]];
    [classes addObject:[ParserNodeCFlowCase class]];
    [classes addObject:[ParserNodeCFlowDefault class]];
    [classes addObject:[ParserNodeCFlowFor class]];
    [classes addObject:[ParserNodeCFlowDoWhile class]];
    [classes addObject:[ParserNodeCFlowWhile class]];
    [classes addObject:[ParserNodeCFlowGoto class]];
    [classes addObject:[ParserNodeCFlowLabel class]];
    [classes addObject:[ParserNodeCFlowReturn class]];
    [classes addObject:[ParserNodeCTypedef class]];
    [classes addObject:[ParserNodeCTypeStruct class]];
    [classes addObject:[ParserNodeCTypeUnion class]];
	[classes addObject:[ParserNodeCTypeEnum class]];
    [classes addObject:[ParserNodeCSizeOf class]];
    [classes addObject:[ParserNodeCTypeOf class]];
    
    [classes addObject:[ParserNodeCFunctionPrototype class]];
    [classes addObject:[ParserNodeCFunctionDefinition class]];
    [classes addObject:[ParserNodeCFunctionCall class]];
    
    return classes;
}

+ (NSSet*) languageTopLevelNodeClasses {
	return [NSSet setWithObjects:[ParserNodeRoot class], [ParserNodeCPreprocessorConditionIf class], [ParserNodeCPreprocessorConditionIfdef class],
    	[ParserNodeCPreprocessorConditionIfndef class], [ParserNodeCPreprocessorConditionElse class], [ParserNodeCPreprocessorConditionElseif class], nil];
}

- (id) init {
	if((self = [super init]))
    	_topLevelNodeClasses = [[NSMutableDictionary alloc] init];
    return self;
}

- (void) dealloc {
	[_topLevelNodeClasses release];
    
	[super dealloc];
}

- (NSString*) name {
    return @"C";
}

- (NSSet*) fileExtensions {
    return [NSSet setWithObject:@"c"];
}

static inline BOOL _IsNodeInBlock(ParserNode* node) {
    while(node.parent) {
    	if([node isKindOfClass:[ParserNodeParenthesis class]] || [node isKindOfClass:[ParserNodeBrackets class]] || [node isKindOfClass:[ParserNodeBraces class]])
        	return YES;
    	node = node.parent;
    }
    
    return NO;
}

static inline BOOL _IsIdentifier(const unichar* buffer, NSUInteger length) {
	for(NSUInteger i = 0; i < length; ++i) {
    	if(!((buffer[i] >= 'a') && (buffer[i] <= 'z'))
        	&& !((buffer[i] >= 'A') && (buffer[i] <= 'Z'))
            && !(i && (buffer[i] >= '0') && (buffer[i] <= '9'))
        	&& (buffer[i] != '_'))
        	return NO;
    }
    return YES;
}

static inline BOOL _IsNodeAtTopLevel(ParserNode* node, NSSet* topLevelClasses) {
	while(node.parent) {
    	if(![topLevelClasses containsObject:[node.parent class]])
        	return NO;
    	node = node.parent;
    }
    
    return YES;
}

- (NSSet*) _topLevelNodeClassesForLanguage:(ParserLanguage*)language {
	NSMutableSet* set = [_topLevelNodeClasses objectForKey:language];
    if(set == nil) {
    	set = [[NSMutableSet alloc] init];
        for(ParserLanguage* sublanguage in language.allLanguageDependencies) {
            if([sublanguage conformsToProtocol:@protocol(ParserLanguageCTopLevelNodeClasses)])
            	[set unionSet:[[sublanguage class] languageTopLevelNodeClasses]];
        }
        [_topLevelNodeClasses setObject:set forKey:language];
        [set release];
    }
    return set;
}

- (ParserNode*) performSyntaxAnalysisForNode:(ParserNode*)node textBuffer:(const unichar*)textBuffer topLevelLanguage:(ParserLanguage*)topLevelLanguage {
    
    if([node isKindOfClass:[ParserNodeBraces class]]) {
        ParserNode* previousNode = [node findPreviousSiblingIgnoringWhitespaceAndNewline];
        
        // "if() {}" "else if() {}" "for() {}" "switch() {}" "while() {}"
        if([previousNode isKindOfClass:[ParserNodeParenthesis class]]) {
            previousNode = [previousNode findPreviousSiblingIgnoringWhitespaceAndNewline];
            if([previousNode isKindOfClass:[ParserNodeCConditionIf class]] || [previousNode isKindOfClass:[ParserNodeCConditionElseIf class]] || [previousNode isKindOfClass:[ParserNodeCFlowFor class]]
            	|| [previousNode isKindOfClass:[ParserNodeCFlowSwitch class]] || [previousNode isKindOfClass:[ParserNodeCFlowWhile class]]) {
               	_RearrangeNodesAsChildren(previousNode, node);
            }
        }
        
        // "do {} while()"
        else if([previousNode isKindOfClass:[ParserNodeCFlowDoWhile class]]) {
            ParserNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
            if([nextNode isKindOfClass:[ParserNodeCFlowWhile class]]) {
                ParserNode* nextNextNode = [nextNode findNextSiblingIgnoringWhitespaceAndNewline];
                if([nextNextNode isKindOfClass:[ParserNodeParenthesis class]]) {
                    _RearrangeNodesAsChildren(previousNode, nextNextNode);
                    
                    [nextNode replaceWithNodeOfClass:[ParserNodeMatch class] preserveChildren:NO];
                }
            }
        }
        
    } else if([node isKindOfClass:[ParserNodeCConditionElse class]]) {
        
        // "else {}" "else"
        ParserNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
        if(![nextNode isKindOfClass:[ParserNodeCConditionIf class]]) {
            ParserNode* bracesNode = [node findNextSiblingOfClass:[ParserNodeBraces class]];
            ParserNode* semicolonNode = [node findNextSiblingOfClass:[ParserNodeSemicolon class]];
            if(bracesNode && (!semicolonNode || ([node.parent indexOfChild:bracesNode] < [node.parent indexOfChild:semicolonNode])))
                _RearrangeNodesAsChildren(node, bracesNode);
            else if(semicolonNode && (!bracesNode || ([node.parent indexOfChild:semicolonNode] < [node.parent indexOfChild:bracesNode])))
                _RearrangeNodesAsChildren(node, semicolonNode);
        }
        
    } else if([node isKindOfClass:[ParserNodeCConditionIf class]] || [node isKindOfClass:[ParserNodeCConditionElseIf class]] || [node isKindOfClass:[ParserNodeCFlowFor class]] || [node isKindOfClass:[ParserNodeCFlowSwitch class]]) {
        
        // "if()" "else if()" "for()" "switch()"
        ParserNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
        if([nextNode isKindOfClass:[ParserNodeParenthesis class]]) {
            ParserNode* bracesNode = [nextNode findNextSiblingOfClass:[ParserNodeBraces class]];
            ParserNode* semicolonNode = [nextNode findNextSiblingOfClass:[ParserNodeSemicolon class]];
            if(semicolonNode && (!bracesNode || ([node.parent indexOfChild:semicolonNode] < [node.parent indexOfChild:bracesNode])))
                _RearrangeNodesAsChildren(node, semicolonNode);
        }
        
    } else if([node isKindOfClass:[ParserNodeCFlowCase class]] || [node isKindOfClass:[ParserNodeCFlowDefault class]]) {
        
        // "case:" "case: break" "default:" "default: break"
        ParserNode* endNode = [node.parent lastChild];
        if([endNode isKindOfClass:[ParserNodeWhitespace class]] || [endNode isKindOfClass:[ParserNodeNewline class]])
        	endNode = [endNode findPreviousSiblingIgnoringWhitespaceAndNewline];
        ParserNode* breakNode = [node findNextSiblingOfClass:[ParserNodeCFlowBreak class]];
        if(breakNode && (breakNode.range.location < endNode.range.location))
        	endNode = [breakNode findNextSiblingOfClass:[ParserNodeSemicolon class]];
        ParserNode* caseNode = [node findNextSiblingOfClass:[ParserNodeCFlowCase class]];
        if(caseNode && (caseNode.range.location < endNode.range.location))
        	endNode = caseNode.previousSibling;
        ParserNode* defaultNode = [node findNextSiblingOfClass:[ParserNodeCFlowDefault class]];
        if(defaultNode && (defaultNode.range.location < endNode.range.location))
        	endNode = defaultNode.previousSibling;
        
        _RearrangeNodesAsChildren(node, endNode);
        
    } else if([node isKindOfClass:[ParserNodeCFlowReturn class]]) {
        
        // "return" "return foo"
        ParserNode* semicolonNode = [node findNextSiblingOfClass:[ParserNodeSemicolon class]];
        if(semicolonNode) {
        	if(semicolonNode.previousSibling != node)
                _RearrangeNodesAsChildren(node, semicolonNode);
        } else {
            if([node.parent isKindOfClass:[ParserNodeCConditionIf class]] || [node.parent isKindOfClass:[ParserNodeCConditionElse class]] || [node.parent isKindOfClass:[ParserNodeCConditionElseIf class]]
            	|| [node.parent isKindOfClass:[ParserNodeCFlowFor class]] || [node.parent isKindOfClass:[ParserNodeCFlowWhile class]])
            	_RearrangeNodesAsChildren(node, node.parent.lastChild);
        }
        
    } else if([node isKindOfClass:[ParserNodeCFlowGoto class]]) {
        
        // "goto foo"
        ParserNode* semicolonNode = [node findNextSiblingOfClass:[ParserNodeSemicolon class]];
        if(semicolonNode) {
            _RearrangeNodesAsChildren(node, semicolonNode);
        } else {
            if([node.parent isKindOfClass:[ParserNodeCConditionIf class]] || [node.parent isKindOfClass:[ParserNodeCConditionElse class]] || [node.parent isKindOfClass:[ParserNodeCConditionElseIf class]]
            	|| [node.parent isKindOfClass:[ParserNodeCFlowFor class]] || [node.parent isKindOfClass:[ParserNodeCFlowWhile class]])
            	_RearrangeNodesAsChildren(node, node.parent.lastChild);
        }
        
    } else if([node isKindOfClass:[ParserNodeColon class]] && [node.parent isKindOfClass:[ParserNodeBraces class]]) {
        
        // "foo:"
        ParserNode* labelNode = [node findPreviousSiblingIgnoringWhitespaceAndNewline];
        if([labelNode isMemberOfClass:[ParserNodeText class]]) {
        	ParserNode* previousNode = [labelNode findPreviousSiblingIgnoringWhitespaceAndNewline];
            if(![previousNode isKindOfClass:[ParserNodeQuestionMark class]]) {
            	ParserNode* newNode = [[ParserNodeCFlowLabel alloc] initWithText:labelNode.text range:NSMakeRange(labelNode.range.location, 0)];
                [labelNode insertPreviousSibling:newNode];
                [newNode release];
                
                _RearrangeNodesAsChildren(newNode, node);
            }
        }
        
    } else if([node isKindOfClass:[ParserNodeQuestionMark class]]) {
        
        // "foo ? bar : baz" "(foo) ? (bar) : (baz)"
        ParserNode* startNode = [node findPreviousSiblingIgnoringWhitespaceAndNewline];
        if([startNode isMemberOfClass:[ParserNodeText class]] || [startNode isKindOfClass:[ParserNodeParenthesis class]]) {
        	ParserNode* middleNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
            if([middleNode isMemberOfClass:[ParserNodeText class]] || [middleNode isKindOfClass:[ParserNodeParenthesis class]]) {
                ParserNode* colonNode = [middleNode findNextSiblingIgnoringWhitespaceAndNewline];
                if([colonNode isKindOfClass:[ParserNodeColon class]]) {
                    ParserNode* endNode = [colonNode findNextSiblingIgnoringWhitespaceAndNewline];
                    if([endNode isMemberOfClass:[ParserNodeText class]] || [endNode isKindOfClass:[ParserNodeParenthesis class]]) {
                        ParserNode* newNode = [[ParserNodeCConditionalOperator alloc] initWithText:startNode.text range:NSMakeRange(startNode.range.location, 0)];
                        [startNode insertPreviousSibling:newNode];
                        [newNode release];
                        
                        _RearrangeNodesAsChildren(newNode, endNode);
                    }
                }
            }
        }
        
    } else if([node isKindOfClass:[ParserNodeCTypeEnum class]] || [node isKindOfClass:[ParserNodeCTypeStruct class]] || [node isKindOfClass:[ParserNodeCTypeUnion class]]) {
        
        // "enum {}" "struct {}" "union {}"
		ParserNode* bracesNode = [node findNextSiblingOfClass:[ParserNodeBraces class]];
        ParserNode* semicolonNode = [node findNextSiblingOfClass:[ParserNodeSemicolon class]];
        if(bracesNode && (!semicolonNode || ([node.parent indexOfChild:semicolonNode] > [node.parent indexOfChild:bracesNode]))) {
            if(!semicolonNode)
                _RearrangeNodesAsChildren(node, node.parent.lastChild);
            else if(semicolonNode)
                _RearrangeNodesAsChildren(node, semicolonNode);
        }
        
    } else if([node isKindOfClass:[ParserNodeCTypedef class]]) {
        
        // "typedef foo"
        ParserNode* semicolonNode = [node findNextSiblingOfClass:[ParserNodeSemicolon class]];
        if(semicolonNode)
            _RearrangeNodesAsChildren(node, semicolonNode);
        
    } else if([node isKindOfClass:[ParserNodeCSizeOf class]] || [node isKindOfClass:[ParserNodeCTypeOf class]]) {
        
        // "sizeof()" "typeof()"
        ParserNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
        if([nextNode isKindOfClass:[ParserNodeParenthesis class]])
            _RearrangeNodesAsChildren(node, nextNode);
        
    } else if([node isKindOfClass:[ParserNodeParenthesis class]]) {
        
        // "foo bar()" "foo bar() {}"
        if(_IsNodeAtTopLevel(node, [self _topLevelNodeClassesForLanguage:topLevelLanguage])) {
            ParserNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
            if([nextNode isKindOfClass:[ParserNodeSemicolon class]] || [nextNode isKindOfClass:[ParserNodeBraces class]]) {
                ParserNode* previousNode = [node findPreviousSiblingIgnoringWhitespaceAndNewline];
                if([previousNode isMemberOfClass:[ParserNodeText class]] && _IsIdentifier(textBuffer + previousNode.range.location, previousNode.range.length)) {
                    previousNode = [previousNode replaceWithNodeOfClass:[ParserNodeMatch class] preserveChildren:NO];
                    while(1) {
                    	ParserNode* siblingNode = [previousNode findPreviousSiblingIgnoringWhitespaceAndNewline];
                        if(![siblingNode isMemberOfClass:[ParserNodeText class]] && ![siblingNode isKindOfClass:[ParserNodeKeyword class]] && ![siblingNode isKindOfClass:[ParserNodeAsterisk class]])
                        	break;
                        previousNode = siblingNode;
                    }
                    ParserNode* newNode = [([nextNode isKindOfClass:[ParserNodeBraces class]] ? [ParserNodeCFunctionDefinition alloc] : [ParserNodeCFunctionPrototype alloc]) initWithText:previousNode.text range:NSMakeRange(previousNode.range.location, 0)];
                    [previousNode insertPreviousSibling:newNode];
                    [newNode release];
                    _RearrangeNodesAsChildren(newNode, nextNode);
                }
                
            }
        }
        
        else if(![node.parent isKindOfClass:[ParserNodeCFunctionDefinition class]] && ![node.parent isKindOfClass:[ParserNodeCFunctionCall class]] && ![node.parent isKindOfClass:[ParserNodeCPreprocessorDefine class]] && _IsNodeInBlock(node)) {
            ParserNode* previousNode = [node findPreviousSiblingIgnoringWhitespaceAndNewline];
            if([previousNode isMemberOfClass:[ParserNodeText class]] && _IsIdentifier(textBuffer + previousNode.range.location, previousNode.range.length)) {
            	previousNode = [previousNode replaceWithNodeOfClass:[ParserNodeMatch class] preserveChildren:NO];
                
                ParserNode* newNode = [[ParserNodeCFunctionCall alloc] initWithText:previousNode.text range:NSMakeRange(previousNode.range.location, 0)];
                [previousNode insertPreviousSibling:newNode];
                [newNode release];
                _RearrangeNodesAsChildren(newNode, node);
            }
            
        }
        
    }
    
    //FIXME: Add support for blocks
    
    return node;
}

@end

@implementation ParserNodeCComment

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (string[0] == '/') && (string[1] == '*') ? 2 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (string[0] == '*') && (string[1] == '/') ? 2 : NSNotFound;
}

- (NSString*) cleanContent {
	NSRange range = self.range;
    return [self.text substringWithRange:NSMakeRange(range.location + 2, range.length - 4)];
}

@end

@implementation ParserNodeCPreprocessor

+ (id) allocWithZone:(NSZone*)zone
{
    if(self == [ParserNodeCPreprocessor class])
        [NSException raise:NSInternalInconsistencyException format:@"ParserNodeCPreprocessor is an abstract class"];
    
    return [super allocWithZone:zone];
}

+ (BOOL) isAtomic {
    return NO;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    while(maxLength) {
        if(IsNewline(*string) || (*string == '#') || ((string[0] == '/') && ((string[1] == '*') || (string[1] == '/')))) {
            do {
                --string;
            } while(IsWhitespace(*string));
            if(*string != '\\')
                return 0;
        }
        if(!IsWhitespace(*string))
            break;
        ++string;
        --maxLength;
    }
    
    return NSNotFound;
}

@end

@implementation ParserNodeCPreprocessorCondition

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    {
        IS_MATCHING_CHARACTERS_EXTENDED("#else", true, NULL, string, maxLength);
        if(_matching != NSNotFound)
            return 0;
    }
    {
        IS_MATCHING_CHARACTERS_EXTENDED("#elseif", true, "(", string, maxLength);
        if(_matching != NSNotFound)
            return 0;
    }
    {
        IS_MATCHING_CHARACTERS_EXTENDED("#endif", true, NULL, string, maxLength);
        if(_matching != NSNotFound)
            return _matching;
    }
    
    return NSNotFound;
}

@end

#define IMPLEMENTATION(__NAME__, __PREFIX__, __CHARACTERS__) \
@implementation ParserNodeCPreprocessorCondition##__NAME__ \
\
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    IS_MATCHING_CHARACTERS_EXTENDED(__PREFIX__, true, __CHARACTERS__, string, maxLength) \
    if(_matching != NSNotFound) { \
        string += _matching; \
        maxLength -= _matching; \
        while(maxLength) { \
            if(IsNewline(*string) || (*string == '#') || ((string[0] == '/') && ((string[1] == '*') || (string[1] == '/')))) { \
                do { \
                    --string; \
                } while(IsWhitespace(*string)); \
                if(*string != '\\') \
                    break; \
            } \
            ++string; \
            --maxLength; \
            ++_matching; \
        } \
    } \
    return _matching; \
} \
\
@end

IMPLEMENTATION(If, "#if", "(")
IMPLEMENTATION(Ifdef, "#ifdef", "(")
IMPLEMENTATION(Ifndef, "#ifndef", "(")
IMPLEMENTATION(Else, "#else", "(")
IMPLEMENTATION(Elseif, "#elseif", "(")

#undef IMPLEMENTATION

/* WARNING: Keep in sync with Obj-C #import */
#define IMPLEMENTATION(__NAME__, __CHARACTERS__, ...) \
@implementation ParserNodeCPreprocessor##__NAME__ \
\
IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_CHARACTERS(__CHARACTERS__, __VA_ARGS__) \
\
- (void) dealloc { \
	[_name release]; \
    \
    [super dealloc]; \
} \
\
- (NSString*) name { \
	if(_name == nil) \
    	_name = [[[self.firstChild findNextSiblingIgnoringWhitespaceAndNewline] content] copy]; \
    return _name; \
} \
\
@end

IMPLEMENTATION(Define, "#define", true, NULL)
IMPLEMENTATION(Undefine, "#undef", true, NULL)
IMPLEMENTATION(Pragma, "#pragma", true, "(")
IMPLEMENTATION(Warning, "#warning", true, "(")
IMPLEMENTATION(Error, "#error", true, "(")
IMPLEMENTATION(Include, "#include", true, NULL)

#undef IMPLEMENTATION

@implementation ParserNodeCCharacterLiteral

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (*string == '\'') ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (*string == '\'') && !((*(string - 1) == '\\') && (*(string - 2) != '\\')) ? 1 : NSNotFound;
}

- (NSString*) cleanContent {
	NSRange range = self.range;
    return _CleanEscapedString([self.text substringWithRange:NSMakeRange(range.location + 1, range.length - 2)]);
}

@end

@implementation ParserNodeCString

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (*string == '"') ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (*string == '"') && !((*(string - 1) == '\\') && (*(string - 2) != '\\')) ? 1 : NSNotFound;
}

- (NSString*) cleanContent {
	NSRange range = self.range;
    return _CleanEscapedString([self.text substringWithRange:NSMakeRange(range.location + 1, range.length - 2)]);
}

@end

KEYWORD_CLASS_IMPLEMENTATION(C, NULL, "NULL")
KEYWORD_CLASS_IMPLEMENTATION(C, Void, "void")
KEYWORD_CLASS_IMPLEMENTATION(C, Auto, "auto")
KEYWORD_CLASS_IMPLEMENTATION(C, Static, "static")
KEYWORD_CLASS_IMPLEMENTATION(C, Register, "register")
KEYWORD_CLASS_IMPLEMENTATION(C, Volatile, "volatile")
KEYWORD_CLASS_IMPLEMENTATION(C, Const, "const")
KEYWORD_CLASS_IMPLEMENTATION(C, Extern, "extern")
KEYWORD_CLASS_IMPLEMENTATION(C, Inline, "inline")
KEYWORD_CLASS_IMPLEMENTATION(C, Signed, "signed")
KEYWORD_CLASS_IMPLEMENTATION(C, Unsigned, "unsigned")
KEYWORD_CLASS_IMPLEMENTATION(C, Char, "char")
KEYWORD_CLASS_IMPLEMENTATION(C, Short, "short")
KEYWORD_CLASS_IMPLEMENTATION(C, Int, "int")
KEYWORD_CLASS_IMPLEMENTATION(C, Long, "long")
KEYWORD_CLASS_IMPLEMENTATION(C, Float, "float")
KEYWORD_CLASS_IMPLEMENTATION(C, Double, "double")

#define IMPLEMENTATION(__NAME__, ...) \
@implementation ParserNodeC##__NAME__ \
\
IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_CHARACTERS(__VA_ARGS__) \
\
+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    return 0; \
} \
\
@end

IMPLEMENTATION(ConditionIf, "if", true, "(")
IMPLEMENTATION(ConditionElse, "else", true, "{")
IMPLEMENTATION(FlowBreak, "break", true, ";")
IMPLEMENTATION(FlowContinue, "continue", true, ";")
IMPLEMENTATION(FlowSwitch, "switch", true, "(")
IMPLEMENTATION(FlowCase, "case", true, NULL)
IMPLEMENTATION(FlowDefault, "default", true, ":")
IMPLEMENTATION(FlowFor, "for", true, "(")
IMPLEMENTATION(FlowDoWhile, "do", true, "{")
IMPLEMENTATION(FlowWhile, "while", true, "(")
IMPLEMENTATION(FlowGoto, "goto", true, NULL)
IMPLEMENTATION(FlowReturn, "return", true, ";(")
IMPLEMENTATION(Typedef, "typedef", true, NULL)
IMPLEMENTATION(TypeStruct, "struct", true, "{")
IMPLEMENTATION(TypeUnion, "union", true, "{")
IMPLEMENTATION(TypeEnum, "enum", true, "{")
IMPLEMENTATION(SizeOf, "sizeof", true, "(")
IMPLEMENTATION(TypeOf, "typeof", true, "(")

#undef IMPLEMENTATION

@implementation ParserNodeCConditionElseIf

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    NSUInteger length = [ParserNodeCConditionElse isMatchingPrefix:string maxLength:maxLength];
    if(length != NSNotFound) {
        string += length;
        maxLength -= length;
        while(IsWhitespaceOrNewline(*string) && maxLength) {
            ++length;
            ++string;
            --maxLength;
        }
        if(maxLength) {
            NSUInteger nextLength = [ParserNodeCConditionIf isMatchingPrefix:string maxLength:maxLength];
            if(nextLength != NSNotFound)
            	return length + nextLength;
        }
    }
    return NSNotFound;
}


@end

@implementation ParserNodeCConditionalOperator
@end

@implementation ParserNodeCFlowLabel
@end

@implementation ParserNodeCFunctionPrototype

- (NSString*) name {
	return [self findFirstChildOfClass:[ParserNodeMatch class]].content;
}

@end

@implementation ParserNodeCFunctionDefinition

- (NSString*) name {
	return [self findFirstChildOfClass:[ParserNodeMatch class]].content;
}

@end

@implementation ParserNodeCFunctionCall

- (NSString*) name {
	return [self findFirstChildOfClass:[ParserNodeMatch class]].content;
}

@end
