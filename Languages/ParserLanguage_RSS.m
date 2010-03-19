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
#import "ParserLanguage_RSS.h"

@interface ParserLanguageRSS : ParserLanguage
@end

@implementation ParserLanguageRSS

+ (NSArray*) languageDependencies {
    return [NSArray arrayWithObject:@"XML"];
}

+ (NSArray*) languageNodeClasses {
    NSMutableArray* classes = [NSMutableArray array];
    
    [classes addObject:[ParserNodeRSSChannel class]];
    [classes addObject:[ParserNodeRSSItem class]];
    [classes addObject:[ParserNodeRSSCategory class]];
    [classes addObject:[ParserNodeRSSTitle class]];
    [classes addObject:[ParserNodeRSSLink class]];
    [classes addObject:[ParserNodeRSSDescription class]];
    [classes addObject:[ParserNodeRSSLanguage class]];
    [classes addObject:[ParserNodeRSSAuthor class]];
    [classes addObject:[ParserNodeRSSEnclosure class]];
    [classes addObject:[ParserNodeRSSGuid class]];
    [classes addObject:[ParserNodeAtomFeed class]];
    [classes addObject:[ParserNodeAtomEntry class]];
    [classes addObject:[ParserNodeAtomSubtitle class]];
    [classes addObject:[ParserNodeAtomID class]];
    [classes addObject:[ParserNodeAtomSummary class]];
    [classes addObject:[ParserNodeAtomName class]];
    [classes addObject:[ParserNodeAtomEmail class]];
    
    return classes;
}

- (NSString*) name {
    return @"RSS";
}

- (NSSet*) fileExtensions {
    return [NSSet setWithObjects:@"rss", @"atom", nil];
}

- (ParserNode*) performSyntaxAnalysis:(NSUInteger)passIndex forNode:(ParserNode*)node textBuffer:(const unichar*)textBuffer topLevelLanguage:(ParserLanguage*)topLevelLanguage {
    
    if([node isKindOfClass:[ParserNodeXMLElement class]]) {
        NSString* name = [node.name lowercaseString];
        if([name isEqualToString:@"channel"]) {
            return [node replaceWithNodeOfClass:[ParserNodeRSSChannel class] preserveChildren:YES];
        }
        if([name isEqualToString:@"item"]) {
            return [node replaceWithNodeOfClass:[ParserNodeRSSItem class] preserveChildren:YES];
        }
        if([name isEqualToString:@"category"]) {
            return [node replaceWithNodeOfClass:[ParserNodeRSSCategory class] preserveChildren:YES];
        }
        if([name isEqualToString:@"title"]) {
            return [node replaceWithNodeOfClass:[ParserNodeRSSTitle class] preserveChildren:YES];
        }
        if([name isEqualToString:@"link"]) {
            return [node replaceWithNodeOfClass:[ParserNodeRSSLink class] preserveChildren:YES];
        }
        if([name isEqualToString:@"description"]) {
            return [node replaceWithNodeOfClass:[ParserNodeRSSDescription class] preserveChildren:YES];
        }
        if([name isEqualToString:@"language"]) {
            return [node replaceWithNodeOfClass:[ParserNodeRSSLanguage class] preserveChildren:YES];
        }
        if([name isEqualToString:@"author"]) {
            return [node replaceWithNodeOfClass:[ParserNodeRSSAuthor class] preserveChildren:YES];
        }
        if([name isEqualToString:@"enclosure"]) {
            return [node replaceWithNodeOfClass:[ParserNodeRSSEnclosure class] preserveChildren:YES];
        }
        if([name isEqualToString:@"guid"]) {
            return [node replaceWithNodeOfClass:[ParserNodeRSSGuid class] preserveChildren:YES];
        }
        if([name isEqualToString:@"feed"]) {
            return [node replaceWithNodeOfClass:[ParserNodeAtomFeed class] preserveChildren:YES];
        }
        if([name isEqualToString:@"entry"]) {
            return [node replaceWithNodeOfClass:[ParserNodeAtomEntry class] preserveChildren:YES];
        }
        if([name isEqualToString:@"subtitle"]) {
            return [node replaceWithNodeOfClass:[ParserNodeAtomSubtitle class] preserveChildren:YES];
        }
        if([name isEqualToString:@"id"]) {
            return [node replaceWithNodeOfClass:[ParserNodeAtomID class] preserveChildren:YES];
        }
        if([name isEqualToString:@"summary"]) {
            return [node replaceWithNodeOfClass:[ParserNodeAtomSummary class] preserveChildren:YES];
        }
        if([name isEqualToString:@"name"]) {
            return [node replaceWithNodeOfClass:[ParserNodeAtomName class] preserveChildren:YES];
        }
        if([name isEqualToString:@"email"]) {
            return [node replaceWithNodeOfClass:[ParserNodeAtomEmail class] preserveChildren:YES];
        }
    }
    
    return node;
}

@end

@implementation ParserNodeRSSChannel
@end

@implementation ParserNodeRSSItem
@end

@implementation ParserNodeRSSCategory
@end

@implementation ParserNodeRSSTitle
@end

@implementation ParserNodeRSSLink
@end

@implementation ParserNodeRSSDescription
@end

@implementation ParserNodeRSSLanguage
@end

@implementation ParserNodeRSSAuthor
@end

@implementation ParserNodeRSSEnclosure
@end

@implementation ParserNodeRSSGuid
@end

@implementation ParserNodeAtomFeed
@end

@implementation ParserNodeAtomEntry
@end

@implementation ParserNodeAtomSubtitle
@end

@implementation ParserNodeAtomID
@end

@implementation ParserNodeAtomSummary
@end

@implementation ParserNodeAtomName
@end

@implementation ParserNodeAtomEmail
@end
