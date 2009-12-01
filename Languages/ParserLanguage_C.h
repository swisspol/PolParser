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

@interface ParserNodeCComment : ParserNode //Leaf
@end

/* Abstract class: do not instantiate */
@interface ParserNodeCPreprocessor : ParserNode
@end

/* Abstract class: do not instantiate */
@interface ParserNodeCPreprocessorCondition : ParserNodeCPreprocessor
@end

@interface ParserNodeCPreprocessorConditionIf : ParserNodeCPreprocessorCondition
@end

@interface ParserNodeCPreprocessorConditionIfdef : ParserNodeCPreprocessorCondition
@end

@interface ParserNodeCPreprocessorConditionIfndef : ParserNodeCPreprocessorCondition
@end

@interface ParserNodeCPreprocessorConditionElse : ParserNodeCPreprocessorCondition
@end

@interface ParserNodeCPreprocessorConditionElseif : ParserNodeCPreprocessorCondition
@end

@interface ParserNodeCPreprocessorDefine : ParserNodeCPreprocessor {
@private
	NSString* _name;
}
@end

@interface ParserNodeCPreprocessorUndefine : ParserNodeCPreprocessor {
@private
	NSString* _name;
}
@end

@interface ParserNodeCPreprocessorPragma : ParserNodeCPreprocessor {
@private
	NSString* _name;
}
@end

@interface ParserNodeCPreprocessorWarning : ParserNodeCPreprocessor {
@private
	NSString* _name;
}
@end

@interface ParserNodeCPreprocessorError : ParserNodeCPreprocessor {
@private
	NSString* _name;
}
@end

@interface ParserNodeCPreprocessorInclude : ParserNodeCPreprocessor {
@private
	NSString* _name;
}
@end

@interface ParserNodeCStringSingleQuote : ParserNode //Leaf
@end

@interface ParserNodeCStringDoubleQuote : ParserNode //Leaf
@end

@interface ParserNodeCConditionalOperator : ParserNode
@end

@interface ParserNodeCConditionIf : ParserNode
@end

@interface ParserNodeCConditionElse : ParserNode
@end

@interface ParserNodeCConditionElseIf : ParserNode
@end

@interface ParserNodeCFlowBreak : ParserNode //Leaf
@end

@interface ParserNodeCFlowContinue : ParserNode //Leaf
@end

@interface ParserNodeCFlowSwitch : ParserNode
@end

@interface ParserNodeCFlowCase : ParserNode
@end

@interface ParserNodeCFlowDefault : ParserNode
@end

@interface ParserNodeCFlowFor : ParserNode
@end

@interface ParserNodeCFlowDoWhile : ParserNode
@end

@interface ParserNodeCFlowWhile : ParserNode
@end

@interface ParserNodeCFlowGoto : ParserNode
@end

@interface ParserNodeCFlowLabel : ParserNode
@end

@interface ParserNodeCFlowReturn : ParserNode //Leaf
@end

@interface ParserNodeCTypedef : ParserNode //Leaf
@end

@interface ParserNodeCTypeEnum : ParserNode //Leaf
@end

@interface ParserNodeCTypeStruct : ParserNode
@end

@interface ParserNodeCTypeUnion : ParserNode
@end

@interface ParserNodeCSizeOf : ParserNode
@end

@interface ParserNodeCTypeOf : ParserNode
@end

@interface ParserNodeCFunctionPrototype : ParserNode
@end

@interface ParserNodeCFunctionDefinition : ParserNode
@end

@interface ParserNodeCFunctionCall : ParserNode
@end

/* Special Keywords */

@interface ParserNodeCNULL : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCVoid : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCAuto : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCStatic : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCRegister : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCVolatile : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCConst : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCExtern : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCInline : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCSigned : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCUnsigned : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCChar : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCShort : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCInt : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCLong : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCFloat : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCDouble : ParserNodeKeyword //Leaf
@end

/* Special Tokens */

@interface ParserNodeColon : ParserNodeToken //Leaf
@end

@interface ParserNodeSemicolon : ParserNodeToken //Leaf
@end

@interface ParserNodeQuestionMark : ParserNodeToken //Leaf
@end

@interface ParserNodeExclamationMark : ParserNodeToken //Leaf
@end

@interface ParserNodeTilda : ParserNodeToken //Leaf
@end

@interface ParserNodeCaret : ParserNodeToken //Leaf
@end

@interface ParserNodeAmpersand : ParserNodeToken //Leaf
@end

@interface ParserNodeAsterisk : ParserNodeToken //Leaf
@end
