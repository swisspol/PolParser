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

@implementation SourceNode

@synthesize source=_source, range=_range, parent=_parent, children=_children;

+ (id) allocWithZone:(NSZone*)zone
{
    if(self == [SourceNode class])
        [NSException raise:NSInternalInconsistencyException format:@"SourceNode is an abstract class"];
    
    return [super allocWithZone:zone];
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

static NSRange _LineNumbersForRange(NSString* string, NSRange range) {
    NSRange lines = NSMakeRange(0, 1);
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
    if(_lines.length == 0)
        _lines = _LineNumbersForRange(_source, _range);
        
    return _lines;
}

- (NSMutableArray*) mutableChildren {
    return _children;
}

- (SourceNode*) firstChild {
    return [_children objectAtIndex:0];
}

- (SourceNode*) lastChild {
    return [_children objectAtIndex:(_children.count - 1)];
}

- (SourceNode*) previousSibling {
    if(_parent == nil)
        [NSException raise:NSInternalInconsistencyException format:@"%@ has no parent", self];
    
    NSArray* children = _parent.children;
    NSUInteger index = [children indexOfObject:self];
    return index > 0 ? [children objectAtIndex:(index - 1)] : nil;
}

- (SourceNode*) nextSibling {
    if(_parent == nil)
        [NSException raise:NSInternalInconsistencyException format:@"%@ has no parent", self];
    
    NSArray* children = _parent.children;
    NSUInteger index = [children indexOfObject:self];
    return index < children.count - 1 ? [children objectAtIndex:(index + 1)] : nil;
}

static void _MergeChildrenContent(SourceNode* node, NSMutableString* string) {
    for(node in node.children) {
        if(node.children)
            _MergeChildrenContent(node, string);
        else
            [string appendString:[node.source substringWithRange:node.range]];
    }
}

- (NSString*) content {
    if(_children) {
        NSMutableString* string = [NSMutableString stringWithCapacity:_range.length];
        _MergeChildrenContent(self, string);
        return string;
    }
    
    return [_source substringWithRange:_range];
}

- (void) addChild:(SourceNode*)child {
    [self insertChild:child atIndex:_children.count];
}

- (void) removeFromParent {
    if(_parent == nil)
        [NSException raise:NSInternalInconsistencyException format:@"%@ has no parent", self];
    
    [_parent removeChildAtIndex:[_parent indexOfChild:self]];
}

- (NSUInteger) indexOfChild:(SourceNode*)child {
    if(child.parent != self)
        [NSException raise:NSInternalInconsistencyException format:@"%@ is not a child of %@", child, self];
    
    return [_children indexOfObject:child];
}

- (void) insertChild:(SourceNode*)child atIndex:(NSUInteger)index {
    if(child.parent)
        [NSException raise:NSInternalInconsistencyException format:@"%@ already has a parent", child];
    
    if(_children == nil)
        _children = [[NSMutableArray alloc] init];
    
    [_children insertObject:child atIndex:index];
    child.parent = self;
}

- (void) removeChildAtIndex:(NSUInteger)index {
    SourceNode* node = [_children objectAtIndex:index];
    [node retain];
    node.parent = nil;
    [_children removeObjectAtIndex:index];
    [node autorelease];
    
    if(!_children.count) {
        [_children release];
        _children = nil;
    }
}

- (void) insertPreviousSibling:(SourceNode*)sibling {
    if(_parent == nil)
        [NSException raise:NSInternalInconsistencyException format:@"%@ has no parent", self];
    
    [_parent insertChild:sibling atIndex:[_parent indexOfChild:self]];
}

- (void) insertNextSibling:(SourceNode*)sibling {
    if(_parent == nil)
        [NSException raise:NSInternalInconsistencyException format:@"%@ has no parent", self];
    
    [_parent insertChild:sibling atIndex:([_parent indexOfChild:self] + 1)];
}

- (void) replaceWithNode:(SourceNode*)node {
    if(_parent == nil)
        [NSException raise:NSInternalInconsistencyException format:@"%@ has no parent", self];
    
    SourceNode* parent = _parent;
    NSUInteger index = [parent indexOfChild:self];
    [parent removeChildAtIndex:index];
    if(node)
        [parent insertChild:node atIndex:index];
}

- (BOOL) hasParentOfClass:(Class)class {
    SourceNode* node = _parent;
    while(node) {
        if([node isKindOfClass:class])
            return YES;
        node = node.parent;
    }
    return NO;
}

- (SourceNode*) findPreviousSiblingOfClass:(Class)class {
    SourceNode* node = self.previousSibling;
    while(node) {
        if([node isKindOfClass:class])
            return node;
        node = node.previousSibling;
    }
    return nil;
}

- (SourceNode*) findNextSiblingOfClass:(Class)class {
    SourceNode* node = self.nextSibling;
    while(node) {
        if([node isKindOfClass:class])
            return node;
        node = node.nextSibling;
    }
    return nil;
}

#if NS_BLOCKS_AVAILABLE
static void _ApplyBlock(SourceNode* node, BOOL recursive, void (^block)(SourceNode* node))
#else
static void _ApplyFunction(SourceNode* node, SourceNodeApplierFunction function, void* context, BOOL recursive)
#endif
{
    NSUInteger count = node.children.count;
    SourceNode* nodes[count];
    [node.children getObjects:nodes];
    
    for(NSUInteger i = 0; i < count; ++i) {
        if(nodes[i].parent == node) {
#if NS_BLOCKS_AVAILABLE
            block(nodes[i]);
#else
			(*function)(nodes[i], context);
#endif
            if((nodes[i].parent == node) && nodes[i].children && recursive)
#if NS_BLOCKS_AVAILABLE
				_ApplyBlock(nodes[i], recursive, block);
#else
                _ApplyFunction(nodes[i], function, context, recursive);        
#endif
        }
    }
}

- (void) applyFunctionOnChildren:(SourceNodeApplierFunction)function context:(void*)context recursively:(BOOL)recursively {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    _ApplyFunction(self, function, context, recursively);
    [pool drain];
}

#if NS_BLOCKS_AVAILABLE

- (void) enumerateChildrenRecursively:(BOOL)recursively usingBlock:(void (^)(SourceNode* node))block {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    _ApplyBlock(self, recursively, block);
    [pool drain];
}

#endif

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
        [string appendFormat:@"%@[%i:%i] <%@> = |%@|\n", prefix, node.lines.location + 1, node.lines.location + node.lines.length, [[node class] name], content];
    else
        [string appendFormat:@"%@[%i:%i] <%@>\n", prefix, node.lines.location + 1, node.lines.location + node.lines.length, [[node class] name]];
    
    prefix = [prefix stringByAppendingString:@"\t"];
    for(node in [node children])
        _AppendNodeDescription(node, string, prefix);
}

- (NSString*) fullDescription {
    NSMutableString*    string = [NSMutableString string];
    _AppendNodeDescription(self, string, @"");
    return string;
}

- (NSString*) description {
    return [NSString stringWithFormat:@"<%@ = %p | characters = [%i, %i] | lines = [%i:%i]>\n%@", [self class], self, self.range.location, self.range.length, self.lines.location + 1, self.lines.location + self.lines.length, [self isKindOfClass:[SourceNodeRoot class]] ? self.fullDescription : self.miniDescription];
}

@end
