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

@implementation SourceNodeWhitespace

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return IsWhiteSpaceOrNewline(*string) ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
	if(IsWhiteSpace(*string) && IsNewline(*(string - 1)))
    	return 0;
    
    return !IsWhiteSpaceOrNewline(*string) ? 0 : NSNotFound;
}

@end

@implementation SourceNodeIndenting

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return IsWhiteSpace(*string) && IsNewline(*(string - 1)) ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
	return !IsWhiteSpace(*string) ? 0 : NSNotFound;
}

@end

@implementation SourceNodeBraces

+ (BOOL) isLeaf {
	return NO;
}

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return *string == '{' ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
	return *string == '}' ? 1 : NSNotFound;
}

@end

@implementation SourceNodeParenthesis

+ (BOOL) isLeaf {
	return NO;
}

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return *string == '(' ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
	return *string == ')' ? 1 : NSNotFound;
}

@end

@implementation SourceNodeBrackets

+ (BOOL) isLeaf {
	return NO;
}

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return *string == '[' ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
	return *string == ']' ? 1 : NSNotFound;
}

@end
