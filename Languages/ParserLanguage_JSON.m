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
#import "ParserLanguage_JSON.h"

@interface ParserLanguageJSON : ParserLanguage
@end

@implementation ParserLanguageJSON

+ (NSSet*) languageReservedKeywords {
    return [NSSet setWithObjects:@"true", @"false", @"null", nil];
}

+ (NSArray*) languageNodeClasses {
    NSMutableArray* classes = [NSMutableArray array];
    
    [classes addObject:[ParserNodeNewline class]];
    [classes addObject:[ParserNodeIndenting class]];
    [classes addObject:[ParserNodeWhitespace class]];
    [classes addObject:[ParserNodeBraces class]];
    [classes addObject:[ParserNodeParenthesis class]];
    [classes addObject:[ParserNodeBrackets class]];
    [classes addObject:[ParserNodeColon class]];
    [classes addObject:[ParserNodeComma class]];
    
    [classes addObject:[ParserNodeJSONString class]];
    
    [classes addObject:[ParserNodeJSONNumber class]];
    [classes addObject:[ParserNodeJSONArray class]];
    [classes addObject:[ParserNodeJSONObject class]];
    [classes addObject:[ParserNodeJSONPair class]];
    
    return classes;
}

- (NSString*) name {
    return @"JSON";
}

- (NSSet*) fileExtensions {
    return [NSSet setWithObject:@"json"];
}

- (ParserNode*) performSyntaxAnalysisForNode:(ParserNode*)node textBuffer:(const unichar*)textBuffer topLevelLanguage:(ParserLanguage*)topLevelLanguage {
    
    if([node isMemberOfClass:[ParserNodeText class]])
        return [node replaceWithNodeOfClass:[ParserNodeJSONNumber class] preserveChildren:NO];
    if([node isKindOfClass:[ParserNodeBraces class]])
        return [node replaceWithNodeOfClass:[ParserNodeJSONObject class] preserveChildren:YES];
    if([node isKindOfClass:[ParserNodeBrackets class]])
        return [node replaceWithNodeOfClass:[ParserNodeJSONArray class] preserveChildren:YES];
    
    if([node.parent isKindOfClass:[ParserNodeJSONObject class]]) {
        if([node isKindOfClass:[ParserNodeJSONString class]]) {
            ParserNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
            if([nextNode isKindOfClass:[ParserNodeColon class]]) {
                nextNode = [nextNode findNextSiblingIgnoringWhitespaceAndNewline];
                if(nextNode) {
                    ParserNode* newNode = [[ParserNodeJSONPair alloc] initWithText:node.text range:NSMakeRange(node.range.location, 0)];
                    [node insertPreviousSibling:newNode];
                    [newNode release];
                    _RearrangeNodesAsChildren(newNode, nextNode);
                }
            }
        }
    }
    
    return node;
}

@end

@implementation ParserNodeJSONString

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (*string == '"') ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (*string == '"') && !((*(string - 1) == '\\') && (*(string - 2) != '\\')) ? 1 : NSNotFound;
}

- (NSString*) cleanContent {
    NSRange range = self.range;
    return _CleanEscapedString([self.text substringWithRange:NSMakeRange(range.location + 1, range.length - 2)]);
}

@end

@implementation ParserNodeJSONNumber
@end

@implementation ParserNodeJSONArray
@end

@implementation ParserNodeJSONObject
@end

@implementation ParserNodeJSONPair

- (NSString*) name {
    return self.firstChild.cleanContent;
}

@end

KEYWORD_CLASS_IMPLEMENTATION(JSON, True, "true")
KEYWORD_CLASS_IMPLEMENTATION(JSON, False, "false")
KEYWORD_CLASS_IMPLEMENTATION(JSON, Null, "null")
