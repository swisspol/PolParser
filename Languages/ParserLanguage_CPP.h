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

@interface ParserNodeCPPComment : ParserNode //Leaf
@end

@interface ParserNodeCPPNamespace : ParserNode
@end

@interface ParserNodeCPPClass : ParserNode
@end

@interface ParserNodeCPPPublic : ParserNode
@end

@interface ParserNodeCPPProtected : ParserNode
@end

@interface ParserNodeCPPPrivate : ParserNode
@end

@interface ParserNodeCPPUsing : ParserNode //Leaf
@end

@interface ParserNodeCPPVirtual : ParserNode //Leaf
@end

@interface ParserNodeCPPTry : ParserNode
@end

@interface ParserNodeCPPCatch : ParserNode
@end

@interface ParserNodeCPPThrow : ParserNode
@end

@interface ParserNodeCPPNew : ParserNode
@end

@interface ParserNodeCPPDelete : ParserNode
@end

@interface ParserNodeCPPFunctionCall : ParserNode
@end

@interface ParserNodeCPPTypeId : ParserNode
@end

/* Special Keywords */

@interface ParserNodeCPPAnd : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPAndEq : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPAsm : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPBitAnd : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPBitOr : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPBool : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPCompl : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPConstCast : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPDynamicCast : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPExplicit : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPExport : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPFalse : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPFriend : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPMutable : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPNot : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPNotEq : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPOperator : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPOr : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPOrEq : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPReinterpretCast : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPStaticCast : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPTemplate : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPThis : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPTrue : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPTypename : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPWCharT : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPXor : ParserNodeKeyword //Leaf
@end

@interface ParserNodeCPPXorEq : ParserNodeKeyword //Leaf
@end
