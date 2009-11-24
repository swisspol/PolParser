#import "SourceParser.h"

static void _ProcessNode(SourceNode* node) {
	//Replace indenting spaces by tabs
    if([node isKindOfClass:[SourceNodeIndenting class]]) {
    	NSString* text = node.content;
        text = [text stringByReplacingOccurrencesOfString:@"    " withString:@"\t"];
        [node replaceWithText:text];
    }
    
    //Delete whitespace at end of lines & remove multiple newlines
    if([node isKindOfClass:[SourceNodeNewline class]]) {
        if([node.previousSibling isKindOfClass:[SourceNodeWhitespace class]]) //FIXME: This is affected by the above operation
        	[node.previousSibling removeFromParent];
        if([node.nextSibling isKindOfClass:[SourceNodeNewline class]] && [node.nextSibling.nextSibling isKindOfClass:[SourceNodeNewline class]])
        	[node.nextSibling removeFromParent];
    }
    
    //Delete empty C++ comments and reformat the others as "  // Comment"
    if([node isKindOfClass:[SourceNodeCommentCPP class]]) {
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
    
    //Reformat if(), for() and while() as "if ()", "for ()" and "while ()"
    if([node isKindOfClass:[SourceNodeConditionIf class]] || [node isKindOfClass:[SourceNodeFlowFor class]] || [node isKindOfClass:[SourceNodeFlowWhile class]]) {
    	while([node.nextSibling isKindOfClass:[SourceNodeWhitespace class]] || [node.nextSibling isKindOfClass:[SourceNodeNewline class]])
        	[node.nextSibling removeFromParent];
        [node insertNextSibling:[SourceNodeText sourceNodeWithText:@" "]];
    }
    
    //Ensure open braces are never preceded by a new line
    if([node isKindOfClass:[SourceNodeBraces class]]) {
    	if([node.previousSibling isKindOfClass:[SourceNodeWhitespace class]])
        	[node.previousSibling removeFromParent];
        if([node.previousSibling isKindOfClass:[SourceNodeNewline class]])
        	[node.previousSibling removeFromParent];
        [node insertPreviousSibling:[SourceNodeText sourceNodeWithText:@" "]];
    }
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
        SourceNodeRoot* root = [SourceLanguage parseSourceFile:path encoding:NSUTF8StringEncoding];
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
