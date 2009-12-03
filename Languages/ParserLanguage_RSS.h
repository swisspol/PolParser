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

@interface ParserNodeRSSChannel : ParserNodeXMLElement
@end

@interface ParserNodeRSSItem : ParserNodeXMLElement
@end

@interface ParserNodeRSSCategory : ParserNodeXMLElement
@end

@interface ParserNodeRSSTitle : ParserNodeXMLElement
@end

@interface ParserNodeRSSLink : ParserNodeXMLElement
@end

@interface ParserNodeRSSDescription : ParserNodeXMLElement
@end

@interface ParserNodeRSSLanguage : ParserNodeXMLElement
@end

@interface ParserNodeRSSAuthor : ParserNodeXMLElement
@end

@interface ParserNodeRSSEnclosure : ParserNodeXMLElement
@end

@interface ParserNodeRSSGuid : ParserNodeXMLElement
@end

@interface ParserNodeAtomFeed : ParserNodeXMLElement
@end

@interface ParserNodeAtomEntry : ParserNodeXMLElement
@end

@interface ParserNodeAtomSubtitle : ParserNodeXMLElement
@end

@interface ParserNodeAtomID : ParserNodeXMLElement
@end

@interface ParserNodeAtomSummary : ParserNodeXMLElement
@end

@interface ParserNodeAtomName : ParserNodeXMLElement
@end

@interface ParserNodeAtomEmail : ParserNodeXMLElement
@end
