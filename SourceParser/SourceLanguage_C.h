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

@interface SourceNodeCComment : SourceNode //Leaf
@end

/* Abstract class: do not instantiate */
@interface SourceNodeCPreprocessor : SourceNode
@end

/* Abstract class: do not instantiate */
@interface SourceNodeCPreprocessorCondition : SourceNodeCPreprocessor
@end

@interface SourceNodeCPreprocessorConditionIf : SourceNodeCPreprocessorCondition
@end

@interface SourceNodeCPreprocessorConditionIfdef : SourceNodeCPreprocessorCondition
@end

@interface SourceNodeCPreprocessorConditionIfndef : SourceNodeCPreprocessorCondition
@end

@interface SourceNodeCPreprocessorConditionElse : SourceNodeCPreprocessorCondition
@end

@interface SourceNodeCPreprocessorConditionElseif : SourceNodeCPreprocessorCondition
@end

@interface SourceNodeCPreprocessorDefine : SourceNodeCPreprocessor
@end

@interface SourceNodeCPreprocessorUndefine : SourceNodeCPreprocessor
@end

@interface SourceNodeCPreprocessorPragma : SourceNodeCPreprocessor
@end

@interface SourceNodeCPreprocessorWarning : SourceNodeCPreprocessor
@end

@interface SourceNodeCPreprocessorError : SourceNodeCPreprocessor
@end

@interface SourceNodeCPreprocessorInclude : SourceNodeCPreprocessor
@end

@interface SourceNodeCStringSingleQuote : SourceNode //Leaf
@end

@interface SourceNodeCStringDoubleQuote : SourceNode //Leaf
@end

@interface SourceNodeCFlowIf : SourceNode
@end

@interface SourceNodeCFlowElse : SourceNode
@end

@interface SourceNodeCFlowBreak : SourceNode //Leaf
@end

@interface SourceNodeCFlowContinue : SourceNode //Leaf
@end

@interface SourceNodeCFlowSwitch : SourceNode
@end

@interface SourceNodeCFlowCase : SourceNode //Leaf
@end

@interface SourceNodeCFlowDefault : SourceNode //Leaf
@end

@interface SourceNodeCFlowFor : SourceNode
@end

@interface SourceNodeCFlowDoWhile : SourceNode
@end

@interface SourceNodeCFlowWhile : SourceNode
@end

@interface SourceNodeCFlowGoto : SourceNode
@end

@interface SourceNodeCFlowReturn : SourceNode //Leaf
@end

@interface SourceNodeCTypedef : SourceNode //Leaf
@end

@interface SourceNodeCTypeStruct : SourceNode
@end

@interface SourceNodeCTypeUnion : SourceNode
@end

@interface SourceNodeCTypeAuto : SourceNode //Leaf
@end

@interface SourceNodeCTypeStatic : SourceNode //Leaf
@end

@interface SourceNodeCTypeRegister : SourceNode //Leaf
@end

@interface SourceNodeCTypeVolatile : SourceNode //Leaf
@end

@interface SourceNodeCTypeConst : SourceNode //Leaf
@end

@interface SourceNodeCTypeEnum : SourceNode //Leaf
@end

@interface SourceNodeCTypeExtern : SourceNode //Leaf
@end

@interface SourceNodeCTypeSizeOf : SourceNode
@end

@interface SourceNodeCFunctionPrototype : SourceNode
@end

@interface SourceNodeCFunctionDefinition : SourceNode
@end
