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

@interface SourceNodeXMLTag : SourceNode {
@private
	NSUInteger _type;
    NSString* _name;
    NSDictionary* _attributes;
}
@end

@interface SourceNodeXMLDeclaration : SourceNode {
@private
	NSDictionary* _attributes;
}
@end

@interface SourceNodeXMLProcessingInstructions : SourceNode
@end

@interface SourceNodeXMLDOCTYPE : SourceNode
@end

@interface SourceNodeXMLComment : SourceNode //Leaf
@end

@interface SourceNodeXMLCDATA : SourceNode //Leaf
@end

@interface SourceNodeXMLEntity : SourceNode //Leaf
@end

@interface SourceNodeXMLElement : SourceNode
@end
