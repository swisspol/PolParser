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
#import "ParserLanguage_ObjC.h"

@interface ParserLanguageObjC : ParserLanguage <ParserLanguageCTopLevelNodeClasses>
@end

/* WARNING: Keep in sync with C #include */
@interface ParserNodeObjCPreprocessorImport ()
@property(nonatomic, retain) NSString* name;
@end

@implementation ParserLanguageObjC

+ (NSArray*) languageDependencies {
	return [NSArray arrayWithObjects:@"Common", @"C", nil];
}

+ (NSSet*) languageReservedKeywords {
	return [NSSet setWithObjects:@"in", @"out", @"inout", @"bycopy", @"byref", @"oneway", @"@class", @"@selector", @"@protocol",
    	@"@encode", @"@synchronized", @"@required", @"@optional", @"@property", @"`", @"@try", @"@throw", @"@catch",
        @"@finally", @"@private", @"@protected", @"@public", @"@interface", @"@implementation", @"@protocol", @"@end",
        @"self", @"super", @"nil", nil]; //Not "true" keywords
}

+ (NSArray*) languageNodeClasses {
	NSMutableArray* classes = [NSMutableArray array];
    
    [classes addObject:[ParserNodeCPPComment class]]; //From C++ language
    
    [classes addObject:[ParserNodeObjCString class]];
    [classes addObject:[ParserNodeObjCPreprocessorImport class]];
    [classes addObject:[ParserNodeObjCInterface class]];
    [classes addObject:[ParserNodeObjCImplementation class]];
    [classes addObject:[ParserNodeObjCProtocol class]];
    [classes addObject:[ParserNodeObjCClass class]];
    [classes addObject:[ParserNodeObjCPublic class]];
    [classes addObject:[ParserNodeObjCProtected class]];
    [classes addObject:[ParserNodeObjCPrivate class]];
    [classes addObject:[ParserNodeObjCOptional class]];
    [classes addObject:[ParserNodeObjCRequired class]];
    [classes addObject:[ParserNodeObjCProperty class]];
    [classes addObject:[ParserNodeObjCSynthesize class]];
    [classes addObject:[ParserNodeObjCTry class]];
    [classes addObject:[ParserNodeObjCCatch class]];
    [classes addObject:[ParserNodeObjCFinally class]];
    [classes addObject:[ParserNodeObjCThrow class]];
    [classes addObject:[ParserNodeObjCSynchronized class]];
    [classes addObject:[ParserNodeObjCSelector class]];
    [classes addObject:[ParserNodeObjCEncode class]];
    
    [classes addObject:[ParserNodeObjCMethodDeclaration class]];
    [classes addObject:[ParserNodeObjCMethodImplementation class]];
    [classes addObject:[ParserNodeObjCMethodCall class]];
    
    return classes;
}

+ (NSSet*) languageTopLevelNodeClasses {
	return [NSSet setWithObjects:[ParserNodeObjCInterface class], [ParserNodeObjCImplementation class], nil];
}

- (NSString*) name {
    return @"Obj-C";
}

- (NSSet*) fileExtensions {
    return [NSSet setWithObject:@"m"];
}

static BOOL _HasInterfaceOrProtocolParent(ParserNode* node) {
    if([node.parent isKindOfClass:[ParserNodeObjCInterface class]] || [node.parent isKindOfClass:[ParserNodeObjCPrivate class]] || [node.parent isKindOfClass:[ParserNodeObjCProtected class]] || [node.parent isKindOfClass:[ParserNodeObjCPublic class]]
    	|| [node.parent isKindOfClass:[ParserNodeObjCProtocol class]] || [node.parent isKindOfClass:[ParserNodeObjCProtected class]] || [node.parent isKindOfClass:[ParserNodeObjCOptional class]])
        return YES;
    
    return [node.parent isKindOfClass:[ParserNodeCPreprocessorCondition class]] ? _HasInterfaceOrProtocolParent(node.parent) : NO;
}

static BOOL _HasImplementationParent(ParserNode* node) {
    if([node.parent isKindOfClass:[ParserNodeObjCImplementation class]])
        return YES;
    
    return [node.parent isKindOfClass:[ParserNodeCPreprocessorCondition class]] ? _HasImplementationParent(node.parent) : NO;
}

static ParserNode* _ApplierFunction(ParserNode* node, void* context) {
	[node removeFromParent];
	[(ParserNode*)context addChild:node];
    return nil;
}

- (ParserNode*) performSyntaxAnalysisForNode:(ParserNode*)node textBuffer:(const unichar*)textBuffer topLevelLanguage:(ParserLanguage*)topLevelLanguage {
    
    if([node isKindOfClass:[ParserNodeObjCPreprocessorImport class]]) {
    	[node setName:[[node.firstChild findNextSiblingIgnoringWhitespaceAndNewline] content]];
    } else if([node isKindOfClass:[ParserNodeBraces class]]) {
        ParserNode* previousNode = [node findPreviousSiblingIgnoringWhitespaceAndNewline];
        
        // "@catch() {}" "@synchronized() {}"
        if([previousNode isKindOfClass:[ParserNodeParenthesis class]]) {
            previousNode = [previousNode findPreviousSiblingIgnoringWhitespaceAndNewline];
            if([previousNode isKindOfClass:[ParserNodeObjCCatch class]] || [previousNode isKindOfClass:[ParserNodeObjCSynchronized class]])
                _RearrangeNodesAsChildren(previousNode, node);
        }
        
        // "@try {}" "@finally {}"
        else if([previousNode isKindOfClass:[ParserNodeObjCTry class]] || [previousNode isKindOfClass:[ParserNodeObjCFinally class]]) {
            _RearrangeNodesAsChildren(previousNode, node);
        }
        
    } else if([node isKindOfClass:[ParserNodeObjCSelector class]] || [node isKindOfClass:[ParserNodeObjCEncode class]]) {
        
        // "@selector()" "@encode()"
        ParserNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
        if([nextNode isKindOfClass:[ParserNodeParenthesis class]])
            _RearrangeNodesAsChildren(node, nextNode);
        
    } else if([node isKindOfClass:[ParserNodeObjCThrow class]]) {
        
        // "@throw" "@throw foo"
        ParserNode* semicolonNode = [node findNextSiblingOfClass:[ParserNodeSemicolon class]];
        if(semicolonNode) {
        	if(semicolonNode.previousSibling != node)
                _RearrangeNodesAsChildren(node, semicolonNode);
        } else {
            if([node.parent isKindOfClass:[ParserNodeCConditionIf class]] || [node.parent isKindOfClass:[ParserNodeCConditionElse class]] || [node.parent isKindOfClass:[ParserNodeCConditionElseIf class]]
            	|| [node.parent isKindOfClass:[ParserNodeCFlowFor class]] || [node.parent isKindOfClass:[ParserNodeCFlowWhile class]])
            	_RearrangeNodesAsChildren(node, node.parent.lastChild);
        }
        
    } else if([node isKindOfClass:[ParserNodeObjCProperty class]] && _HasInterfaceOrProtocolParent(node)) {
        
        // "@property" "@property()"
        ParserNode* semicolonNode = [node findNextSiblingOfClass:[ParserNodeSemicolon class]];
        if(semicolonNode)
            _RearrangeNodesAsChildren(node, semicolonNode);
        
    } else if([node isKindOfClass:[ParserNodeObjCSynthesize class]] && _HasImplementationParent(node)) {
        
        // "@synthesize"
        ParserNode* semicolonNode = [node findNextSiblingOfClass:[ParserNodeSemicolon class]];
        if(semicolonNode)
            _RearrangeNodesAsChildren(node, semicolonNode);
        
    } else if([node isMemberOfClass:[ParserNodeObjCPrivate class]] || [node isMemberOfClass:[ParserNodeObjCProtected class]] || [node isMemberOfClass:[ParserNodeObjCPublic class]]) {
        
        // "@private ..." "@protected ..." "@public ..."
    	ParserNode* endNode = [node.parent.lastChild findPreviousSiblingIgnoringWhitespaceAndNewline]; //Last child is guaranted to be @end
        ParserNode* otherNode = [node findNextSiblingOfClass:[ParserNodeObjCPrivate class]];
        if(otherNode && (otherNode.range.location < endNode.range.location))
        	endNode = otherNode.previousSibling;
        otherNode = [node findNextSiblingOfClass:[ParserNodeObjCProtected class]];
        if(otherNode && (otherNode.range.location < endNode.range.location))
        	endNode = otherNode.previousSibling;
        otherNode = [node findNextSiblingOfClass:[ParserNodeObjCPublic class]];
        if(otherNode && (otherNode.range.location < endNode.range.location))
        	endNode = otherNode.previousSibling;
        if([endNode isKindOfClass:[ParserNodeWhitespace class]] || [endNode isKindOfClass:[ParserNodeNewline class]])
        	endNode = [endNode findPreviousSiblingIgnoringWhitespaceAndNewline];
        _RearrangeNodesAsChildren(node, endNode);
        
    } else if([node isMemberOfClass:[ParserNodeObjCRequired class]] || [node isMemberOfClass:[ParserNodeObjCOptional class]]) {
        
        // "@required ..." @"@optional ..."
    	ParserNode* endNode = [node.parent.lastChild findPreviousSiblingIgnoringWhitespaceAndNewline]; //Last child is guaranted to be @end
        ParserNode* otherNode = [node findNextSiblingOfClass:[ParserNodeObjCRequired class]];
        if(otherNode && (otherNode.range.location < endNode.range.location))
        	endNode = otherNode.previousSibling;
        otherNode = [node findNextSiblingOfClass:[ParserNodeObjCOptional class]];
        if(otherNode && (otherNode.range.location < endNode.range.location))
        	endNode = otherNode.previousSibling;
        if([endNode isKindOfClass:[ParserNodeWhitespace class]] || [endNode isKindOfClass:[ParserNodeNewline class]])
        	endNode = [endNode findPreviousSiblingIgnoringWhitespaceAndNewline];
        _RearrangeNodesAsChildren(node, endNode);
        
    } else if([node isMemberOfClass:[ParserNodeText class]] && _HasInterfaceOrProtocolParent(node)) {
        
        // "-(foo)bar" "+(foo)bar" "-bar" "+bar"
        NSString* content = node.content;
        if([content isEqualToString:@"-"] || [content isEqualToString:@"+"]) {
            ParserNode* semicolonNode = [node findNextSiblingOfClass:[ParserNodeSemicolon class]];
            if(semicolonNode) {
                ParserNode* newNode = [[ParserNodeMatch alloc] initWithText:node.text range:node.range];
                newNode.lines = node.lines;
                [node replaceWithNode:newNode];
                [newNode release];
                node = newNode;
                
                newNode = [[ParserNodeObjCMethodDeclaration alloc] initWithText:node.text range:NSMakeRange(node.range.location, 0)];
                [node insertPreviousSibling:newNode];
                [newNode release];
                _RearrangeNodesAsChildren(newNode, semicolonNode);
            }
        }
        
    } else if([node isMemberOfClass:[ParserNodeText class]] && _HasImplementationParent(node)) {
        
        // "-(foo)bar" "+(foo)bar" "-bar" "+bar"
        NSString* content = node.content;
        if([content isEqualToString:@"-"] || [content isEqualToString:@"+"]) {
            ParserNode* nextNode = [node findNextSiblingOfClass:[ParserNodeBraces class]];
            if(nextNode) {
                ParserNode* newNode = [[ParserNodeMatch alloc] initWithText:node.text range:node.range];
                newNode.lines = node.lines;
                [node replaceWithNode:newNode];
                [newNode release];
                node = newNode;
                
                newNode = [[ParserNodeObjCMethodImplementation alloc] initWithText:node.text range:NSMakeRange(node.range.location, 0)];
                [node insertPreviousSibling:newNode];
                [newNode release];
                _RearrangeNodesAsChildren(newNode, nextNode);
            }
        }
        
    }
    else if([node isKindOfClass:[ParserNodeBrackets class]] && node.children) {
        
        // "[foo bar:baz]"
        ParserNode* target = [node.firstChild findNextSiblingIgnoringWhitespaceAndNewline];
        if([target isKindOfClass:[ParserNodeParenthesis class]])
        	target = [target findNextSiblingIgnoringWhitespaceAndNewline];
        if([target isMemberOfClass:[ParserNodeText class]] || [target isKindOfClass:[ParserNodeObjCSelf class]] || [target isKindOfClass:[ParserNodeObjCSuper class]]
        	|| [target isKindOfClass:[ParserNodeBrackets class]] || [target isKindOfClass:[ParserNodeCFunctionCall class]] || [target isKindOfClass:[ParserNodeObjCString class]]) {
        	if([target.nextSibling isKindOfClass:[ParserNodeWhitespace class]] || [target.nextSibling isKindOfClass:[ParserNodeNewline class]]) {
                ParserNode* nextNode = [target findNextSiblingIgnoringWhitespaceAndNewline];
                if([nextNode isMemberOfClass:[ParserNodeText class]]) {
                	if([target isMemberOfClass:[ParserNodeText class]]) {
						ParserNode* newNode = [[ParserNodeMatch alloc] initWithText:target.text range:target.range];
                        newNode.lines = target.lines;
                        [target replaceWithNode:newNode];
                        [newNode release];
					}
                    
                    ParserNode* newNode = [[ParserNodeObjCMethodCall alloc] initWithText:node.text range:node.range];
                    [node applyFunctionOnChildren:_ApplierFunction context:newNode];
                    newNode.lines = node.lines;
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

/* WARNING: Keep in sync with C #include */
@implementation ParserNodeObjCPreprocessorImport

@synthesize name=_name;

IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_CHARACTERS("#import", true, NULL)

- (void) dealloc {
	[_name release];
    
    [super dealloc];
}

@end

@implementation ParserNodeObjCString

+ (NSArray*) patchedClasses {
	return [NSArray arrayWithObject:[ParserNodeCStringDoubleQuote class]];
}

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (string[0] == '@') && (string[1] == '"') ? 2 : NSNotFound;
}

- (NSString*) cleanContent {
	return [[super cleanContent] substringFromIndex:1];
}

@end

KEYWORD_CLASS_IMPLEMENTATION(ObjC, Self, "self")
KEYWORD_CLASS_IMPLEMENTATION(ObjC, Super, "super")
KEYWORD_CLASS_IMPLEMENTATION(ObjC, Nil, "nil")

#define IMPLEMENTATION(__NAME__, __TOKEN__) \
@implementation ParserNodeObjC##__NAME__ \
\
+ (BOOL) isAtomic { \
    return NO; \
} \
\
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    IS_MATCHING_CHARACTERS_EXTENDED(__TOKEN__, true, NULL, string, maxLength) \
    if(_matching != NSNotFound) { \
        string += _matching; \
        maxLength -= _matching; \
        while(maxLength) { \
            if(IsNewline(*string) || (*string == '{') || ((string[0] == '/') && ((string[1] == '*') || (string[1] == '/')))) { \
                do { \
                    --string; \
                } while(IsWhitespace(*string)); \
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
IS_MATCHING_SUFFIX_METHOD_WITH_TRAILING_CHARACTERS("@end", false, NULL) \
\
@end

IMPLEMENTATION(Interface, "@interface")
IMPLEMENTATION(Implementation, "@implementation")
IMPLEMENTATION(Protocol, "@protocol")

#undef IMPLEMENTATION

#define IMPLEMENTATION(__NAME__, ...) \
@implementation ParserNodeObjC##__NAME__ \
\
IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_CHARACTERS(__VA_ARGS__) \
\
+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    return 0; \
} \
\
@end

IMPLEMENTATION(Class, "@class", true, NULL)
IMPLEMENTATION(Public, "@public", true, NULL)
IMPLEMENTATION(Protected, "@protected", true, NULL)
IMPLEMENTATION(Private, "@private", true, NULL)
IMPLEMENTATION(Required, "@required", true, NULL)
IMPLEMENTATION(Optional, "@optional", true, NULL)
IMPLEMENTATION(Try, "@try", true, "{")
IMPLEMENTATION(Catch, "@catch", true, "(")
IMPLEMENTATION(Finally, "@finally", true, "{")
IMPLEMENTATION(Throw, "@throw", false, NULL)
IMPLEMENTATION(Synchronized, "@synchronized", true, "(")
IMPLEMENTATION(Property, "@property", true, "(")
IMPLEMENTATION(Synthesize, "@synthesize", true, "(")
IMPLEMENTATION(Selector, "@selector", true, "(")
IMPLEMENTATION(Encode, "@encode", true, "(")

#undef IMPLEMENTATION

static NSString* _SelectorFromMethod(ParserNode* node) {
	NSMutableString* string = [NSMutableString string];
    node = [node findNextSiblingIgnoringWhitespaceAndNewline];
    if([node isKindOfClass:[ParserNodeParenthesis class]])
        node = [node findNextSiblingIgnoringWhitespaceAndNewline];
    ParserNode* colonNode = [node findNextSiblingOfClass:[ParserNodeColon class]];
    if(colonNode) {
        node = colonNode;
        while(node) {
            if(![node.previousSibling isKindOfClass:[ParserNodeWhitespace class]] && ![node.previousSibling isKindOfClass:[ParserNodeNewline class]])
                [string appendString:node.previousSibling.content];
            [string appendString:node.content];
            node = [node findNextSiblingOfClass:[ParserNodeColon class]];
        }
    } else {
        [string appendString:node.content];
    }
    return string;
}

@implementation ParserNodeObjCMethodDeclaration

- (void) dealloc {
	[_name release];
    
    [super dealloc];
}

- (NSString*) name {
	if(_name == nil)
    	_name = [_SelectorFromMethod(self.firstChild) retain];
    return _name;
}

@end

@implementation ParserNodeObjCMethodImplementation

- (void) dealloc {
	[_name release];
    
    [super dealloc];
}

- (NSString*) name {
	if(_name == nil)
    	_name = [_SelectorFromMethod(self.firstChild) retain];
    return _name;
}

@end

@implementation ParserNodeObjCMethodCall

- (void) dealloc {
	[_name release];
    
    [super dealloc];
}

- (NSString*) name {
	if(_name == nil) {
    	ParserNode* node = self.firstChild;
        node = [node findNextSiblingIgnoringWhitespaceAndNewline];
    	if([node isKindOfClass:[ParserNodeParenthesis class]])
        	node = [node findNextSiblingIgnoringWhitespaceAndNewline];
    	_name = [_SelectorFromMethod(node) retain];
    }
    return _name;
}

@end
