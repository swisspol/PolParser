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

#define IsNewline(C) (C == '\n')
#define IsWhitespace(C) ((C == ' ') || (C == '\t'))
#define IsWhitespaceOrNewline(C) ((C == ' ') || (C == '\t') || (C == '\n'))

static inline BOOL _IsCharacterInSet(const unichar character, const char* set, NSUInteger count) {
	for(NSUInteger i = 0; i < count; ++i) {
    	if(character == set[i])
       		return YES;
    }
    return NO;
}

#define IS_MATCHING(__MATCH__, __WHITESPACE_OR_NEWLINE__, __OTHER_CHARACTERS__, __STRING__, __MAXLENGTH__) \
    NSUInteger _matching; \
    static unichar* __match = NULL; \
    static NSUInteger __length; \
    if(__match == NULL) { \
        NSString* string = __MATCH__; \
        __length = string.length; \
        __match = malloc(__length * sizeof(unichar)); \
        [string getCharacters:__match]; \
    } \
    if(__WHITESPACE_OR_NEWLINE__ && __OTHER_CHARACTERS__) { \
        NSUInteger count = sizeof(__OTHER_CHARACTERS__) - 1; \
        _matching = (__MAXLENGTH__ > __length) && _EqualUnichars(string, __match, __length) && (IsWhitespaceOrNewline(string[__length]) || _IsCharacterInSet(string[__length], __OTHER_CHARACTERS__, count)) ? __length : NSNotFound; \
    } \
    else if(__OTHER_CHARACTERS__) { \
        NSUInteger count = sizeof(__OTHER_CHARACTERS__) - 1; \
        _matching = (__MAXLENGTH__ > __length) && _EqualUnichars(string, __match, __length) && _IsCharacterInSet(string[__length], __OTHER_CHARACTERS__, count) ? __length : NSNotFound; \
    } \
    else if(__WHITESPACE_OR_NEWLINE__) { \
        _matching = (__MAXLENGTH__ > __length) && _EqualUnichars(string, __match, __length) && IsWhitespaceOrNewline(string[__length]) ? __length : NSNotFound; \
    } \
    else { \
        _matching = (__MAXLENGTH__ >= __length) && _EqualUnichars(string, __match, __length) ? __length : NSNotFound; \
    }

#define IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_CHARACTERS(__PREFIX__, __WHITESPACE_OR_NEWLINE__, __OTHER_CHARACTERS__) \
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    IS_MATCHING(__PREFIX__, __WHITESPACE_OR_NEWLINE__, __OTHER_CHARACTERS__, string, maxLength) \
    return _matching; \
}

#define IS_MATCHING_SUFFIX_METHOD_WITH_TRAILING_CHARACTERS(__SUFFIX__, __WHITESPACE_OR_NEWLINE__, __OTHER_CHARACTERS__) \
+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    IS_MATCHING(__SUFFIX__, __WHITESPACE_OR_NEWLINE__, __OTHER_CHARACTERS__, string, maxLength) \
    return _matching; \
}

#define KEYWORD_CLASS_IMPLEMENTATION(__LANGUAGE__, __NAME__, __MATCH__) \
@implementation SourceNode##__LANGUAGE__##__NAME__ \
\
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    IS_MATCHING(__MATCH__, true, ";)]}*", string, maxLength) \
    return _matching; \
} \
\
@end

#define TOKEN_CLASS_IMPLEMENTATION(__NAME__, __CHARACTERS__) \
@implementation SourceNode##__NAME__ \
\
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    const char* characters = __CHARACTERS__; \
    NSUInteger count = sizeof(__CHARACTERS__) - 1; \
    for(NSUInteger i = 0; i < count; ++i) { \
    	if(string[i] != characters[i]) \
       		return NSNotFound; \
    } \
    return count; \
} \
\
@end

static inline BOOL _EqualUnichars(const unichar* string1, const unichar* string2, NSUInteger length) {
    while(length) {
        if(*string1++ != *string2++)
        return NO;
        --length;
    }
    return YES;
}

void _RearrangeNodesAsChildren(SourceNode* startNode, SourceNode* endNode);

@interface SourceNode ()
+ (BOOL) isAtomic;
+ (NSArray*) patchedClasses;
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength; //"maxLength" is guaranteed to be at least 1
+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength; //"maxLength" may be 0 for atomic classes
@property(nonatomic) NSRange range;
@property(nonatomic, assign) SourceNode* parent;
@property(nonatomic, readonly) NSMutableArray* mutableChildren;
@property(nonatomic) NSUInteger revision;
@property(nonatomic) void* jsObject;
- (id) initWithSource:(NSString*)source range:(NSRange)range;
@end

@interface SourceNodeRoot ()
- (id) initWithSource:(NSString*)source language:(SourceLanguage*)language;
@end

@interface SourceLanguage ()
+ (NSArray*) languageDependencies;
+ (NSSet*) languageReservedKeywords;
+ (NSArray*) languageNodeClasses;
+ (NSSet*) languageTopLevelNodeClasses;
@property(nonatomic, readonly) NSSet* topLevelNodeClasses;
- (SourceNodeRoot*) parseSourceString:(NSString*)source range:(NSRange)range buffer:(const unichar*)buffer syntaxAnalysis:(BOOL)syntaxAnalysis;
- (SourceNode*) performSyntaxAnalysisForNode:(SourceNode*)node sourceBuffer:(const unichar*)sourceBuffer topLevelNodeClasses:(NSSet*)nodeClasses; //Override point to perform language dependent source tree refactoring after parsing
@end

@interface SourceLanguageBase : SourceLanguage
@end

@interface SourceLanguageC : SourceLanguage
@end

@interface SourceLanguageCPP : SourceLanguage
@end

@interface SourceLanguageObjC : SourceLanguage
@end

@interface SourceLanguageObjCPP : SourceLanguage
@end
