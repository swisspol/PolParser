#import "SourceParser.h"

static void _ProcessNode(SourceNode* node) {
    //Replace indenting spaces by tabs - FIXME: This affects open-braces reformatting since it replaces some "SourceNodeIndenting" nodes
    /*if([node isKindOfClass:[SourceNodeIndenting class]]) {
        NSString* text = node.content;
        text = [text stringByReplacingOccurrencesOfString:@"    " withString:@"\t"];
        [node replaceWithText:text];
    }*/
    
    //Strip multiple whitespace (but not indenting)
    if([node isMemberOfClass:[SourceNodeWhitespace class]]) {
    	[node replaceWithText:@" "];
    }
    
    //Strip whitespace at end of lines & multiple newlines
    if([node isKindOfClass:[SourceNodeNewline class]]) {
        if([node.previousSibling isKindOfClass:[SourceNodeWhitespace class]]) //FIXME: This is affected by the above operation
            [node.previousSibling removeFromParent];
        if([node.nextSibling isKindOfClass:[SourceNodeNewline class]] && [node.nextSibling.nextSibling isKindOfClass:[SourceNodeNewline class]])
            [node.nextSibling removeFromParent];
    }
    
    //Strip multiple semicolons (except in for() loops) and whitespace before the remaining ones
    if([node isKindOfClass:[SourceNodeSemicolon class]]) {
    	while([node.previousSibling isKindOfClass:[SourceNodeWhitespace class]] || [node.previousSibling isKindOfClass:[SourceNodeNewline class]]) {
        	[node.previousSibling removeFromParent];
        }
        if(![node.parent.parent isKindOfClass:[SourceNodeCFlowFor class]]) {
            SourceNode* nextNode = [node findNextSiblingIgnoringWhitespaceAndNewline];
            while([nextNode isKindOfClass:[SourceNodeSemicolon class]]) {
                SourceNode* tempNode = [nextNode findNextSiblingIgnoringWhitespaceAndNewline];
                [nextNode removeFromParent];
                nextNode = tempNode;
            }
        }
    }
    
    //Delete empty C++ comments and reformat the remaining ones as "  // Comment"
    if([node isKindOfClass:[SourceNodeCPPComment class]]) {
        if([node.previousSibling isKindOfClass:[SourceNodeWhitespace class]])
            [node.previousSibling removeFromParent];
        NSString* text = node.content;
        NSRange range = [node.content rangeOfCharacterFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet] options:0 range:NSMakeRange(2, text.length - 2)];
        if(range.location != NSNotFound)
            text = [NSString stringWithFormat:@"%@// %@", [node.previousSibling isKindOfClass:[SourceNodeNewline class]] ? @"": @"  ", [text substringFromIndex:range.location]];
        else
            text = nil;
        [node replaceWithText:text];
    }
    
    //Reformat "if...", "else if...", "for..." and "while..." as "if ...", "else if ...", "for ..." and "while ..."
    if(([node isKindOfClass:[SourceNodeCConditionIf class]] || [node isKindOfClass:[SourceNodeCConditionElseIf class]] || [node isKindOfClass:[SourceNodeCFlowFor class]] || [node isKindOfClass:[SourceNodeCFlowWhile class]]) && node.children.count) {
        SourceNode* subnode = node.firstChild;
        while([subnode.nextSibling isKindOfClass:[SourceNodeWhitespace class]] || [subnode.nextSibling isKindOfClass:[SourceNodeNewline class]])
            [subnode.nextSibling removeFromParent];
        [subnode insertNextSibling:[SourceNodeText sourceNodeWithText:@" "]];
    }
    
    //Reformat "do {} while()" as "do {} while ()"
    if([node isKindOfClass:[SourceNodeCFlowDoWhile class]] && node.children.count) {
        SourceNode* subnode = node.lastChild;
        if([subnode isKindOfClass:[SourceNodeParenthesis class]]) {
            while([subnode.previousSibling isKindOfClass:[SourceNodeWhitespace class]] || [subnode.previousSibling isKindOfClass:[SourceNodeNewline class]])
                [subnode.previousSibling removeFromParent];
            [subnode insertPreviousSibling:[SourceNodeText sourceNodeWithText:@" "]];
        }
    }
    
    //Reformat open-braces as "... {"
    if([node isKindOfClass:[SourceNodeBraces class]]) {
        if([node.parent isKindOfClass:[SourceNodeCFlowFor class]] || [node.parent isKindOfClass:[SourceNodeCFlowDoWhile class]] || [node.parent isKindOfClass:[SourceNodeCFlowWhile class]]
            || [node.parent isKindOfClass:[SourceNodeCConditionIf class]] || [node.parent isKindOfClass:[SourceNodeCConditionElse class]] || [node.parent isKindOfClass:[SourceNodeCFunctionDefinition class]]
            || [node.parent isKindOfClass:[SourceNodeObjCInterface class]] || [node.parent isKindOfClass:[SourceNodeObjCTry class]] || [node.parent isKindOfClass:[SourceNodeObjCCatch class]]
            || [node.parent isKindOfClass:[SourceNodeObjCFinally class]] || [node.parent isKindOfClass:[SourceNodeObjCSynchronized class]] || [node.parent isKindOfClass:[SourceNodeObjCMethodImplementation class]]
            || [node.parent isKindOfClass:[SourceNodeCConditionElseIf class]]) {
            
            SourceNode* subnode = [node findPreviousSiblingIgnoringWhitespaceAndNewline];
            if(subnode) {
                while([subnode.nextSibling isKindOfClass:[SourceNodeWhitespace class]] || [subnode.nextSibling isKindOfClass:[SourceNodeNewline class]]) {
                    [subnode.nextSibling removeFromParent];
                }
                [node insertPreviousSibling:[SourceNodeText sourceNodeWithText:@" "]];
            }
        }
    }
    
    //FIXME: Remove all indenting and re-intend according to braces
}

#if !NS_BLOCKS_AVAILABLE

static void _ApplierFunction(SourceNode* node, void* context) {
    _ProcessNode(node);
}

#endif

int main(int argc, const char* argv[]) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    if(argc >= 2) {
        BOOL optionClean = NO;
        BOOL optionDiff = NO;
        
        int offset = 1;
        while(argv[offset][0] == '-') {
            if(strcmp(argv[offset], "-clean") == 0)
                optionClean = YES;
            else if(strcmp(argv[offset], "-diff") == 0)
                optionDiff = YES;
            ++offset;
        }
        
        NSString* path = [[NSString stringWithUTF8String:argv[offset]] stringByStandardizingPath];
        SourceNodeRoot* root = [SourceLanguage parseSourceFile:path encoding:NSUTF8StringEncoding syntaxAnalysis:YES];
        if(root) {
            if(optionClean)
#if NS_BLOCKS_AVAILABLE
                [root enumerateChildrenRecursively:YES usingBlock:^(SourceNode* node) {
                    _ProcessNode(node);
                }];
#else
                [root applyFunctionOnChildren:_ApplierFunction context:NULL recursively:YES];
#endif
            
            printf("%s\n", [[root fullDescription] UTF8String]);
            
            if(argc >= 3) {
                NSString* newPath = [[NSString stringWithUTF8String:argv[offset + 1]] stringByStandardizingPath];
                if([root writeContentToFile:newPath encoding:NSUTF8StringEncoding] && optionDiff) {
                    NSTask* task = [[NSTask alloc] init];
                    [task setLaunchPath:@"/usr/bin/opendiff"];
                    [task setArguments:[NSArray arrayWithObjects:path, newPath, nil]];
                    @try {
                        [task launch];
                    }
                    @catch(NSException* exception) {
                        ;
                    }
                    [task waitUntilExit];
                    [task release];
                }
            }
        }
    }
    
    [pool drain];
    return 0;
}
