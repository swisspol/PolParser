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
        [classes addObject:[SourceNodeColon class]];
        [classes addObject:[SourceNodeSemicolon class]];
        [classes addObject:[SourceNodeQuestionMark class]];
        [classes addObject:[SourceNodeExclamationMark class]];
        [classes addObject:[SourceNodeTilda class]];
        [classes addObject:[SourceNodeCaret class]];
        [classes addObject:[SourceNodeAmpersand class]];
        [classes addObject:[SourceNodeAsterisk class]];
        [classes addObject:[SourceNodeStringSingleQuote class]];
        [classes addObject:[SourceNodeStringDoubleQuote class]];
        [classes addObject:[SourceNodeConditionIf class]];
        [classes addObject:[SourceNodeConditionElse class]];
        [classes addObject:[SourceNodeFlowBreak class]];
        [classes addObject:[SourceNodeFlowContinue class]];
        [classes addObject:[SourceNodeFlowSwitch class]];
        [classes addObject:[SourceNodeFlowCase class]];
        [classes addObject:[SourceNodeFlowDefault class]];
        [classes addObject:[SourceNodeFlowFor class]];
        [classes addObject:[SourceNodeFlowDo class]];
        [classes addObject:[SourceNodeFlowWhile class]];
        [classes addObject:[SourceNodeFlowGoto class]];
        [classes addObject:[SourceNodeFlowReturn class]];
        [classes addObject:[SourceNodeTypedef class]];
        [classes addObject:[SourceNodeTypeStruct class]];
        [classes addObject:[SourceNodeTypeUnion class]];
        [classes addObject:[SourceNodeTypeAuto class]];
        [classes addObject:[SourceNodeTypeStatic class]];
        [classes addObject:[SourceNodeTypeRegister class]];
        [classes addObject:[SourceNodeTypeVolatile class]];
        [classes addObject:[SourceNodeTypeConst class]];
        [classes addObject:[SourceNodeTypeEnum class]];
        [classes addObject:[SourceNodeTypeExtern class]];
        [classes addObject:[SourceNodeTypeSizeOf class]];
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
        [NSException raise:NSInternalInconsistencyException format:@"SourceNodePreprocessor is an abstract class"];
	
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
        [NSException raise:NSInternalInconsistencyException format:@"SourceNodePreprocessorCondition is an abstract class"];
	
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

#define IMPLEMENTATION(__NAME__, ...) \
@implementation SourceNode##__NAME__ \
\
IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_CHARACTER(__VA_ARGS__); \
\
@end

IMPLEMENTATION(PreprocessorConditionIf, @"#if", '(')
IMPLEMENTATION(PreprocessorConditionIfdef, @"#ifdef", '(')
IMPLEMENTATION(PreprocessorConditionIfndef, @"#ifndef", '(')
IMPLEMENTATION(PreprocessorConditionElse, @"#else", 0)
IMPLEMENTATION(PreprocessorConditionElseif, @"#elseif", '(')
IMPLEMENTATION(PreprocessorDefine, @"#define", 0)
IMPLEMENTATION(PreprocessorUndefine, @"#undef", 0)
IMPLEMENTATION(PreprocessorPragma, @"#pragma", 0)
IMPLEMENTATION(PreprocessorInclude, @"#include", 0)

#undef IMPLEMENTATION

#define IMPLEMENTATION(__NAME__, __CHARACTER__) \
@implementation SourceNode##__NAME__ \
\
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    return *string == __CHARACTER__ ? 1 : NSNotFound; \
} \
\
+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
	return 0; \
} \
\
@end

IMPLEMENTATION(Colon, ':')
IMPLEMENTATION(Semicolon, ';')
IMPLEMENTATION(QuestionMark, '?')
IMPLEMENTATION(ExclamationMark, '!')
IMPLEMENTATION(Tilda, '~')
IMPLEMENTATION(Caret, '^')
IMPLEMENTATION(Ampersand, '&')
IMPLEMENTATION(Asterisk, '*')

#undef IMPLEMENTATION

@implementation SourceNodeStringSingleQuote

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (*string == '\'') ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
	return maxLength && (*string == '\'') && !((*(string - 1) == '\\') && (*(string - 2) != '\\')) ? 1 : NSNotFound;
}

@end

@implementation SourceNodeStringDoubleQuote

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (*string == '"') ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
	return maxLength && (*string == '"') && !((*(string - 1) == '\\') && (*(string - 2) != '\\')) ? 1 : NSNotFound;
}

@end

#define IMPLEMENTATION(__NAME__, ...) \
@implementation SourceNode##__NAME__ \
\
IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_CHARACTER(__VA_ARGS__); \
\
+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
	return 0; \
} \
\
@end

IMPLEMENTATION(ConditionIf, @"if", '(')
IMPLEMENTATION(ConditionElse, @"else", '{')
IMPLEMENTATION(FlowBreak, @"break", 0)
IMPLEMENTATION(FlowContinue, @"continue", 0)
IMPLEMENTATION(FlowSwitch, @"switch", '(')
IMPLEMENTATION(FlowCase, @"case", ':')
IMPLEMENTATION(FlowDefault, @"default", ':')
IMPLEMENTATION(FlowFor, @"for", '(')
IMPLEMENTATION(FlowDo, @"do", '{')
IMPLEMENTATION(FlowWhile, @"while", '(')
IMPLEMENTATION(FlowGoto, @"goto", 0)
IMPLEMENTATION(FlowReturn, @"return", '(')
IMPLEMENTATION(Typedef, @"typedef", 0)
IMPLEMENTATION(TypeStruct, @"struct", '{')
IMPLEMENTATION(TypeUnion, @"union", '{')
IMPLEMENTATION(TypeAuto, @"auto", 0)
IMPLEMENTATION(TypeStatic, @"static", 0)
IMPLEMENTATION(TypeRegister, @"register", 0)
IMPLEMENTATION(TypeVolatile, @"volatile", 0)
IMPLEMENTATION(TypeConst, @"const", 0)
IMPLEMENTATION(TypeEnum, @"enum", '{')
IMPLEMENTATION(TypeExtern, @"extern", 0)
IMPLEMENTATION(TypeSizeOf, @"sizeof", '(')

#undef IMPLEMENTATION
