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

#import <Foundation/Foundation.h>

@class SourceNode;

typedef void (*SourceNodeApplierFunction)(SourceNode* node, void* context);

/* Abstract class: do not instantiate */
@interface SourceNode : NSObject {
@private
    NSString* _source;
    NSRange _range;
    NSRange _lines;
    SourceNode* _parent;
    NSMutableArray* _children;
    NSUInteger _revision;
}
+ (NSString*) name;

@property(nonatomic, readonly) NSString* source;
@property(nonatomic, readonly) NSRange range;
@property(nonatomic, readonly) NSRange lines;
@property(nonatomic, readonly) NSString* content;

@property(nonatomic, readonly) SourceNode* parent;
@property(nonatomic, readonly) NSArray* children;
@property(nonatomic, readonly) SourceNode* firstChild;
@property(nonatomic, readonly) SourceNode* lastChild;
@property(nonatomic, readonly) SourceNode* previousSibling;
@property(nonatomic, readonly) SourceNode* nextSibling;

@property(nonatomic, readonly) NSString* miniDescription;
@property(nonatomic, readonly) NSString* fullDescription;

- (void) addChild:(SourceNode*)child;
- (void) removeFromParent;
- (NSUInteger) indexOfChild:(SourceNode*)child;
- (void) insertChild:(SourceNode*)child atIndex:(NSUInteger)index;
- (void) removeChildAtIndex:(NSUInteger)index;
- (void) insertPreviousSibling:(SourceNode*)sibling;
- (void) insertNextSibling:(SourceNode*)sibling;
- (void) replaceWithNode:(SourceNode*)node; //Replaces self by "node" (passing nil just removes the node from the tree)

- (BOOL) hasParentOfClass:(Class)class;
- (SourceNode*) findPreviousSiblingOfClass:(Class)class;
- (SourceNode*) findNextSiblingOfClass:(Class)class;

- (void) applyFunctionOnChildren:(SourceNodeApplierFunction)function context:(void*)context recursively:(BOOL)recursively;
#if NS_BLOCKS_AVAILABLE
- (void) enumerateChildrenRecursively:(BOOL)recursively usingBlock:(void (^)(SourceNode* node))block;
#endif
@end
