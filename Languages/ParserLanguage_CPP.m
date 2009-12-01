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

#import "Parser_Internal.h"

@interface ParserLanguageCPP : ParserLanguage
@end

@implementation ParserLanguageCPP

+ (NSArray*) languageDependencies {
	return [NSArray arrayWithObjects:@"Base", @"C", nil];
}

+ (NSSet*) languageReservedKeywords {
	return [NSSet setWithObjects:@"this", nil]; //Not "true" keywords
}

+ (NSArray*) languageNodeClasses {
	NSMutableArray* classes = [NSMutableArray arrayWithArray:[super languageNodeClasses]];
    
    [classes addObject:[ParserNodeDoubleSemicolon class]];
    
    [classes addObject:[ParserNodeCPPComment class]];
    
    return classes;
}

- (NSString*) name {
    return @"C++";
}

- (NSSet*) fileExtensions {
    return [NSSet setWithObjects:@"cc", @"cp", @"cpp", nil];
}

- (ParserNodeRoot*) parseText:(NSString*)text range:(NSRange)range textBuffer:(const unichar*)textBuffer syntaxAnalysis:(BOOL)syntaxAnalysis {
    NSLog(@"%@ parsing is not fully implemented", self.name);
    
    return [super parseText:text range:range textBuffer:textBuffer syntaxAnalysis:syntaxAnalysis];
}

@end

@implementation ParserNodeCPPComment

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (string[0] == '/') && (string[1] == '/') ? 2 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    while(maxLength) {
        if(IsNewline(*string)) {
            do {
                --string;
            } while(IsWhitespace(*string));
            if(*string != '\\')
                return 0;
        }
        if(!IsWhitespace(*string))
            break;
        ++string;
        --maxLength;
    }
    
    return NSNotFound;
}

@end

TOKEN_CLASS_IMPLEMENTATION(DoubleSemicolon, "::")

@implementation ParserNodeDoubleSemicolon (Patch)

+ (NSArray*) patchedClasses {
	return [NSArray arrayWithObject:[ParserNodeColon class]];
}

@end

KEYWORD_CLASS_IMPLEMENTATION(CPP, This, "this")
