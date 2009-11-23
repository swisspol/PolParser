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

@implementation SourceLanguageObjC

- (NSString*) name {
	return @"Obj-C";
}

- (NSSet*) fileExtensions {
	return [NSSet setWithObject:@"m"];
}

- (NSArray*) nodeClasses {
	static NSMutableArray* classes = nil;
    if(classes == nil) {
        classes = [[NSMutableArray alloc] init];
        [classes addObjectsFromArray:[super nodeClasses]];
        
        [classes addObject:[SourceNodeCommentCPP class]];
        
        [classes insertObject:[SourceNodeObjCString class] atIndex:[classes indexOfObject:[SourceNodeStringSingleQuote class]]]; //Must be before single and double quote strings
        
        [classes addObject:[SourceNodePreprocessorImport class]];
        [classes addObject:[SourceNodeObjCInterface class]];
        [classes addObject:[SourceNodeObjCImplementation class]];
        [classes addObject:[SourceNodeObjCProtocol class]];
        [classes addObject:[SourceNodeObjCPublic class]];
        [classes addObject:[SourceNodeObjCProtected class]];
        [classes addObject:[SourceNodeObjCPrivate class]];
        [classes addObject:[SourceNodeObjCProperty class]];
        [classes addObject:[SourceNodeObjCTry class]];
        [classes addObject:[SourceNodeObjCCatch class]];
        [classes addObject:[SourceNodeObjCFinally class]];
        [classes addObject:[SourceNodeObjCThrow class]];
        [classes addObject:[SourceNodeObjCSynchronized class]];
        
    }
    return classes;
}

@end

@implementation SourceLanguageObjCPP

- (NSString*) name {
	return @"Obj-C++";
}

- (NSSet*) fileExtensions {
	return [NSSet setWithObject:@"mm"];
}

@end

@implementation SourceNodePreprocessorImport

IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE(@"#import")

@end

@implementation SourceNodeObjCString

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (maxLength >= 2) && (string[0] == '@') && (string[1] == '"') ? 2 : NSNotFound;
}

@end

@implementation SourceNodeObjCInterface

+ (BOOL) isLeaf {
	return NO;
}

IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE(@"@interface")

IS_MATCHING_SUFFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE(@"@end")

@end

@implementation SourceNodeObjCImplementation

IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE(@"@implementation")

@end

@implementation SourceNodeObjCProtocol

IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE(@"@protocol")

@end

#define IMPLEMENTATION(__NAME__, ...) \
@implementation SourceNodeObjC##__NAME__ \
\
IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_WHITESPACE_OR_NEWLINE_OR_CHARACTER(__VA_ARGS__); \
\
+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
	return 0; \
} \
\
@end

IMPLEMENTATION(Public, @"@public", 0)
IMPLEMENTATION(Protected, @"@protected", 0)
IMPLEMENTATION(Private, @"@private", 0)
IMPLEMENTATION(Try, @"@try", '{')
IMPLEMENTATION(Catch, @"@catch", '(')
IMPLEMENTATION(Finally, @"@finally", '{')
IMPLEMENTATION(Throw, @"@throw", 0)
IMPLEMENTATION(Synchronized, @"@synchronized", '(')
IMPLEMENTATION(Property, @"@property", '(')

#undef IMPLEMENTATION
