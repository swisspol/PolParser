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
#import "ParserLanguage_SGML.h"

enum {
    kSGMLType_Endless = -2,
    kSGMLType_Empty = -1,
    kSGMLType_Start = 0,
    kSGMLType_End = 1
};

@interface ParserNodeSGMLTag ()
@property(nonatomic, readonly) NSInteger sgmlType;
@property(nonatomic, retain) NSDictionary* attributes;
@end

@interface ParserNodeSGMLValueSingleQuote : ParserNode
@end

@interface ParserNodeSGMLValueDoubleQuote : ParserNode
@end

@implementation ParserLanguageSGML

+ (NSArray*) languageNodeClasses {
    NSMutableArray* classes = [NSMutableArray array];
    
    [classes addObject:[ParserNodeIndenting class]];
    
    [classes addObject:[ParserNodeSGMLDOCTYPE class]];
    [classes addObject:[ParserNodeSGMLComment class]];
    [classes addObject:[ParserNodeSGMLCDATA class]];
    [classes addObject:[ParserNodeSGMLTag class]];
    [classes addObject:[ParserNodeSGMLEntity class]];
    
    [classes addObject:[ParserNodeSGMLElement class]];
    
    return classes;
}

+ (NSString*) stringWithReplacedEntities:(NSString*)string {
    return string;
}

+ (Class) SGMLElementClass {
    return [ParserNodeSGMLElement class];
}

- (NSString*) name {
    return @"SGML";
}

- (NSSet*) fileExtensions {
    return [NSSet setWithObject:@"sgml"];
}

- (ParserNode*) performSyntaxAnalysis:(NSUInteger)passIndex forNode:(ParserNode*)node textBuffer:(const unichar*)textBuffer topLevelLanguage:(ParserLanguage*)topLevelLanguage {
    
    if([node isKindOfClass:[ParserNodeSGMLTag class]]) {
        ParserNodeSGMLTag* sgmlNode = (ParserNodeSGMLTag*)node;
        if(sgmlNode.sgmlType < 0) {
            ParserNode* newNode = [[[[self class] SGMLElementClass] alloc] initWithText:node.text range:NSMakeRange(node.range.location, 0)];
            [node insertPreviousSibling:newNode];
            [newNode release];
            
            _RearrangeNodesAsParentAndChildren(newNode, node);
        } else if(sgmlNode.sgmlType == kSGMLType_Start) {
            ParserNodeSGMLTag* endNode = sgmlNode;
            while(endNode) {
                endNode = (ParserNodeSGMLTag*)[endNode findNextSiblingOfClass:[ParserNodeSGMLTag class]];
                if((endNode.sgmlType == kSGMLType_End) && ([endNode.name caseInsensitiveCompare:sgmlNode.name] == NSOrderedSame)) {
                    break;
                }
            }
            if(endNode) {
                ParserNode* newNode = [[[[self class] SGMLElementClass] alloc] initWithText:node.text range:NSMakeRange(node.range.location, 0)];
                [node insertPreviousSibling:newNode];
                [newNode release];
                
                _RearrangeNodesAsParentAndChildren(newNode, endNode);
            }
        }
        
        if(sgmlNode.sgmlType != kSGMLType_End) {
            NSRange range = NSMakeRange(sgmlNode.range.location + 1 + sgmlNode.name.length, sgmlNode.range.length - 1 - sgmlNode.name.length - (sgmlNode.sgmlType == kSGMLType_Empty ? 2 : 1));
            if(range.length > 0) {
                static NSMutableArray* classes = nil;
                if(classes == nil) {
                    classes = [[NSMutableArray alloc] init];
                    [classes addObject:[ParserNodeWhitespace class]];
                    [classes addObject:[ParserNodeNewline class]];
                    [classes addObject:[ParserNodeEqual class]];
                    [classes addObject:[ParserNodeSGMLValueSingleQuote class]];
                    [classes addObject:[ParserNodeSGMLValueDoubleQuote class]];
                }
                ParserNodeRoot* root = [ParserLanguage newNodeTreeFromText:sgmlNode.text range:range textBuffer:textBuffer withNodeClasses:classes];
                if(root) {
                    ParserNode* attributeNode = [root.firstChild findNextSiblingIgnoringWhitespaceAndNewline];
                    NSMutableDictionary* dictionary = nil;
                    while([attributeNode isKindOfClass:[ParserNodeText class]]) {
                        NSString* name = attributeNode.content;
                        attributeNode = [attributeNode findNextSiblingIgnoringWhitespaceAndNewline];
                        if(attributeNode == nil) {
                            break;
                        }
                        NSString* value;
                        if([attributeNode isKindOfClass:[ParserNodeEqual class]]) {
                            attributeNode = [attributeNode findNextSiblingIgnoringWhitespaceAndNewline];
                            value = attributeNode.cleanContent;
                            attributeNode = [attributeNode findNextSiblingIgnoringWhitespaceAndNewline];
                        } else {
                            value = @""; //FIXME: Is this the best placeholder?
                        }
                        if(dictionary == nil) {
                            dictionary = [[NSMutableDictionary alloc] init];
                        }
                        [dictionary setObject:[[self class] stringWithReplacedEntities:value] forKey:[[self class] stringWithReplacedEntities:name]];
                    }
                    sgmlNode.attributes = dictionary;
                    [dictionary release];
                    [root release];
                }
            }
        }
    }
    
    return node;
}

@end

PREFIX_SUFFIX_CLASS_IMPLEMENTATION(SGMLDOCTYPE, "<!DOCTYPE", ">")
PREFIX_SUFFIX_CLASS_IMPLEMENTATION(SGMLComment, "<!--", "-->")
PREFIX_SUFFIX_CLASS_IMPLEMENTATION(SGMLCDATA, "<![CDATA[", "]]>")

@implementation ParserNodeSGMLDOCTYPE (Internal)

+ (NSSet*) patchedClasses {
    return [NSSet setWithObject:[ParserNodeSGMLTag class]];
}

@end

@implementation ParserNodeSGMLComment (Internal)

+ (NSSet*) patchedClasses {
    return [NSSet setWithObject:[ParserNodeSGMLTag class]];
}

- (NSString*) cleanContent {
    NSRange range = self.range;
    return [ParserLanguageSGML stringWithReplacedEntities:[self.text substringWithRange:NSMakeRange(range.location + 4, range.length - 7)]];
}

@end

@implementation ParserNodeSGMLCDATA (Internal)

+ (NSSet*) patchedClasses {
    return [NSSet setWithObject:[ParserNodeSGMLTag class]];
}

- (NSString*) cleanContent {
    NSRange range = self.range;
    return [self.text substringWithRange:NSMakeRange(range.location + 9, range.length - 12)];
}

@end

@implementation ParserNodeSGMLTag

@synthesize attributes=_attributes;

+ (NSSet*) emptyTags {
  return nil;
}

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    if(*string != '<') {
        return NSNotFound;
    }
    
    NSUInteger length = 0;
    do {
        ++string;
        --maxLength;
        ++length;
    } while(maxLength && !IsWhitespaceOrNewline(*string) && (*string != '>') && !((maxLength > 1) && (*string == '/') && (*(string + 1) == '>')));
    return length;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return *string == '>' ? 1 : ((*string == '/') && (*(string + 1) == '>') ? 2 : NSNotFound);
}

- (void) dealloc {
    [_name release];
    [_attributes release];
    
    [super dealloc];
}

- (void) _analyze {
    NSString* content = self.content;
    
    NSRange range;
    if([content hasSuffix:@"/>"]) {
        _type = kSGMLType_Empty;
        range = NSMakeRange(1, content.length - 3);
    } else if([content hasPrefix:@"</"]) {
        _type = kSGMLType_End;
        range = NSMakeRange(2, content.length - 3);
    } else {
        _type = kSGMLType_Start;
        range = NSMakeRange(1, content.length - 2);
    }
    
    NSRange subrange = [content rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] options:0 range:range];
    if(subrange.location != NSNotFound) {
        _name = [[content substringWithRange:NSMakeRange(range.location, subrange.location - range.location)] retain];
    } else {
        _name = [[content substringWithRange:range] retain];
    }
    
    NSSet* set = [[self class] emptyTags];
    if(set && [set containsObject:[_name lowercaseString]]) {
        _type = kSGMLType_Endless;
    }
}

- (NSInteger) sgmlType {
    if(_name == nil) {
        [self _analyze];
    }
    return _type;
}

- (NSString*) name {
    if(_name == nil) {
        [self _analyze];
    }
    return _name;
}

@end

@implementation ParserNodeSGMLEntity

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return *string == '&' ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return *string == ';' ? 1 : NSNotFound;
}

- (NSString*) cleanContent {
    return [ParserLanguageSGML stringWithReplacedEntities:[self.text substringWithRange:self.range]];
}

@end

@implementation ParserNodeSGMLElement

- (NSString*) cleanContent {
    NSMutableString* string = [NSMutableString string];
    for(ParserNode* node in self.children) {
        if([node isKindOfClass:[ParserNodeSGMLTag class]] || [node isKindOfClass:[ParserNodeSGMLComment class]]|| [node isKindOfClass:[ParserNodeSGMLCDATA class]]) {
            continue;
        }
        [string appendString:node.cleanContent];
    }
    return string;
}

- (NSString*) name {
    return [(ParserNodeSGMLTag*)self.firstChild name];
}

- (NSDictionary*) attributes {
    return [(ParserNodeSGMLTag*)self.firstChild attributes];
}

@end

@implementation ParserNodeSGMLValueSingleQuote

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (*string == '\'') ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return *string == '\'' ? 1 : NSNotFound;
}

- (NSString*) cleanContent {
    NSRange range = self.range;
    return [self.text substringWithRange:NSMakeRange(range.location + 1, range.length - 2)];
}

@end

@implementation ParserNodeSGMLValueDoubleQuote

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (*string == '"') ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return *string == '"' ? 1 : NSNotFound;
}

- (NSString*) cleanContent {
    NSRange range = self.range;
    return [self.text substringWithRange:NSMakeRange(range.location + 1, range.length - 2)];
}

@end
