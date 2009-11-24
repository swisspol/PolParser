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

void _RearrangeNodesAsChildren(SourceNode* startNode, SourceNode* endNode) {
	SourceNode* node = [[SourceNodeText alloc] initWithSource:startNode.source range:startNode.range];
    [startNode addChild:node];
    [node release];
    node = startNode.nextSibling;
    do {
        SourceNode* sibling = node.nextSibling; //This will not be available afterwards
        [node removeFromParent];
        [startNode addChild:node];
        node = (node == endNode ? nil : sibling);
    } while(node);
    startNode.range = NSMakeRange(startNode.range.location, endNode.range.location + endNode.range.length - startNode.range.location);
}

@implementation SourceLanguage

static NSMutableSet* _languageCache = nil;

+ (void) initialize {
	if(_languageCache == nil) {
    	_languageCache = [[NSMutableSet alloc] init];
        [_languageCache addObject:[[[SourceLanguageBase alloc] init] autorelease]];
        [_languageCache addObject:[[[SourceLanguageC alloc] init] autorelease]];
        [_languageCache addObject:[[[SourceLanguageCPP alloc] init] autorelease]];
        [_languageCache addObject:[[[SourceLanguageObjC alloc] init] autorelease]];
        [_languageCache addObject:[[[SourceLanguageObjCPP alloc] init] autorelease]];
    }
    
    [super initialize];
}

+ (id) allocWithZone:(NSZone*)zone
{
	if(self == [SourceLanguage class])
        [NSException raise:NSInternalInconsistencyException format:@"SourceNode is an abstract class"];
	
	return [super allocWithZone:zone];
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

+ (SourceNodeRoot*) parseSourceFile:(NSString*)path encoding:(NSStringEncoding)encoding {
	NSString* source = [[NSString alloc] initWithContentsOfFile:path encoding:encoding error:NULL];
    if(source == nil)
    	return nil;
	
    NSString* extension = [[path pathExtension] lowercaseString];
    SourceLanguage* language = nil;
    for(language in [SourceLanguage allLanguages]) {
    	if([[language fileExtensions] containsObject:extension])
        	break;
    }
    if(language == nil) {
    	language = [SourceLanguage languageForName:nil]; //FIXME: Find a cleaner way to retrieve Base language
        if(language == nil)
        	[NSException raise:NSInternalInconsistencyException format:@"No language found for \"%@\"", path];
    }
    
    SourceNodeRoot* root = [language parseSourceString:source];
    [source release];
    
    return root;
}

- (NSString*) name {
	[self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (NSSet*) fileExtensions {
	[self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (NSArray*) nodeClasses {
	static NSMutableArray* classes = nil;
    if(classes == nil) {
        classes = [[NSMutableArray alloc] init];
        [classes addObject:[SourceNodeText class]]; //Special-cased by parser
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
            if([prefixClass isAtomic]) {
            	NSUInteger length = prefixLength;
                NSUInteger suffixLength = NSNotFound;
                while(1) {
                    suffixLength = [prefixClass isMatchingSuffix:(buffer + range.location + length) maxLength:(range.length - length)];
                    if(suffixLength != NSNotFound)
                    	break;
                    if(length == range.length)
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
	;
}

@end

@implementation SourceNodeRoot

@synthesize language=_language;

+ (BOOL) isAtomic {
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

- (BOOL) writeContentToFile:(NSString*)path encoding:(NSStringEncoding)encoding {
	return [[self content] writeToFile:path atomically:YES encoding:encoding error:NULL];
}

@end

@implementation SourceNodeText

+ (SourceNodeText*) sourceNodeWithText:(NSString*)text {
	return [[[self alloc] initWithText:text] autorelease];
}

- (id) initWithText:(NSString*)text {
	if(text.length == 0)
    	[NSException raise:NSInternalInconsistencyException format:@"Text cannot be empty"];
    
    return [self initWithSource:text range:NSMakeRange(0, text.length)];
}

- (void) insertChild:(SourceNode*)child atIndex:(NSUInteger)index {
	[self doesNotRecognizeSelector:_cmd];
}

@end

@implementation SourceNode (SourceNodeTextExtensions)

- (void) replaceWithText:(NSString*)text {
    SourceNodeText* node = text.length ? [[SourceNodeText alloc] initWithText:text] : nil;
    [self replaceWithNode:node];
    [node release];
}

@end
