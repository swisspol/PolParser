#import "SourceParser.h"

static void _ProcessNode(SourceNode* node) {
	//Replace indenting spaces by tabs
    if([node isMemberOfClass:[SourceNodeIndenting class]]) {
    	NSString* text = node.content;
        text = [text stringByReplacingOccurrencesOfString:@"    " withString:@"\t"];
        [node replaceWithText:text];
    }
    
    //Delete whitespace at end of lines
    else if([node isMemberOfClass:[SourceNodeNewline class]]) {
        if([node.previousSibling isMemberOfClass:[SourceNodeWhitespace class]])
        	[node.previousSibling removeFromParent];
    }
    
    //Delete empty C++ comments and reformat the others as "  // Comment"
    else if([node isMemberOfClass:[SourceNodeCommentCPP class]]) {
        if([node.previousSibling isMemberOfClass:[SourceNodeWhitespace class]])
        	[node.previousSibling removeFromParent];
        NSString* text = node.content;
        NSRange range = [node.content rangeOfCharacterFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet] options:0 range:NSMakeRange(2, text.length - 2)];
        if(range.location != NSNotFound)
            text = [NSString stringWithFormat:@"%@// %@", [node.previousSibling isMemberOfClass:[SourceNodeNewline class]] ? @"": @"  ", [text substringFromIndex:range.location]];
        else
            text = nil;
        [node replaceWithText:text];
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
