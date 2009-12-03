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

static IMP _nameMethod = NULL;
static IMP _cleanContentMethod = NULL;

@implementation ParserNode

@synthesize text=_text, range=_range, lines=_lines, parent=_parent, children=_children, revision=_revision, jsObject=_jsObject;

+ (void) initialize {
	if(self == [ParserNode class]) {
    	_nameMethod = [ParserNode instanceMethodForSelector:@selector(name)];
        _cleanContentMethod = [ParserNode instanceMethodForSelector:@selector(cleanContent)];
    }
}

+ (id) allocWithZone:(NSZone*)zone
{
    if(self == [ParserNode class])
        [NSException raise:NSInternalInconsistencyException format:@"ParserNode is an abstract class"];
    
    return [super allocWithZone:zone];
}

+ (NSArray*) patchedClasses {
	return nil;
}

+ (BOOL) isAtomic {
    return YES;
}

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return NSNotFound;
}

+ (NSString*) name {
    return [NSStringFromClass(self) substringFromIndex:[@"ParserNode" length]];
}

- (id) initWithText:(NSString*)text range:(NSRange)range {
    if((self = [super init])) {
        _text = [text copy];
        _range = range;
    }
    
    return self;
}

- (void) dealloc {
    for(ParserNode* node in _children)
        node.parent = nil;
    [_children release];
    
    [_text release];
    
    [super dealloc];
}

- (id) copyWithZone:(NSZone*)zone {
	ParserNode* copy = [[[self class] alloc] init];
    if(copy) {
    	copy->_text = [_text retain];
        copy->_range = _range;
        copy->_lines = _lines;
        //node->_parent = nil;
        //node->_children = nil;
        //node->_revision = 0;
        //node->_jsObject = NULL;
        for(ParserNode* node in _children) {
        	ParserNode* child = [node copyWithZone:zone];
            if(child) {
            	[copy addChild:child];
                [child release];
            } else {
                [copy release];
                return nil;
            }
        }
    }
    return copy;
}

- (NSMutableArray*) mutableChildren {
    return _children;
}

- (ParserNode*) firstChild {
    return [_children objectAtIndex:0];
}

- (ParserNode*) lastChild {
    return [_children objectAtIndex:(_children.count - 1)];
}

- (ParserNode*) previousSibling {
    if(_parent == nil)
        [NSException raise:NSInternalInconsistencyException format:@"%@ has no parent", self];
    
    NSArray* children = _parent.children;
    NSUInteger index = [children indexOfObject:self];
    return index > 0 ? [children objectAtIndex:(index - 1)] : nil;
}

- (ParserNode*) nextSibling {
    if(_parent == nil)
        [NSException raise:NSInternalInconsistencyException format:@"%@ has no parent", self];
    
    NSArray* children = _parent.children;
    NSUInteger index = [children indexOfObject:self];
    return index < children.count - 1 ? [children objectAtIndex:(index + 1)] : nil;
}

static void _MergeChildrenContent(ParserNode* node, NSMutableString* string) {
    for(node in node.children) {
        if(node.children)
            _MergeChildrenContent(node, string);
        else
            [string appendString:node.content];
    }
}

- (NSString*) content {
    if(_children) {
        NSMutableString* string = [NSMutableString stringWithCapacity:_range.length];
        _MergeChildrenContent(self, string);
        return string;
    }
    
    return [_text substringWithRange:_range];
}

static void _MergeChildrenCleanContent(ParserNode* node, NSMutableString* string) {
    for(node in node.children) {
        if(node.children)
            _MergeChildrenCleanContent(node, string);
        else
            [string appendString:node.cleanContent];
    }
}

- (NSString*) cleanContent {
    if(_children) {
        NSMutableString* string = [NSMutableString stringWithCapacity:_range.length];
        _MergeChildrenCleanContent(self, string);
        return string;
    }
    
    return self.content;
}

- (NSString*) name {
	return [[self class] name];
}

- (NSDictionary*) attributes {
    return nil;
}

- (void) addChild:(ParserNode*)child {
    [self insertChild:child atIndex:_children.count];
}

- (void) removeFromParent {
    if(_parent == nil)
        [NSException raise:NSInternalInconsistencyException format:@"%@ has no parent", self];
    
    [_parent removeChildAtIndex:[_parent indexOfChild:self]];
}

- (NSUInteger) indexOfChild:(ParserNode*)child {
    if(child.parent != self)
        [NSException raise:NSInternalInconsistencyException format:@"%@ is not a child of %@", child, self];
    
    return [_children indexOfObject:child];
}

- (void) insertChild:(ParserNode*)child atIndex:(NSUInteger)index {
    if(child.parent)
        [NSException raise:NSInternalInconsistencyException format:@"%@ already has a parent", child];
    
    if(_children == nil)
        _children = [[NSMutableArray alloc] init];
    
    [_children insertObject:child atIndex:index];
    child.parent = self;
}

- (void) removeChildAtIndex:(NSUInteger)index {
    ParserNode* node = [_children objectAtIndex:index];
    [node retain];
    node.parent = nil;
    [_children removeObjectAtIndex:index];
    [node autorelease];
    
    if(!_children.count) {
        [_children release];
        _children = nil;
    }
}

- (void) insertPreviousSibling:(ParserNode*)sibling {
    if(_parent == nil)
        [NSException raise:NSInternalInconsistencyException format:@"%@ has no parent", self];
    
    [_parent insertChild:sibling atIndex:[_parent indexOfChild:self]];
}

- (void) insertNextSibling:(ParserNode*)sibling {
    if(_parent == nil)
        [NSException raise:NSInternalInconsistencyException format:@"%@ has no parent", self];
    
    [_parent insertChild:sibling atIndex:([_parent indexOfChild:self] + 1)];
}

- (void) replaceWithNode:(ParserNode*)node {
    [self replaceWithNode:node preserveChildren:NO];
}

static ParserNode* _ApplierFunction(ParserNode* node, void* context) {
	[node removeFromParent];
	[(ParserNode*)context addChild:node];
    return nil;
}

- (void) replaceWithNode:(ParserNode*)node preserveChildren:(BOOL)preserveChildren {
    if(_parent == nil)
        [NSException raise:NSInternalInconsistencyException format:@"%@ has no parent", self];
    
    ParserNode* parent = _parent;
    NSUInteger index = [parent indexOfChild:self];
    [parent removeChildAtIndex:index];
    if(node) {
        [parent insertChild:node atIndex:index];
        if(preserveChildren)
        	[self applyFunctionOnChildren:_ApplierFunction context:node];
    }
}

- (ParserNode*) replaceWithNodeOfClass:(Class)class preserveChildren:(BOOL)preserveChildren {
    ParserNode* node = [[class alloc] initWithText:self.text range:self.range];
    node.lines = self.lines;
    [self replaceWithNode:node preserveChildren:preserveChildren];
    [node release];
    return node;
}

- (ParserNode*) findPreviousSiblingOfClass:(Class)class {
    ParserNode* node = self.previousSibling;
    while(node) {
        if([node isKindOfClass:class])
            return node;
        node = node.previousSibling;
    }
    return nil;
}

- (ParserNode*) findNextSiblingOfClass:(Class)class {
    ParserNode* node = self.nextSibling;
    while(node) {
        if([node isKindOfClass:class])
            return node;
        node = node.nextSibling;
    }
    return nil;
}

- (ParserNode*) findFirstChildOfClass:(Class)class {
	ParserNode* node = self.firstChild;
    while(node) {
        if([node isKindOfClass:class])
            return node;
        node = node.nextSibling;
    }
    return nil;
}

- (ParserNode*) findLastChildOfClass:(Class)class {
	ParserNode* node = self.lastChild;
    while(node) {
        if([node isKindOfClass:class])
            return node;
        node = node.previousSibling;
    }
    return nil;
}

- (NSUInteger) getDepthInParentsOfClass:(Class)class {
	NSUInteger depth = 0;
    ParserNode* node = self;
    while(node.parent) {
    	if(!class || [node.parent isKindOfClass:class])
        	++depth;
        node = node.parent;
    }
    return depth;
}

/* WARNING: Keep in sync with _ApplyBlock() */
static void _ApplyFunction(ParserNode* node, NSUInteger revision, ParserNodeApplierFunction function, void* context) {
    NSUInteger count = node.children.count;
    ParserNode* nodes[count];
    [node.children getObjects:nodes];
    
    for(NSUInteger i = 0; i < count; ++i) {
        if(nodes[i].parent) {
        	if(nodes[i].revision != revision) {
                nodes[i].revision = revision;
                nodes[i] = (*function)(nodes[i], context);
				if(nodes[i] == nil)
                	continue;
            }
            if(nodes[i].parent && nodes[i].children)
                _ApplyFunction(nodes[i], revision, function, context);
        }
    }
}

static NSUInteger _globalRevision = 0;

- (void) applyFunctionOnChildren:(ParserNodeApplierFunction)function context:(void*)context {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    if(_children)
    	_ApplyFunction(self, ++_globalRevision, function, context);
    [pool drain];
}

#if NS_BLOCKS_AVAILABLE

/* WARNING: Keep in sync with _ApplyFunction() */
static void _ApplyBlock(ParserNode* node, NSUInteger revision, void (^block)(ParserNode* node)) {
    NSUInteger count = node.children.count;
    ParserNode* nodes[count];
    [node.children getObjects:nodes];
    
    for(NSUInteger i = 0; i < count; ++i) {
        if(nodes[i].parent) {
        	if(nodes[i].revision != revision) {
                nodes[i].revision = revision;
                nodes[i] = block(nodes[i]);
				if(nodes[i] == nil)
                	continue;
            }
            if(nodes[i].parent && nodes[i].children)
				_ApplyBlock(nodes[i], revision, block);
        }
    }
}

- (void) enumerateChildrenUsingBlock:(BOOL (^)(ParserNode* node))block {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    if(_children)
    	_ApplyBlock(self, ++_globalRevision, block);
    [pool drain];
}

#endif

static NSString* _FormatString(NSString* string) {
    static NSString* spaceString = @"•"; //0x2022
    static NSString* tabString = @"→"; //0x2192
    static NSString* newlineString = @"¶"; //0x00B6
    string = [NSMutableString stringWithString:string];
    [(NSMutableString*)string replaceOccurrencesOfString:@" " withString:spaceString options:0 range:NSMakeRange(0, string.length)];
    [(NSMutableString*)string replaceOccurrencesOfString:@"\t" withString:tabString options:0 range:NSMakeRange(0, string.length)];
    [(NSMutableString*)string replaceOccurrencesOfString:@"\r\n" withString:newlineString options:0 range:NSMakeRange(0, string.length)];
    [(NSMutableString*)string replaceOccurrencesOfString:@"\r" withString:newlineString options:0 range:NSMakeRange(0, string.length)];
    [(NSMutableString*)string replaceOccurrencesOfString:@"\n" withString:newlineString options:0 range:NSMakeRange(0, string.length)];
    return string;
}

- (NSString*) contentDescription {
    return _FormatString(self.content);
}

static void _AppendChildrenCompactDescription(ParserNode* node, NSMutableString* string, NSString* prefix) {
    static NSString* separator = @"♢"; //0x2662
    prefix = [prefix stringByAppendingString:@"·  "]; //0x00B7
    [string appendFormat:@"<%@>\n", [[node class] name]];
    ParserNode* firstNode = node.firstChild;
    ParserNode* lastNode = node.lastChild;
    for(node in node.children) {
    	if(node.children) {
        	if(node == firstNode)
            	[string appendString:prefix];
            else
            	[string appendFormat:@"\n%@", prefix];
            _AppendChildrenCompactDescription(node, string, prefix);
            if((node != lastNode) && (node.nextSibling.children == nil))
            	[string appendFormat:@"\n%@%@", prefix, separator];
        } else {
        	if(node == firstNode)
            	[string appendFormat:@"%@%@", prefix, separator];
            if([node isMemberOfClass:[ParserNodeWhitespace class]] || [node isMemberOfClass:[ParserNodeNewline class]] || [node isMemberOfClass:[ParserNodeText class]])
                [string appendFormat:@"%@%@", _FormatString(node.content), separator];
            else
            	[string appendFormat:@"|%@|%@", _FormatString(node.content), separator];
        }
    }
}

- (NSString*) compactDescription {
	if(_children == nil)
    	return [self contentDescription];
    
    NSMutableString* string = [NSMutableString string];
    _AppendChildrenCompactDescription(self, string, @"");
    return string;
}

static void _AppendNodeFullDescription(ParserNode* node, NSMutableString* string, NSString* prefix) {
    static NSString* separator = @"♢"; //0x2662
    NSString* content = (node.children ? nil : _FormatString(node.content));
    if(content.length)
        [string appendFormat:@"%@[%i:%i] <%@> = %@%@%@\n", prefix, node.lines.location + 1, node.lines.location + node.lines.length, [[node class] name], separator, content, separator];
    else
        [string appendFormat:@"%@[%i:%i] <%@>\n", prefix, node.lines.location + 1, node.lines.location + node.lines.length, [[node class] name]];
    
    if([node methodForSelector:@selector(name)] != _nameMethod)
    	[string appendFormat:@"%@+ <name> = ♢%@♢\n", prefix, _FormatString(node.name)]; //0x2662
    
    if([node methodForSelector:@selector(cleanContent)] != _cleanContentMethod)
    	[string appendFormat:@"%@+ <cleaned> = ♢%@♢\n", prefix, _FormatString(node.cleanContent)]; //0x2662
    
    NSDictionary* attributes = node.attributes;
    if(attributes) {
    	for(NSString* name in attributes)
    		[string appendFormat:@"%@+ ♢%@♢ = ♢%@♢\n", prefix, name, _FormatString([attributes objectForKey:name])]; //0x2662
    }
    
    if(node.children) {
        prefix = [prefix stringByAppendingString:@"|    "];
        for(node in node.children)
            _AppendNodeFullDescription(node, string, prefix);
    }
}

- (NSString*) detailedDescription {
    NSMutableString* string = [NSMutableString string];
    _AppendNodeFullDescription(self, string, @"");
    [string deleteCharactersInRange:NSMakeRange(string.length - 1, 1)];
    return string;
}

- (NSString*) description {
    return [NSString stringWithFormat:@"<%@ = %p | characters = [%i, %i] | lines = [%i:%i]>", [self class], self, self.range.location, self.range.length, self.lines.location + 1, self.lines.location + self.lines.length];
}

@end
