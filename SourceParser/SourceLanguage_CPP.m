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

@implementation SourceLanguageCPP

- (NSString*) name {
	return @"C++";
}

- (NSSet*) fileExtensions {
	return [NSSet setWithObjects:@"cc", @"cp", @"cpp", nil];
}

- (NSArray*) nodeClasses {
	static NSMutableArray* classes = nil;
    if(classes == nil) {
        classes = [[NSMutableArray alloc] init];
        [classes addObjectsFromArray:[super nodeClasses]];
        
        [classes addObject:[SourceNodeCommentCPP class]];
    }
    return classes;
}

@end

@implementation SourceNodeCommentCPP

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (maxLength >= 2) && (string[0] == '/') && (string[1] == '/') ? 2 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    while(maxLength) {
        if(IsNewline(*string)) {
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

