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

@interface ParserNode (ParserLanguageExtensions)
- (ParserNode*) findPreviousSiblingIgnoringWhitespaceAndNewline;
- (ParserNode*) findNextSiblingIgnoringWhitespaceAndNewline;
@end

/* This class cannot have children */
@interface ParserNodeWhitespace : ParserNode
@end

/* This class cannot have children */
@interface ParserNodeIndenting : ParserNodeWhitespace
@end

/* This class cannot have children */
@interface ParserNodeNewline : ParserNode
@end

@interface ParserNodeBraces : ParserNode
@end

@interface ParserNodeParenthesis : ParserNode
@end

@interface ParserNodeBrackets : ParserNode
@end

/* Abstract class: do not instantiate */
@interface ParserNodeToken : ParserNodeText //Leaf
@end

@interface ParserNodeColon : ParserNodeToken //Leaf
@end

@interface ParserNodeSemicolon : ParserNodeToken //Leaf
@end

@interface ParserNodeQuestionMark : ParserNodeToken //Leaf
@end

@interface ParserNodeExclamationMark : ParserNodeToken //Leaf
@end

@interface ParserNodeVerticalBar : ParserNodeToken //Leaf
@end

@interface ParserNodeTilde : ParserNodeToken //Leaf
@end

@interface ParserNodeCaret : ParserNodeToken //Leaf
@end

@interface ParserNodeAmpersand : ParserNodeToken //Leaf
@end

@interface ParserNodeAsterisk : ParserNodeToken //Leaf
@end

@interface ParserNodeDoubleSemicolon : ParserNodeToken //Leaf
@end

@interface ParserNodeComma : ParserNodeToken //Leaf
@end

@interface ParserNodeEqual : ParserNodeToken //Leaf
@end

@interface ParserNodePound : ParserNodeToken //Leaf
@end

@interface ParserNodeDot : ParserNodeToken //Leaf
@end

@interface ParserNodeArrow : ParserNodeToken //Leaf
@end
