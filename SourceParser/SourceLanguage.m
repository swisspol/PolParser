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

#import <objc/runtime.h>

#import "SourceParser_Internal.h"

#define SourceLanguagePrefix "SourceLanguage"

void _RearrangeNodesAsChildren(SourceNode* startNode, SourceNode* endNode) {
    if(startNode == endNode)
    	[NSException raise:NSInternalInconsistencyException format:@""];
    
    SourceNode* node;
    if(startNode.range.length) {
        node = [[SourceNodeMatch alloc] initWithSource:startNode.source range:startNode.range];
        node.lines = startNode.lines;
        [startNode addChild:node];
        [node release];
    }
    SourceNode* sibling = startNode.nextSibling;
    node = sibling;
    do {
        SourceNode* sibling = node.nextSibling; //This will not be available afterwards
        [node removeFromParent];
        [startNode addChild:node];
        node = (node == endNode ? nil : sibling);
    } while(node);
    startNode.range = NSMakeRange(startNode.range.location, endNode.range.location + endNode.range.length - startNode.range.location);
    startNode.lines = NSMakeRange(sibling.lines.location, endNode.lines.location + endNode.lines.length - sibling.lines.location);
}

@implementation SourceLanguage

+ (id) allocWithZone:(NSZone*)zone
{
    if(self == [SourceLanguage class])
        [NSException raise:NSInternalInconsistencyException format:@"SourceNode is an abstract class"];
    
    return [super allocWithZone:zone];
}

+ (NSSet*) allLanguages {
    static NSMutableSet* set = nil;
	if(set == nil) {
    	set = [[NSMutableSet alloc] init];
        int count = objc_getClassList(NULL, 0);
        if(count > 0) {
            Class* list = malloc(count * sizeof(Class));
            count = objc_getClassList(list, count);
            for(int i = 0; i < count; ++i) {
                if(strncmp(class_getName(list[i]), SourceLanguagePrefix, sizeof(SourceLanguagePrefix) - 1) == 0) {
                	if(list[i] != [SourceLanguage class])
                    	[set addObject:[[[list[i] alloc] init] autorelease]];
                }
            }
            free(list);
        }
    }
	return set;
}

+ (SourceLanguage*) languageWithName:(NSString*)name {
    for(SourceLanguage* language in [SourceLanguage allLanguages]) {
        if([[language name] caseInsensitiveCompare:name] == NSOrderedSame)
            return language;
    }
    return nil;
}

+ (SourceLanguage*) defaultLanguageForFileExtension:(NSString*)extension {
	extension = [extension lowercaseString];
    SourceLanguage* language = nil;
    for(language in [SourceLanguage allLanguages]) {
        if([[language fileExtensions] containsObject:extension])
            break;
    }
    if(language == nil) {
        language = [SourceLanguage languageWithName:@"Base"];
        if(language == nil)
            [NSException raise:NSInternalInconsistencyException format:@"No language found for file extension \"%@\"", extension];
    }
    return language;
}

+ (SourceNodeRoot*) parseSourceFile:(NSString*)path encoding:(NSStringEncoding)encoding syntaxAnalysis:(BOOL)syntaxAnalysis {
    NSString* source = [[NSString alloc] initWithContentsOfFile:path encoding:encoding error:NULL];
    if(source == nil)
        return nil;
    SourceNodeRoot* root = [[self defaultLanguageForFileExtension:[path pathExtension]] parseSourceString:source syntaxAnalysis:syntaxAnalysis];
    [source release];
    return root;
}

+ (NSArray*) languageDependencies {
	return nil;
}

+ (NSSet*) languageReservedKeywords {
	return nil;
}

+ (NSArray*) languageNodeClasses {
    NSMutableArray* classes = [NSMutableArray arrayWithObjects:[SourceNodeText class], [SourceNodeMatch class], nil]; //Special-cased by parser
    
    NSString* prefix = [NSStringFromClass(self) substringFromIndex:[@SourceLanguagePrefix length]];
    for(NSString* keyword in [self languageReservedKeywords]) {
    	Class class = NSClassFromString([NSString stringWithFormat:@"SourceNode%@%@%@", prefix, [[keyword substringToIndex:1]uppercaseString], [keyword substringFromIndex:1]]);
        if(class)
        	[classes addObject:class];
    }
    return classes;
}

+ (NSSet*) languageTopLevelNodeClasses {
	return [NSSet setWithObject:[SourceNodeRoot class]]; //Special case
}

- (void) dealloc {
	[_keywords release];
    [_nodeClasses release];
    [_topLevelClasses release];
    
	[super dealloc];
}

- (NSString*) name {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (NSSet*) fileExtensions {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (NSArray*) _allLanguageDependencies {
	NSMutableArray* array = [NSMutableArray array];
    for(NSString* name in [[self class] languageDependencies])
        [array addObject:[SourceLanguage languageWithName:name]];
    [array addObject:self];
    return array;
}

- (NSSet*) reservedKeywords {
	if(_keywords == nil) {
    	_keywords = [[NSMutableSet alloc] init];
        for(SourceLanguage* language in [self _allLanguageDependencies]) {
            [_keywords unionSet:[[language class] languageReservedKeywords]];
        }
    }
    return _keywords;
}

- (NSArray*) nodeClasses {
    if(_nodeClasses == nil) {
        _nodeClasses = [[NSMutableArray alloc] init];
        for(SourceLanguage* language in [self _allLanguageDependencies]) {
            for(Class class in [[language class] languageNodeClasses]) {
            	if(![_nodeClasses containsObject:class]) {
                	NSUInteger index = _nodeClasses.count;
                    for(Class patchedClass in [class patchedClasses]) {
                    	NSUInteger patchedIndex = [_nodeClasses indexOfObject:patchedClass];
                        if((patchedIndex != NSNotFound) && (patchedIndex < index))
                        	index = patchedIndex;
                    }
                    [_nodeClasses insertObject:class atIndex:index];
                }
            }
        }
    }
    return _nodeClasses;
}

- (NSSet*) topLevelNodeClasses {
	if(_topLevelClasses == nil) {
    	_topLevelClasses = [[NSMutableSet alloc] init];
        for(SourceLanguage* language in [self _allLanguageDependencies]) {
            [_topLevelClasses unionSet:[[language class] languageTopLevelNodeClasses]];
        }
    }
    return _topLevelClasses;
}

static SourceNode* _ApplierFunction(SourceNode* node, void* context) {
    void** params = (void**)context;
    SourceLanguage* language = params[0];
    const unichar* buffer = params[1];
    NSSet* nodeClasses = params[2];
    return [language performSyntaxAnalysisForNode:node sourceBuffer:buffer topLevelNodeClasses:nodeClasses];
}

+ (SourceNodeRoot*) newNodeTreeFromSource:(NSString*)source range:(NSRange)range buffer:(const unichar*)buffer withNodeClasses:(NSArray*)nodeClasses {
    SourceNodeRoot* rootNode = [[SourceNodeRoot alloc] initWithSource:source range:range];
    if(rootNode == nil)
    	return nil;
    
    NSMutableArray* stack = [NSMutableArray array];
    [stack addObject:rootNode];
    NSUInteger lastLine = 0;
    NSUInteger currentLine = 0;
    NSUInteger rawLength = 0;
    while(range.length) {
        if(stack.count > 1) {
            SourceNode* parentNode = [stack lastObject];
            NSUInteger suffixLength;
            suffixLength = [[parentNode class] isMatchingSuffix:(buffer + range.location + rawLength) maxLength:(range.length - rawLength)];
            if(suffixLength != NSNotFound) {
                if(rawLength > 0) {
                    for(NSUInteger i = 0; i < rawLength; ++i) {
                    	if((*(buffer + range.location + i) == '\n') || ((*(buffer + range.location + i) == '\r') && (*(buffer + range.location + i + 1) != '\n')))
                            ++currentLine;
                    }
                    
                    SourceNode* node = [[SourceNodeText alloc] initWithSource:source range:NSMakeRange(range.location, rawLength)];
                    node.lines = NSMakeRange(lastLine, currentLine - lastLine + 1);
                    lastLine = currentLine;
                    [parentNode addChild:node];
                    [node release];
                    
                    range.location += rawLength;
                    range.length -= rawLength;
                    rawLength = 0;
                }
                
                parentNode.range = NSMakeRange(parentNode.range.location, range.location + suffixLength - parentNode.range.location);
                
                if(suffixLength > 0) {
                    for(NSUInteger i = 0; i < suffixLength; ++i) {
                    	if((*(buffer + range.location + i) == '\n') || ((*(buffer + range.location + i) == '\r') && (*(buffer + range.location + i + 1) != '\n')))
                            ++currentLine;
                    }
                    
                    SourceNode* node = [[SourceNodeMatch alloc] initWithSource:source range:NSMakeRange(parentNode.range.location + parentNode.range.length - suffixLength, suffixLength)];
                    node.lines = NSMakeRange(lastLine, currentLine - lastLine + 1);
                    lastLine = currentLine;
                    [parentNode addChild:node];
                    [node release];
                }
                
                parentNode.lines = NSMakeRange(parentNode.lines.location, currentLine - parentNode.lines.location + 1);
                
                [stack removeLastObject];
                range.location += suffixLength;
                range.length -= suffixLength;
                continue;
            }
        }
        
        Class prefixClass;
        NSUInteger prefixLength;
        for(prefixClass in nodeClasses) {
            if((prefixClass == [SourceNodeText class]) || (prefixClass == [SourceNodeMatch class]))
                continue;
            prefixLength = [prefixClass isMatchingPrefix:(buffer + range.location + rawLength) maxLength:(range.length - rawLength)];
            if(prefixLength != NSNotFound)
                break;
        }
        if(prefixClass) {
            if(rawLength > 0) {
                for(NSUInteger i = 0; i < rawLength; ++i) {
                    if((*(buffer + range.location + i) == '\n') || ((*(buffer + range.location + i) == '\r') && (*(buffer + range.location + i + 1) != '\n')))
                        ++currentLine;
                }
                
                SourceNode* node = [[SourceNodeText alloc] initWithSource:source range:NSMakeRange(range.location, rawLength)];
                [(SourceNode*)[stack lastObject] addChild:node];
                node.lines = NSMakeRange(lastLine, currentLine - lastLine + 1);
                lastLine = currentLine;
                [node release];
                
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
                
                for(NSUInteger i = 0; i < length; ++i) {
                    if((*(buffer + range.location + i) == '\n') || ((*(buffer + range.location + i) == '\r') && (*(buffer + range.location + i + 1) != '\n')))
                        ++currentLine;
                }
                
                SourceNode* node = [[prefixClass alloc] initWithSource:source range:NSMakeRange(range.location, length)];
                node.lines = NSMakeRange(lastLine, currentLine - lastLine + 1);
                lastLine = currentLine;
                [(SourceNode*)[stack lastObject] addChild:node];
                [node release];
                
                range.location += length;
                range.length -= length;
            } else {
                SourceNode* node = [[prefixClass alloc] initWithSource:source range:NSMakeRange(range.location, 0)];
                node.lines = NSMakeRange(currentLine, 0);
                [(SourceNode*)[stack lastObject] addChild:node];
                [stack addObject:node];
                [node release];
                
                for(NSUInteger i = 0; i < prefixLength; ++i) {
                    if((*(buffer + range.location + i) == '\n') || ((*(buffer + range.location + i) == '\r') && (*(buffer + range.location + i + 1) != '\n')))
                        ++currentLine;
                }
                
                node = [[SourceNodeMatch alloc] initWithSource:source range:NSMakeRange(range.location, prefixLength)];
                node.lines = NSMakeRange(lastLine, currentLine - lastLine + 1);
                lastLine = currentLine;
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
            node.lines = NSMakeRange(lastLine, currentLine - lastLine + 1);
            [(SourceNode*)[stack lastObject] addChild:node];
            [node release];
            break;
        }
    }
    
    [stack removeObjectAtIndex:0];
    if(stack.count > 0) {
        NSLog(@"Parser failed because some branch nodes are still opened at the end of the source:");
        for(SourceNode* node in stack)
            NSLog(@"\t%@", node);
        [rootNode release];
        return nil;
    }
    
    rootNode.lines = NSMakeRange(0, currentLine + 1);
    
    return rootNode;
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

- (SourceNodeRoot*) parseSourceString:(NSString*)source range:(NSRange)range buffer:(const unichar*)buffer syntaxAnalysis:(BOOL)syntaxAnalysis {
	SourceNodeRoot* rootNode = [[[self class] newNodeTreeFromSource:source range:range buffer:buffer withNodeClasses:self.nodeClasses] autorelease];
    if(rootNode == nil)
    	return nil;
    rootNode.language = self;
    
    if(syntaxAnalysis) {
    	NSMutableArray* array = [NSMutableArray array];
        for(NSString* name in [[self class] languageDependencies])
            [array addObject:[SourceLanguage languageWithName:name]];
        [array addObject:self];
        for(SourceLanguage* language in array) {
        	SourceNode* node = [language performSyntaxAnalysisForNode:rootNode sourceBuffer:buffer topLevelNodeClasses:self.topLevelNodeClasses];
        	if(node) {
                void* params[3];
                params[0] = language;
                params[1] = (void*)buffer;
                params[2] = self.topLevelNodeClasses;
                [node applyFunctionOnChildren:_ApplierFunction context:params];
            }
        }
    }
    
    NSMutableArray* stack = [NSMutableArray array];
    if(!_CheckTreeConsistency(rootNode, stack)) {
        NSLog(@"Parser failed because resulting tree is not consistent:\n%@\n%@", [[(SourceNode*)[stack objectAtIndex:0] parent] detailedDescription], stack);
        return nil;
    }
    
    return rootNode;
}

- (SourceNodeRoot*) parseSourceString:(NSString*)source syntaxAnalysis:(BOOL)syntaxAnalysis {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    source = [source copy];
    NSRange range = NSMakeRange(0, source.length);
    unichar* buffer = malloc((range.length + 2) * sizeof(unichar));
    buffer[0] = 0x0000; //We need one-character padding at the start since some nodes look at buffer[index - 1]
    buffer[range.length + 1] = 0x0000; //We need one-character padding at the end since some nodes look at buffer[index + 1]
    [source getCharacters:(buffer + 1)];
    
    SourceNodeRoot* root = [[self parseSourceString:source range:range buffer:(buffer + 1) syntaxAnalysis:syntaxAnalysis] retain];
    
    free(buffer);
    [source release];
    [pool drain];
    
    return [root autorelease];
}

- (SourceNode*) performSyntaxAnalysisForNode:(SourceNode*)node sourceBuffer:(const unichar*)sourceBuffer topLevelNodeClasses:(NSSet*)nodeClasses {
    return nil;
}

@end

@implementation SourceNodeRoot

@synthesize language=_language;

+ (BOOL) isAtomic {
    return NO;
}

- (id) copyWithZone:(NSZone*)zone {
	SourceNodeRoot* copy = [super copyWithZone:zone];
    if(copy)
    	copy->_language = _language;
    return copy;
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

@implementation SourceNodeMatch
@end

@implementation SourceNodeKeyword

+ (id) allocWithZone:(NSZone*)zone
{
    if(self == [SourceNodeKeyword class])
        [NSException raise:NSInternalInconsistencyException format:@"SourceNodeKeyword is an abstract class"];
    
    return [super allocWithZone:zone];
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return 0;
}

@end

@implementation SourceNodeToken

+ (id) allocWithZone:(NSZone*)zone
{
    if(self == [SourceNodeKeyword class])
        [NSException raise:NSInternalInconsistencyException format:@"SourceNodeToken is an abstract class"];
    
    return [super allocWithZone:zone];
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return 0;
}

@end

@implementation SourceNode (SourceNodeTextExtensions)

- (void) replaceWithText:(NSString*)text {
    SourceNodeText* node = text.length ? [[SourceNodeText alloc] initWithText:text] : nil;
    [self replaceWithNode:node];
    [node release];
}

@end
