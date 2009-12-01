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

@interface ParserLanguageBase : ParserLanguage
@end

@implementation ParserLanguageBase

+ (NSArray*) languageNodeClasses {
	NSMutableArray* classes = [NSMutableArray arrayWithArray:[super languageNodeClasses]];
    
    [classes addObject:[ParserNodeNewline class]];
    [classes addObject:[ParserNodeIndenting class]]; //Must be before ParserNodeWhitespace
    [classes addObject:[ParserNodeWhitespace class]];
    [classes addObject:[ParserNodeBraces class]];
    [classes addObject:[ParserNodeParenthesis class]];
    [classes addObject:[ParserNodeBrackets class]];
    
    return classes;
}

- (NSString*) name {
    return @"Base";
}

- (NSSet*) fileExtensions {
    return nil;
}

@end

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
    return maxLength && !IsWhitespace(*string) ? 0 : NSNotFound;
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
    return maxLength && !IsWhitespace(*string) ? 0 : NSNotFound;
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
