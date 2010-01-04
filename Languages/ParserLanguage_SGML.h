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

#import "ParserLanguage.h"

@interface ParserNodeSGMLTag : ParserNode { //Leaf
@private
    NSInteger _type;
    NSString* _name;
    NSDictionary* _attributes;
}
@end

@interface ParserNodeSGMLDOCTYPE : ParserNode //Leaf
@end

@interface ParserNodeSGMLComment : ParserNode //Leaf
@end

@interface ParserNodeSGMLCDATA : ParserNode //Leaf
@end

@interface ParserNodeSGMLEntity : ParserNode //Leaf
@end

@interface ParserNodeSGMLElement : ParserNode
@end
