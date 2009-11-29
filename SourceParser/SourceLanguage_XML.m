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

@interface SourceNodeXMLTag ()
@property(nonatomic, readonly) NSInteger xmlType;
@end

@implementation SourceLanguageXML

+ (NSArray*) languageDependencies {
	return [NSArray arrayWithObject:@"Base"];
}

+ (NSArray*) languageNodeClasses {
	NSMutableArray* classes = [NSMutableArray arrayWithArray:[super languageNodeClasses]];
    
    [classes addObject:[SourceNodeXMLDeclaration class]]; //Must be before SourceNodeXMLProcessingInstructions
    [classes addObject:[SourceNodeXMLProcessingInstructions class]]; //Must be before SourceNodeXMLTag
    [classes addObject:[SourceNodeXMLDOCTYPE class]]; //Must be before SourceNodeXMLTag
    [classes addObject:[SourceNodeXMLComment class]]; //Must be before SourceNodeXMLTag
    [classes addObject:[SourceNodeXMLCDATA class]]; //Must be before SourceNodeXMLTag
    [classes addObject:[SourceNodeXMLTag class]];
    [classes addObject:[SourceNodeXMLEntity class]];
    
    [classes addObject:[SourceNodeXMLElement class]];
    
    return classes;
}

- (NSString*) name {
    return @"XML";
}

- (NSSet*) fileExtensions {
    return [NSSet setWithObjects:@"xml", @"plist", nil];
}

- (SourceNode*) performSyntaxAnalysisForNode:(SourceNode*)node sourceBuffer:(const unichar*)sourceBuffer topLevelNodeClasses:(NSSet*)nodeClasses {
	
    if([node isKindOfClass:[SourceNodeXMLTag class]]) {
    	SourceNodeXMLTag* xmlNode = (SourceNodeXMLTag*)node;
        if(xmlNode.xmlType == 0) {
        	SourceNode* newNode = [[SourceNodeXMLElement alloc] initWithSource:node.source range:NSMakeRange(node.range.location, 0)];
            [node insertPreviousSibling:newNode];
            [newNode release];
            
            _RearrangeNodesAsChildren(newNode, node);
        } else if(xmlNode.xmlType < 0) {
        	SourceNode* endNode = node;
            while(endNode) {
                endNode = [endNode findNextSiblingOfClass:[SourceNodeXMLTag class]];
                if([endNode.name isEqualToString:xmlNode.name])
                	break;
            }
            if(endNode) {
            	SourceNode* newNode = [[SourceNodeXMLElement alloc] initWithSource:node.source range:NSMakeRange(node.range.location, 0)];
                [node insertPreviousSibling:newNode];
                [newNode release];
                
                _RearrangeNodesAsChildren(newNode, endNode);
            }
        }
    }
    
    return node;
}

@end

#define IMPLEMENTATION(__NAME__, __START__, __END__) \
@implementation SourceNodeXML##__NAME__ \
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

IMPLEMENTATION(Declaration, "<?xml ", "?>")
IMPLEMENTATION(ProcessingInstructions, "<?", "?>")
IMPLEMENTATION(DOCTYPE, "<!DOCTYPE", ">")
IMPLEMENTATION(Comment, "<!--", "-->")
IMPLEMENTATION(CDATA, "<![CDATA[", "]]>")

#undef IMPLEMENTATION

static NSString* _StringWithReplacedEntities(NSString* string) {
	NSMutableString* newString = [NSMutableString stringWithString:string];
    [newString replaceOccurrencesOfString:@"&lt;" withString:@"<" options:0 range:NSMakeRange(0, newString.length)];
    [newString replaceOccurrencesOfString:@"&gt;" withString:@">" options:0 range:NSMakeRange(0, newString.length)];
    [newString replaceOccurrencesOfString:@"&amp;" withString:@"&" options:0 range:NSMakeRange(0, newString.length)];
    [newString replaceOccurrencesOfString:@"&apos;" withString:@"'" options:0 range:NSMakeRange(0, newString.length)];
    [newString replaceOccurrencesOfString:@"&quot;" withString:@"\"" options:0 range:NSMakeRange(0, newString.length)];
    return newString;
}

@implementation SourceNodeXMLProcessingInstructions (Internal)

- (NSString*) cleanContent {
	NSRange range = self.range;
    return _StringWithReplacedEntities([self.source substringWithRange:NSMakeRange(range.location + 2, range.length - 4)]);
}

@end

@implementation SourceNodeXMLComment (Internal)

- (NSString*) cleanContent {
	NSRange range = self.range;
    return _StringWithReplacedEntities([self.source substringWithRange:NSMakeRange(range.location + 4, range.length - 7)]);
}

@end

@implementation SourceNodeXMLCDATA (Internal)

- (NSString*) cleanContent {
	NSRange range = self.range;
    return [self.source substringWithRange:NSMakeRange(range.location + 9, range.length - 12)];
}

@end

static NSDictionary* _ParseAttributes(NSString* content) {
	NSMutableDictionary* attributes = nil;
   	NSRange range = NSMakeRange(0, content.length);
    while(range.length) {
    	NSRange subrange = [content rangeOfCharacterFromSet:[[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet] options:0 range:range];
        if(subrange.location == NSNotFound)
        	break;
        range.length -= subrange.location - range.location;
        range.location = subrange.location;
        
        subrange = [content rangeOfString:@"=" options:0 range:range];
        if(subrange.location == NSNotFound)
        	break;
        NSRange aRange = [content rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] options:0 range:range];
        if(aRange.location > subrange.location)
        	aRange.location = subrange.location;
        NSString* name = [content substringWithRange:NSMakeRange(range.location, aRange.location - range.location)];
        range.length -= subrange.location + 1 - range.location;
        range.location = subrange.location + 1;
        
        subrange = [content rangeOfCharacterFromSet:[[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet] options:0 range:range];
        if(subrange.location == NSNotFound)
        	break;
        range.length -= subrange.location - range.location;
        range.location = subrange.location;
        
        if([content characterAtIndex:range.location] == '"')
        	subrange = [content rangeOfString:@"\"" options:0 range:NSMakeRange(range.location + 1, range.length - 1)];
        else if([content characterAtIndex:range.location] == '\'')
        	subrange = [content rangeOfString:@"'" options:0 range:NSMakeRange(range.location + 1, range.length - 1)];
        else
        	break;
        if(subrange.location == NSNotFound)
        	break;
        NSString* value = [content substringWithRange:NSMakeRange(range.location + 1, subrange.location + 1 - range.location - 2)];
        range.length -= subrange.location + 1 - range.location;
        range.location = subrange.location + 1;
        
        if(attributes == nil)
        	attributes = [NSMutableDictionary dictionary];
        [attributes setObject:_StringWithReplacedEntities(value) forKey:_StringWithReplacedEntities(name)];
    }
	return attributes;
}

@implementation SourceNodeXMLDeclaration (Internal)

- (void) dealloc {
	[_attributes release];
    
    [super dealloc];
}

- (NSDictionary*) attributes {
	if(_attributes == nil) {
    	NSString* content = self.content;
        _attributes = [_ParseAttributes([content substringWithRange:NSMakeRange(5, content.length - 5 - 2)]) retain];
    }
    return _attributes;
}

@end

@implementation SourceNodeXMLTag

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
    return *string == '>' ? 1 : ((maxLength >= 2) && (*string == '/') && (*(string + 1) == '>') ? 2 : NSNotFound);
}

- (void) dealloc {
	[_name release];
    
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
    
    if(((_type == 0) || (_type < 0)) && (range.location != NSNotFound))
        _attributes = [_ParseAttributes([content substringFromIndex:range.location]) retain];
}

- (NSInteger) xmlType {
	if(_name == nil)
    	[self _analyze];
    return _type;
}

- (NSString*) name {
	if(_name == nil)
    	[self _analyze];
    return _name;
}

- (NSDictionary*) attributes {
	if(_name == nil)
    	[self _analyze];
    return _attributes;
}

@end

@implementation SourceNodeXMLEntity

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return *string == '&' ? 1 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return *string == ';' ? 1 : NSNotFound;
}

- (NSString*) cleanContent {
    return _StringWithReplacedEntities([self.source substringWithRange:self.range]);
}

@end

@implementation SourceNodeXMLElement

- (NSString*) cleanContent {
    NSMutableString* string = [NSMutableString string];
    for(SourceNode* node in self.children) {
    	if([node isKindOfClass:[SourceNodeXMLTag class]] || [node isKindOfClass:[SourceNodeXMLElement class]]
        	|| [node isKindOfClass:[SourceNodeXMLComment class]]|| [node isKindOfClass:[SourceNodeXMLCDATA class]])
        	continue;
        [string appendString:node.cleanContent];
    }
    return string;
}

/*
- (NSDictionary*) attributes {
	return [(SourceNodeXMLTag*)self.firstChild attributes];
}
*/

@end
