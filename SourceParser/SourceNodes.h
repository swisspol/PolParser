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

#import "SourceParser.h"

@interface SourceNodeWhitespace : SourceNode //Leaf
@end

@interface SourceNodeIndenting : SourceNodeWhitespace //Leaf
@end

@interface SourceNodeBraces : SourceNode
@end

@interface SourceNodeParenthesis : SourceNode
@end

@interface SourceNodeBrackets : SourceNode
@end