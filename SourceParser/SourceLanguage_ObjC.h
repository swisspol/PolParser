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

#import "SourceLanguage.h"

@interface SourceNodeObjCPreprocessorImport : SourceNodeCPreprocessor
@end

@interface SourceNodeObjCString : SourceNodeCStringDoubleQuote //Leaf
@end

@interface SourceNodeObjCInterface : SourceNode
@end

@interface SourceNodeObjCImplementation : SourceNode
@end

@interface SourceNodeObjCProtocol : SourceNode
@end

@interface SourceNodeObjCClass : SourceNode //Leaf
@end

@interface SourceNodeObjCPublic : SourceNode //Leaf
@end

@interface SourceNodeObjCProtected : SourceNode //Leaf
@end

@interface SourceNodeObjCPrivate : SourceNode //Leaf
@end

@interface SourceNodeObjCRequired : SourceNode //Leaf
@end

@interface SourceNodeObjCOptional : SourceNode //Leaf
@end

@interface SourceNodeObjCProperty : SourceNode
@end

@interface SourceNodeObjCSynthesize : SourceNode
@end

@interface SourceNodeObjCTry : SourceNode
@end

@interface SourceNodeObjCCatch : SourceNode
@end

@interface SourceNodeObjCFinally : SourceNode
@end

@interface SourceNodeObjCThrow : SourceNode
@end

@interface SourceNodeObjCSynchronized : SourceNode
@end

@interface SourceNodeObjCSelector : SourceNode
@end

@interface SourceNodeObjCEncode : SourceNode
@end

@interface SourceNodeObjCMethodDeclaration : SourceNode {
@private
	NSString* _name;
}
@end

@interface SourceNodeObjCMethodImplementation : SourceNode {
@private
	NSString* _name;
}
@end

@interface SourceNodeObjCMethodCall : SourceNode {
@private
	NSString* _name;
}
@end

/* Special Keywords */

@interface SourceNodeObjCNil : SourceNodeKeyword //Leaf
@end

@interface SourceNodeObjCSelf : SourceNodeKeyword //Leaf
@end

@interface SourceNodeObjCSuper : SourceNodeKeyword //Leaf
@end
