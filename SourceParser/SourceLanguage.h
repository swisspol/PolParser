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

@class SourceNodeRoot;

/* Abstract class: do not instantiate */
@interface SourceLanguage : NSObject
+ (NSSet*) allLanguages;
+ (SourceLanguage*) languageForName:(NSString*)name;
+ (SourceNodeRoot*) parseSourceFile:(NSString*)path;

@property(nonatomic, readonly) NSString* name;
@property(nonatomic, readonly) NSSet* fileExtensions;
@property(nonatomic, readonly) NSArray* nodeClasses;

- (SourceNodeRoot*) parseSourceString:(NSString*)source; //Expects Unix line-endings
@end

@interface SourceNodeRoot : SourceNode {
@private
	SourceLanguage* _language;
}
@property(nonatomic, readonly) SourceLanguage* language;

- (BOOL) writeContentToFile:(NSString*)path;
@end

@interface SourceNodeText : SourceNode //Leaf
- (id) initWithText:(NSString*)text;
@end

@interface SourceNode (SourceNodeTextExtensions)
- (void) replaceWithText:(NSString*)text; //Replaces self by a SourceNodeText instance with the given text (passing an empty text just deletes the node)
@end
