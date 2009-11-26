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

+ (NSArray*) languageDependencies {
	return [NSArray arrayWithObjects:@"Base", @"C", nil];
}

+ (NSSet*) languageReservedKeywords {
	return [NSSet setWithObjects:@"in", @"out", @"inout", @"bycopy", @"byref", @"oneway", @"@class", @"@selector", @"@protocol",
    	@"@encode", @"@synchronized", @"@required", @"@optional", @"@property", @"@try", @"@throw", @"@catch", @"@finally",
        @"@private", @"@protected", @"@public", @"@interface", @"@implementation", @"@protocol", @"@end", nil];
}

+ (NSArray*) languageNodeClasses {
	NSMutableArray* classes = [NSMutableArray array];
    
    [classes addObject:[SourceNodeCPPComment class]]; //From C++ language
    
    [classes addObject:[SourceNodeObjCString class]];
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
    [classes addObject:[SourceNodeObjCNil class]];
    
    [classes addObject:[SourceNodeObjCMethodDeclaration class]];
    [classes addObject:[SourceNodeObjCMethodImplementation class]];
    [classes addObject:[SourceNodeObjCMethodCall class]];
    
    return classes;
}

+ (NSSet*) languageTopLevelNodeClasses {
	return [NSSet setWithObjects:[SourceNodeObjCInterface class], [SourceNodeObjCImplementation class], nil];
}

- (NSString*) name {
    return @"Obj-C";
}

- (NSSet*) fileExtensions {
    return [NSSet setWithObject:@"m"];
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

static SourceNode* _ApplierFunction(SourceNode* node, void* context) {
	[node removeFromParent];
	[(SourceNode*)context addChild:node];
    return nil;
}

- (SourceNode*) performSyntaxAnalysisForNode:(SourceNode*)node sourceBuffer:(const unichar*)sourceBuffer topLevelNodeClasses:(NSSet*)nodeClasses {
    
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
                _RearrangeNodesAsChildren(node, semicolonNode);
        } else {
            if([node.parent isKindOfClass:[SourceNodeCConditionIf class]] || [node.parent isKindOfClass:[SourceNodeCConditionElse class]] || [node.parent isKindOfClass:[SourceNodeCConditionElseIf class]]
            	|| [node.parent isKindOfClass:[SourceNodeCFlowFor class]] || [node.parent isKindOfClass:[SourceNodeCFlowWhile class]])
            	_RearrangeNodesAsChildren(node, node.parent.lastChild);
        }
        
    } else if([node isKindOfClass:[SourceNodeObjCProperty class]] && _HasInterfaceOrProtocolParent(node)) {
        
        // "@property" "@property()"
        SourceNode* semicolonNode = [node findNextSiblingOfClass:[SourceNodeSemicolon class]];
        if(semicolonNode)
            _RearrangeNodesAsChildren(node, semicolonNode);
        
    } else if([node isKindOfClass:[SourceNodeText class]] && _HasInterfaceOrProtocolParent(node)) {
        
        // "-(foo)bar" "+(foo)bar" "-bar" "+bar"
        NSString* content = node.content;
        if([content isEqualToString:@"-"] || [content isEqualToString:@"+"]) {
            SourceNode* semicolonNode = [node findNextSiblingOfClass:[SourceNodeSemicolon class]];
            if(semicolonNode) {
                SourceNode* newNode = [[SourceNodeObjCMethodDeclaration alloc] initWithSource:node.source range:NSMakeRange(node.range.location, 0)];
                [node insertPreviousSibling:newNode];
                [newNode release];
                _RearrangeNodesAsChildren(newNode, semicolonNode);
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
    else if([node isKindOfClass:[SourceNodeBrackets class]] && node.children) {
        
        // "[foo bar:baz]"
        SourceNode* target = [node.firstChild findNextSiblingIgnoringWhitespaceAndNewline];
        if([target isKindOfClass:[SourceNodeText class]] || [target isKindOfClass:[SourceNodeObjCSelf class]] || [target isKindOfClass:[SourceNodeObjCSuper class]]
        	|| [target isKindOfClass:[SourceNodeBrackets class]] || [target isKindOfClass:[SourceNodeCFunctionCall class]] || [target isKindOfClass:[SourceNodeObjCString class]]) {
        	if([target.nextSibling isKindOfClass:[SourceNodeWhitespace class]] || [target.nextSibling isKindOfClass:[SourceNodeNewline class]]) {
                SourceNode* nextNode = [target findNextSiblingIgnoringWhitespaceAndNewline];
                if([nextNode isKindOfClass:[SourceNodeText class]]) {
                	SourceNode* newNode = [[SourceNodeObjCMethodCall alloc] initWithSource:node.source range:node.range];
                    [node applyFunctionOnChildren:_ApplierFunction context:newNode];
                    [node replaceWithNode:newNode];
                    [newNode release];
                    
                    return newNode;
                }
            }
        }
        
    }
    
    return node;
}

@end

@implementation SourceNodeObjCPreprocessorImport

IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_SEMICOLON_OR_CHARACTER(@"#import", false, false, 0)

@end

@implementation SourceNodeObjCString

+ (NSArray*) patchedClasses {
	return [NSArray arrayWithObject:[SourceNodeCStringDoubleQuote class]];
}

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
IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_SEMICOLON_OR_CHARACTER(__TOKEN__, true, false, 0) \
\
IS_MATCHING_SUFFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_SEMICOLON_OR_CHARACTER(@"@end", true, false, 0) \
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

IMPLEMENTATION(Class, @"@class", true, false, 0)
IMPLEMENTATION(Public, @"@public", true, false, 0)
IMPLEMENTATION(Protected, @"@protected", true, false, 0)
IMPLEMENTATION(Private, @"@private", true, false, 0)
IMPLEMENTATION(Required, @"@required", true, false, 0)
IMPLEMENTATION(Optional, @"@optional", true, false, 0)
IMPLEMENTATION(Try, @"@try", true, false, '{')
IMPLEMENTATION(Catch, @"@catch", true, false, '(')
IMPLEMENTATION(Finally, @"@finally", true, false, '{')
IMPLEMENTATION(Throw, @"@throw", false, false, 0)
IMPLEMENTATION(Synchronized, @"@synchronized", true, false, '(')
IMPLEMENTATION(Property, @"@property", true, false, '(')
IMPLEMENTATION(Selector, @"@selector", true, false, '(')
IMPLEMENTATION(Encode, @"@encode", true, false, '(')
IMPLEMENTATION(Self, @"self", false, false, 0)
IMPLEMENTATION(Super, @"super", false, false, 0)
IMPLEMENTATION(Nil, @"nil", false, false, 0)

#undef IMPLEMENTATION

@implementation SourceNodeObjCMethodDeclaration
@end

@implementation SourceNodeObjCMethodImplementation
@end

@implementation SourceNodeObjCMethodCall
@end
