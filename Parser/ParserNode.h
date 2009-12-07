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

@class ParserNode;

typedef ParserNode* (*ParserNodeApplierFunction)(ParserNode* node, void* context); //Return a node whose children to process for recursive operations

/* Abstract class: do not instantiate */
@interface ParserNode : NSObject <NSCopying> {
@private
    NSString* _text;
    NSRange _range;
    NSRange _lines;
    ParserNode* _parent;
    NSMutableArray* _children;
    NSUInteger _revision;
    void* _jsObject;
}
+ (NSString*) name;

@property(nonatomic, readonly) NSString* text;
@property(nonatomic, readonly) NSRange range;
@property(nonatomic, readonly) NSRange lines;
@property(nonatomic, readonly) NSString* content;

@property(nonatomic, readonly) NSString* name; //A name for the node whose definition depends on the node class - returns +name by default
@property(nonatomic, readonly) NSDictionary* attributes; //A dictionary of attributes whose definition depends on the node class - returns nil by default
@property(nonatomic, readonly) NSString* cleanContent; //A clean version of "content" whose definition depends on the node class - returns "content" by default

@property(nonatomic, readonly) ParserNode* parent;
@property(nonatomic, readonly) NSArray* children;
@property(nonatomic, readonly) ParserNode* firstChild;
@property(nonatomic, readonly) ParserNode* lastChild;
@property(nonatomic, readonly) ParserNode* previousSibling;
@property(nonatomic, readonly) ParserNode* nextSibling;

@property(nonatomic, readonly) NSString* contentDescription; //Like "content" but with whitespace and newline replaced with special characters
@property(nonatomic, readonly) NSString* compactDescription;
@property(nonatomic, readonly) NSString* detailedDescription;

- (void) addChild:(ParserNode*)child;
- (void) removeFromParent;
- (NSUInteger) indexOfChild:(ParserNode*)child;
- (void) insertChild:(ParserNode*)child atIndex:(NSUInteger)index;
- (void) removeChildAtIndex:(NSUInteger)index;
- (void) insertPreviousSibling:(ParserNode*)sibling;
- (void) insertNextSibling:(ParserNode*)sibling;
- (void) replaceWithNode:(ParserNode*)node;
- (void) replaceWithNode:(ParserNode*)node preserveChildren:(BOOL)preserveChildren; //Replaces self by "node" (passing nil just removes the node from the tree)

- (ParserNode*) findPreviousSiblingOfClass:(Class)class;
- (ParserNode*) findNextSiblingOfClass:(Class)class;
- (ParserNode*) findFirstChildOfClass:(Class)class;
- (ParserNode*) findLastChildOfClass:(Class)class;
- (ParserNode*) findPreviousSiblingOfAnyClass:(NSSet*)classes;
- (ParserNode*) findNextSiblingOfAnyClass:(NSSet*)classes;
- (ParserNode*) findFirstChildOfAnyClass:(NSSet*)classes;
- (ParserNode*) findLastChildOfAnyClass:(NSSet*)classes;
- (NSUInteger) getDepthInParentsOfClass:(Class)class; //Passing nil returns the absolute depth

- (void) applyFunctionOnChildren:(ParserNodeApplierFunction)function context:(void*)context;
#if NS_BLOCKS_AVAILABLE
- (void) enumerateChildrenUsingBlock:(ParserNode* (^)(ParserNode* node))block;
#endif
@end
