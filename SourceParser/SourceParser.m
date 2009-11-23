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
        [classes addObject:[SourceNodeText class]]; //Must be #0
        [classes addObject:[SourceNodeIndenting class]]; //Must be #1
        [classes addObject:[SourceNodeWhitespace class]]; //Must be #2
        
        [classes addObject:[SourceNodeBraces class]];
        [classes addObject:[SourceNodeParenthesis class]];
        [classes addObject:[SourceNodeBrackets class]];
    }
    return classes;
}

static BOOL _CheckTreeConsistency(SourceNode* node, NSMutableArray* stack) {
    NSRange range = node.range;
    for(SourceNode* subnode in node.children) {
        if(subnode.children) {
            if(!_CheckTreeConsistency(subnode, stack)) {
            	[stack addObject:subnode];
                return NO;
            }
        }
        else {
        	if(subnode.range.location != range.location) {
        	    [stack addObject:subnode];
                return NO;
            }
        }
        range.location += subnode.range.length;
        range.length -= subnode.range.length;
    }
    if(range.length) {
        [stack addObject:node];
        return NO;
    }
    
    return YES;
}

static BOOL _ParseSource(SourceLanguage* language, NSString* source, const unichar* buffer, NSRange range, SourceNode* rootNode) {
	NSMutableArray* stack = [NSMutableArray array];
    [stack addObject:rootNode];
    NSUInteger rawLength = 0;
    while(range.length) {
        if(stack.count > 1) {
        	SourceNode* parentNode = [stack lastObject];
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
                
                if(suffixLength > 0) {
                	SourceNode* node = [[SourceNodeText alloc] initWithSource:source range:NSMakeRange(parentNode.range.location + parentNode.range.length - suffixLength, suffixLength)];
                    [parentNode addChild:node];
                    [node release];
                }
                
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
        	if(prefixClass == [SourceNodeText class])
            	continue;
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
                
                node = [[SourceNodeText alloc] initWithSource:source range:NSMakeRange(range.location, prefixLength)];
                [(SourceNode*)[stack lastObject] addChild:node];
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
    
    [stack removeObjectAtIndex:0];
    if(stack.count > 0) {
    	NSLog(@"\"%@\" parser failed because some branch nodes are still opened at the end of the source:", [language name]);
        for(SourceNode* node in stack)
        	NSLog(@"\t%@", node);
        return NO;
    }
    
    if(!_CheckTreeConsistency(rootNode, stack)) {
    	NSLog(@"\"%@\" parser failed because resulting tree is not consistent:\n%@", [language name], stack);
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
	//FIXME: Override this point to perform language dependent tree operations as nodes are inserted
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

- (NSRange) lines {
	if(_lines.location == 0)
    	_lines = _LineNumbersForRange(_source, _range);
        
    return _lines;
}

- (NSString*) content {
	return [_source substringWithRange:_range];
}

- (void) insertChild:(SourceNode*)child atIndex:(NSUInteger)index {
	if(child.parent)
    	[NSException raise:NSInternalInconsistencyException format:@""];
    
    if(_children == nil)
    	_children = [[NSMutableArray alloc] init];
    
    [_children insertObject:child atIndex:index];
    child.parent = self;
}

- (void) removeChildAtIndex:(NSUInteger)index {
	[[_children objectAtIndex:index] setParent:nil];
    [_children removeObjectAtIndex:index];
    if(!_children.count) {
    	[_children release];
        _children = nil;
    }
}

- (void) addChild:(SourceNode*)child {
	[self insertChild:child atIndex:_children.count];
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
	return [NSString stringWithFormat:@"<%@ = %p | characters = [%i, %i] | lines = [%i, %i]>\n%@", [self class], self, self.range.location, self.range.length, self.lines.location, self.lines.length, [self isKindOfClass:[SourceNodeRoot class]] ? self.fullDescription : self.miniDescription];
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

@end

@implementation SourceNodeRoot

@synthesize language=_language;

+ (BOOL) isLeaf {
	return NO;
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

static void _GenerateSource(SourceNode* node, NSMutableString* string) {
	for(node in node.children) {
    	if(node.children)
        	_GenerateSource(node, string);
        else
        	[string appendString:node.content];
    }
}

- (NSString*) generateSourceFromTree {
	NSMutableString* string = [NSMutableString stringWithCapacity:self.range.length];
    _GenerateSource(self, string);
    return string;
}

- (BOOL) writeSourceFromTreeToFile:(NSString*)path {
	return [[self generateSourceFromTree] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL]; //FIXME: Don't assume UTF8
}

@end

@implementation SourceNodeText

- (id) initWithText:(NSString*)text {
	return [self initWithSource:text range:NSMakeRange(0, text.length)];
}

@end
