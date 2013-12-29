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
#import "ParserLanguage_PropertyList.h"

@interface ParserLanguagePropertyList : ParserLanguage
@end

@implementation ParserLanguagePropertyList

+ (NSArray*) languageDependencies {
    return [NSArray arrayWithObject:@"XML"];
}

+ (NSArray*) languageNodeClasses {
    NSMutableArray* classes = [NSMutableArray array];
    
    [classes addObject:[ParserNodePropertyList class]];
    [classes addObject:[ParserNodePropertyListDictionary class]];
    [classes addObject:[ParserNodePropertyListArray class]];
    [classes addObject:[ParserNodePropertyListKey class]];
    [classes addObject:[ParserNodePropertyListString class]];
    [classes addObject:[ParserNodePropertyListData class]];
    [classes addObject:[ParserNodePropertyListDate class]];
    [classes addObject:[ParserNodePropertyListTrue class]];
    [classes addObject:[ParserNodePropertyListFalse class]];
    [classes addObject:[ParserNodePropertyListReal class]];
    [classes addObject:[ParserNodePropertyListInteger class]];
    
    return classes;
}

- (NSString*) name {
    return @"PropertyList";
}

- (NSSet*) fileExtensions {
    return [NSSet setWithObject:@"plist"];
}

- (ParserNode*) performSyntaxAnalysis:(NSUInteger)passIndex forNode:(ParserNode*)node textBuffer:(const unichar*)textBuffer topLevelLanguage:(ParserLanguage*)topLevelLanguage {
    
    if([node isKindOfClass:[ParserNodeXMLElement class]]) {
        NSString* name = node.name;
        if([name isEqualToString:@"plist"]) {
            return [node replaceWithNodeOfClass:[ParserNodePropertyList class] preserveChildren:YES];
        }
        if([name isEqualToString:@"dict"]) {
            return [node replaceWithNodeOfClass:[ParserNodePropertyListDictionary class] preserveChildren:YES];
        }
        if([name isEqualToString:@"array"]) {
            return [node replaceWithNodeOfClass:[ParserNodePropertyListArray class] preserveChildren:YES];
        }
        if([name isEqualToString:@"key"]) {
            return [node replaceWithNodeOfClass:[ParserNodePropertyListKey class] preserveChildren:YES];
        }
        if([name isEqualToString:@"string"]) {
            return [node replaceWithNodeOfClass:[ParserNodePropertyListString class] preserveChildren:YES];
        }
        if([name isEqualToString:@"data"]) {
            return [node replaceWithNodeOfClass:[ParserNodePropertyListData class] preserveChildren:YES];
        }
        if([name isEqualToString:@"date"]) {
            return [node replaceWithNodeOfClass:[ParserNodePropertyListDate class] preserveChildren:YES];
        }
        if([name isEqualToString:@"true"]) {
            return [node replaceWithNodeOfClass:[ParserNodePropertyListTrue class] preserveChildren:YES];
        }
        if([name isEqualToString:@"false"]) {
            return [node replaceWithNodeOfClass:[ParserNodePropertyListFalse class] preserveChildren:YES];
        }
        if([name isEqualToString:@"real"]) {
            return [node replaceWithNodeOfClass:[ParserNodePropertyListReal class] preserveChildren:YES];
        }
        if([name isEqualToString:@"integer"]) {
            return [node replaceWithNodeOfClass:[ParserNodePropertyListInteger class] preserveChildren:YES];
        }
    }
    
    return node;
}

@end

@implementation ParserNodePropertyList
@end

@implementation ParserNodePropertyListDictionary
@end

@implementation ParserNodePropertyListArray
@end

@implementation ParserNodePropertyListKey
@end

@implementation ParserNodePropertyListString
@end

@implementation ParserNodePropertyListData
@end

@implementation ParserNodePropertyListDate
@end

@implementation ParserNodePropertyListTrue
@end

@implementation ParserNodePropertyListFalse
@end

@implementation ParserNodePropertyListReal
@end

@implementation ParserNodePropertyListInteger
@end
