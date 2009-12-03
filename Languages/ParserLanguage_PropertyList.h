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

#import "ParserLanguage_XML.h"

@interface ParserNodePropertyList : ParserNodeXMLElement
@end

@interface ParserNodePropertyListDictionary : ParserNodeXMLElement
@end

@interface ParserNodePropertyListArray : ParserNodeXMLElement
@end

@interface ParserNodePropertyListKey : ParserNodeXMLElement //Leaf
@end

@interface ParserNodePropertyListString : ParserNodeXMLElement //Leaf
@end

@interface ParserNodePropertyListData : ParserNodeXMLElement //Leaf
@end

@interface ParserNodePropertyListDate : ParserNodeXMLElement //Leaf
@end

@interface ParserNodePropertyListTrue : ParserNodeXMLElement //Leaf
@end

@interface ParserNodePropertyListFalse : ParserNodeXMLElement //Leaf
@end

@interface ParserNodePropertyListReal : ParserNodeXMLElement //Leaf
@end

@interface ParserNodePropertyListInteger : ParserNodeXMLElement //Leaf
@end
