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
#import "ParserLanguage_CSV.h"

@interface ParserLanguageCSV : ParserLanguage
@end

@implementation ParserLanguageCSV

+ (NSArray*) languageNodeClasses {
    NSMutableArray* classes = [NSMutableArray array];
    
    [classes addObject:[ParserNodeNewline class]];
    
    [classes addObject:[ParserNodeComma class]]; //Must be before ParserNodeCSVField
    [classes addObject:[ParserNodeCSVField class]];
    
    [classes addObject:[ParserNodeCSVRecord class]];
    
    return classes;
}

- (NSString*) name {
    return @"CSV";
}

- (NSSet*) fileExtensions {
    return [NSSet setWithObject:@"csv"];
}

- (ParserNode*) performSyntaxAnalysis:(NSUInteger)passIndex forNode:(ParserNode*)node textBuffer:(const unichar*)textBuffer topLevelLanguage:(ParserLanguage*)topLevelLanguage {
    
    if(![node isKindOfClass:[ParserNodeRoot class]] && ![node.parent isKindOfClass:[ParserNodeCSVRecord class]]) {
        ParserNode* endNode = node;
        while(endNode.nextSibling) {
            if([endNode isKindOfClass:[ParserNodeNewline class]]) {
                break;
            }
            endNode = endNode.nextSibling;
        }
        
        if(endNode != node) {
            ParserNode* newNode = [[ParserNodeCSVRecord alloc] initWithText:node.text range:NSMakeRange(node.range.location, 0)];
            [node insertPreviousSibling:newNode];
            [newNode release];
            
            _RearrangeNodesAsParentAndChildren(newNode, endNode);
        }
    }
    
    return node;
}

@end

@implementation ParserNodeCSVField

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return 0;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    BOOL inQuotes = NO;
    NSUInteger length = 0;
    while(maxLength) {
        if(((*string == ',') || IsNewline(*string)) && !inQuotes) {
            break;
        }
        if(*string == '\"') {
            inQuotes = !inQuotes;
        }
        ++length;
        ++string;
        --maxLength;
    }
    return length;
}

- (NSString*) cleanContent {
    NSMutableString* content = [NSMutableString stringWithString:self.content];
    [content replaceOccurrencesOfString:@"\"\"" withString:@"\"" options:0 range:NSMakeRange(0, content.length)];
    if([content hasPrefix:@"\""]) {
        [content deleteCharactersInRange:NSMakeRange(0, 1)];
    }
    if([content hasSuffix:@"\""]) {
        [content deleteCharactersInRange:NSMakeRange(content.length - 1, 1)];
    }
    return content;
}

@end

@implementation ParserNodeCSVRecord
@end
