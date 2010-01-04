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
#import "ParserLanguage_CSS.h"

@interface ParserLanguageCSS : ParserLanguage
@end

@interface ParserNodeCSSEscapedCharacter : ParserNode
@end

@implementation ParserLanguageCSS

+ (NSArray*) languageNodeClasses {
    NSMutableArray* classes = [NSMutableArray array];
    
    [classes addObject:[ParserNodeNewline class]];
    [classes addObject:[ParserNodeIndenting class]];
    [classes addObject:[ParserNodeWhitespace class]];
    [classes addObject:[ParserNodeBraces class]];
    [classes addObject:[ParserNodeParenthesis class]];
    [classes addObject:[ParserNodeBrackets class]];
    [classes addObject:[ParserNodeComma class]];
    [classes addObject:[ParserNodeColon class]];
    [classes addObject:[ParserNodeSemicolon class]];
    
    [classes addObject:[ParserNodeCSSString class]];
    [classes addObject:[ParserNodeCSSComment class]];
    [classes addObject:[ParserNodeCSSAtRule class]];
    
    [classes addObject:[ParserNodeCSSRule class]];
    [classes addObject:[ParserNodeCSSSelector class]];
    [classes addObject:[ParserNodeCSSPropertyName class]];
    [classes addObject:[ParserNodeCSSPropertyValue class]];
    
    return classes;
}

- (NSString*) name {
    return @"CSS";
}

- (NSSet*) fileExtensions {
    return [NSSet setWithObject:@"css"];
}

- (ParserNode*) performSyntaxAnalysisForNode:(ParserNode*)node textBuffer:(const unichar*)textBuffer topLevelLanguage:(ParserLanguage*)topLevelLanguage {
    
    if([node isMemberOfClass:[ParserNodeText class]] && ![node.parent isKindOfClass:[ParserNodeCSSAtRule class]] && ![node.parent isKindOfClass:[ParserNodeCSSPropertyValue class]]) {
        if(![node.parent isKindOfClass:[ParserNodeCSSRule class]]) {
            ParserNode* endNode = [node findNextSiblingOfClass:[ParserNodeBraces class]];
            if(endNode) {
                ParserNode* newNode = [[ParserNodeCSSRule alloc] initWithText:node.text range:NSMakeRange(node.range.location, 0)];
                [node insertPreviousSibling:newNode];
                [newNode release];
                
                _RearrangeNodesAsChildren(newNode, endNode);
            }
        }
        
        if(![node.parent isKindOfClass:[ParserNodeCSSSelector class]] && ![node.parent isKindOfClass:[ParserNodeBraces class]]) {
            static NSSet* set = nil;
            if(set == nil)
                set = [[NSSet alloc] initWithObjects:[ParserNodeWhitespace class], [ParserNodeNewline class], [ParserNodeComma class], [ParserNodeBraces class], nil];
            ParserNode* nextNode = [[node findNextSiblingOfAnyClass:set] previousSibling];
            if(nextNode) {
                ParserNode* newNode = [[ParserNodeCSSSelector alloc] initWithText:node.text range:NSMakeRange(node.range.location, nextNode.range.location + nextNode.range.length - node.range.location)];
                newNode.lines = NSMakeRange(node.lines.location, nextNode.lines.location + nextNode.lines.length - node.lines.location);
                [node insertPreviousSibling:newNode];
                [newNode release];
                while(1) {
                    ParserNode* siblingNode = node.nextSibling;
                    [node removeFromParent];
                    if(node == nextNode)
                        break;
                    node = siblingNode;
                }
            }
        }
    } else if([node isKindOfClass:[ParserNodeColon class]] && [node.parent isKindOfClass:[ParserNodeBraces class]]) {
        ParserNode* name = [node findPreviousSiblingIgnoringWhitespaceAndNewline];
        ParserNode* startNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
        ParserNode* endNode = [node findNextSiblingOfClass:[ParserNodeSemicolon class]];
        endNode = [(endNode ? endNode : node.parent.lastChild) findPreviousSiblingIgnoringWhitespaceAndNewline];
        if([name isKindOfClass:[ParserNodeText class]] && startNode) {
            [name replaceWithNodeOfClass:[ParserNodeCSSPropertyName class] preserveChildren:NO];
            
            ParserNode* newNode = [[ParserNodeCSSPropertyValue alloc] initWithText:startNode.text range:NSMakeRange(startNode.range.location, 0)];
            [startNode insertPreviousSibling:newNode];
            [newNode release];
            
            _RearrangeNodesAsChildren(newNode, endNode);
        }
    }
    
    return node;
}

@end

@implementation ParserNodeCSSString

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    if((*string == '"') || (*string == '\'')) {
        unichar character = *string;
        NSUInteger length = 1;
        ++string;
        --maxLength;
        while(maxLength) {
            ++length;
            if((*string == character) && !((*(string - 1) == '\\') && (*(string - 2) != '\\')))
                return length;
            ++string;
            --maxLength;
        }
    }
    return NSNotFound;
}

- (NSString*) cleanContent {
    static NSMutableArray* classes = nil;
    if(classes == nil) {
        classes = [[NSMutableArray alloc] init];
        [classes addObject:[ParserNodeCSSEscapedCharacter class]];
    }
    NSRange range = self.range;
    return _CleanString([self.text substringWithRange:NSMakeRange(range.location + 1, range.length - 2)], classes);
}

@end

@implementation ParserNodeCSSComment

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (string[0] == '/') && (string[1] == '*') ? 2 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (string[0] == '*') && (string[1] == '/') ? 2 : NSNotFound;
}

- (NSString*) cleanContent {
    NSRange range = self.range;
    return [self.text substringWithRange:NSMakeRange(range.location + 2, range.length - 4)];
}

@end

@implementation ParserNodeCSSAtRule

+ (BOOL) isAtomic {
    return NO;
}

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    if(*string == '@') {
        NSUInteger length = 1;
        ++string;
        --maxLength;
        while(maxLength) {
            if(IsWhitespaceOrNewline(*string))
                return length;
            ++length;
            ++string;
            --maxLength;
        }
    }
    return NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (*(string - 1) == '}') || (*string == ';') ? 0 : NSNotFound;
}

- (void) dealloc {
    [_name release];
    
    [super dealloc];
}

- (NSString*) name {
    if(_name == nil)
        _name = [[self.firstChild.content substringFromIndex:1] copy];
    return _name;
}

@end

@implementation ParserNodeCSSRule
@end

@implementation ParserNodeCSSSelector
@end

@implementation ParserNodeCSSPropertyName
@end

@implementation ParserNodeCSSPropertyValue
@end

@implementation ParserNodeCSSEscapedCharacter

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    if((maxLength >= 2) && (*string == '\\')) {
        ++string;
        --maxLength;
        switch(*string) {
            
            case '\r':
            return *(string + 1) == '\n' ? 3 : 2;
            
            case '\n':
            case '\\':
            case '\'':
            case '"':
            case ';':
            return 2;
            
            default: {
                NSUInteger length = 1;
                while(maxLength) {
                    if(IsWhitespaceOrNewline(*string) || (length == 7))
                        return length;
                    ++length;
                    ++string;
                    --maxLength;
                }
            }
            
        }
    }
    return NSNotFound;
}

- (NSString*) cleanContent {
    NSString* content = self.content;
    switch([content characterAtIndex:1]) {
        case '\n': case '\r': content = @""; break;
        case '\\': content = @"\\"; break;
        case '\'': content = @"'"; break;
        case '"': content = @"\""; break;
        case ';': content = @";"; break;
        default: content = _StringFromHexUnicodeCharacter([content substringFromIndex:1]); 
    }
    return content;
}

@end
