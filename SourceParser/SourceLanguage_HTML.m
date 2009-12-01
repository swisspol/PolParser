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

#warning SGML (abstract)
#warning Create Language directory
#warning Rename TextParser & Language
#warning MiniParser

@interface SourceNodeHTMLEqual : SourceNodeToken
@end

@interface SourceLanguageHTML : SourceLanguage
@end

@interface SourceNodeHTMLTag ()
@property(nonatomic, readonly) NSInteger htmlType;
@property(nonatomic, retain) NSDictionary* attributes;
@end

@implementation SourceLanguageHTML

+ (NSArray*) languageDependencies {
	return [NSArray arrayWithObject:@"Base"];
}

+ (NSArray*) languageNodeClasses {
	NSMutableArray* classes = [NSMutableArray arrayWithArray:[super languageNodeClasses]];
    
    [classes addObject:[SourceNodeHTMLDOCTYPE class]]; //Must be before SourceNodeHTMLTag
    [classes addObject:[SourceNodeHTMLComment class]]; //Must be before SourceNodeHTMLTag
    [classes addObject:[SourceNodeHTMLCDATA class]]; //Must be before SourceNodeXMLTag
    [classes addObject:[SourceNodeHTMLTag class]];
    
    [classes addObject:[SourceNodeHTMLElement class]];
    
    return classes;
}

- (NSString*) name {
    return @"HTML";
}

- (NSSet*) fileExtensions {
    return [NSSet setWithObjects:@"htm", @"html", nil];
}

static NSString* _StringWithReplacedEntities(NSString* string) {
#warning FIXME
	NSMutableString* newString = [NSMutableString stringWithString:string];
    [newString replaceOccurrencesOfString:@"&lt;" withString:@"<" options:0 range:NSMakeRange(0, newString.length)];
    [newString replaceOccurrencesOfString:@"&gt;" withString:@">" options:0 range:NSMakeRange(0, newString.length)];
    [newString replaceOccurrencesOfString:@"&amp;" withString:@"&" options:0 range:NSMakeRange(0, newString.length)];
    [newString replaceOccurrencesOfString:@"&apos;" withString:@"'" options:0 range:NSMakeRange(0, newString.length)];
    [newString replaceOccurrencesOfString:@"&quot;" withString:@"\"" options:0 range:NSMakeRange(0, newString.length)];
    return newString;
}

- (SourceNode*) performSyntaxAnalysisForNode:(SourceNode*)node sourceBuffer:(const unichar*)sourceBuffer topLevelNodeClasses:(NSSet*)nodeClasses {
	
    if([node isKindOfClass:[SourceNodeHTMLTag class]]) {
    	SourceNodeHTMLTag* htmlNode = (SourceNodeHTMLTag*)node;
        if(htmlNode.htmlType == 0) {
        	SourceNode* newNode = [[SourceNodeHTMLElement alloc] initWithSource:node.source range:NSMakeRange(node.range.location, 0)];
            [node insertPreviousSibling:newNode];
            [newNode release];
            
            _RearrangeNodesAsChildren(newNode, node);
        } else if(htmlNode.htmlType < 0) {
        	SourceNode* endNode = node;
            while(endNode) {
                endNode = [endNode findNextSiblingOfClass:[SourceNodeHTMLTag class]];
                if([endNode.name isEqualToString:htmlNode.name])
                	break;
            }
            if(endNode) {
            	SourceNode* newNode = [[SourceNodeHTMLElement alloc] initWithSource:node.source range:NSMakeRange(node.range.location, 0)];
                [node insertPreviousSibling:newNode];
                [newNode release];
                
                _RearrangeNodesAsChildren(newNode, endNode);
            }
        }
        
        if(htmlNode.htmlType <= 0) {
        	NSRange range = NSMakeRange(htmlNode.range.location + 1 + htmlNode.name.length, htmlNode.range.length - htmlNode.name.length - (htmlNode.htmlType ? 2 : 3));
            if(range.length > 0) {
            	static NSMutableArray* classes = nil;
                if(classes == nil) {
                    classes = [[NSMutableArray alloc] init];
                    [classes addObjectsFromArray:[NSClassFromString(@"SourceLanguageBase") languageNodeClasses]];
                    [classes addObject:NSClassFromString(@"SourceNodeCStringSingleQuote")];
                    [classes addObject:NSClassFromString(@"SourceNodeCStringDoubleQuote")];
                    [classes addObject:[SourceNodeHTMLEqual class]];
                }
                SourceNodeRoot* root = [SourceLanguage newNodeTreeFromSource:htmlNode.source range:range buffer:sourceBuffer withNodeClasses:classes];
                if(root) {
                    SourceNode* attributeNode = [root.firstChild findNextSiblingIgnoringWhitespaceAndNewline];
                    NSMutableDictionary* dictionary = nil;
                    while([attributeNode isKindOfClass:[SourceNodeText class]]) {
                        NSString* name = attributeNode.content;
                        attributeNode = [attributeNode findNextSiblingIgnoringWhitespaceAndNewline];
                        if(attributeNode == nil)
                        	break;
                        NSString* value;
                        if([attributeNode isKindOfClass:[SourceNodeHTMLEqual class]]) {
                        	attributeNode = [attributeNode findNextSiblingIgnoringWhitespaceAndNewline];
                            value = attributeNode.cleanContent;
                            attributeNode = [attributeNode findNextSiblingIgnoringWhitespaceAndNewline];
                        } else {
                            value = @""; //FIXME: Is this the best placeholder?
                        }
						if(dictionary == nil)
                        	dictionary = [[NSMutableDictionary alloc] init];
                        [dictionary setObject:_StringWithReplacedEntities(value) forKey:_StringWithReplacedEntities(name)];
                    }
                    htmlNode.attributes = dictionary;
                    [dictionary release];
                    [root release];
                }
            }
        }
    }
    
    return node;
}

@end

TOKEN_CLASS_IMPLEMENTATION(HTMLEqual, "=")

#define IMPLEMENTATION(__NAME__, __START__, __END__) \
@implementation SourceNodeHTML##__NAME__ \
\
+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
    IS_MATCHING_CHARACTERS(__START__, string, maxLength); \
    return _matching; \
} \
\
+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength { \
	IS_MATCHING_CHARACTERS(__END__, string, maxLength); \
    return _matching; \
} \
\
@end

IMPLEMENTATION(DOCTYPE, "<!DOCTYPE", ">")
IMPLEMENTATION(Comment, "<!--", "-->")
IMPLEMENTATION(CDATA, "<![CDATA[", "]]>")

#undef IMPLEMENTATION

@implementation SourceNodeHTMLComment (Internal)

- (NSString*) cleanContent {
	NSRange range = self.range;
    return _StringWithReplacedEntities([self.source substringWithRange:NSMakeRange(range.location + 4, range.length - 7)]);
}

@end

@implementation SourceNodeHTMLCDATA (Internal)

- (NSString*) cleanContent {
	NSRange range = self.range;
    return [self.source substringWithRange:NSMakeRange(range.location + 9, range.length - 12)];
}

@end

@implementation SourceNodeHTMLTag

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

- (NSInteger) htmlType {
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

@implementation SourceNodeHTMLElement

- (NSString*) cleanContent {
    NSMutableString* string = [NSMutableString string];
    for(SourceNode* node in self.children) {
    	if([node isKindOfClass:[SourceNodeHTMLTag class]] || [node isKindOfClass:[SourceNodeHTMLElement class]]
        	|| [node isKindOfClass:[SourceNodeHTMLComment class]]|| [node isKindOfClass:[SourceNodeHTMLCDATA class]])
        	continue;
        [string appendString:node.cleanContent];
    }
    return string;
}

- (NSString*) name {
	return [(SourceNodeHTMLTag*)self.firstChild name];
}

/*
- (NSDictionary*) attributes {
	return [(SourceNodeHTMLTag*)self.firstChild attributes];
}
*/

@end
