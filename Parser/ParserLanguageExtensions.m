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

@interface ParserNodeEscapedCharacter : ParserNode
@end

@interface ParserNodeUnicodeCharacter : ParserNode
@end

void _RearrangeNodesAsChildren(ParserNode* startNode, ParserNode* endNode) {
    if(startNode == endNode)
    	[NSException raise:NSInternalInconsistencyException format:@""];
    
    ParserNode* node;
    if(startNode.range.length) {
        node = [[ParserNodeMatch alloc] initWithText:startNode.text range:startNode.range];
        node.lines = startNode.lines;
        [startNode addChild:node];
        [node release];
    }
    ParserNode* sibling = startNode.nextSibling;
    node = sibling;
    do {
        ParserNode* sibling = node.nextSibling; //This will not be available afterwards
        [node removeFromParent];
        [startNode addChild:node];
        node = (node == endNode ? nil : sibling);
    } while(node);
    startNode.range = NSMakeRange(startNode.range.location, endNode.range.location + endNode.range.length - startNode.range.location);
    startNode.lines = NSMakeRange(sibling.lines.location, endNode.lines.location + endNode.lines.length - sibling.lines.location);
}

NSString* _CleanEscapedString(NSString* string) {
    static NSMutableArray* classes = nil;
    if(classes == nil) {
        classes = [[NSMutableArray alloc] init];
        [classes addObject:[ParserNodeWhitespace class]];
        [classes addObject:[ParserNodeNewline class]];
        [classes addObject:[ParserNodeUnicodeCharacter class]]; //Must be before ParserNodeEscapedCharacter
        [classes addObject:[ParserNodeEscapedCharacter class]];
    }
    ParserNodeRoot* root = [ParserLanguage newNodeTreeFromText:string withNodeClasses:classes];
    if(root.children) {
        ParserNode* node = root.firstChild;
        do {
        	ParserNode* nextNode = node.nextSibling;
            if([node isKindOfClass:[ParserNodeNewline class]])
            	[node removeFromParent];
            node = nextNode;
        } while(node);
        string = root.cleanContent;
        [root release];
    }
    return string;
}

@implementation ParserNode (ParserLanguageExtensions)

- (ParserNode*) findPreviousSiblingIgnoringWhitespaceAndNewline {
    ParserNode* node = self.previousSibling;
    while(node) {
        if(![node isKindOfClass:[ParserNodeWhitespace class]] && ![node isKindOfClass:[ParserNodeNewline class]])
            return node;
        node = node.previousSibling;
    }
    return nil;
}

- (ParserNode*) findNextSiblingIgnoringWhitespaceAndNewline {
    ParserNode* node = self.nextSibling;
    while(node) {
        if(![node isKindOfClass:[ParserNodeWhitespace class]] && ![node isKindOfClass:[ParserNodeNewline class]])
            return node;
        node = node.nextSibling;
    }
    return nil;
}

@end

@implementation ParserNodeWhitespace

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return IsWhitespace(*string) ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return !IsWhitespace(*string) ? 0 : NSNotFound;
}

- (void) insertChild:(ParserNode*)child atIndex:(NSUInteger)index {
    [self doesNotRecognizeSelector:_cmd];
}

@end

@implementation ParserNodeIndenting

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return IsWhitespace(*string) && ((*(string - 1) == 0) || IsNewline(*(string - 1))) ? 1 : NSNotFound; //The string buffer starts with a padding zero (see ParserLanguage.m)
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return !IsWhitespace(*string) ? 0 : NSNotFound;
}

- (void) insertChild:(ParserNode*)child atIndex:(NSUInteger)index {
    [self doesNotRecognizeSelector:_cmd];
}

@end

@implementation ParserNodeNewline

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (*string == '\r') && (*(string + 1) == '\n') ? 2 : ((*string == '\r') || (*string == '\n') ? 1 : NSNotFound);
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return 0;
}

- (void) insertChild:(ParserNode*)child atIndex:(NSUInteger)index {
    [self doesNotRecognizeSelector:_cmd];
}

@end

#define IMPLEMENTATION(__NAME__, __OPEN__, __CLOSE__) \
@implementation ParserNode##__NAME__ \
\
+ (BOOL) isAtomic { \
    return NO; \
} \
\
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    return *string == __OPEN__ ? 1 : NSNotFound; \
} \
\
+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    return *string == __CLOSE__ ? 1 : NSNotFound; \
} \
\
@end

IMPLEMENTATION(Braces, '{', '}')
IMPLEMENTATION(Parenthesis, '(', ')')
IMPLEMENTATION(Brackets, '[', ']')

#undef IMPLEMENTATION

@implementation ParserNodeToken

+ (id) allocWithZone:(NSZone*)zone
{
    if(self == [ParserNodeKeyword class])
        [NSException raise:NSInternalInconsistencyException format:@"ParserNodeToken is an abstract class"];
    
    return [super allocWithZone:zone];
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return 0;
}

@end

#define IMPLEMENTATION(__NAME__, __CHARACTERS__) \
@implementation ParserNode##__NAME__ \
\
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    IS_MATCHING_CHARACTERS(__CHARACTERS__, string, maxLength); \
    return _matching; \
} \
\
@end

IMPLEMENTATION(Colon, ":")
IMPLEMENTATION(Semicolon, ";")
IMPLEMENTATION(QuestionMark, "?")
IMPLEMENTATION(ExclamationMark, "!")
IMPLEMENTATION(Tilda, "~")
IMPLEMENTATION(Caret, "^")
IMPLEMENTATION(Ampersand, "&")
IMPLEMENTATION(Asterisk, "*")
IMPLEMENTATION(DoubleSemicolon, "::")
IMPLEMENTATION(Comma, ",")
IMPLEMENTATION(Equal, "=")

#undef IMPLEMENTATION

@implementation ParserNodeEscapedCharacter

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
	return (maxLength >= 2) && (*string == '\\') ? 2 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
	return 0;
}

- (NSString*) cleanContent {
	unichar character = [self.content characterAtIndex:1];
    switch(character) {
        //case '?': character = '?'; break;
        case 'f': character = '\f'; break;
        case 'a': character = '\a'; break;
        case 'v': character = '\v'; break;
        case 'b': character = '\b'; break;
        case 't': character = '\t'; break;
        case 'n': character = '\n'; break;
        case 'r': character = '\r'; break;
        //case '\'': character = '\''; break;
        //case '"': character = '"'; break;
        //case '\\': character = '\\'; break;
    }
    return [NSString stringWithCharacters:&character length:1];
}

@end

//FIXME: We don't handle "\nnn = character with octal value nnn"
@implementation ParserNodeUnicodeCharacter

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
	if((maxLength >= 2) && (*string == '\\') && (*(string + 1) != '\\')) {
    	if((*(string + 1) == 'x') && (maxLength >= 4))
        	return 4;
        if((*(string + 1) == 'u') && (maxLength >= 6))
        	return 6;
        if((*(string + 1) == 'U') && (maxLength >= 10))
        	return 10;
    }
    return NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
	return 0;
}

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

- (NSString*) cleanContent {
    return _StringFromHexUnicodeCharacter([self.content substringFromIndex:2]);
}

@end
