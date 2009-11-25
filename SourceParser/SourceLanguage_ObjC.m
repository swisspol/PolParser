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

@implementation SourceLanguageObjC

- (NSString*) name {
    return @"Obj-C";
}

- (NSSet*) fileExtensions {
    return [NSSet setWithObject:@"m"];
}

- (NSArray*) nodeClasses {
    static NSMutableArray* classes = nil;
    if(classes == nil) {
        classes = [[NSMutableArray alloc] init];
        [classes addObjectsFromArray:[super nodeClasses]];
        
        [classes addObject:[SourceNodeCPPComment class]]; //From C++ language
        
        [classes insertObject:[SourceNodeObjCString class] atIndex:[classes indexOfObject:[SourceNodeCStringSingleQuote class]]]; //Must be before single and double quote strings
        
        [classes addObject:[SourceNodeObjCPreprocessorImport class]];
        [classes addObject:[SourceNodeObjCInterface class]];
        [classes addObject:[SourceNodeObjCImplementation class]];
        [classes addObject:[SourceNodeObjCProtocol class]];
        [classes addObject:[SourceNodeObjCClass class]];
        [classes addObject:[SourceNodeObjCPublic class]];
        [classes addObject:[SourceNodeObjCProtected class]];
        [classes addObject:[SourceNodeObjCPrivate class]];
        [classes addObject:[SourceNodeObjCOptional class]];
        [classes addObject:[SourceNodeObjCRequired class]];
        [classes addObject:[SourceNodeObjCProperty class]];
        [classes addObject:[SourceNodeObjCTry class]];
        [classes addObject:[SourceNodeObjCCatch class]];
        [classes addObject:[SourceNodeObjCFinally class]];
        [classes addObject:[SourceNodeObjCThrow class]];
        [classes addObject:[SourceNodeObjCSynchronized class]];
        [classes addObject:[SourceNodeObjCSelector class]];
        [classes addObject:[SourceNodeObjCEncode class]];
        [classes addObject:[SourceNodeObjCSelf class]];
        [classes addObject:[SourceNodeObjCSuper class]];
        
        [classes addObject:[SourceNodeObjCMethodDeclaration class]];
        [classes addObject:[SourceNodeObjCMethodImplementation class]];
    }
    return classes;
}

static BOOL _HasInterfaceOrProtocolParent(SourceNode* node) {
    if([node.parent isKindOfClass:[SourceNodeObjCInterface class]] || [node.parent isKindOfClass:[SourceNodeObjCProtocol class]])
        return YES;
    
    return [node.parent isKindOfClass:[SourceNodeCPreprocessorCondition class]] ? _HasInterfaceOrProtocolParent(node.parent) : NO;
}

static BOOL _HasImplementationParent(SourceNode* node) {
    if([node.parent isKindOfClass:[SourceNodeObjCImplementation class]])
        return YES;
    
    return [node.parent isKindOfClass:[SourceNodeCPreprocessorCondition class]] ? _HasImplementationParent(node.parent) : NO;
}

- (BOOL) nodeIsStatementDelimiter:(SourceNode*)node {
    return [super nodeIsStatementDelimiter:node] || [node isKindOfClass:[SourceNodeCPPComment class]];
}

- (BOOL) nodeHasRootParent:(SourceNode*)node {
    if(node.parent && (node.parent.parent == nil))
        return YES;
    
    return [node.parent isKindOfClass:[SourceNodeCPreprocessorCondition class]] || [node.parent isKindOfClass:[SourceNodeObjCInterface class]] || [node.parent isKindOfClass:[SourceNodeObjCImplementation class]] ? [self nodeHasRootParent:node.parent] : NO;
}

- (void) performSyntaxAnalysisForNode:(SourceNode*)node {
    [super performSyntaxAnalysisForNode:node];
    
    if([node isKindOfClass:[SourceNodeBraces class]]) {
        SourceNode* previousNode = [node findPreviousSiblingIgnoringWhitespaceAndNewline];
        
        // "@catch() {}" "@synchronized() {}"
        if([previousNode isKindOfClass:[SourceNodeParenthesis class]]) {
            previousNode = [previousNode findPreviousSiblingIgnoringWhitespaceAndNewline];
            if([previousNode isKindOfClass:[SourceNodeObjCCatch class]] || [previousNode isKindOfClass:[SourceNodeObjCSynchronized class]])
                _RearrangeNodesAsChildren(previousNode, node);
        }
        
        // "@try {}" "@finally {}"
        else if([previousNode isKindOfClass:[SourceNodeObjCTry class]] || [previousNode isKindOfClass:[SourceNodeObjCFinally class]]) {
            _RearrangeNodesAsChildren(previousNode, node);
        }
        
    } else if([node isKindOfClass:[SourceNodeObjCSelector class]] || [node isKindOfClass:[SourceNodeObjCEncode class]]) {
        
        // "@selector()" "@encode()"
        SourceNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
        if([nextNode isKindOfClass:[SourceNodeParenthesis class]])
            _RearrangeNodesAsChildren(node, nextNode);
        
    } else if([node isKindOfClass:[SourceNodeObjCThrow class]]) {
        
        // "@throw" "@throw foo"
        SourceNode* semicolonNode = [node findNextSiblingOfClass:[SourceNodeSemicolon class]];
        if(semicolonNode) {
        	if(semicolonNode.previousSibling != node)
                _RearrangeNodesAsChildren(node, SEMICOLON_PREVIOUS_SIBLING(semicolonNode));
        } else {
            if([node.parent isKindOfClass:[SourceNodeCFlowIf class]] || [node.parent isKindOfClass:[SourceNodeCFlowElse class]] || [node.parent isKindOfClass:[SourceNodeCFlowElseIf class]]
            	|| [node.parent isKindOfClass:[SourceNodeCFlowFor class]] || [node.parent isKindOfClass:[SourceNodeCFlowWhile class]])
            	_RearrangeNodesAsChildren(node, node.parent.lastChild);
        }
        
    } else if([node isKindOfClass:[SourceNodeObjCProperty class]] && _HasInterfaceOrProtocolParent(node)) {
        
        // "@property" "@property()"
        SourceNode* semicolonNode = [node findNextSiblingOfClass:[SourceNodeSemicolon class]];
        if(semicolonNode)
            _RearrangeNodesAsChildren(node, SEMICOLON_PREVIOUS_SIBLING(semicolonNode));
        
    } else if([node isKindOfClass:[SourceNodeText class]] && _HasInterfaceOrProtocolParent(node)) {
        
        // "-(foo)bar" "+(foo)bar" "-bar" "+bar"
        NSString* content = node.content;
        if([content isEqualToString:@"-"] || [content isEqualToString:@"+"]) {
            SourceNode* semicolonNode = [node findNextSiblingOfClass:[SourceNodeSemicolon class]];
            if(semicolonNode) {
                SourceNode* newNode = [[SourceNodeObjCMethodDeclaration alloc] initWithSource:node.source range:NSMakeRange(node.range.location, 0)];
                [node insertPreviousSibling:newNode];
                [newNode release];
                _RearrangeNodesAsChildren(newNode, SEMICOLON_PREVIOUS_SIBLING(semicolonNode));
            }
        }
        
    } else if([node isKindOfClass:[SourceNodeText class]] && _HasImplementationParent(node)) {
        
        // "-(foo)bar" "+(foo)bar" "-bar" "+bar"
        NSString* content = node.content;
        if([content isEqualToString:@"-"] || [content isEqualToString:@"+"]) {
            SourceNode* nextNode = [node findNextSiblingOfClass:[SourceNodeBraces class]];
            if(nextNode) {
                SourceNode* newNode = [[SourceNodeObjCMethodImplementation alloc] initWithSource:node.source range:NSMakeRange(node.range.location, 0)];
                [node insertPreviousSibling:newNode];
                [newNode release];
                _RearrangeNodesAsChildren(newNode, nextNode);
            }
        }
        
    }
}

@end

@implementation SourceLanguageObjCPP

- (NSString*) name {
    return @"Obj-C++";
}

- (NSSet*) fileExtensions {
    return [NSSet setWithObjects:@"h", @"mm", nil];
}

- (SourceNodeRoot*) parseSourceString:(NSString*)source range:(NSRange)range buffer:(const unichar*)buffer syntaxAnalysis:(BOOL)syntaxAnalysis {
    NSLog(@"%@ parsing is not fully implemented", self.name);
    
    return [super parseSourceString:source range:range buffer:buffer syntaxAnalysis:syntaxAnalysis];
}

@end

@implementation SourceNodeObjCPreprocessorImport

IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_SEMICOLON_OR_CHARACTER(@"#import", false, 0)

@end

@implementation SourceNodeObjCString

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (maxLength >= 2) && (string[0] == '@') && (string[1] == '"') ? 2 : NSNotFound;
}

@end

#define IMPLEMENTATION(__NAME__, __TOKEN__) \
@implementation SourceNodeObjC##__NAME__ \
\
+ (BOOL) isAtomic { \
    return NO; \
} \
\
IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_SEMICOLON_OR_CHARACTER(__TOKEN__, false, 0) \
\
IS_MATCHING_SUFFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_SEMICOLON_OR_CHARACTER(@"@end", false, 0) \
\
@end

IMPLEMENTATION(Interface, @"@interface")
IMPLEMENTATION(Implementation, @"@implementation")
IMPLEMENTATION(Protocol, @"@protocol")

#undef IMPLEMENTATION

#define IMPLEMENTATION(__NAME__, ...) \
@implementation SourceNodeObjC##__NAME__ \
\
IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_SEMICOLON_OR_CHARACTER(__VA_ARGS__); \
\
+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    return 0; \
} \
\
@end

IMPLEMENTATION(Class, @"@class", false, 0)
IMPLEMENTATION(Public, @"@public", false, 0)
IMPLEMENTATION(Protected, @"@protected", false, 0)
IMPLEMENTATION(Private, @"@private", false, 0)
IMPLEMENTATION(Required, @"@required", false, 0)
IMPLEMENTATION(Optional, @"@optional", false, 0)
IMPLEMENTATION(Try, @"@try", false, '{')
IMPLEMENTATION(Catch, @"@catch", false, '(')
IMPLEMENTATION(Finally, @"@finally", false, '{')
IMPLEMENTATION(Throw, @"@throw", true, 0)
IMPLEMENTATION(Synchronized, @"@synchronized", false, '(')
IMPLEMENTATION(Property, @"@property", false, '(')
IMPLEMENTATION(Selector, @"@selector", false, '(')
IMPLEMENTATION(Encode, @"@encode", false, '(')
IMPLEMENTATION(Self, @"self", true, 0)
IMPLEMENTATION(Super, @"super", true, 0)

#undef IMPLEMENTATION

@implementation SourceNodeObjCMethodDeclaration
@end

@implementation SourceNodeObjCMethodImplementation
@end
