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
#define IsWhiteSpace(C) ((C == ' ') || (C == '\t'))
#define IsWhiteSpaceOrNewline(C) ((C == ' ') || (C == '\t') || (C == '\n'))

#define IS_MATCHING(__MATCH__, __TRAILING_WHITESPACE_OR_NEWLINE__, __SEMICOLON__, __CHARACTER__, __STRING__, __MAXLENGTH__) \
    NSUInteger _matching; \
    static unichar* __match = NULL; \
    static NSUInteger __length; \
    if(__match == NULL) { \
        NSString* string = __MATCH__; \
        __length = string.length; \
        __match = malloc(__length * sizeof(unichar)); \
        [string getCharacters:__match]; \
    } \
    if(__TRAILING_WHITESPACE_OR_NEWLINE__ && __SEMICOLON__) { \
        _matching = (__MAXLENGTH__ > __length) && _EqualUnichars(string, __match, __length) && (IsWhiteSpaceOrNewline(string[__length]) || (string[__length] == ';') || (__CHARACTER__ && (string[__length] == __CHARACTER__))) ? __length : NSNotFound; \
    } else if(__TRAILING_WHITESPACE_OR_NEWLINE__) { \
        _matching = (__MAXLENGTH__ > __length) && _EqualUnichars(string, __match, __length) && (IsWhiteSpaceOrNewline(string[__length]) || (__CHARACTER__ && (string[__length] == __CHARACTER__))) ? __length : NSNotFound; \
    } else { \
        _matching = (__MAXLENGTH__ >= __length) && _EqualUnichars(string, __match, __length) ? __length : NSNotFound; \
    }

#define IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_SEMICOLON_OR_CHARACTER(__PREFIX__, __TRAILING_WHITESPACE_OR_NEWLINE__, __SEMICOLON__, __CHARACTER__) \
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    IS_MATCHING(__PREFIX__, __TRAILING_WHITESPACE_OR_NEWLINE__, __SEMICOLON__, __CHARACTER__, string, maxLength) \
    return _matching; \
}

#define IS_MATCHING_SUFFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_SEMICOLON_OR_CHARACTER(__SUFFIX__, __TRAILING_WHITESPACE_OR_NEWLINE__, __SEMICOLON__, __CHARACTER__) \
+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    IS_MATCHING(__SUFFIX__, __TRAILING_WHITESPACE_OR_NEWLINE__, __SEMICOLON__, __CHARACTER__, string, maxLength) \
    return _matching; \
}

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
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength; //"maxLength" is guaranteed to be at least 1
+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength; //"maxLength" may be 0 for atomic classes
@property(nonatomic) NSRange range;
@property(nonatomic, assign) SourceNode* parent;
@property(nonatomic, readonly) NSMutableArray* mutableChildren;
@property(nonatomic) NSUInteger revision;
- (id) initWithSource:(NSString*)source range:(NSRange)range;
@end

@interface SourceNodeRoot ()
- (id) initWithSource:(NSString*)source language:(SourceLanguage*)language;
@end

@interface SourceLanguage ()
- (SourceNodeRoot*) parseSourceString:(NSString*)source range:(NSRange)range buffer:(const unichar*)buffer syntaxAnalysis:(BOOL)syntaxAnalysis;
- (void) performSyntaxAnalysisForNode:(SourceNode*)node; //Override point to perform language dependent source tree refactoring after parsing
@end

@interface SourceLanguageBase : SourceLanguage
@end

@interface SourceLanguageC : SourceLanguageBase
- (BOOL) nodeHasRootParent:(SourceNode*)node;
- (BOOL) nodeIsStatementDelimiter:(SourceNode*)node;
@end

@interface SourceLanguageCPP : SourceLanguageC
@end

@interface SourceLanguageObjC : SourceLanguageC
@end

@interface SourceLanguageObjCPP : SourceLanguageObjC
@end
