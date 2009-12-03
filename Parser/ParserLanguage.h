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

#import "ParserNode.h"

@class ParserNodeRoot;

/* Abstract class: do not instantiate */
@interface ParserLanguage : NSObject <NSCopying> {
@private
	NSMutableSet* _keywords;
	NSMutableArray* _nodeClasses;
}
+ (NSSet*) allLanguages;
+ (ParserLanguage*) languageWithName:(NSString*)name;
+ (ParserLanguage*) defaultLanguageForFileExtension:(NSString*)extension;
+ (ParserNodeRoot*) parseTextFile:(NSString*)path encoding:(NSStringEncoding)encoding syntaxAnalysis:(BOOL)syntaxAnalysis;

@property(nonatomic, readonly) NSString* name;
@property(nonatomic, readonly) NSSet* fileExtensions;
@property(nonatomic, readonly) NSSet* reservedKeywords;
@property(nonatomic, readonly) NSArray* nodeClasses;

- (ParserNodeRoot*) parseText:(NSString*)text syntaxAnalysis:(BOOL)syntaxAnalysis;
@end

@interface ParserNodeRoot : ParserNode {
@private
    ParserLanguage* _language;
}
@property(nonatomic, readonly) ParserLanguage* language;

- (BOOL) writeContentToFile:(NSString*)path encoding:(NSStringEncoding)encoding;
@end

/* This class cannot have children */
@interface ParserNodeText : ParserNode //Leaf
+ (ParserNodeText*) parserNodeWithText:(NSString*)text;
- (id) initWithText:(NSString*)text;
@end

/* Abstract class: do not instantiate */
@interface ParserNodeKeyword : ParserNodeText //Leaf
@end

/* Abstract class: do not instantiate */
@interface ParserNodeToken : ParserNodeText //Leaf
@end

@interface ParserNodeMatch : ParserNodeText //Leaf
@end

@interface ParserNode (ParserNodeTextExtensions)
- (void) replaceWithText:(NSString*)text; //Replaces self by a ParserNodeText instance with the given text (passing an empty text just removes the node from the tree)
@end
