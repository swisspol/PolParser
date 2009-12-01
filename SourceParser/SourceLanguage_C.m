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

@interface SourceLanguageC : SourceLanguage
@end

@implementation SourceLanguageC

+ (NSArray*) languageDependencies {
	return [NSArray arrayWithObject:@"Base"];
}

+ (NSSet*) languageReservedKeywords {
	return [NSSet setWithObjects:@"auto", @"break", @"case", @"char", @"const", @"continue", @"default", @"do", @"double",
    	@"else", @"enum", @"inline", @"extern", @"float", @"for", @"goto", @"if", @"int", @"long", @"register", @"return", @"short",
        @"signed", @"sizeof", @"static", @"struct", @"switch", @"typedef", @"union", @"unsigned", @"void", @"volatile", @"while",
        @"NULL", nil]; //Not "true" keywords
}

+ (NSArray*) languageNodeClasses {
	NSMutableArray* classes = [NSMutableArray arrayWithArray:[super languageNodeClasses]];
    
    [classes addObject:[SourceNodeColon class]];
    [classes addObject:[SourceNodeSemicolon class]];
    [classes addObject:[SourceNodeQuestionMark class]];
    [classes addObject:[SourceNodeExclamationMark class]];
    [classes addObject:[SourceNodeTilda class]];
    [classes addObject:[SourceNodeCaret class]];
    [classes addObject:[SourceNodeAmpersand class]];
    [classes addObject:[SourceNodeAsterisk class]];
    
    [classes addObject:[SourceNodeCComment class]];
    [classes addObject:[SourceNodeCPreprocessorConditionIf class]];
    [classes addObject:[SourceNodeCPreprocessorConditionIfdef class]];
    [classes addObject:[SourceNodeCPreprocessorConditionIfndef class]];
    [classes addObject:[SourceNodeCPreprocessorConditionElse class]];
    [classes addObject:[SourceNodeCPreprocessorConditionElseif class]];
    [classes addObject:[SourceNodeCPreprocessorDefine class]];
    [classes addObject:[SourceNodeCPreprocessorUndefine class]];
    [classes addObject:[SourceNodeCPreprocessorPragma class]];
    [classes addObject:[SourceNodeCPreprocessorWarning class]];
    [classes addObject:[SourceNodeCPreprocessorError class]];
    [classes addObject:[SourceNodeCPreprocessorInclude class]];
    [classes addObject:[SourceNodeCStringSingleQuote class]];
    [classes addObject:[SourceNodeCStringDoubleQuote class]];
    [classes addObject:[SourceNodeCConditionalOperator class]];
    [classes addObject:[SourceNodeCConditionIf class]];
    [classes addObject:[SourceNodeCConditionElseIf class]]; //Must be before SourceNodeCConditionElse
    [classes addObject:[SourceNodeCConditionElse class]];
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
	[classes addObject:[SourceNodeCTypeEnum class]];
    [classes addObject:[SourceNodeCSizeOf class]];
    [classes addObject:[SourceNodeCTypeOf class]];
    
    [classes addObject:[SourceNodeCFunctionPrototype class]];
    [classes addObject:[SourceNodeCFunctionDefinition class]];
    [classes addObject:[SourceNodeCFunctionCall class]];
    
    return classes;
}

+ (NSSet*) languageTopLevelNodeClasses {
	return [NSSet setWithObjects:[SourceNodeCPreprocessorConditionIf class], [SourceNodeCPreprocessorConditionIfdef class],
    	[SourceNodeCPreprocessorConditionIfndef class], [SourceNodeCPreprocessorConditionElse class], [SourceNodeCPreprocessorConditionElseif class], nil];
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
    
    if([node isKindOfClass:[SourceNodeBraces class]]) {
        SourceNode* previousNode = [node findPreviousSiblingIgnoringWhitespaceAndNewline];
        
        // "if() {}" "else if() {}" "for() {}" "switch() {}" "while() {}"
        if([previousNode isKindOfClass:[SourceNodeParenthesis class]]) {
            previousNode = [previousNode findPreviousSiblingIgnoringWhitespaceAndNewline];
            if([previousNode isKindOfClass:[SourceNodeCConditionIf class]] || [previousNode isKindOfClass:[SourceNodeCConditionElseIf class]] || [previousNode isKindOfClass:[SourceNodeCFlowFor class]]
            	|| [previousNode isKindOfClass:[SourceNodeCFlowSwitch class]] || [previousNode isKindOfClass:[SourceNodeCFlowWhile class]]) {
               	_RearrangeNodesAsChildren(previousNode, node);
            }
        }
        
        // "do {} while()"
        else if([previousNode isKindOfClass:[SourceNodeCFlowDoWhile class]]) {
            SourceNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
            if([nextNode isKindOfClass:[SourceNodeCFlowWhile class]]) {
                SourceNode* nextNextNode = [nextNode findNextSiblingIgnoringWhitespaceAndNewline];
                if([nextNextNode isKindOfClass:[SourceNodeParenthesis class]]) {
                    _RearrangeNodesAsChildren(previousNode, nextNextNode);
                    
                    SourceNode* newWhile = [[SourceNodeMatch alloc] initWithSource:nextNode.source range:nextNode.range];
                    newWhile.lines = nextNode.lines;
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
        
    } else if([node isKindOfClass:[SourceNodeCConditionIf class]] || [node isKindOfClass:[SourceNodeCConditionElseIf class]] || [node isKindOfClass:[SourceNodeCFlowFor class]] || [node isKindOfClass:[SourceNodeCFlowSwitch class]]) {
        
        // "if()" "else if()" "for()" "switch()"
        SourceNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
        if([nextNode isKindOfClass:[SourceNodeParenthesis class]]) {
            SourceNode* bracesNode = [nextNode findNextSiblingOfClass:[SourceNodeBraces class]];
            SourceNode* semicolonNode = [nextNode findNextSiblingOfClass:[SourceNodeSemicolon class]];
            if(semicolonNode && (!bracesNode || ([node.parent indexOfChild:semicolonNode] < [node.parent indexOfChild:bracesNode])))
                _RearrangeNodesAsChildren(node, semicolonNode);
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
        if([labelNode isMemberOfClass:[SourceNodeText class]]) {
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
        if([startNode isMemberOfClass:[SourceNodeText class]] || [startNode isKindOfClass:[SourceNodeParenthesis class]]) {
        	SourceNode* middleNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
            if([middleNode isMemberOfClass:[SourceNodeText class]] || [middleNode isKindOfClass:[SourceNodeParenthesis class]]) {
                SourceNode* colonNode = [middleNode findNextSiblingIgnoringWhitespaceAndNewline];
                if([colonNode isKindOfClass:[SourceNodeColon class]]) {
                    SourceNode* endNode = [colonNode findNextSiblingIgnoringWhitespaceAndNewline];
                    if([endNode isMemberOfClass:[SourceNodeText class]] || [endNode isKindOfClass:[SourceNodeParenthesis class]]) {
                        SourceNode* newNode = [[SourceNodeCConditionalOperator alloc] initWithSource:startNode.source range:NSMakeRange(startNode.range.location, 0)];
                        [startNode insertPreviousSibling:newNode];
                        [newNode release];
                        
                        _RearrangeNodesAsChildren(newNode, endNode);
                    }
                }
            }
        }
        
    } else if([node isKindOfClass:[SourceNodeCTypeEnum class]] || [node isKindOfClass:[SourceNodeCTypeStruct class]] || [node isKindOfClass:[SourceNodeCTypeUnion class]]) {
        
        // "enum {}" "struct {}" "union {}"
		SourceNode* bracesNode = [node findNextSiblingOfClass:[SourceNodeBraces class]];
        SourceNode* semicolonNode = [node findNextSiblingOfClass:[SourceNodeSemicolon class]];
        if(bracesNode && (!semicolonNode || ([node.parent indexOfChild:semicolonNode] > [node.parent indexOfChild:bracesNode]))) {
            if(!semicolonNode)
                _RearrangeNodesAsChildren(node, node.parent.lastChild);
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
                if([previousNode isMemberOfClass:[SourceNodeText class]] && _IsIdentifier(sourceBuffer + previousNode.range.location, previousNode.range.length)) {
                    SourceNode* newNode = [[SourceNodeMatch alloc] initWithSource:previousNode.source range:previousNode.range];
                    newNode.lines = previousNode.lines;
                    [previousNode replaceWithNode:newNode];
                    [newNode release];
                    previousNode = newNode;
                    while(1) {
                    	SourceNode* siblingNode = [previousNode findPreviousSiblingIgnoringWhitespaceAndNewline];
                        if(![siblingNode isMemberOfClass:[SourceNodeText class]] && ![siblingNode isKindOfClass:[SourceNodeKeyword class]] && ![siblingNode isKindOfClass:[SourceNodeAsterisk class]])
                        	break;
                        previousNode = siblingNode;
                    }
                    newNode = [([nextNode isKindOfClass:[SourceNodeBraces class]] ? [SourceNodeCFunctionDefinition alloc] : [SourceNodeCFunctionPrototype alloc]) initWithSource:previousNode.source range:NSMakeRange(previousNode.range.location, 0)];
                    [previousNode insertPreviousSibling:newNode];
                    [newNode release];
                    _RearrangeNodesAsChildren(newNode, nextNode);
                }
                
            }
        }
        
        else if(![node.parent isKindOfClass:[SourceNodeCFunctionDefinition class]] && ![node.parent isKindOfClass:[SourceNodeCFunctionCall class]] && ![node.parent isKindOfClass:[SourceNodeCPreprocessorDefine class]] && _IsNodeInBlock(node)) {
            SourceNode* previousNode = [node findPreviousSiblingIgnoringWhitespaceAndNewline];
            if([previousNode isMemberOfClass:[SourceNodeText class]] && _IsIdentifier(sourceBuffer + previousNode.range.location, previousNode.range.length)) {
            	SourceNode* newNode = [[SourceNodeMatch alloc] initWithSource:previousNode.source range:previousNode.range];
                newNode.lines = previousNode.lines;
                [previousNode replaceWithNode:newNode];
                [newNode release];
                previousNode = newNode;
                
                newNode = [[SourceNodeCFunctionCall alloc] initWithSource:previousNode.source range:NSMakeRange(previousNode.range.location, 0)];
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

TOKEN_CLASS_IMPLEMENTATION(Colon, ":")
TOKEN_CLASS_IMPLEMENTATION(Semicolon, ";")
TOKEN_CLASS_IMPLEMENTATION(QuestionMark, "?")
TOKEN_CLASS_IMPLEMENTATION(ExclamationMark, "!")
TOKEN_CLASS_IMPLEMENTATION(Tilda, "~")
TOKEN_CLASS_IMPLEMENTATION(Caret, "^")
TOKEN_CLASS_IMPLEMENTATION(Ampersand, "&")
TOKEN_CLASS_IMPLEMENTATION(Asterisk, "*")

@implementation SourceNodeCComment

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (string[0] == '/') && (string[1] == '*') ? 2 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (string[0] == '*') && (string[1] == '/') ? 2 : NSNotFound;
}

- (NSString*) cleanContent {
	NSRange range = self.range;
    return [self.source substringWithRange:NSMakeRange(range.location + 2, range.length - 4)];
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

@implementation SourceNodeCPreprocessorCondition

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
@implementation SourceNodeCPreprocessorCondition##__NAME__ \
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
@implementation SourceNodeCPreprocessor##__NAME__ \
\
IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_CHARACTERS(__CHARACTERS__, __VA_ARGS__) \
\
- (NSString*) name { \
	NSUInteger count = sizeof(__CHARACTERS__) - 1; \
    NSString* name = self.content; \
    name = [name substringWithRange:NSMakeRange(count, name.length - count)]; \
    NSRange range = [name rangeOfCharacterFromSet:[[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet]]; \
    if(range.location != NSNotFound) { \
    	name = [name substringWithRange:NSMakeRange(range.location, name.length - range.location)]; \
        range = [name rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; \
        if(range.location != NSNotFound) \
        	name = [name substringWithRange:NSMakeRange(0, range.location)];\
    } \
    return name; \
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

static NSString* _StringFromHexUnicodeCharacter(NSString* string) {
    unichar character = 0;
	NSUInteger length = string.length;
    unichar buffer[length];
    [string getCharacters:buffer];
    for(NSUInteger i = 0; i < length; ++i) {
    	NSUInteger num = 0;
        if((buffer[i] >= 'A') && (buffer[i] <= 'F'))
		num = buffer[i] - 'A' + 10;
		else if((buffer[i] >= 'a') && (buffer[i] <= 'f'))
		num = buffer[i] - 'a' + 10;
		else if((buffer[i] >= '0') && (buffer[i] <= '9'))
		num = buffer[i] - '0';
        if(i > 0)
        	character <<= 4;
        character |= num;
    }
	return [NSString stringWithCharacters:&character length:1];
}

//FIXME: We don't handle "\nnn = character with octal value nnn"
static NSString* _CleanString(NSString* string) {
    NSMutableString* newString = [NSMutableString stringWithString:string];
    
    NSRange range = NSMakeRange(0, newString.length);
    while(1) {
    	NSRange subrange = [newString rangeOfString:@"\\\\" options:0 range:range];
        if(subrange.location != NSNotFound) {
            range.length -= subrange.location + 2 - range.location;
            range.location = subrange.location + 2;
            continue;
        }
        subrange = [newString rangeOfString:@"\\x" options:0 range:range];
        if(subrange.location == NSNotFound)
        	break;
        if(range.length - subrange.location + range.location < 2)
        	break;
        [newString replaceCharactersInRange:NSMakeRange(subrange.location, 4) withString:_StringFromHexUnicodeCharacter([newString substringWithRange:NSMakeRange(subrange.location + 2, 2)])];
        range.length -= subrange.location + 4 - range.location;
        range.location = subrange.location + 1;
    }
    
    range = NSMakeRange(0, newString.length);
    while(1) {
    	NSRange subrange = [newString rangeOfString:@"\\\\" options:0 range:range];
        if(subrange.location != NSNotFound) {
            range.length -= subrange.location + 2 - range.location;
            range.location = subrange.location + 2;
            continue;
        }
        subrange = [newString rangeOfString:@"\\u" options:0 range:range];
        if(subrange.location == NSNotFound)
        	break;
        if(range.length - subrange.location + range.location < 4)
        	break;
        [newString replaceCharactersInRange:NSMakeRange(subrange.location, 6) withString:_StringFromHexUnicodeCharacter([newString substringWithRange:NSMakeRange(subrange.location + 2, 4)])];
        range.length -= subrange.location + 6 - range.location;
        range.location = subrange.location + 1;
    }
    
    range = NSMakeRange(0, newString.length);
    while(1) {
    	NSRange subrange = [newString rangeOfString:@"\\\\" options:0 range:range];
        if(subrange.location != NSNotFound) {
            range.length -= subrange.location + 2 - range.location;
            range.location = subrange.location + 2;
            continue;
        }
        subrange = [newString rangeOfString:@"\\U" options:0 range:range];
        if(subrange.location == NSNotFound)
        	break;
        if(range.length - subrange.location + range.location < 8)
        	break;
        [newString replaceCharactersInRange:NSMakeRange(subrange.location, 10) withString:_StringFromHexUnicodeCharacter([newString substringWithRange:NSMakeRange(subrange.location + 2, 8)])];
        range.length -= subrange.location + 10 - range.location;
        range.location = subrange.location + 1;
    }
    
    [newString replaceOccurrencesOfString:@"\\?" withString:@"?" options:0 range:NSMakeRange(0, newString.length)];
    [newString replaceOccurrencesOfString:@"\\f" withString:@"\f" options:0 range:NSMakeRange(0, newString.length)];
    [newString replaceOccurrencesOfString:@"\\a" withString:@"\a" options:0 range:NSMakeRange(0, newString.length)];
    [newString replaceOccurrencesOfString:@"\\v" withString:@"\v" options:0 range:NSMakeRange(0, newString.length)];
    [newString replaceOccurrencesOfString:@"\\b" withString:@"\b" options:0 range:NSMakeRange(0, newString.length)];
    [newString replaceOccurrencesOfString:@"\\t" withString:@"\t" options:0 range:NSMakeRange(0, newString.length)];
    [newString replaceOccurrencesOfString:@"\\n" withString:@"\n" options:0 range:NSMakeRange(0, newString.length)];
    [newString replaceOccurrencesOfString:@"\\r" withString:@"\r" options:0 range:NSMakeRange(0, newString.length)];
    [newString replaceOccurrencesOfString:@"\\\"" withString:@"\"" options:0 range:NSMakeRange(0, newString.length)];
    [newString replaceOccurrencesOfString:@"\\\'" withString:@"\'" options:0 range:NSMakeRange(0, newString.length)];
    [newString replaceOccurrencesOfString:@"\\\\" withString:@"\\" options:0 range:NSMakeRange(0, newString.length)];
    
    return newString;
}

@implementation SourceNodeCStringSingleQuote

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (*string == '\'') ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return maxLength && (*string == '\'') && !((*(string - 1) == '\\') && (*(string - 2) != '\\')) ? 1 : NSNotFound;
}

- (NSString*) cleanContent {
	NSRange range = self.range;
    return _CleanString([self.source substringWithRange:NSMakeRange(range.location + 1, range.length - 2)]);
}

@end

@implementation SourceNodeCStringDoubleQuote

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (*string == '"') ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return maxLength && (*string == '"') && !((*(string - 1) == '\\') && (*(string - 2) != '\\')) ? 1 : NSNotFound;
}

- (NSString*) cleanContent {
	NSRange range = self.range;
    return _CleanString([self.source substringWithRange:NSMakeRange(range.location + 1, range.length - 2)]);
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
@implementation SourceNodeC##__NAME__ \
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

@implementation SourceNodeCConditionElseIf

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    NSUInteger length = [SourceNodeCConditionElse isMatchingPrefix:string maxLength:maxLength];
    if(length != NSNotFound) {
        string += length;
        maxLength -= length;
        while(IsWhitespaceOrNewline(*string) && maxLength) {
            ++length;
            ++string;
            --maxLength;
        }
        if(maxLength) {
            NSUInteger nextLength = [SourceNodeCConditionIf isMatchingPrefix:string maxLength:maxLength];
            if(nextLength != NSNotFound)
            	return length + nextLength;
        }
    }
    return NSNotFound;
}


+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return 0;
}

@end

@implementation SourceNodeCConditionalOperator
@end

@implementation SourceNodeCFlowLabel
@end

@implementation SourceNodeCFunctionPrototype

- (NSString*) name {
	return [self findFirstChildOfClass:[SourceNodeMatch class]].content;
}

@end

@implementation SourceNodeCFunctionDefinition

- (NSString*) name {
	return [self findFirstChildOfClass:[SourceNodeMatch class]].content;
}

@end

@implementation SourceNodeCFunctionCall

- (NSString*) name {
	return [self findFirstChildOfClass:[SourceNodeMatch class]].content;
}

@end
