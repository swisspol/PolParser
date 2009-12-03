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

@interface ParserNodeSGMLTag ()
@property(nonatomic, readonly) NSInteger sgmlType;
@property(nonatomic, retain) NSDictionary* attributes;
@end

@interface ParserNodeSGMLEqual : ParserNodeToken
@end

@interface ParserNodeSGMLValueSingleQuote : ParserNode
@end

@interface ParserNodeSGMLValueDoubleQuote : ParserNode
@end

@implementation ParserLanguageSGML

+ (NSArray*) languageDependencies {
	return [NSArray arrayWithObject:@"Base"];
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

- (ParserNode*) performSyntaxAnalysisForNode:(ParserNode*)node textBuffer:(const unichar*)textBuffer topLevelNodeClasses:(NSSet*)nodeClasses {
	
    if([node isKindOfClass:[ParserNodeSGMLTag class]]) {
    	ParserNodeSGMLTag* sgmlNode = (ParserNodeSGMLTag*)node;
        if(sgmlNode.sgmlType == 0) {
        	ParserNode* newNode = [[[[self class] SGMLElementClass] alloc] initWithText:node.text range:NSMakeRange(node.range.location, 0)];
            [node insertPreviousSibling:newNode];
            [newNode release];
            
            _RearrangeNodesAsChildren(newNode, node);
        } else if(sgmlNode.sgmlType < 0) {
        	ParserNode* endNode = node;
            while(endNode) {
                endNode = [endNode findNextSiblingOfClass:[ParserNodeSGMLTag class]];
                if([endNode.name isEqualToString:sgmlNode.name])
                	break;
            }
            if(endNode) {
            	ParserNode* newNode = [[[[self class] SGMLElementClass] alloc] initWithText:node.text range:NSMakeRange(node.range.location, 0)];
                [node insertPreviousSibling:newNode];
                [newNode release];
                
                _RearrangeNodesAsChildren(newNode, endNode);
            }
        }
        
        if(sgmlNode.sgmlType <= 0) {
        	NSRange range = NSMakeRange(sgmlNode.range.location + 1 + sgmlNode.name.length, sgmlNode.range.length - sgmlNode.name.length - (sgmlNode.sgmlType ? 2 : 3));
            if(range.length > 0) {
            	static NSMutableArray* classes = nil;
                if(classes == nil) {
                    classes = [[NSMutableArray alloc] init];
                    [classes addObject:NSClassFromString(@"ParserNodeWhitespace")];
                    [classes addObject:NSClassFromString(@"ParserNodeNewline")];
                    [classes addObject:[ParserNodeSGMLValueSingleQuote class]];
                    [classes addObject:[ParserNodeSGMLValueDoubleQuote class]];
                    [classes addObject:[ParserNodeSGMLEqual class]];
                }
                ParserNodeRoot* root = [ParserLanguage newNodeTreeFromText:sgmlNode.text range:range textBuffer:textBuffer withNodeClasses:classes];
                if(root) {
                    ParserNode* attributeNode = [root.firstChild findNextSiblingIgnoringWhitespaceAndNewline];
                    NSMutableDictionary* dictionary = nil;
                    while([attributeNode isKindOfClass:[ParserNodeText class]]) {
                        NSString* name = attributeNode.content;
                        attributeNode = [attributeNode findNextSiblingIgnoringWhitespaceAndNewline];
                        if(attributeNode == nil)
                        	break;
                        NSString* value;
                        if([attributeNode isKindOfClass:[ParserNodeSGMLEqual class]]) {
                        	attributeNode = [attributeNode findNextSiblingIgnoringWhitespaceAndNewline];
                            value = attributeNode.cleanContent;
                            attributeNode = [attributeNode findNextSiblingIgnoringWhitespaceAndNewline];
                        } else {
                            value = @""; //FIXME: Is this the best placeholder?
                        }
						if(dictionary == nil)
                        	dictionary = [[NSMutableDictionary alloc] init];
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

SGML_CLASS_IMPLEMENTATION(SGMLDOCTYPE, "<!DOCTYPE", ">")
SGML_CLASS_IMPLEMENTATION(SGMLComment, "<!--", "-->")
SGML_CLASS_IMPLEMENTATION(SGMLCDATA, "<![CDATA[", "]]>")

@implementation ParserNodeSGMLComment (Internal)

- (NSString*) cleanContent {
	NSRange range = self.range;
    return [ParserLanguageSGML stringWithReplacedEntities:[self.text substringWithRange:NSMakeRange(range.location + 4, range.length - 7)]];
}

@end

@implementation ParserNodeSGMLCDATA (Internal)

- (NSString*) cleanContent {
	NSRange range = self.range;
    return [self.text substringWithRange:NSMakeRange(range.location + 9, range.length - 12)];
}

@end

@implementation ParserNodeSGMLTag

@synthesize attributes=_attributes;

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    if(*string != '<')
    	return NSNotFound;
    
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
    
    if([content hasSuffix:@"/>"]) {
        _type = 0;
        content = [content substringWithRange:NSMakeRange(1, content.length - 3)];
    }
    else if([content hasPrefix:@"</"]) {
    	_type = 1;
        content = [content substringWithRange:NSMakeRange(2, content.length - 3)];
    }
    else {
    	_type = -1;
        content = [content substringWithRange:NSMakeRange(1, content.length - 2)];
    }
    
    NSRange range = [content rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] options:0 range:NSMakeRange(0, content.length)];
    if(range.location != NSNotFound)
        _name = [[content substringWithRange:NSMakeRange(0, range.location)] retain];
    else
        _name = [content retain];
}

- (NSInteger) sgmlType {
	if(_name == nil)
    	[self _analyze];
    return _type;
}

- (NSString*) name {
	if(_name == nil)
    	[self _analyze];
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
    	if([node isKindOfClass:[ParserNodeSGMLTag class]] || [node isKindOfClass:[ParserNodeSGMLElement class]]
        	|| [node isKindOfClass:[ParserNodeSGMLComment class]]|| [node isKindOfClass:[ParserNodeSGMLCDATA class]])
        	continue;
        [string appendString:node.cleanContent];
    }
    return string;
}

- (NSString*) name {
	return [(ParserNodeSGMLTag*)self.firstChild name];
}

/*
- (NSDictionary*) attributes {
	return [(ParserNodeSGMLTag*)self.firstChild attributes];
}
*/

@end

TOKEN_CLASS_IMPLEMENTATION(SGMLEqual, "=")

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
