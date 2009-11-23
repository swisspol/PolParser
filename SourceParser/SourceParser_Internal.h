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

#import "SourceParser.h"
#import "SourceNodes.h"
#import "SourceLanguage_C.h"
#import "SourceLanguage_CPP.h"
#import "SourceLanguage_ObjC.h"

#define IsNewline(C) (C == '\n')
#define IsWhiteSpace(C) ((C == ' ') || (C == '\t'))
#define IsWhiteSpaceOrNewline(C) ((C == ' ') || (C == '\t') || (C == '\n'))

#define IS_MATCHING(__MATCH__, __TRAILING_WHITESPACE_OR_NEWLINE__, __CHARACTER__, __STRING__, __MAXLENGTH__) \
	NSUInteger _matching; \
	static unichar* __match = NULL; \
    static NSUInteger __length; \
    if(__match == NULL) { \
    	NSString* string = __MATCH__; \
        __length = string.length; \
        __match = malloc(__length * sizeof(unichar)); \
        [string getCharacters:__match]; \
    } \
    if(__TRAILING_WHITESPACE_OR_NEWLINE__) { \
    	_matching = (__MAXLENGTH__ > __length) && _EqualUnichars(string, __match, __length) && (IsWhiteSpaceOrNewline(string[__length]) || (__CHARACTER__ && (string[__length] == __CHARACTER__))) ? __length : NSNotFound; \
    } else { \
    	_matching = (__MAXLENGTH__ >= __length) && _EqualUnichars(string, __match, __length) ? __length : NSNotFound; \
    }

#define IS_MATCHING_PREFIX_METHOD(__PREFIX__) \
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    IS_MATCHING(__PREFIX__, false, 0, string, maxLength) \
    return _matching; \
}

#define IS_MATCHING_SUFFIX_METHOD(__SUFFIX__) \
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    IS_MATCHING(__SUFFIX__, false, 0, string, maxLength) \
    return _matching; \
}

#define IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_CHARACTER(__PREFIX__, __CHARACTER__) \
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    IS_MATCHING(__PREFIX__, true, __CHARACTER__, string, maxLength) \
    return _matching; \
}

#define IS_MATCHING_SUFFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_CHARACTER(__SUFFIX__, __CHARACTER__) \
+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    IS_MATCHING(__SUFFIX__, true, __CHARACTER__, string, maxLength) \
    return _matching; \
}

#define IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE(__PREFIX__) \
	IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_CHARACTER(__PREFIX__, 0)

#define IS_MATCHING_SUFFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE(__SUFFIX__) \
	IS_MATCHING_SUFFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_CHARACTER(__SUFFIX__, 0)
    
static inline BOOL _EqualUnichars(const unichar* string1, const unichar* string2, NSUInteger length) {
	while(length) {
    	if(*string1++ != *string2++)
        return NO;
        --length;
    }
    return YES;
}

@interface SourceNode ()
@property(nonatomic) NSRange range;
@property(nonatomic, assign) SourceNode* parent;
@property(nonatomic, readonly) NSMutableArray* mutableChildren;
- (id) initWithSource:(NSString*)source range:(NSRange)range;
- (void) addChild:(SourceNode*)child;
@end

@interface SourceNode (Parsing)
+ (BOOL) isLeaf;
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength;
+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength;
@end

@interface SourceNodeRoot ()
- (id) initWithSource:(NSString*)source language:(SourceLanguage*)language;
@end

@interface SourceLanguage ()
- (void) didAddChildNodeToSourceTree:(SourceNode*)child;
@end

@interface SourceLanguageC : SourceLanguage
@end

@interface SourceLanguageCPP : SourceLanguageC
@end

@interface SourceLanguageObjC : SourceLanguageC
@end

@interface SourceLanguageObjCPP : SourceLanguageObjC
@end
