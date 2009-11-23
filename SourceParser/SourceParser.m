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

BOOL _IsRealLineBreak(const unichar* string) {
	if(!IsNewline(*string))
        return NO;
    do {
    	--string;
    } while(IsWhiteSpaceOrNewline(*string));
    return *string != '\\';
}

BOOL _EqualUnichars(const unichar* string1, const unichar* string2, NSUInteger length) {
	while(length) {
    	if(*string1++ != *string2++)
        return NO;
        --length;
    }
    return YES;
}

NSString* _StripLineBrakes(NSString* content) {
	NSMutableString* string = [NSMutableString stringWithString:content];
    NSUInteger offset = 0;
    while(offset < string.length) {
        NSRange range1 = [string rangeOfString:@"\\" options:0 range:NSMakeRange(offset, string.length - offset)];
        if(range1.location != NSNotFound) {
            NSRange range2 = [string rangeOfString:@"\\" options:NSAnchoredSearch range:NSMakeRange(range1.location + 1, string.length - range1.location - 1)];
            if(range2.location == NSNotFound) {
                NSRange range3 = [string rangeOfString:@"\n" options:0 range:NSMakeRange(range1.location + 1, string.length - range1.location - 1)];
                if(range3.location == NSNotFound) {
                    range3.location = string.length;
                    range3.length = 0;
                }
                [string replaceCharactersInRange:NSMakeRange(range1.location, range3.location - range1.location + range3.length) withString:@""];
            } else {
                range1.location = range2.location + range2.length;
            }
        } else {
            range1.location = string.length;
        }
        offset = range1.location;
    }
    return string;
}

@implementation SourceLanguage

static NSMutableSet* _languageCache = nil;

+ (void) initialize {
	if(_languageCache == nil) {
    	_languageCache = [[NSMutableSet alloc] init];
        [_languageCache addObject:[[[SourceLanguage alloc] init] autorelease]];
        [_languageCache addObject:[[[SourceLanguageC alloc] init] autorelease]];
        [_languageCache addObject:[[[SourceLanguageCPP alloc] init] autorelease]];
        [_languageCache addObject:[[[SourceLanguageObjC alloc] init] autorelease]];
        [_languageCache addObject:[[[SourceLanguageObjCPP alloc] init] autorelease]];
    }
    
    [super initialize];
}

+ (NSSet*) allLanguages {
	return _languageCache;
}

+ (SourceLanguage*) languageForName:(NSString*)name {
	for(SourceLanguage* language in _languageCache) {
    	if(([language name] == name) || ([[language name] caseInsensitiveCompare:name] == NSOrderedSame))
        	return language;
    }
    return nil;
}

+ (SourceNodeRoot*) parseSourceFile:(NSString*)path {
	NSString* source = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL]; //FIXME: Don't assume UTF8
    if(source == nil)
    	return nil;
	
    NSString* extension = [[path pathExtension] lowercaseString];
    SourceLanguage* language = nil;
    for(language in [SourceLanguage allLanguages]) {
    	if([[language fileExtensions] containsObject:extension])
        	break;
    }
    if(language == nil) {
    	language = [SourceLanguage languageForName:nil];
        if(language == nil)
        	[NSException raise:NSInternalInconsistencyException format:@""];
    }
    
    SourceNodeRoot* root = [language parseSourceString:source];
    [source release];
    
    return root;
}

- (NSString*) name {
	return nil;
}

- (NSSet*) fileExtensions {
	return nil;
}

- (NSArray*) nodeClasses {
	static NSMutableArray* classes = nil;
    if(classes == nil) {
        classes = [[NSMutableArray alloc] init];
        [classes addObject:[SourceNodeIndenting class]]; //Must be first
        [classes addObject:[SourceNodeWhitespace class]]; //Must be second
        
        [classes addObject:[SourceNodeBraces class]];
        [classes addObject:[SourceNodeParenthesis class]];
        [classes addObject:[SourceNodeBrackets class]];
    }
    return classes;
}

static BOOL _ParseSource(SourceLanguage* language, NSString* source, const unichar* buffer, NSRange range, SourceNode* parentNode) {
	NSMutableArray* stack = [NSMutableArray array];
    [stack addObject:parentNode];
    NSUInteger rawLength = 0;
    while(range.length) {
        if(stack.count > 1) {
        	parentNode = [stack lastObject];
            NSUInteger suffixLength;
        	suffixLength = [[parentNode class] isMatchingSuffix:(buffer + range.location + rawLength) maxLength:(range.length - rawLength)];
            if(suffixLength != NSNotFound) {
            	if(rawLength > 0) {
                    SourceNode* node = [[SourceNodeText alloc] initWithSource:source range:NSMakeRange(range.location, rawLength)];
                    [parentNode addChild:node];
                    [node release];
                    
                    [language didAddChildNodeToSourceTree:node];
                    
                    range.location += rawLength;
                    range.length -= rawLength;
                    rawLength = 0;
                }
                
                parentNode.range = NSMakeRange(parentNode.range.location, range.location + suffixLength - parentNode.range.location);
                
                [language didAddChildNodeToSourceTree:parentNode];
                
				[stack removeLastObject];
                range.location += suffixLength;
                range.length -= suffixLength;
                continue;
            }
        }
        
        Class prefixClass;
        NSUInteger prefixLength;
        for(prefixClass in language.nodeClasses) {
        	prefixLength = [prefixClass isMatchingPrefix:(buffer + range.location + rawLength) maxLength:(range.length - rawLength)];
            if(prefixLength != NSNotFound)
                break;
        }
    	if(prefixClass) {
        	if(rawLength > 0) {
                SourceNode* node = [[SourceNodeText alloc] initWithSource:source range:NSMakeRange(range.location, rawLength)];
                [(SourceNode*)[stack lastObject] addChild:node];
                [node release];
                
                [language didAddChildNodeToSourceTree:node];
                
                range.location += rawLength;
                range.length -= rawLength;
                rawLength = 0;
            }
            if([prefixClass isLeaf]) {
            	NSUInteger length = prefixLength;
                NSUInteger suffixLength = NSNotFound;
                while(length < range.length) {
                    suffixLength = [prefixClass isMatchingSuffix:(buffer + range.location + length) maxLength:(range.length - length)];
                    if(suffixLength != NSNotFound)
                    	break;
                    ++length;
                }
                if(suffixLength == NSNotFound) {
                	prefixClass = [SourceNodeText class];
                    suffixLength = 0;
                }
                
                length = length + suffixLength;
                SourceNode* node = [[prefixClass alloc] initWithSource:source range:NSMakeRange(range.location, length)];
                [(SourceNode*)[stack lastObject] addChild:node];
                [node release];
                
                [language didAddChildNodeToSourceTree:node];
                
                range.location += length;
                range.length -= length;
            } else {
                SourceNode* node = [[prefixClass alloc] initWithSource:source range:NSMakeRange(range.location, prefixLength)];
                [(SourceNode*)[stack lastObject] addChild:node];
                [stack addObject:node];
                [node release];
                
                range.location += prefixLength;
                range.length -= prefixLength;
            }
            continue;
        }
        
        ++rawLength;
        if(rawLength == range.length) {
        	SourceNode* node = [[SourceNodeText alloc] initWithSource:source range:range];
            [(SourceNode*)[stack lastObject] addChild:node];
            [node release];
            
            [language didAddChildNodeToSourceTree:node];
            
            break;
        }
    }
    
    if(stack.count > 1) {
    	[stack removeObjectAtIndex:0];
        NSLog(@"\"%@\" parser failed because some non-leaf nodes are still opened at the end of the file:", [language name]);
        for(SourceNode* node in stack)
        	NSLog(@"\t%@", node);
        return NO;
    }
    
    return YES;
}

- (SourceNodeRoot*) parseSourceString:(NSString*)source {
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    source = [source copy];
    NSRange range = NSMakeRange(0, source.length);
    unichar* buffer = malloc((range.length + 1) * sizeof(unichar));
    buffer[0] = 0xFFFF; //We need one-character padding at the start since some nodes look at buffer[index - 1]
    [source getCharacters:(buffer + 1) range:range];
    
    SourceNodeRoot* root = [[SourceNodeRoot alloc] initWithSource:source language:self];
    if(!_ParseSource(self, source, buffer + 1, range, root)) {
    	[root release];
        root = nil;
    }
    
    free(buffer);
    [source release];
    [pool drain];
    
    return [root autorelease];
}

- (void) didAddChildNodeToSourceTree:(SourceNode*)child {
	;
}

@end

@implementation SourceNode

@synthesize source=_source, range=_range, parent=_parent, children=_children;

+ (id) allocWithZone:(NSZone*)zone
{
	if(self == [SourceNode class])
        [[NSException exceptionWithName:NSInternalInconsistencyException reason:@"SourceNode is an abstract class" userInfo:nil] raise];
	
	return [super allocWithZone:zone];
}

+ (NSString*) name {
	return [NSStringFromClass(self) substringFromIndex:[@"SourceNode" length]];
}

- (id) initWithSource:(NSString*)source range:(NSRange)range {
	if((self = [super init])) {
    	_source = [source copy];
        _range = range;
    }
    
    return self;
}

- (void) dealloc {
	for(SourceNode* node in _children)
    	node.parent = nil;
    [_children release];
    
    [_content release];
    [_source release];
    
    [super dealloc];
}

- (NSMutableArray*) mutableChildren {
	return _children;
}

static NSRange _LineNumbersForRange(NSString* string, NSRange range) {
	NSRange lines = NSMakeRange(1, 1);
    NSRange subrange = NSMakeRange(0, 0);
    while(1) {
    	subrange = [string rangeOfString:@"\n" options:0 range:NSMakeRange(subrange.location, string.length - subrange.location)];
        if(subrange.location == NSNotFound)
        	break;
        if(subrange.location < range.location) {
        	lines.location += 1;
        }
        else {
            if(subrange.location < range.location + range.length)
                lines.length += 1;
            else
            	break;
        }
        subrange.location += subrange.length;
    }
    
    return lines;
}

- (NSRange) lineNumbers {
	if(_lineNumbers.location == 0)
    	_lineNumbers = _LineNumbersForRange(_source, _range);
        
    return _lineNumbers;
}

- (NSString*) content {
	if(_content == nil)
    	_content = [[[self class] tidyContent:[_source substringWithRange:_range]] retain];
    
    return _content;
}

- (void) addChild:(SourceNode*)node {
	if(_children == nil)
    	_children = [[NSMutableArray alloc] init];
    
    [_children addObject:node];
    node.parent = self;
}

static NSString* _FormatString(NSString* string) {
	static NSString* spaceString = nil;
    if(spaceString == nil) {
    	const unichar aChar = 0x2022;
        spaceString = [[NSString alloc] initWithCharacters:&aChar length:1];
    }
    static NSString* tabString = nil;
    if(tabString == nil) {
    	const unichar aChar = 0x2192;
        tabString = [[NSString alloc] initWithCharacters:&aChar length:1];
    }
    static NSString* newlineString = nil;
    if(newlineString == nil) {
    	const unichar aChar = 0x00B6; //0x21A9
        newlineString = [[NSString alloc] initWithCharacters:&aChar length:1];
    }
    
    string = [NSMutableString stringWithString:string];
    [(NSMutableString*)string replaceOccurrencesOfString:@" " withString:spaceString options:0 range:NSMakeRange(0, string.length)];
    [(NSMutableString*)string replaceOccurrencesOfString:@"\t" withString:tabString options:0 range:NSMakeRange(0, string.length)];
    [(NSMutableString*)string replaceOccurrencesOfString:@"\n" withString:newlineString options:0 range:NSMakeRange(0, string.length)];
    return string;
}

- (NSString*) miniDescription {
	return _FormatString(self.content);
}

static void _AppendNodeDescription(SourceNode* node, NSMutableString* string, NSString* prefix) {
	NSString* content = (node.children ? nil : _FormatString(node.content));
    if(content.length)
        [string appendFormat:@"%@[%@] = |%@|\n", prefix, [[node class] name], content];
    else
    	[string appendFormat:@"%@[%@]\n", prefix, [[node class] name]];
    
    prefix = [prefix stringByAppendingString:@"\t"];
    for(node in [node children])
        _AppendNodeDescription(node, string, prefix);
}

- (NSString*) fullDescription {
	NSMutableString*	string = [NSMutableString string];
	_AppendNodeDescription(self, string, @"");
	return string;
}

- (NSString*) description {
	return [NSString stringWithFormat:@"<%@ = %p | characters = [%i, %i] | lines = [%i, %i]>\n%@", [self class], self, self.range.location, self.range.length, self.lineNumbers.location, self.lineNumbers.length, [self isKindOfClass:[SourceNodeRoot class]] ? self.fullDescription : self.miniDescription];
}

@end

@implementation SourceNode (Parsing)

+ (BOOL) isLeaf {
	return YES;
}

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return NSNotFound;
}

+ (BOOL) trimTrailingWhitespace {
	return NO;
}

+ (NSString*) tidyContent:(NSString*)content {
	if([self trimTrailingWhitespace]) {
    	NSRange range = [content rangeOfCharacterFromSet:[[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet] options:NSBackwardsSearch range:NSMakeRange(0, content.length)];
        if((range.location != NSNotFound) && (range.location < content.length - 1))
        	content = [content substringToIndex:(range.location + 1)];
    }
    
    return content;
}

@end

@implementation SourceNodeRoot

@synthesize language=_language;

+ (BOOL) isLeaf {
	return NO;
}

- (id) initWithSource:(NSString*)source range:(NSRange)range {
	[self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id) initWithSource:(NSString*)source language:(SourceLanguage*)language {
	if((self = [super initWithSource:source range:NSMakeRange(0, source.length)]))
    	_language = [language retain];
        
    return self;
}

- (void) dealloc {
	[_language release];
    
	[super dealloc];
}

@end

@implementation SourceNodeText
@end
