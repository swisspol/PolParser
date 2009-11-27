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

#import "SourceNode.h"

/* IMPORTANT REQUIREMENTS:
- The source must have Unix line-endings
- The source is assumed to compile
*/

@class SourceNodeRoot;

/* Abstract class: do not instantiate */
@interface SourceLanguage : NSObject {
@private
	NSMutableSet* _keywords;
	NSMutableArray* _nodeClasses;
    NSMutableSet* _topLevelClasses;
}
+ (NSSet*) allLanguages;
+ (SourceLanguage*) languageWithName:(NSString*)name;
+ (SourceLanguage*) defaultLanguageForFileExtension:(NSString*)extension;
+ (SourceNodeRoot*) parseSourceFile:(NSString*)path encoding:(NSStringEncoding)encoding syntaxAnalysis:(BOOL)syntaxAnalysis;

@property(nonatomic, readonly) NSString* name;
@property(nonatomic, readonly) NSSet* fileExtensions;
@property(nonatomic, readonly) NSSet* reservedKeywords;
@property(nonatomic, readonly) NSArray* nodeClasses;

- (SourceNodeRoot*) parseSourceString:(NSString*)source syntaxAnalysis:(BOOL)syntaxAnalysis;
@end

@interface SourceNodeRoot : SourceNode {
@private
    SourceLanguage* _language;
}
@property(nonatomic, readonly) SourceLanguage* language;

- (BOOL) writeContentToFile:(NSString*)path encoding:(NSStringEncoding)encoding;
@end

@interface SourceNodeText : SourceNode //Leaf
+ (SourceNodeText*) sourceNodeWithText:(NSString*)text;
- (id) initWithText:(NSString*)text;
@end

/* Abstract class: do not instantiate */
@interface SourceNodeKeyword : SourceNodeText //Leaf
@end

/* Abstract class: do not instantiate */
@interface SourceNodeToken : SourceNodeText //Leaf
@end

@interface SourceNodeMatch : SourceNodeText //Leaf
@end

@interface SourceNode (SourceNodeTextExtensions)
- (void) replaceWithText:(NSString*)text; //Replaces self by a SourceNodeText instance with the given text (passing an empty text just removes the node from the tree)
@end
