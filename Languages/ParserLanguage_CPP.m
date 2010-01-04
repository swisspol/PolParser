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

#import "Parser_Internal.h"
#import "ParserLanguage_CPP.h"

@interface ParserLanguageCPP : ParserLanguage <ParserLanguageCTopLevelNodeClasses>
@end

@implementation ParserLanguageCPP

+ (NSArray*) languageDependencies {
    return [NSArray arrayWithObject:@"C"];
}

+ (NSSet*) languageReservedKeywords {
    return [NSSet setWithObjects:@"class", @"public", @"protected", @"private", @"using", @"namespace", @"virtual",
        @"try", @"catch", @"throw", @"new", @"delete", @"typeid",
        @"and", @"and_eq", @"asm", @"bitand", @"bitor", @"bool", @"compl", @"const_cast", @"dynamic_cast", @"explicit", @"export",  //Not "true" keywords
        @"false", @"friend", @"mutable", @"not", @"not_eq", @"operator", @"or", @"or_eq", @"reinterpret_cast", @"static_cast", @"template", //Not "true" keywords
        @"this", @"true", @"typename", @"wchar_t", @"xor", @"xor_eq", nil]; //Not "true" keywords
}

+ (NSArray*) languageNodeClasses {
    NSMutableArray* classes = [NSMutableArray array];
    
    [classes addObject:[ParserNodeDoubleSemicolon class]];
    [classes addObject:[ParserNodeDot class]];
    [classes addObject:[ParserNodeArrow class]];
    
    [classes addObject:[ParserNodeCPPComment class]];
    [classes addObject:[ParserNodeCPPClass class]];
    [classes addObject:[ParserNodeCPPPublic class]];
    [classes addObject:[ParserNodeCPPProtected class]];
    [classes addObject:[ParserNodeCPPPrivate class]];
    [classes addObject:[ParserNodeCPPUsing class]];
    [classes addObject:[ParserNodeCPPNamespace class]];
    [classes addObject:[ParserNodeCPPVirtual class]];
    [classes addObject:[ParserNodeCPPTry class]];
    [classes addObject:[ParserNodeCPPCatch class]];
    [classes addObject:[ParserNodeCPPThrow class]];
    [classes addObject:[ParserNodeCPPTypeId class]];
    
    [classes addObject:[ParserNodeCPPFunctionCall class]];
    
    return classes;
}

+ (NSSet*) languageTopLevelNodeClasses {
    return [NSSet setWithObjects:[ParserNodeCPPNamespace class], [ParserNodeCPPClass class], [ParserNodeCTypeStruct class], 
        [ParserNodeCPPPublic class], [ParserNodeCPPPrivate class], [ParserNodeCPPProtected class], nil];
}

+ (NSUInteger) languageSyntaxAnalysisPasses {
    return 2;
}

- (NSString*) name {
    return @"C++";
}

- (NSSet*) fileExtensions {
    return [NSSet setWithObjects:@"cc", @"cp", @"cpp", nil];
}

- (ParserNode*) performSyntaxAnalysis:(NSUInteger)passIndex forNode:(ParserNode*)node textBuffer:(const unichar*)textBuffer topLevelLanguage:(ParserLanguage*)topLevelLanguage {
    
    if(passIndex == 0) {
        if([node isKindOfClass:[ParserNodeBraces class]]) {
            ParserNode* previousNode = [node findPreviousSiblingIgnoringWhitespaceAndNewline];
            
            // "catch() {}"
            if([previousNode isKindOfClass:[ParserNodeParenthesis class]]) {
                previousNode = [previousNode findPreviousSiblingIgnoringWhitespaceAndNewline];
                if([previousNode isKindOfClass:[ParserNodeCPPCatch class]])
                    _RearrangeNodesAsParentAndChildren(previousNode, node);
            }
            
            // "try {}"
            else if([previousNode isKindOfClass:[ParserNodeCPPTry class]]) {
                _RearrangeNodesAsParentAndChildren(previousNode, node);
            }
            
        } else if([node isKindOfClass:[ParserNodeParenthesis class]]) {
            ParserNode* previousNode = [node findPreviousSiblingIgnoringWhitespaceAndNewline];
            
            // "throw()"
            if([previousNode isKindOfClass:[ParserNodeCPPThrow class]]) {
                _RearrangeNodesAsParentAndChildren(previousNode, node);
            }
            
        } else if([node isKindOfClass:[ParserNodeCPPPrivate class]] || [node isKindOfClass:[ParserNodeCPPProtected class]] || [node isKindOfClass:[ParserNodeCPPPublic class]]) {
            
            // "private ..." "protected ..." "public ..."
            ParserNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
            if([nextNode isKindOfClass:[ParserNodeColon class]]) {
                ParserNode* endNode = [node.parent.lastChild findPreviousSiblingIgnoringWhitespaceAndNewline]; //Last child is guaranted to be "}"
                ParserNode* otherNode = [node findNextSiblingOfClass:[ParserNodeCPPPrivate class]];
                if(otherNode && (otherNode.range.location < endNode.range.location))
                    endNode = otherNode.previousSibling;
                otherNode = [node findNextSiblingOfClass:[ParserNodeCPPProtected class]];
                if(otherNode && (otherNode.range.location < endNode.range.location))
                    endNode = otherNode.previousSibling;
                otherNode = [node findNextSiblingOfClass:[ParserNodeCPPPublic class]];
                if(otherNode && (otherNode.range.location < endNode.range.location))
                    endNode = otherNode.previousSibling;
                if([endNode isKindOfClass:[ParserNodeWhitespace class]] || [endNode isKindOfClass:[ParserNodeNewline class]])
                    endNode = [endNode findPreviousSiblingIgnoringWhitespaceAndNewline];
                _RearrangeNodesAsParentAndChildren(node, endNode);
            }
            
        } else if([node isKindOfClass:[ParserNodeCPPNamespace class]]) {
            
            // "namespace {}"
            ParserNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
            if([nextNode isMemberOfClass:[ParserNodeText class]]) {
                nextNode = [nextNode findNextSiblingIgnoringWhitespaceAndNewline];
                if([nextNode isKindOfClass:[ParserNodeBraces class]])
                    _RearrangeNodesAsParentAndChildren(node, nextNode);
            }
            
        } else if([node isKindOfClass:[ParserNodeCPPClass class]]) {
            
            // "class {}"
            ParserNode* bracesNode = [node findNextSiblingOfClass:[ParserNodeBraces class]];
            ParserNode* semicolonNode = [node findNextSiblingOfClass:[ParserNodeSemicolon class]];
            if(bracesNode && (!semicolonNode || ([node.parent indexOfChild:semicolonNode] > [node.parent indexOfChild:bracesNode]))) {
                if(!semicolonNode)
                    _RearrangeNodesAsParentAndChildren(node, node.parent.lastChild);
                else
                    _RearrangeNodesAsParentAndChildren(node, semicolonNode);
            }
            
        } else if([node isKindOfClass:[ParserNodeCPPNew class]] || [node isKindOfClass:[ParserNodeCPPDelete class]]) {
            
            // "new foo" "delete foo"
            ParserNode* semicolonNode = [node findNextSiblingOfClass:[ParserNodeSemicolon class]];
            if(semicolonNode)
                _RearrangeNodesAsParentAndChildren(node, semicolonNode);
            
        } else if([node isKindOfClass:[ParserNodeCPPTypeId class]]) {
            
            // "typeid()"
            ParserNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
            if([nextNode isKindOfClass:[ParserNodeParenthesis class]])
                _RearrangeNodesAsParentAndChildren(node, nextNode);
            
        } else if([node isKindOfClass:[ParserNodeCPPVirtual class]]) {
            
            // "virtual foo bar()"
            ParserNode* semicolonNode = [node findNextSiblingOfClass:[ParserNodeSemicolon class]];
            if(semicolonNode)
                _RearrangeNodesAsParentAndChildren(node, semicolonNode);
            
        }
    }
    
    if(passIndex == 1) {
        
        if([node isKindOfClass:[ParserNodeCFunctionCall class]]) {
            
            // "virtual foo bar()"
            if([node.parent isKindOfClass:[ParserNodeCPPVirtual class]]) {
                [node replaceWithNode:nil preserveChildren:YES];
            }
            
            // "foo.bar()" "foo->bar()"
            else {
                ParserNode* previousNode1 = node.previousSibling;
                if([previousNode1 isKindOfClass:[ParserNodeDot class]] || [previousNode1 isKindOfClass:[ParserNodeArrow class]]) {
                    ParserNode* previousNode2 = previousNode1.previousSibling;
                    if([previousNode2 isKindOfClass:[ParserNodeText class]]) {
                        _AdoptNodesAsChildren(previousNode2, node);
                        return [node replaceWithNodeOfClass:[ParserNodeCPPFunctionCall class] preserveChildren:YES];
                    }
                }
            }
            
        }
        
        else if([node isKindOfClass:[ParserNodeCFunctionDefinition class]] || [node isKindOfClass:[ParserNodeCFunctionPrototype class]]) {
            
            // "constructor() : foo_(bar) {}"
            if([node.parent isKindOfClass:[ParserNodeCFunctionDefinition class]]) {
            	[node replaceWithNode:nil preserveChildren:YES];
            }
            
            // "~destructor()" "foo::bar()"
        	else {
                ParserNode* previousNode1 = node.previousSibling;
                if([previousNode1 isKindOfClass:[ParserNodeTilde class]]) {
                    _AdoptNodesAsChildren(previousNode1, node);
                    return [node replaceWithNodeOfClass:[node class] preserveChildren:YES];
                } else if([previousNode1 isKindOfClass:[ParserNodeDoubleSemicolon class]]) {
                    ParserNode* previousNode2 = previousNode1.previousSibling;
                    if([previousNode2 isKindOfClass:[ParserNodeText class]]) {
                        _AdoptNodesAsChildren(previousNode2, node);
                        return [node replaceWithNodeOfClass:[node class] preserveChildren:YES];
                    }
                }
            }
            
        }
        
    }
    
    //FIXME: Add support for templates
    
    return node;
}

@end

@implementation ParserNodeCPPComment

+ (NSUInteger) isMatchingPrefix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    return (string[0] == '/') && (string[1] == '/') ? 2 : NSNotFound;
}

+ (NSUInteger) isMatchingSuffix:(const unichar*)string maxLength:(NSUInteger)maxLength {
    while(maxLength) {
        if(IsNewline(*string)) {
            do {
                --string;
            } while(IsWhitespace(*string));
            if(*string != '\\')
                return 0;
        }
        if(!IsWhitespace(*string))
            break;
        ++string;
        --maxLength;
    }
    
    return NSNotFound;
}

- (NSString*) cleanContent {
    NSMutableString* string = [NSMutableString stringWithString:self.content];
    NSRange range = [string rangeOfCharacterFromSet:[[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet] options:0 range:NSMakeRange(2, string.length - 2)];
    [string deleteCharactersInRange:NSMakeRange(0, range.location != NSNotFound ? range.location : string.length)];
    return string;
}

@end

@implementation ParserNodeDoubleSemicolon (Patch)

+ (NSSet*) patchedClasses {
    return [NSSet setWithObject:[ParserNodeColon class]];
}

@end

KEYWORD_CLASS_IMPLEMENTATION(CPP, And, "and")
KEYWORD_CLASS_IMPLEMENTATION(CPP, AndEq, "and_eq")
KEYWORD_CLASS_IMPLEMENTATION(CPP, Asm, "asm")
KEYWORD_CLASS_IMPLEMENTATION(CPP, BitAnd, "bitand")
KEYWORD_CLASS_IMPLEMENTATION(CPP, BitOr, "bitor")
KEYWORD_CLASS_IMPLEMENTATION(CPP, Bool, "bool")
KEYWORD_CLASS_IMPLEMENTATION(CPP, Compl, "compl")
KEYWORD_CLASS_IMPLEMENTATION(CPP, ConstCast, "const_cast")
KEYWORD_CLASS_IMPLEMENTATION(CPP, DynamicCast, "dynamic_cast")
KEYWORD_CLASS_IMPLEMENTATION(CPP, Explicit, "explicit")
KEYWORD_CLASS_IMPLEMENTATION(CPP, Export, "export")
KEYWORD_CLASS_IMPLEMENTATION(CPP, False, "false")
KEYWORD_CLASS_IMPLEMENTATION(CPP, Friend, "friend")
KEYWORD_CLASS_IMPLEMENTATION(CPP, Mutable, "mutable")
KEYWORD_CLASS_IMPLEMENTATION(CPP, Not, "not")
KEYWORD_CLASS_IMPLEMENTATION(CPP, NotEq, "not_eq")
KEYWORD_CLASS_IMPLEMENTATION(CPP, Operator, "operator")
KEYWORD_CLASS_IMPLEMENTATION(CPP, Or, "or")
KEYWORD_CLASS_IMPLEMENTATION(CPP, OrEq, "or_eq")
KEYWORD_CLASS_IMPLEMENTATION(CPP, ReinterpretCast, "reinterpret_cast")
KEYWORD_CLASS_IMPLEMENTATION(CPP, StaticCast, "static_cast")
KEYWORD_CLASS_IMPLEMENTATION(CPP, Template, "template")
KEYWORD_CLASS_IMPLEMENTATION(CPP, This, "this")
KEYWORD_CLASS_IMPLEMENTATION(CPP, True, "true")
KEYWORD_CLASS_IMPLEMENTATION(CPP, Typename, "typename")
KEYWORD_CLASS_IMPLEMENTATION(CPP, WCharT, "wchar_t")
KEYWORD_CLASS_IMPLEMENTATION(CPP, Xor, "xor")
KEYWORD_CLASS_IMPLEMENTATION(CPP, XorEq, "xor_eq")

#define IMPLEMENTATION(__NAME__, ...) \
@implementation ParserNodeCPP##__NAME__ \
\
IS_MATCHING_PREFIX_METHOD_WITH_TRAILING_CHARACTERS(__VA_ARGS__) \
\
@end

IMPLEMENTATION(Public, "public", true, ":")
IMPLEMENTATION(Protected, "protected", true, ":")
IMPLEMENTATION(Private, "private", true, ":")
IMPLEMENTATION(Try, "try", true, "{")
IMPLEMENTATION(Catch, "catch", true, "(")
IMPLEMENTATION(Throw, "throw", false, "(")
IMPLEMENTATION(Virtual, "virtual", true, NULL)
IMPLEMENTATION(Class, "class", true, NULL)
IMPLEMENTATION(Using, "using", true, NULL)
IMPLEMENTATION(Namespace, "namespace", true, NULL)
IMPLEMENTATION(New, "new", true, NULL)
IMPLEMENTATION(Delete, "delete", true, NULL)
IMPLEMENTATION(TypeId, "typeid", true, "(")

#undef IMPLEMENTATION

@implementation ParserNodeCPPFunctionCall
@end
