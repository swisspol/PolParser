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

#import "Parser_Internal.h"

#define ParserLanguagePrefix "ParserLanguage"

@implementation ParserLanguage

+ (id) allocWithZone:(NSZone*)zone
{
    if(self == [ParserLanguage class])
        [NSException raise:NSInternalInconsistencyException format:@"ParserLanguage is an abstract class"];
    
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
                if(strncmp(class_getName(list[i]), ParserLanguagePrefix, sizeof(ParserLanguagePrefix) - 1) == 0) {
                	if(list[i] != [ParserLanguage class])
                    	[set addObject:[[[list[i] alloc] init] autorelease]];
                }
            }
            free(list);
        }
    }
	return set;
}

+ (ParserLanguage*) languageWithName:(NSString*)name {
    for(ParserLanguage* language in [ParserLanguage allLanguages]) {
        if([[language name] caseInsensitiveCompare:name] == NSOrderedSame)
            return language;
    }
    return nil;
}

+ (ParserLanguage*) defaultLanguageForFileExtension:(NSString*)extension {
	extension = [extension lowercaseString];
    for(ParserLanguage* language in [ParserLanguage allLanguages]) {
        if([[language fileExtensions] containsObject:extension])
            return language;
    }
    return nil;
}

+ (ParserNodeRoot*) parseTextFile:(NSString*)path encoding:(NSStringEncoding)encoding syntaxAnalysis:(BOOL)syntaxAnalysis {
    NSString* string = [[NSString alloc] initWithContentsOfFile:path encoding:encoding error:NULL];
    if(string == nil)
        return nil;
    ParserNodeRoot* root = [[self defaultLanguageForFileExtension:[path pathExtension]] parseText:string syntaxAnalysis:syntaxAnalysis];
    [string release];
    return root;
}

+ (NSArray*) languageDependencies {
	return nil;
}

+ (NSSet*) languageReservedKeywords {
	return nil;
}

+ (NSArray*) languageNodeClasses {
    return nil;
}

- (void) dealloc {
	[_languageDependencies release];
    [_keywords release];
    [_nodeClasses release];
    
	[super dealloc];
}

- (id) copyWithZone:(NSZone*)zone {
	return [self retain];
}

- (NSString*) name {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (NSSet*) fileExtensions {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (NSArray*) allLanguageDependencies {
	if(_languageDependencies == nil) {
        _languageDependencies = [[NSMutableArray alloc] init];
        for(NSString* name in [[self class] languageDependencies]) {
            ParserLanguage* language = [ParserLanguage languageWithName:name];
            for(language in language.allLanguageDependencies) {
            	if(![_languageDependencies containsObject:language])
                	[_languageDependencies addObject:language];
            }
        }
        [_languageDependencies addObject:self];
    }
    return _languageDependencies;
}

- (NSSet*) reservedKeywords {
	if(_keywords == nil) {
    	_keywords = [[NSMutableSet alloc] init];
        for(ParserLanguage* language in self.allLanguageDependencies) {
            [_keywords unionSet:[[language class] languageReservedKeywords]];
        }
    }
    return _keywords;
}

- (NSArray*) nodeClasses {
    if(_nodeClasses == nil) {
        _nodeClasses = [[NSMutableArray alloc] init];
        [_nodeClasses addObject:[ParserNodeText class]]; //Special-cased by parser
        [_nodeClasses addObject:[ParserNodeMatch class]]; //Special-cased by parser
        for(ParserLanguage* language in self.allLanguageDependencies) {
            NSString* prefix = [NSStringFromClass([language class]) substringFromIndex:[@ParserLanguagePrefix length]];
            for(NSString* keyword in [[language class] languageReservedKeywords]) {
                Class class = NSClassFromString([NSString stringWithFormat:@"ParserNode%@%@%@", prefix, [[keyword substringToIndex:1]uppercaseString], [keyword substringFromIndex:1]]);
                if(class)
                    [_nodeClasses addObject:class];
            }
            
            for(Class class in [[language class] languageNodeClasses]) {
            	if(![_nodeClasses containsObject:class]) {
                	NSUInteger count = _nodeClasses.count;
                    NSUInteger index = count;
                    for(Class patchedClass in [class patchedClasses]) {
                    	NSUInteger patchedIndex = NSNotFound;
						for(NSUInteger i = 0; i < count; ++i) {
                        	if([[_nodeClasses objectAtIndex:i] isSubclassOfClass:patchedClass]) {
                            	patchedIndex = i;
                                break;
                            }
                        }
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

static ParserNode* _ApplierFunction(ParserNode* node, void* context) {
    void** params = (void**)context;
    ParserLanguage* language = params[0];
    const unichar* buffer = params[1];
    ParserLanguage* topLevelLanguage = params[2];
    return [language performSyntaxAnalysisForNode:node textBuffer:buffer topLevelLanguage:topLevelLanguage];
}

+ (ParserNodeRoot*) newNodeTreeFromText:(NSString*)text range:(NSRange)range textBuffer:(const unichar*)textBuffer withNodeClasses:(NSArray*)nodeClasses {
    ParserNodeRoot* rootNode = [[ParserNodeRoot alloc] initWithText:text range:range];
    if(rootNode == nil)
    	return nil;
    
    NSMutableArray* stack = [NSMutableArray array];
    [stack addObject:rootNode];
    NSUInteger lastLine = 0;
    NSUInteger currentLine = 0;
    NSUInteger rawLength = 0;
    while(range.length) {
        if(stack.count > 1) {
            ParserNode* parentNode = [stack lastObject];
            NSUInteger suffixLength;
            suffixLength = [[parentNode class] isMatchingSuffix:(textBuffer + range.location + rawLength) maxLength:(range.length - rawLength)];
            if(suffixLength != NSNotFound) {
                if(rawLength > 0) {
                    for(NSUInteger i = 0; i < rawLength; ++i) {
                    	if((*(textBuffer + range.location + i) == '\n') || ((*(textBuffer + range.location + i) == '\r') && (*(textBuffer + range.location + i + 1) != '\n')))
                            ++currentLine;
                    }
                    
                    ParserNode* node = [[ParserNodeText alloc] initWithText:text range:NSMakeRange(range.location, rawLength)];
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
                    	if((*(textBuffer + range.location + i) == '\n') || ((*(textBuffer + range.location + i) == '\r') && (*(textBuffer + range.location + i + 1) != '\n')))
                            ++currentLine;
                    }
                    
                    ParserNode* node = [[ParserNodeMatch alloc] initWithText:text range:NSMakeRange(parentNode.range.location + parentNode.range.length - suffixLength, suffixLength)];
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
            if((prefixClass == [ParserNodeText class]) || (prefixClass == [ParserNodeMatch class]))
                continue;
            prefixLength = [prefixClass isMatchingPrefix:(textBuffer + range.location + rawLength) maxLength:(range.length - rawLength)];
            if(prefixLength != NSNotFound)
                break;
        }
        if(prefixClass) {
            if(rawLength > 0) {
                for(NSUInteger i = 0; i < rawLength; ++i) {
                    if((*(textBuffer + range.location + i) == '\n') || ((*(textBuffer + range.location + i) == '\r') && (*(textBuffer + range.location + i + 1) != '\n')))
                        ++currentLine;
                }
                
                ParserNode* node = [[ParserNodeText alloc] initWithText:text range:NSMakeRange(range.location, rawLength)];
                [(ParserNode*)[stack lastObject] addChild:node];
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
                    suffixLength = [prefixClass isMatchingSuffix:(textBuffer + range.location + length) maxLength:(range.length - length)];
                    if(suffixLength != NSNotFound)
                        break;
                    if(length == range.length)
                        break;
                    ++length;
                }
                if(suffixLength == NSNotFound) {
                    prefixClass = [ParserNodeText class];
                    suffixLength = 0;
                }
                length = length + suffixLength;
                
                for(NSUInteger i = 0; i < length; ++i) {
                    if((*(textBuffer + range.location + i) == '\n') || ((*(textBuffer + range.location + i) == '\r') && (*(textBuffer + range.location + i + 1) != '\n')))
                        ++currentLine;
                }
                
                ParserNode* node = [[prefixClass alloc] initWithText:text range:NSMakeRange(range.location, length)];
                node.lines = NSMakeRange(lastLine, currentLine - lastLine + 1);
                lastLine = currentLine;
                [(ParserNode*)[stack lastObject] addChild:node];
                [node release];
                
                range.location += length;
                range.length -= length;
            } else {
                ParserNode* node = [[prefixClass alloc] initWithText:text range:NSMakeRange(range.location, 0)];
                node.lines = NSMakeRange(currentLine, 0);
                [(ParserNode*)[stack lastObject] addChild:node];
                [stack addObject:node];
                [node release];
                
                for(NSUInteger i = 0; i < prefixLength; ++i) {
                    if((*(textBuffer + range.location + i) == '\n') || ((*(textBuffer + range.location + i) == '\r') && (*(textBuffer + range.location + i + 1) != '\n')))
                        ++currentLine;
                }
                
                node = [[ParserNodeMatch alloc] initWithText:text range:NSMakeRange(range.location, prefixLength)];
                node.lines = NSMakeRange(lastLine, currentLine - lastLine + 1);
                lastLine = currentLine;
                [(ParserNode*)[stack lastObject] addChild:node];
                [node release];
                
                range.location += prefixLength;
                range.length -= prefixLength;
            }
            continue;
        }
        
        ++rawLength;
        if(rawLength == range.length) {
            for(NSUInteger i = 0; i < rawLength; ++i) {
                if((*(textBuffer + range.location + i) == '\n') || ((*(textBuffer + range.location + i) == '\r') && (*(textBuffer + range.location + i + 1) != '\n')))
                    ++currentLine;
            }
            
            ParserNode* node = [[ParserNodeText alloc] initWithText:text range:range];
            node.lines = NSMakeRange(lastLine, currentLine - lastLine + 1);
            [(ParserNode*)[stack lastObject] addChild:node];
            [node release];
            break;
        }
    }
    
    [stack removeObjectAtIndex:0];
    if(stack.count > 0) {
        NSLog(@"Parser failed because some branch nodes are still opened at the end of the text:");
        for(ParserNode* node in stack)
            NSLog(@"\t%@", node);
        [rootNode release];
        return nil;
    }
    
    rootNode.lines = NSMakeRange(0, currentLine + 1);
    
    return rootNode;
}

static ParserNodeRoot* _NewNodeTreeFromText(id self, NSString* text, NSArray* nodeClasses, BOOL syntaxAnalysis) {
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    text = [text copy];
    NSRange range = NSMakeRange(0, text.length);
    unichar* buffer = malloc((range.length + 2) * sizeof(unichar));
    buffer[0] = 0x0000; //We need one-character padding at the start since some nodes look at buffer[index - 1]
    buffer[range.length + 1] = 0x0000; //We need one-character padding at the end since some nodes look at buffer[index + 1]
    [text getCharacters:(buffer + 1)];
    
    ParserNodeRoot* root;
    if([self isKindOfClass:[ParserLanguage class]])
        root = [[self parseText:text range:range textBuffer:(buffer + 1) syntaxAnalysis:syntaxAnalysis] retain];
    else
    	root = [self newNodeTreeFromText:text range:range textBuffer:(buffer + 1) withNodeClasses:nodeClasses];
    
    free(buffer);
    [text release];
    [pool drain];
    
    return root;
}

+ (ParserNodeRoot*) newNodeTreeFromText:(NSString*)text withNodeClasses:(NSArray*)nodeClasses {
	return _NewNodeTreeFromText(self, text, nodeClasses, NO);
}

//FIXME: Also check lines
static BOOL _CheckTreeConsistency(ParserNode* node, NSMutableArray* stack) {
    NSRange range = node.range;
    for(ParserNode* subnode in node.children) {
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

- (ParserNodeRoot*) parseText:(NSString*)text range:(NSRange)range textBuffer:(const unichar*)textBuffer syntaxAnalysis:(BOOL)syntaxAnalysis {
	ParserNodeRoot* rootNode = [[[self class] newNodeTreeFromText:text range:range textBuffer:textBuffer withNodeClasses:self.nodeClasses] autorelease];
    if(rootNode == nil)
    	return nil;
    rootNode.language = self;
    
    if(syntaxAnalysis) {
    	for(ParserLanguage* language in self.allLanguageDependencies) {
        	ParserNode* node = [language performSyntaxAnalysisForNode:rootNode textBuffer:textBuffer topLevelLanguage:self];
        	if(node) {
                void* params[3];
                params[0] = language;
                params[1] = (void*)textBuffer;
                params[2] = self;
                [node applyFunctionOnChildren:_ApplierFunction context:params];
            }
        }
    }
    
    NSMutableArray* stack = [NSMutableArray array];
    if(!_CheckTreeConsistency(rootNode, stack)) {
        NSLog(@"Parser failed because resulting tree is not consistent:\n%@\n%@", [[(ParserNode*)[stack objectAtIndex:0] parent] detailedDescription], stack);
        return nil;
    }
    
    return rootNode;
}

- (ParserNodeRoot*) parseText:(NSString*)text syntaxAnalysis:(BOOL)syntaxAnalysis {
    return [_NewNodeTreeFromText(self, text, nil, syntaxAnalysis) autorelease];
}

- (ParserNode*) performSyntaxAnalysisForNode:(ParserNode*)node textBuffer:(const unichar*)textBuffer topLevelLanguage:(ParserLanguage*)topLevelLanguage {
    return nil;
}

@end

@implementation ParserNodeRoot

@synthesize language=_language;

+ (BOOL) isAtomic {
    return NO;
}

- (id) copyWithZone:(NSZone*)zone {
	ParserNodeRoot* copy = [super copyWithZone:zone];
    if(copy)
    	copy->_language = _language;
    return copy;
}

- (BOOL) writeContentToFile:(NSString*)path encoding:(NSStringEncoding)encoding {
    return [[self content] writeToFile:path atomically:YES encoding:encoding error:NULL];
}

@end

@implementation ParserNodeText

+ (ParserNodeText*) parserNodeWithText:(NSString*)text {
    return [[[self alloc] initWithText:text] autorelease];
}

- (id) initWithText:(NSString*)text {
    if(text.length == 0)
        [NSException raise:NSInternalInconsistencyException format:@"Text cannot be empty"];
    
    return [self initWithText:text range:NSMakeRange(0, text.length)];
}

- (void) insertChild:(ParserNode*)child atIndex:(NSUInteger)index {
    [self doesNotRecognizeSelector:_cmd];
}

@end

@implementation ParserNodeMatch
@end

@implementation ParserNodeKeyword

+ (id) allocWithZone:(NSZone*)zone
{
    if(self == [ParserNodeKeyword class])
        [NSException raise:NSInternalInconsistencyException format:@"ParserNodeKeyword is an abstract class"];
    
    return [super allocWithZone:zone];
}

@end

@implementation ParserNode (ParserNodeTextExtensions)

- (void) replaceWithText:(NSString*)text {
    ParserNodeText* node = text.length ? [[ParserNodeText alloc] initWithText:text] : nil;
    [self replaceWithNode:node];
    [node release];
}

@end
