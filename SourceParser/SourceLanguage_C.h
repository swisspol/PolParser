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

#import "SourceLanguage_Base.h"

@interface SourceNodeCommentC : SourceNode //Leaf
@end

/* Abstract class: do not instantiate */
@interface SourceNodePreprocessor : SourceNode
@end

/* Abstract class: do not instantiate */
@interface SourceNodePreprocessorCondition : SourceNodePreprocessor
@end

@interface SourceNodePreprocessorConditionIf : SourceNodePreprocessorCondition
@end

@interface SourceNodePreprocessorConditionIfdef : SourceNodePreprocessorCondition
@end

@interface SourceNodePreprocessorConditionIfndef : SourceNodePreprocessorCondition
@end

@interface SourceNodePreprocessorConditionElse : SourceNodePreprocessorCondition
@end

@interface SourceNodePreprocessorConditionElseif : SourceNodePreprocessorCondition
@end

@interface SourceNodePreprocessorDefine : SourceNodePreprocessor
@end

@interface SourceNodePreprocessorUndefine : SourceNodePreprocessor
@end

@interface SourceNodePreprocessorPragma : SourceNodePreprocessor
@end

@interface SourceNodePreprocessorInclude : SourceNodePreprocessor
@end

@interface SourceNodeColon : SourceNode //Leaf
@end

@interface SourceNodeSemicolon : SourceNode //Leaf
@end

@interface SourceNodeQuestionMark : SourceNode //Leaf
@end

@interface SourceNodeExclamationMark : SourceNode //Leaf
@end

@interface SourceNodeTilda : SourceNode //Leaf
@end

@interface SourceNodeCaret : SourceNode //Leaf
@end

@interface SourceNodeAmpersand : SourceNode //Leaf
@end

@interface SourceNodeAsterisk : SourceNode //Leaf
@end

@interface SourceNodeStringSingleQuote : SourceNode //Leaf
@end

@interface SourceNodeStringDoubleQuote : SourceNode //Leaf
@end

@interface SourceNodeConditionIf : SourceNode //Leaf
@end

@interface SourceNodeConditionElse : SourceNode //Leaf
@end

@interface SourceNodeFlowBreak : SourceNode //Leaf
@end

@interface SourceNodeFlowContinue : SourceNode //Leaf
@end

@interface SourceNodeFlowSwitch : SourceNode //Leaf
@end

@interface SourceNodeFlowCase : SourceNode //Leaf
@end

@interface SourceNodeFlowDefault : SourceNode //Leaf
@end

@interface SourceNodeFlowFor : SourceNode //Leaf
@end

@interface SourceNodeFlowDo : SourceNode //Leaf
@end

@interface SourceNodeFlowWhile : SourceNode //Leaf
@end

@interface SourceNodeFlowGoto : SourceNode //Leaf
@end

@interface SourceNodeFlowReturn : SourceNode //Leaf
@end

@interface SourceNodeTypedef : SourceNode //Leaf
@end

@interface SourceNodeTypeStruct : SourceNode //Leaf
@end

@interface SourceNodeTypeUnion : SourceNode //Leaf
@end

@interface SourceNodeTypeAuto : SourceNode //Leaf
@end

@interface SourceNodeTypeStatic : SourceNode //Leaf
@end

@interface SourceNodeTypeRegister : SourceNode //Leaf
@end

@interface SourceNodeTypeVolatile : SourceNode //Leaf
@end

@interface SourceNodeTypeConst : SourceNode //Leaf
@end

@interface SourceNodeTypeEnum : SourceNode //Leaf
@end

@interface SourceNodeTypeExtern : SourceNode //Leaf
@end

@interface SourceNodeTypeSizeOf : SourceNode //Leaf
@end
