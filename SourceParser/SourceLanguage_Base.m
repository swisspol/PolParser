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

@implementation SourceLanguageBase

- (NSString*) name {
	return @"Base";
}

- (NSSet*) fileExtensions {
	return nil;
}

- (NSArray*) nodeClasses {
	static NSMutableArray* classes = nil;
    if(classes == nil) {
        classes = [[NSMutableArray alloc] init];
        [classes addObjectsFromArray:[super nodeClasses]];
        
        [classes addObject:[SourceNodeNewline class]];
        [classes addObject:[SourceNodeIndenting class]]; //Must be before SourceNodeWhitespace
        [classes addObject:[SourceNodeWhitespace class]];
        [classes addObject:[SourceNodeBraces class]];
        [classes addObject:[SourceNodeParenthesis class]];
        [classes addObject:[SourceNodeBrackets class]];
    }
    return classes;
}

@end

@implementation SourceNode (SourceLanguageExtensions)

- (SourceNode*) findPreviousSiblingIgnoringWhitespaceAndNewline {
	SourceNode* node = self.previousSibling;
    while(node) {
    	if(![node isKindOfClass:[SourceNodeWhitespace class]] && ![node isKindOfClass:[SourceNodeNewline class]])
        	return node;
        node = node.previousSibling;
    }
    return nil;
}

- (SourceNode*) findNextSiblingIgnoringWhitespaceAndNewline {
	SourceNode* node = self.nextSibling;
    while(node) {
    	if(![node isKindOfClass:[SourceNodeWhitespace class]] && ![node isKindOfClass:[SourceNodeNewline class]])
        	return node;
        node = node.nextSibling;
    }
    return nil;
}

@end

@implementation SourceNodeWhitespace

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return IsWhiteSpace(*string) ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
	return maxLength && !IsWhiteSpace(*string) ? 0 : NSNotFound;
}

- (void) insertChild:(SourceNode*)child atIndex:(NSUInteger)index {
	[self doesNotRecognizeSelector:_cmd];
}

@end

@implementation SourceNodeIndenting

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return IsWhiteSpace(*string) && IsNewline(*(string - 1)) ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
	return maxLength && !IsWhiteSpace(*string) ? 0 : NSNotFound;
}

- (void) insertChild:(SourceNode*)child atIndex:(NSUInteger)index {
	[self doesNotRecognizeSelector:_cmd];
}

@end

@implementation SourceNodeNewline

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return IsNewline(*string) ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
	return 0;
}

- (void) insertChild:(SourceNode*)child atIndex:(NSUInteger)index {
	[self doesNotRecognizeSelector:_cmd];
}

@end

#define IMPLEMENTATION(__NAME__, __OPEN__, __CLOSE__) \
@implementation SourceNode##__NAME__ \
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