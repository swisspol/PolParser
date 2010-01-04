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

#import "ParserLanguage_C.h"
#import "ParserLanguage_CPP.h" //For C++ comments

@interface ParserNodeObjCPreprocessorImport : ParserNodeCPreprocessor {
@private
    NSString* _name;
}
@end

@interface ParserNodeObjCString : ParserNodeCString //Leaf
@end

@interface ParserNodeObjCInterface : ParserNode
@end

@interface ParserNodeObjCImplementation : ParserNode
@end

@interface ParserNodeObjCProtocol : ParserNode
@end

@interface ParserNodeObjCClass : ParserNode //Leaf
@end

@interface ParserNodeObjCPublic : ParserNode //Leaf
@end

@interface ParserNodeObjCProtected : ParserNode //Leaf
@end

@interface ParserNodeObjCPrivate : ParserNode //Leaf
@end

@interface ParserNodeObjCRequired : ParserNode //Leaf
@end

@interface ParserNodeObjCOptional : ParserNode //Leaf
@end

@interface ParserNodeObjCProperty : ParserNode
@end

@interface ParserNodeObjCSynthesize : ParserNode
@end

@interface ParserNodeObjCTry : ParserNode
@end

@interface ParserNodeObjCCatch : ParserNode
@end

@interface ParserNodeObjCFinally : ParserNode
@end

@interface ParserNodeObjCThrow : ParserNode
@end

@interface ParserNodeObjCSynchronized : ParserNode
@end

@interface ParserNodeObjCSelector : ParserNode
@end

@interface ParserNodeObjCEncode : ParserNode
@end

@interface ParserNodeObjCMethodDeclaration : ParserNode {
@private
    NSString* _name;
}
@end

@interface ParserNodeObjCMethodImplementation : ParserNode {
@private
    NSString* _name;
}
@end

@interface ParserNodeObjCMethodCall : ParserNode {
@private
    NSString* _name;
}
@end

/* Special Keywords */

@interface ParserNodeObjCNil : ParserNodeKeyword //Leaf
@end

@interface ParserNodeObjCSelf : ParserNodeKeyword //Leaf
@end

@interface ParserNodeObjCSuper : ParserNodeKeyword //Leaf
@end
