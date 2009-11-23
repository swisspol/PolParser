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

@implementation SourceLanguageC

- (NSString*) name {
	return @"C";
}

- (NSSet*) fileExtensions {
	return [NSSet setWithObject:@"c"];
}

- (NSArray*) nodeClasses {
	static NSMutableArray* classes = nil;
    if(classes == nil) {
        classes = [[NSMutableArray alloc] init];
        [classes addObjectsFromArray:[super nodeClasses]];
        
        [classes addObject:[SourceNodeCommentC class]];
        [classes addObject:[SourceNodePreprocessorConditionIf class]];
        [classes addObject:[SourceNodePreprocessorConditionIfdef class]];
        [classes addObject:[SourceNodePreprocessorConditionIfndef class]];
        [classes addObject:[SourceNodePreprocessorConditionElse class]];
        [classes addObject:[SourceNodePreprocessorConditionElseif class]];
        [classes addObject:[SourceNodePreprocessorDefine class]];
        [classes addObject:[SourceNodePreprocessorUndefine class]];
        [classes addObject:[SourceNodePreprocessorPragma class]];
        [classes addObject:[SourceNodePreprocessorInclude class]];
        [classes addObject:[SourceNodeSemicolon class]];
        [classes addObject:[SourceNodeStringSingleQuote class]];
        [classes addObject:[SourceNodeStringDoubleQuote class]];
    }
    return classes;
}

- (NSSet*) statementClasses {
	static NSMutableSet* classes = nil;
    if(classes == nil) {
    	classes = [[NSMutableSet alloc] init];
        [classes addObject:[SourceNodeWhitespace class]];
        [classes addObject:[SourceNodeIndenting class]];
        [classes addObject:[SourceNodeText class]];
        [classes addObject:[SourceNodeParenthesis class]];
        [classes addObject:[SourceNodeBrackets class]];
        [classes addObject:[SourceNodeStringSingleQuote class]];
        [classes addObject:[SourceNodeStringDoubleQuote class]];
    }
    return classes;
}

@end

@implementation SourceNodeCommentC

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (maxLength >= 2) && (string[0] == '/') && (string[1] == '*') ? 2 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
	return (maxLength >= 2) && (string[0] == '*') && (string[1] == '/') ? 2 : NSNotFound;
}

@end

@implementation SourceNodePreprocessor

+ (id) allocWithZone:(NSZone*)zone
{
	if(self == [SourceNodePreprocessor class])
        [[NSException exceptionWithName:NSInternalInconsistencyException reason:@"SourceNodePreprocessor is an abstract class" userInfo:nil] raise];
	
	return [super allocWithZone:zone];
}

+ (BOOL) isLeaf {
	return NO;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    while(maxLength) {
        if(IsNewline(*string) || (*string == '#') || ((maxLength >= 2) && (string[0] == '/') && (string[1] == '/'))) {
            do {
                --string;
            } while(IsWhiteSpace(*string));
            if(*string != '\\')
                return 0;
        }
        if(!IsWhiteSpace(*string))
            break;
        ++string;
        --maxLength;
    }
    
    return NSNotFound;
}

@end

@implementation SourceNodePreprocessorCondition

+ (id) allocWithZone:(NSZone*)zone
{
	if(self == [SourceNodePreprocessorCondition class])
        [[NSException exceptionWithName:NSInternalInconsistencyException reason:@"SourceNodePreprocessorCondition is an abstract class" userInfo:nil] raise];
	
	return [super allocWithZone:zone];
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
	{
    	IS_MATCHING(@"#else", true, 0, string, maxLength);
        if(_matching != NSNotFound)
        	return 0;
    }
    {
    	IS_MATCHING(@"#elseif", true, '(', string, maxLength);
        if(_matching != NSNotFound)
        	return 0;
    }
    {
    	IS_MATCHING(@"#endif", true, 0, string, maxLength);
        if(_matching != NSNotFound)
        	return _matching;
    }
    
    return NSNotFound;
}

@end

@implementation SourceNodePreprocessorConditionIf

IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_CHARACTER(@"#if", '(');

@end

@implementation SourceNodePreprocessorConditionIfdef

IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_CHARACTER(@"#ifdef", '(');

@end

@implementation SourceNodePreprocessorConditionIfndef

IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_CHARACTER(@"#ifndef", '(');

@end

@implementation SourceNodePreprocessorConditionElse

IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE(@"#else");

@end

@implementation SourceNodePreprocessorConditionElseif

IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_CHARACTER(@"#elseif", '(');

@end

@implementation SourceNodePreprocessorDefine

IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE(@"#define")

@end

@implementation SourceNodePreprocessorUndefine

IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE(@"#undef")

@end

@implementation SourceNodePreprocessorPragma

IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE(@"#pragma")

@end

@implementation SourceNodePreprocessorInclude

IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE(@"#include")

@end

@implementation SourceNodeSemicolon

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return *string == ';' ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
	return 0;
}

@end

@implementation SourceNodeStringSingleQuote

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (*string == '\'') ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
	return (*string == '\'') && !((*(string - 1) == '\\') && (*(string - 2) != '\\')) ? 1 : NSNotFound;
}

@end

@implementation SourceNodeStringDoubleQuote

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (*string == '"') ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
	return (*string == '"') && !((*(string - 1) == '\\') && (*(string - 2) != '\\')) ? 1 : NSNotFound;
}

@end
