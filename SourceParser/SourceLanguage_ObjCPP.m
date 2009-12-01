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

@interface SourceLanguageObjCPP : SourceLanguage
@end

@implementation SourceLanguageObjCPP

+ (NSArray*) languageDependencies {
	return [NSArray arrayWithObjects:@"Base", @"C", @"C++", @"Obj-C", nil];
}

- (NSString*) name {
    return @"Obj-C++";
}

- (NSSet*) fileExtensions {
    return [NSSet setWithObjects:@"h", @"mm", nil]; //FIXME: We assume .h to be in the "superset" language
}

- (SourceNodeRoot*) parseSourceString:(NSString*)source range:(NSRange)range buffer:(const unichar*)buffer syntaxAnalysis:(BOOL)syntaxAnalysis {
    NSLog(@"%@ parsing is not fully implemented", self.name);
    
    return [super parseSourceString:source range:range buffer:buffer syntaxAnalysis:syntaxAnalysis];
}

@end
