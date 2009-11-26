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

#import "SourceParser_Internal.h"

@implementation SourceLanguageC

+ (NSArray*) languageDependencies {
	return [NSArray arrayWithObject:@"Base"];
}

+ (NSSet*) languageReservedKeywords {
	return [NSSet setWithObjects:@"auto", @"break", @"case", @"char", @"const", @"continue", @"default", @"do", @"double",
    	@"else", @"enum", @"extern", @"float", @"for", @"goto", @"if", @"int", @"long", @"register", @"return", @"short", @"signed",
        @"sizeof", @"static", @"struct", @"switch", @"typedef", @"union", @"unsigned", @"void", @"volatile", @"while", nil];
}

+ (NSArray*) languageNodeClasses {
	NSMutableArray* classes = [NSMutableArray array];
    
    [classes addObject:[SourceNodeCComment class]];
    [classes addObject:[SourceNodeCPreprocessorIf class]];
    [classes addObject:[SourceNodeCPreprocessorIfdef class]];
    [classes addObject:[SourceNodeCPreprocessorIfndef class]];
    [classes addObject:[SourceNodeCPreprocessorElse class]];
    [classes addObject:[SourceNodeCPreprocessorElseif class]];
    [classes addObject:[SourceNodeCPreprocessorEndif class]];
    [classes addObject:[SourceNodeCPreprocessorDefine class]];
    [classes addObject:[SourceNodeCPreprocessorUndefine class]];
    [classes addObject:[SourceNodeCPreprocessorPragma class]];
    [classes addObject:[SourceNodeCPreprocessorWarning class]];
    [classes addObject:[SourceNodeCPreprocessorError class]];
    [classes addObject:[SourceNodeCPreprocessorInclude class]];
    [classes addObject:[SourceNodeColon class]];
    [classes addObject:[SourceNodeSemicolon class]];
    [classes addObject:[SourceNodeQuestionMark class]];
    [classes addObject:[SourceNodeExclamationMark class]];
    [classes addObject:[SourceNodeTilda class]];
    [classes addObject:[SourceNodeCaret class]];
    [classes addObject:[SourceNodeAmpersand class]];
    [classes addObject:[SourceNodeAsterisk class]];
    [classes addObject:[SourceNodeCNULL class]];
    [classes addObject:[SourceNodeCVoid class]];
    [classes addObject:[SourceNodeCStringSingleQuote class]];
    [classes addObject:[SourceNodeCStringDoubleQuote class]];
    [classes addObject:[SourceNodeCConditionalOperator class]];
    [classes addObject:[SourceNodeCConditionIf class]];
    [classes addObject:[SourceNodeCConditionElse class]];
    [classes addObject:[SourceNodeCConditionElseIf class]];
    [classes addObject:[SourceNodeCFlowBreak class]];
    [classes addObject:[SourceNodeCFlowContinue class]];
    [classes addObject:[SourceNodeCFlowSwitch class]];
    [classes addObject:[SourceNodeCFlowCase class]];
    [classes addObject:[SourceNodeCFlowDefault class]];
    [classes addObject:[SourceNodeCFlowFor class]];
    [classes addObject:[SourceNodeCFlowDoWhile class]];
    [classes addObject:[SourceNodeCFlowWhile class]];
    [classes addObject:[SourceNodeCFlowGoto class]];
    [classes addObject:[SourceNodeCFlowLabel class]];
    [classes addObject:[SourceNodeCFlowReturn class]];
    [classes addObject:[SourceNodeCTypedef class]];
    [classes addObject:[SourceNodeCTypeStruct class]];
    [classes addObject:[SourceNodeCTypeUnion class]];
    [classes addObject:[SourceNodeCTypeAuto class]];
    [classes addObject:[SourceNodeCTypeStatic class]];
    [classes addObject:[SourceNodeCTypeRegister class]];
    [classes addObject:[SourceNodeCTypeVolatile class]];
    [classes addObject:[SourceNodeCTypeConst class]];
    [classes addObject:[SourceNodeCTypeEnum class]];
    [classes addObject:[SourceNodeCTypeExtern class]];
    [classes addObject:[SourceNodeCTypeInline class]];
    [classes addObject:[SourceNodeCSizeOf class]];
    [classes addObject:[SourceNodeCTypeOf class]];
    
    [classes addObject:[SourceNodeCFunctionPrototype class]];
    [classes addObject:[SourceNodeCFunctionDefinition class]];
    [classes addObject:[SourceNodeCFunctionCall class]];
    
    return classes;
}

+ (NSSet*) languageTopLevelNodeClasses {
	return [NSSet setWithObjects:[SourceNodeCPreprocessorIf class], [SourceNodeCPreprocessorIfdef class],
    	[SourceNodeCPreprocessorIfndef class], [SourceNodeCPreprocessorElse class], [SourceNodeCPreprocessorElseif class], nil];
}

- (NSString*) name {
    return @"C";
}

- (NSSet*) fileExtensions {
    return [NSSet setWithObject:@"c"];
}

static inline BOOL _IsNodeInBlock(SourceNode* node) {
    while(node.parent) {
    	if([node isKindOfClass:[SourceNodeParenthesis class]] || [node isKindOfClass:[SourceNodeBrackets class]] || [node isKindOfClass:[SourceNodeBraces class]])
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

static inline BOOL _IsNodeAtTopLevel(SourceNode* node, NSSet* topLevelClasses) {
	while(node.parent) {
    	if(![topLevelClasses containsObject:[node.parent class]])
        	return NO;
    	node = node.parent;
    }
    
    return YES;
}

- (SourceNode*) performSyntaxAnalysisForNode:(SourceNode*)node sourceBuffer:(const unichar*)sourceBuffer topLevelNodeClasses:(NSSet*)nodeClasses {
    
    if([node isKindOfClass:[SourceNodeCPreprocessorIf class]] || [node isKindOfClass:[SourceNodeCPreprocessorIfdef class]] || [node isKindOfClass:[SourceNodeCPreprocessorIfndef class]]
    	|| [node isKindOfClass:[SourceNodeCPreprocessorElse class]] || [node isKindOfClass:[SourceNodeCPreprocessorElseif class]]) {
    	
        // #if #ifdef #ifndef #else #elseif ... #endif
        SourceNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
        while(nextNode) {
        	if([nextNode isKindOfClass:[SourceNodeCPreprocessorElse class]] || [nextNode isKindOfClass:[SourceNodeCPreprocessorElseif class]] || [nextNode isKindOfClass:[SourceNodeCPreprocessorEndif class]])
            	break;
            nextNode = [nextNode findNextSiblingIgnoringWhitespaceAndNewline];
        }
        if(nextNode)
        	_RearrangeNodesAsChildren(node, [nextNode findPreviousSiblingIgnoringWhitespaceAndNewline]);
        
    } else if([node isKindOfClass:[SourceNodeBraces class]]) {
        SourceNode* previousNode = [node findPreviousSiblingIgnoringWhitespaceAndNewline];
        
        // "if() {}" "for() {}" "switch() {}" "while() {}" "else if() {}"
        if([previousNode isKindOfClass:[SourceNodeParenthesis class]]) {
            previousNode = [previousNode findPreviousSiblingIgnoringWhitespaceAndNewline];
            if([previousNode isKindOfClass:[SourceNodeCConditionIf class]] || [previousNode isKindOfClass:[SourceNodeCFlowFor class]] || [previousNode isKindOfClass:[SourceNodeCFlowSwitch class]] || [previousNode isKindOfClass:[SourceNodeCFlowWhile class]]) {
                SourceNode* elseNode = [previousNode isKindOfClass:[SourceNodeCConditionIf class]] ? [previousNode findPreviousSiblingIgnoringWhitespaceAndNewline] : nil;
                if([elseNode isKindOfClass:[SourceNodeCConditionElse class]] && !elseNode.children) {
                	SourceNode* newNode = [[SourceNodeCConditionElseIf alloc] initWithSource:elseNode.source range:NSMakeRange(elseNode.range.location, 0)];
                    [elseNode insertPreviousSibling:newNode];
                    [newNode release];
                    
                    SourceNode* textNode = [[SourceNodeText alloc] initWithSource:elseNode.source range:elseNode.range];
                    [elseNode insertPreviousSibling:textNode];
                    [textNode release];
                    [elseNode removeFromParent];
                    
                    textNode = [[SourceNodeText alloc] initWithSource:previousNode.source range:previousNode.range];
                    [previousNode insertPreviousSibling:textNode];
                    [textNode release];
                    [previousNode removeFromParent];
                    
                    _RearrangeNodesAsChildren(newNode, node);
                } else {
                	_RearrangeNodesAsChildren(previousNode, node);
                }
            }
        }
        
        // "do {} while()"
        else if([previousNode isKindOfClass:[SourceNodeCFlowDoWhile class]]) {
            SourceNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
            if([nextNode isKindOfClass:[SourceNodeCFlowWhile class]]) {
                SourceNode* nextNextNode = [nextNode findNextSiblingIgnoringWhitespaceAndNewline];
                if([nextNextNode isKindOfClass:[SourceNodeParenthesis class]]) {
                    _RearrangeNodesAsChildren(previousNode, nextNextNode);
                    
                    SourceNode* newWhile = [[SourceNodeText alloc] initWithSource:nextNode.source range:nextNode.range];
                    [nextNode replaceWithNode:newWhile];
                    [newWhile release];
                }
            }
        }
        
    } else if([node isKindOfClass:[SourceNodeCConditionElse class]]) {
        
        // "else {}" "else"
        SourceNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
        if(![nextNode isKindOfClass:[SourceNodeCConditionIf class]]) {
            SourceNode* bracesNode = [node findNextSiblingOfClass:[SourceNodeBraces class]];
            SourceNode* semicolonNode = [node findNextSiblingOfClass:[SourceNodeSemicolon class]];
            if(bracesNode && (!semicolonNode || ([node.parent indexOfChild:bracesNode] < [node.parent indexOfChild:semicolonNode])))
                _RearrangeNodesAsChildren(node, bracesNode);
            else if(semicolonNode && (!bracesNode || ([node.parent indexOfChild:semicolonNode] < [node.parent indexOfChild:bracesNode])))
                _RearrangeNodesAsChildren(node, semicolonNode);
        }
        
    } else if([node isKindOfClass:[SourceNodeCConditionIf class]] || [node isKindOfClass:[SourceNodeCFlowFor class]] || [node isKindOfClass:[SourceNodeCFlowSwitch class]]) {
        
        // "if()" "for()" "switch()" "else if()"
        SourceNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
        if([nextNode isKindOfClass:[SourceNodeParenthesis class]]) {
            SourceNode* bracesNode = [nextNode findNextSiblingOfClass:[SourceNodeBraces class]];
            SourceNode* semicolonNode = [nextNode findNextSiblingOfClass:[SourceNodeSemicolon class]];
            if(semicolonNode && (!bracesNode || ([node.parent indexOfChild:semicolonNode] < [node.parent indexOfChild:bracesNode]))) {
                SourceNode* elseNode = [node isKindOfClass:[SourceNodeCConditionIf class]] ? [node findPreviousSiblingIgnoringWhitespaceAndNewline] : nil;
                if([elseNode isKindOfClass:[SourceNodeCConditionElse class]] && !elseNode.children) {
                	SourceNode* newNode = [[SourceNodeCConditionElseIf alloc] initWithSource:elseNode.source range:NSMakeRange(elseNode.range.location, 0)];
                    [elseNode insertPreviousSibling:newNode];
                    [newNode release];
                    
                    SourceNode* textNode = [[SourceNodeText alloc] initWithSource:elseNode.source range:elseNode.range];
                    [elseNode insertPreviousSibling:textNode];
                    [textNode release];
                    [elseNode removeFromParent];
                    
                    textNode = [[SourceNodeText alloc] initWithSource:node.source range:node.range];
                    [node insertPreviousSibling:textNode];
                    [textNode release];
                    [node removeFromParent];
                    
                    _RearrangeNodesAsChildren(newNode, semicolonNode);
                } else {
                    _RearrangeNodesAsChildren(node, semicolonNode);
                }
            }
        }
        
    } else if([node isKindOfClass:[SourceNodeCFlowCase class]] || [node isKindOfClass:[SourceNodeCFlowDefault class]]) {
        
        // "case:" "case: break" "default:" "default: break"
        SourceNode* endNode = [node.parent lastChild];
        if([endNode isKindOfClass:[SourceNodeWhitespace class]] || [endNode isKindOfClass:[SourceNodeNewline class]])
        	endNode = [endNode findPreviousSiblingIgnoringWhitespaceAndNewline];
        SourceNode* breakNode = [node findNextSiblingOfClass:[SourceNodeCFlowBreak class]];
        if(breakNode && (breakNode.range.location < endNode.range.location))
        	endNode = [breakNode findNextSiblingOfClass:[SourceNodeSemicolon class]];
        SourceNode* caseNode = [node findNextSiblingOfClass:[SourceNodeCFlowCase class]];
        if(caseNode && (caseNode.range.location < endNode.range.location))
        	endNode = caseNode.previousSibling;
        SourceNode* defaultNode = [node findNextSiblingOfClass:[SourceNodeCFlowDefault class]];
        if(defaultNode && (defaultNode.range.location < endNode.range.location))
        	endNode = defaultNode.previousSibling;
        
        _RearrangeNodesAsChildren(node, endNode);
        
    } else if([node isKindOfClass:[SourceNodeCFlowReturn class]]) {
        
        // "return" "return foo"
        SourceNode* semicolonNode = [node findNextSiblingOfClass:[SourceNodeSemicolon class]];
        if(semicolonNode) {
        	if(semicolonNode.previousSibling != node)
                _RearrangeNodesAsChildren(node, semicolonNode);
        } else {
            if([node.parent isKindOfClass:[SourceNodeCConditionIf class]] || [node.parent isKindOfClass:[SourceNodeCConditionElse class]] || [node.parent isKindOfClass:[SourceNodeCConditionElseIf class]]
            	|| [node.parent isKindOfClass:[SourceNodeCFlowFor class]] || [node.parent isKindOfClass:[SourceNodeCFlowWhile class]])
            	_RearrangeNodesAsChildren(node, node.parent.lastChild);
        }
        
    } else if([node isKindOfClass:[SourceNodeCFlowGoto class]]) {
        
        // "goto foo"
        SourceNode* semicolonNode = [node findNextSiblingOfClass:[SourceNodeSemicolon class]];
        if(semicolonNode) {
            _RearrangeNodesAsChildren(node, semicolonNode);
        } else {
            if([node.parent isKindOfClass:[SourceNodeCConditionIf class]] || [node.parent isKindOfClass:[SourceNodeCConditionElse class]] || [node.parent isKindOfClass:[SourceNodeCConditionElseIf class]]
            	|| [node.parent isKindOfClass:[SourceNodeCFlowFor class]] || [node.parent isKindOfClass:[SourceNodeCFlowWhile class]])
            	_RearrangeNodesAsChildren(node, node.parent.lastChild);
        }
        
    } else if([node isKindOfClass:[SourceNodeColon class]] && [node.parent isKindOfClass:[SourceNodeBraces class]]) {
        
        // "foo:"
        SourceNode* labelNode = [node findPreviousSiblingIgnoringWhitespaceAndNewline];
        if([labelNode isKindOfClass:[SourceNodeText class]]) {
        	SourceNode* previousNode = [labelNode findPreviousSiblingIgnoringWhitespaceAndNewline];
            if(![previousNode isKindOfClass:[SourceNodeQuestionMark class]]) {
            	SourceNode* newNode = [[SourceNodeCFlowLabel alloc] initWithSource:labelNode.source range:NSMakeRange(labelNode.range.location, 0)];
                [labelNode insertPreviousSibling:newNode];
                [newNode release];
                
                _RearrangeNodesAsChildren(newNode, node);
            }
        }
        
    } else if([node isKindOfClass:[SourceNodeQuestionMark class]]) {
        
        // "foo ? bar : baz" "(foo) ? (bar) : (baz)"
        SourceNode* startNode = [node findPreviousSiblingIgnoringWhitespaceAndNewline];
        if([startNode isKindOfClass:[SourceNodeText class]] || [startNode isKindOfClass:[SourceNodeParenthesis class]]) {
        	SourceNode* middleNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
            if([middleNode isKindOfClass:[SourceNodeText class]] || [middleNode isKindOfClass:[SourceNodeParenthesis class]]) {
                SourceNode* colonNode = [middleNode findNextSiblingIgnoringWhitespaceAndNewline];
                if([colonNode isKindOfClass:[SourceNodeColon class]]) {
                    SourceNode* endNode = [colonNode findNextSiblingIgnoringWhitespaceAndNewline];
                    if([endNode isKindOfClass:[SourceNodeText class]] || [endNode isKindOfClass:[SourceNodeParenthesis class]]) {
                        SourceNode* newNode = [[SourceNodeCConditionalOperator alloc] initWithSource:startNode.source range:NSMakeRange(startNode.range.location, 0)];
                        [startNode insertPreviousSibling:newNode];
                        [newNode release];
                        
                        _RearrangeNodesAsChildren(newNode, endNode);
                    }
                }
            }
        }
        
    } else if([node isKindOfClass:[SourceNodeCTypeStruct class]] || [node isKindOfClass:[SourceNodeCTypeUnion class]]) {
        
        // "struct {}" "union {}"
        SourceNode* bracesNode = [node findNextSiblingOfClass:[SourceNodeBraces class]];
        SourceNode* semicolonNode = [node findNextSiblingOfClass:[SourceNodeSemicolon class]];
        if(bracesNode && (!semicolonNode || ([node.parent indexOfChild:semicolonNode] > [node.parent indexOfChild:bracesNode]))) {
            semicolonNode = [bracesNode findNextSiblingOfClass:[SourceNodeSemicolon class]];
            if(!semicolonNode && [bracesNode.parent isKindOfClass:[SourceNodeCTypedef class]])
                _RearrangeNodesAsChildren(node, bracesNode.parent.lastChild);
            else if(semicolonNode)
                _RearrangeNodesAsChildren(node, semicolonNode);
        }
        
    } else if([node isKindOfClass:[SourceNodeCTypedef class]]) {
        
        // "typedef foo"
        SourceNode* semicolonNode = [node findNextSiblingOfClass:[SourceNodeSemicolon class]];
        if(semicolonNode)
            _RearrangeNodesAsChildren(node, semicolonNode);
        
    } else if([node isKindOfClass:[SourceNodeCSizeOf class]] || [node isKindOfClass:[SourceNodeCTypeOf class]]) {
        
        // "sizeof()" "typeof()"
        SourceNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
        if([nextNode isKindOfClass:[SourceNodeParenthesis class]])
            _RearrangeNodesAsChildren(node, nextNode);
        
    } else if([node isKindOfClass:[SourceNodeParenthesis class]]) {
        
        // "foo bar()" "foo bar() {}"
        if(_IsNodeAtTopLevel(node, nodeClasses)) {
            SourceNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
            if([nextNode isKindOfClass:[SourceNodeSemicolon class]] || [nextNode isKindOfClass:[SourceNodeBraces class]]) {
                SourceNode* previousNode = [node findPreviousSiblingIgnoringWhitespaceAndNewline];
                if([previousNode isKindOfClass:[SourceNodeText class]] && ![self.reservedKeywords containsObject:[previousNode.source substringWithRange:previousNode.range]]) {
                    NSUInteger count = 0;
                    while(1) {
                    	SourceNode* siblingNode = [previousNode findPreviousSiblingIgnoringWhitespaceAndNewline];
                        if(![siblingNode isMemberOfClass:[SourceNodeText class]] && ![siblingNode isKindOfClass:[SourceNodeAsterisk class]] && ![siblingNode isKindOfClass:[SourceNodeCVoid class]]
                        	&& ![siblingNode isKindOfClass:[SourceNodeCTypeStatic class]] && ![siblingNode isKindOfClass:[SourceNodeCTypeExtern class]] && ![siblingNode isKindOfClass:[SourceNodeCTypeInline class]])
                        	break;
                        if(![siblingNode isKindOfClass:[SourceNodeAsterisk class]])
                        	++count;
                        previousNode = siblingNode;
                    }
                    SourceNode* newNode = [([nextNode isKindOfClass:[SourceNodeBraces class]] ? [SourceNodeCFunctionDefinition alloc] : [SourceNodeCFunctionPrototype alloc]) initWithSource:previousNode.source range:NSMakeRange(previousNode.range.location, 0)];
                    [previousNode insertPreviousSibling:newNode];
                    [newNode release];
                    _RearrangeNodesAsChildren(newNode, nextNode);
                }
                
            }
        }
        
        else if(![node.parent isKindOfClass:[SourceNodeCFunctionDefinition class]] && ![node.parent isKindOfClass:[SourceNodeCFunctionCall class]] && ![node.parent isKindOfClass:[SourceNodeCPreprocessorDefine class]] && _IsNodeInBlock(node)) {
            SourceNode* previousNode = [node findPreviousSiblingIgnoringWhitespaceAndNewline];
            if([previousNode isKindOfClass:[SourceNodeText class]] && _IsIdentifier(sourceBuffer + previousNode.range.location, previousNode.range.length) && ![self.reservedKeywords containsObject:[previousNode.source substringWithRange:previousNode.range]]) {
            	SourceNode* newNode = [[SourceNodeCFunctionCall alloc] initWithSource:previousNode.source range:NSMakeRange(previousNode.range.location, 0)];
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

#define IMPLEMENTATION(__NAME__, __CHARACTER__) \
@implementation SourceNode##__NAME__ \
\
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    return *string == __CHARACTER__ ? 1 : NSNotFound; \
} \
\
+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    return 0; \
} \
\
@end

IMPLEMENTATION(Colon, ':')
IMPLEMENTATION(Semicolon, ';')
IMPLEMENTATION(QuestionMark, '?')
IMPLEMENTATION(ExclamationMark, '!')
IMPLEMENTATION(Tilda, '~')
IMPLEMENTATION(Caret, '^')
IMPLEMENTATION(Ampersand, '&')
IMPLEMENTATION(Asterisk, '*')

#undef IMPLEMENTATION

@implementation SourceNodeCComment

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (maxLength >= 2) && (string[0] == '/') && (string[1] == '*') ? 2 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (maxLength >= 2) && (string[0] == '*') && (string[1] == '/') ? 2 : NSNotFound;
}

@end

@implementation SourceNodeCPreprocessor

+ (id) allocWithZone:(NSZone*)zone
{
    if(self == [SourceNodeCPreprocessor class])
        [NSException raise:NSInternalInconsistencyException format:@"SourceNodeCPreprocessor is an abstract class"];
    
    return [super allocWithZone:zone];
}

+ (BOOL) isAtomic {
    return NO;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    while(maxLength) {
        if(IsNewline(*string) || (*string == '#') || ((maxLength >= 2) && (string[0] == '/') && (string[1] == '/'))) {
            do {
                --string;
            } while(IsWhiteSpace(*string));
            if(*string != '\\')
                return 0;
        }
        if(!IsWhiteSpace(*string))
            break;
        ++string;
        --maxLength;
    }
    
    return NSNotFound;
}

@end

#define IMPLEMENTATION(__NAME__, ...) \
@implementation SourceNodeCPreprocessor##__NAME__ \
\
IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_SEMICOLON_OR_CHARACTER(__VA_ARGS__); \
\
@end

IMPLEMENTATION(If, @"#if", true, false, '(')
IMPLEMENTATION(Ifdef, @"#ifdef", true, false, '(')
IMPLEMENTATION(Ifndef, @"#ifndef", true, false, '(')
IMPLEMENTATION(Else, @"#else", true, false, '(')
IMPLEMENTATION(Elseif, @"#elseif", true, false, '(')
IMPLEMENTATION(Endif, @"#endif", true, false, '(')
IMPLEMENTATION(Define, @"#define", true, false, 0)
IMPLEMENTATION(Undefine, @"#undef", true, false, 0)
IMPLEMENTATION(Pragma, @"#pragma", true, false, '(')
IMPLEMENTATION(Warning, @"#warning", true, false, '(')
IMPLEMENTATION(Error, @"#error", true, false, '(')
IMPLEMENTATION(Include, @"#include", false, false, 0)

#undef IMPLEMENTATION

@implementation SourceNodeCStringSingleQuote

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (*string == '\'') ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return maxLength && (*string == '\'') && !((*(string - 1) == '\\') && (*(string - 2) != '\\')) ? 1 : NSNotFound;
}

@end

@implementation SourceNodeCStringDoubleQuote

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (*string == '"') ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return maxLength && (*string == '"') && !((*(string - 1) == '\\') && (*(string - 2) != '\\')) ? 1 : NSNotFound;
}

@end

#define IMPLEMENTATION(__NAME__, ...) \
@implementation SourceNodeC##__NAME__ \
\
IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_SEMICOLON_OR_CHARACTER(__VA_ARGS__); \
\
+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    return 0; \
} \
\
@end

IMPLEMENTATION(NULL, @"NULL", false, false, 0)
IMPLEMENTATION(Void, @"void", false, false, 0)
IMPLEMENTATION(ConditionIf, @"if", true, false, '(')
IMPLEMENTATION(ConditionElse, @"else", true, false, '{')
IMPLEMENTATION(FlowBreak, @"break", true, true, 0)
IMPLEMENTATION(FlowContinue, @"continue", true, true, 0)
IMPLEMENTATION(FlowSwitch, @"switch", true, false, '(')
IMPLEMENTATION(FlowCase, @"case", true, false, 0)
IMPLEMENTATION(FlowDefault, @"default", true, false, ':')
IMPLEMENTATION(FlowFor, @"for", true, false, '(')
IMPLEMENTATION(FlowDoWhile, @"do", true, false, '{')
IMPLEMENTATION(FlowWhile, @"while", true, false, '(')
IMPLEMENTATION(FlowGoto, @"goto", true, false, 0)
IMPLEMENTATION(FlowReturn, @"return", true, true, '(')
IMPLEMENTATION(Typedef, @"typedef", true, false, 0)
IMPLEMENTATION(TypeStruct, @"struct", true, false, '{')
IMPLEMENTATION(TypeUnion, @"union", true, false, '{')
IMPLEMENTATION(TypeAuto, @"auto", true, false, 0)
IMPLEMENTATION(TypeStatic, @"static", true, false, 0)
IMPLEMENTATION(TypeRegister, @"register", true, false, 0)
IMPLEMENTATION(TypeVolatile, @"volatile", true, false, 0)
IMPLEMENTATION(TypeConst, @"const", true, false, 0)
IMPLEMENTATION(TypeEnum, @"enum", true, false, '{')
IMPLEMENTATION(TypeExtern, @"extern", true, false, 0)
IMPLEMENTATION(TypeInline, @"inline", true, false, 0)
IMPLEMENTATION(SizeOf, @"sizeof", true, false, '(')
IMPLEMENTATION(TypeOf, @"sizeof", true, false, '(')

#undef IMPLEMENTATION

@implementation SourceNodeCConditionElseIf
@end

@implementation SourceNodeCConditionalOperator
@end

@implementation SourceNodeCFlowLabel
@end

@implementation SourceNodeCFunctionPrototype
@end

@implementation SourceNodeCFunctionDefinition
@end

@implementation SourceNodeCFunctionCall
@end
