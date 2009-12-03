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

#import "Parser.h"

#define IsNewline(C) ((C == '\r') || (C == '\n'))
#define IsWhitespace(C) ((C == ' ') || (C == '\t'))
#define IsWhitespaceOrNewline(C) (IsWhitespace(C) || IsNewline(C))

#define IS_MATCHING_CHARACTERS(__CHARACTERS__, __STRING__, __MAXLENGTH__) \
	const char* __characters = __CHARACTERS__; \
	NSUInteger __count = sizeof(__CHARACTERS__) - 1; \
	NSUInteger _matching = (__MAXLENGTH__ >= __count) && _EqualsCharacters(__STRING__, __characters, __count) ? __count : NSNotFound;

#define IS_MATCHING_CHARACTERS_EXTENDED(__CHARACTERS__, __WHITESPACE_OR_NEWLINE__, __OTHER_CHARACTERS__, __STRING__, __MAXLENGTH__) \
    NSUInteger _matching; \
    const char* __characters = __CHARACTERS__; \
	NSUInteger __count = sizeof(__CHARACTERS__) - 1; \
    if(__WHITESPACE_OR_NEWLINE__ && __OTHER_CHARACTERS__) { \
        NSUInteger count = sizeof(__OTHER_CHARACTERS__) - 1; \
        _matching = (__MAXLENGTH__ > __count) && _EqualsCharacters(string, __characters, __count) && (IsWhitespaceOrNewline(string[__count]) || _IsCharacterInSet(string[__count], __OTHER_CHARACTERS__, count)) ? __count : NSNotFound; \
    } \
    else if(__OTHER_CHARACTERS__) { \
        NSUInteger count = sizeof(__OTHER_CHARACTERS__) - 1; \
        _matching = (__MAXLENGTH__ > __count) && _EqualsCharacters(string, __characters, __count) && _IsCharacterInSet(string[__count], __OTHER_CHARACTERS__, count) ? __count : NSNotFound; \
    } \
    else if(__WHITESPACE_OR_NEWLINE__) { \
        _matching = (__MAXLENGTH__ > __count) && _EqualsCharacters(string, __characters, __count) && IsWhitespaceOrNewline(string[__count]) ? __count : NSNotFound; \
    } \
    else { \
        _matching = (__MAXLENGTH__ >= __count) && _EqualsCharacters(string, __characters, __count) ? __count : NSNotFound; \
    }

#define IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_CHARACTERS(__CHARACTERS__, __WHITESPACE_OR_NEWLINE__, __OTHER_CHARACTERS__) \
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    IS_MATCHING_CHARACTERS_EXTENDED(__CHARACTERS__, __WHITESPACE_OR_NEWLINE__, __OTHER_CHARACTERS__, string, maxLength) \
    return _matching; \
}

#define IS_MATCHING_SUFFIX_METHOD_WITH_TRAILING_CHARACTERS(__CHARACTERS__, __WHITESPACE_OR_NEWLINE__, __OTHER_CHARACTERS__) \
+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    IS_MATCHING_CHARACTERS_EXTENDED(__CHARACTERS__, __WHITESPACE_OR_NEWLINE__, __OTHER_CHARACTERS__, string, maxLength) \
    return _matching; \
}

#define KEYWORD_CLASS_IMPLEMENTATION(__LANGUAGE__, __NAME__, __MATCH__) \
@implementation ParserNode##__LANGUAGE__##__NAME__ \
\
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    IS_MATCHING_CHARACTERS_EXTENDED(__MATCH__, true, ";)]}*", string, maxLength) \
    return _matching; \
} \
\
@end

#define TOKEN_CLASS_IMPLEMENTATION(__NAME__, __CHARACTERS__) \
@implementation ParserNode##__NAME__ \
\
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    IS_MATCHING_CHARACTERS(__CHARACTERS__, string, maxLength); \
    return _matching; \
} \
\
@end

#define SGML_CLASS_IMPLEMENTATION(__NAME__, __START__, __END__) \
@implementation ParserNode##__NAME__ \
\
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    IS_MATCHING_CHARACTERS(__START__, string, maxLength); \
    return _matching; \
} \
\
+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
	IS_MATCHING_CHARACTERS(__END__, string, maxLength); \
    return _matching; \
} \
\
@end

static inline BOOL _IsCharacterInSet(const unichar character, const char* set, NSUInteger count) {
	for(NSUInteger i = 0; i < count; ++i) {
    	if(character == set[i])
       		return YES;
    }
    return NO;
}

static inline BOOL _EqualsCharacters(const unichar* string, const char* array, NSUInteger length) {
    while(length) {
        if(*string++ != *array++)
        return NO;
        --length;
    }
    return YES;
}

void _RearrangeNodesAsChildren(ParserNode* startNode, ParserNode* endNode);

@interface ParserNode ()
+ (BOOL) isAtomic;
+ (NSArray*) patchedClasses;
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength; //"maxLength" is guaranteed to be at least 1
+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength; //"maxLength" may be 0 for atomic classes
@property(nonatomic) NSRange range;
@property(nonatomic) NSRange lines;
@property(nonatomic, assign) ParserNode* parent;
@property(nonatomic, readonly) NSMutableArray* mutableChildren;
@property(nonatomic) NSUInteger revision;
@property(nonatomic) void* jsObject;
- (id) initWithText:(NSString*)text range:(NSRange)range;
@end

@interface ParserNodeRoot ()
@property(nonatomic, assign) ParserLanguage* language;
@end

@interface ParserLanguage ()
+ (NSArray*) languageDependencies;
+ (NSSet*) languageReservedKeywords;
+ (NSArray*) languageNodeClasses;
+ (NSSet*) languageTopLevelNodeClasses;
+ (ParserNodeRoot*) newNodeTreeFromText:(NSString*)text withNodeClasses:(NSArray*)nodeClasses;
+ (ParserNodeRoot*) newNodeTreeFromText:(NSString*)text range:(NSRange)range textBuffer:(const unichar*)textBuffer withNodeClasses:(NSArray*)nodeClasses;
@property(nonatomic, readonly) NSSet* topLevelNodeClasses;
- (ParserNodeRoot*) parseText:(NSString*)text range:(NSRange)range textBuffer:(const unichar*)textBuffer syntaxAnalysis:(BOOL)syntaxAnalysis;
- (ParserNode*) performSyntaxAnalysisForNode:(ParserNode*)node textBuffer:(const unichar*)textBuffer topLevelNodeClasses:(NSSet*)nodeClasses; //Override point to perform language dependent string tree refactoring after parsing
@end

@interface ParserLanguageSGML : ParserLanguage
+ (NSString*) stringWithReplacedEntities:(NSString*)string;
+ (Class) SGMLElementClass;
@end

/* Workaround some compiler warnings */
@interface NSObject (ParserNode)
- (void) setName:(NSString*)name;
@end
