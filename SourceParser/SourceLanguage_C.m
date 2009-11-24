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

- (NSString*) name {
    return @"C";
}

- (NSSet*) fileExtensions {
    return [NSSet setWithObject:@"c"];
}

- (NSArray*) nodeClasses {
    static NSMutableArray* classes = nil;
    if(classes == nil) {
        classes = [[NSMutableArray alloc] init];
        [classes addObjectsFromArray:[super nodeClasses]];
        
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
        [classes addObject:[SourceNodeColon class]];
        [classes addObject:[SourceNodeSemicolon class]];
        [classes addObject:[SourceNodeQuestionMark class]];
        [classes addObject:[SourceNodeExclamationMark class]];
        [classes addObject:[SourceNodeTilda class]];
        [classes addObject:[SourceNodeCaret class]];
        [classes addObject:[SourceNodeAmpersand class]];
        [classes addObject:[SourceNodeAsterisk class]];
        [classes addObject:[SourceNodeCStringSingleQuote class]];
        [classes addObject:[SourceNodeCStringDoubleQuote class]];
        [classes addObject:[SourceNodeCFlowIf class]];
        [classes addObject:[SourceNodeCFlowElse class]];
        [classes addObject:[SourceNodeCFlowBreak class]];
        [classes addObject:[SourceNodeCFlowContinue class]];
        [classes addObject:[SourceNodeCFlowSwitch class]];
        [classes addObject:[SourceNodeCFlowCase class]];
        [classes addObject:[SourceNodeCFlowDefault class]];
        [classes addObject:[SourceNodeCFlowFor class]];
        [classes addObject:[SourceNodeCFlowDoWhile class]];
        [classes addObject:[SourceNodeCFlowWhile class]];
        [classes addObject:[SourceNodeCFlowGoto class]];
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
        [classes addObject:[SourceNodeCTypeSizeOf class]];
        
        [classes addObject:[SourceNodeCFunctionPrototype class]];
        [classes addObject:[SourceNodeCFunctionDefinition class]];
    }
    return classes;
}

- (BOOL) nodeHasRootParent:(SourceNode*)node {
    if(node.parent && (node.parent.parent == nil))
        return YES;
    
    return [node.parent isKindOfClass:[SourceNodeCPreprocessorCondition class]] ? [self nodeHasRootParent:node.parent] : NO;
}

- (BOOL) nodeIsStatementDelimiter:(SourceNode*)node {
    return node.children.count || [node isKindOfClass:[SourceNodeSemicolon class]] || [node isKindOfClass:[SourceNodeCComment class]];
}

- (void) refactorSourceNode:(SourceNode*)node {
    [super refactorSourceNode:node];
    
    if([node isKindOfClass:[SourceNodeBraces class]]) {
        SourceNode* previousNode = [node findPreviousSiblingIgnoringWhitespaceAndNewline];
        
        // "if() {}" "for() {}" "switch() {}" "while() {}"
        if([previousNode isKindOfClass:[SourceNodeParenthesis class]]) {
            previousNode = [previousNode findPreviousSiblingIgnoringWhitespaceAndNewline];
            if([previousNode isKindOfClass:[SourceNodeCFlowIf class]] || [previousNode isKindOfClass:[SourceNodeCFlowFor class]] || [previousNode isKindOfClass:[SourceNodeCFlowSwitch class]] || [previousNode isKindOfClass:[SourceNodeCFlowWhile class]])
                _RearrangeNodesAsChildren(previousNode, node);
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
        
    } else if([node isKindOfClass:[SourceNodeCFlowElse class]]) {
        
        // "else {}"
        SourceNode* bracesNode = [node findNextSiblingOfClass:[SourceNodeBraces class]];
        SourceNode* semicolonNode = [node findNextSiblingOfClass:[SourceNodeSemicolon class]];
        if(bracesNode && (!semicolonNode || ([node.parent indexOfChild:bracesNode] < [node.parent indexOfChild:semicolonNode])))
            _RearrangeNodesAsChildren(node, bracesNode);
        else if(semicolonNode && (!bracesNode || ([node.parent indexOfChild:semicolonNode] < [node.parent indexOfChild:bracesNode])))
            _RearrangeNodesAsChildren(node, semicolonNode.previousSibling); //FIXME: Strip trailing whitespace?
        #warning moving the following nodes down one level may have them be refactored twice because they are still in the cache of children of current parents \
        and will be evaluated again as children of "else"
    } else if([node isKindOfClass:[SourceNodeCFlowIf class]] || [node isKindOfClass:[SourceNodeCFlowFor class]] || [node isKindOfClass:[SourceNodeCFlowSwitch class]]) {
        
        // "if()" "for()" "switch()"
        SourceNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
        if([nextNode isKindOfClass:[SourceNodeParenthesis class]]) {
            SourceNode* bracesNode = [nextNode findNextSiblingOfClass:[SourceNodeBraces class]];
            SourceNode* semicolonNode = [nextNode findNextSiblingOfClass:[SourceNodeSemicolon class]];
            if(semicolonNode && (!bracesNode || ([node.parent indexOfChild:semicolonNode] < [node.parent indexOfChild:bracesNode])))
                _RearrangeNodesAsChildren(node, semicolonNode.previousSibling); //FIXME: Strip trailing whitespace?
        }
        
    } else if([node isKindOfClass:[SourceNodeCFlowGoto class]]) {
        
        // "goto foo"
        SourceNode* semicolonNode = [node findNextSiblingOfClass:[SourceNodeSemicolon class]];
        if(semicolonNode)
            _RearrangeNodesAsChildren(node, semicolonNode.previousSibling); //FIXME: Strip trailing whitespace?
        
    } else if([node isKindOfClass:[SourceNodeCTypeStruct class]] || [node isKindOfClass:[SourceNodeCTypeUnion class]]) {
        
        // "struct {}" "union {}"
        SourceNode* bracesNode = [node findNextSiblingOfClass:[SourceNodeBraces class]];
        SourceNode* semicolonNode = [node findNextSiblingOfClass:[SourceNodeSemicolon class]];
        if(bracesNode && (!semicolonNode || ([node.parent indexOfChild:semicolonNode] > [node.parent indexOfChild:bracesNode]))) {
            semicolonNode = [bracesNode findNextSiblingOfClass:[SourceNodeSemicolon class]];
            if(!semicolonNode && [bracesNode.parent isKindOfClass:[SourceNodeCTypedef class]])
                _RearrangeNodesAsChildren(node, bracesNode.parent.lastChild);
            else if(semicolonNode)
                _RearrangeNodesAsChildren(node, semicolonNode.previousSibling); //FIXME: Strip trailing whitespace?
        }
        
    } else if([node isKindOfClass:[SourceNodeCTypedef class]]) {
        
        // "typedef foo"
        SourceNode* semicolonNode = [node findNextSiblingOfClass:[SourceNodeSemicolon class]];
        if(semicolonNode)
            _RearrangeNodesAsChildren(node, semicolonNode.previousSibling); //FIXME: Strip trailing whitespace?
        
    } else if([node isKindOfClass:[SourceNodeCTypeSizeOf class]]) {
        
        // "sizeof()"
        SourceNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
        if([nextNode isKindOfClass:[SourceNodeParenthesis class]])
            _RearrangeNodesAsChildren(node, nextNode);
        
    } else if([node isKindOfClass:[SourceNodeParenthesis class]] && [self nodeHasRootParent:node]) {
        
        // "foo bar()" "foo bar() {}"
        SourceNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
        if([nextNode isKindOfClass:[SourceNodeSemicolon class]] || [nextNode isKindOfClass:[SourceNodeBraces class]]) {
            SourceNode* previousNode = [node findPreviousSiblingIgnoringWhitespaceAndNewline];
            if([previousNode isKindOfClass:[SourceNodeText class]]) {
                previousNode = previousNode.previousSibling;
                while(previousNode && ![self nodeIsStatementDelimiter:previousNode]) {
                    previousNode = previousNode.previousSibling;
                }
                if(previousNode == nil) {
                    previousNode = node.parent.firstChild;
                    if([previousNode isKindOfClass:[SourceNodeWhitespace class]] || [previousNode isKindOfClass:[SourceNodeNewline class]])
                        previousNode = [previousNode findNextSiblingIgnoringWhitespaceAndNewline];
                }
                else {
                    previousNode = [previousNode findNextSiblingIgnoringWhitespaceAndNewline];
                }
                
                SourceNode* newNode = [([nextNode isKindOfClass:[SourceNodeBraces class]] ? [SourceNodeCFunctionDefinition alloc] : [SourceNodeCFunctionPrototype alloc]) initWithSource:previousNode.source range:NSMakeRange(previousNode.range.location, 0)];
                [previousNode insertPreviousSibling:newNode];
                [newNode release];
                _RearrangeNodesAsChildren(newNode, [nextNode isKindOfClass:[SourceNodeBraces class]] ? nextNode : nextNode.previousSibling); //FIXME: Strip trailing whitespace?
            }
            
            #warning nodes after "node" will never be refactored!
        }
        
    }
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

@implementation SourceNodeCPreprocessorCondition

+ (id) allocWithZone:(NSZone*)zone
{
    if(self == [SourceNodeCPreprocessorCondition class])
        [NSException raise:NSInternalInconsistencyException format:@"SourceNodeCPreprocessorCondition is an abstract class"];
    
    return [super allocWithZone:zone];
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    {
        IS_MATCHING(@"#else", true, 0, string, maxLength);
        if(_matching != NSNotFound)
            return 0;
    }
    {
        IS_MATCHING(@"#elseif", true, '(', string, maxLength);
        if(_matching != NSNotFound)
            return 0;
    }
    {
        IS_MATCHING(@"#endif", true, 0, string, maxLength);
        if(_matching != NSNotFound)
            return _matching;
    }
    
    return NSNotFound;
}

@end

#define IMPLEMENTATION(__NAME__, ...) \
@implementation SourceNodeC##__NAME__ \
\
IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_CHARACTER(__VA_ARGS__); \
\
@end

IMPLEMENTATION(PreprocessorConditionIf, @"#if", '(')
IMPLEMENTATION(PreprocessorConditionIfdef, @"#ifdef", '(')
IMPLEMENTATION(PreprocessorConditionIfndef, @"#ifndef", '(')
IMPLEMENTATION(PreprocessorConditionElse, @"#else", 0)
IMPLEMENTATION(PreprocessorConditionElseif, @"#elseif", '(')
IMPLEMENTATION(PreprocessorDefine, @"#define", 0)
IMPLEMENTATION(PreprocessorUndefine, @"#undef", 0)
IMPLEMENTATION(PreprocessorPragma, @"#pragma", 0)
IMPLEMENTATION(PreprocessorWarning, @"#warning", 0)
IMPLEMENTATION(PreprocessorError, @"#error", 0)
IMPLEMENTATION(PreprocessorInclude, @"#include", 0)

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
IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_CHARACTER(__VA_ARGS__); \
\
+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    return 0; \
} \
\
@end

IMPLEMENTATION(FlowIf, @"if", '(')
IMPLEMENTATION(FlowElse, @"else", '{')
IMPLEMENTATION(FlowBreak, @"break", 0)
IMPLEMENTATION(FlowContinue, @"continue", 0)
IMPLEMENTATION(FlowSwitch, @"switch", '(')
IMPLEMENTATION(FlowCase, @"case", ':')
IMPLEMENTATION(FlowDefault, @"default", ':')
IMPLEMENTATION(FlowFor, @"for", '(')
IMPLEMENTATION(FlowDoWhile, @"do", '{')
IMPLEMENTATION(FlowWhile, @"while", '(')
IMPLEMENTATION(FlowGoto, @"goto", 0)
IMPLEMENTATION(FlowReturn, @"return", '(')
IMPLEMENTATION(Typedef, @"typedef", 0)
IMPLEMENTATION(TypeStruct, @"struct", '{')
IMPLEMENTATION(TypeUnion, @"union", '{')
IMPLEMENTATION(TypeAuto, @"auto", 0)
IMPLEMENTATION(TypeStatic, @"static", 0)
IMPLEMENTATION(TypeRegister, @"register", 0)
IMPLEMENTATION(TypeVolatile, @"volatile", 0)
IMPLEMENTATION(TypeConst, @"const", 0)
IMPLEMENTATION(TypeEnum, @"enum", '{')
IMPLEMENTATION(TypeExtern, @"extern", 0)
IMPLEMENTATION(TypeSizeOf, @"sizeof", '(')

#undef IMPLEMENTATION

@implementation SourceNodeCFunctionPrototype
@end

@implementation SourceNodeCFunctionDefinition
@end
