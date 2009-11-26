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

#import <libgen.h>

#import "SourceParser.h"

extern BOOL RunJavaScriptOnRootNode(NSString* script, SourceNode* root);

int main(int argc, const char* argv[]) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    int result = 1;
    
    if(argc >= 2) {
        BOOL optionDiff = NO;
        NSString* optionScript = nil;
        
        int offset = 1;
        while(argv[offset][0] == '-') {
            if((strcmp(argv[offset], "-refactor") == 0) && (offset + 1 < argc)) {
                if(argv[offset + 1][0] != '-') {
                	NSString* path = [[NSString stringWithUTF8String:argv[offset + 1]] stringByStandardizingPath];
                    optionScript = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
                    if(optionScript) {
                        ++offset;
                    } else {
                    	printf("Failed loading JavaScript from \"%s\"\n", [path UTF8String]);
                        goto Exit;
                    }
                }
            }
            else if(strcmp(argv[offset], "-diff") == 0)
                optionDiff = YES;
            ++offset;
        }
        NSString* inFile = [[NSString stringWithUTF8String:argv[offset]] stringByStandardizingPath];
        NSString* outFile = (offset + 1 < argc ? [[NSString stringWithUTF8String:argv[offset + 1]] stringByStandardizingPath] : nil);
        
        SourceNodeRoot* root = [SourceLanguage parseSourceFile:inFile encoding:NSUTF8StringEncoding syntaxAnalysis:YES];
        if(root) {
            if(optionScript) {
            	if(RunJavaScriptOnRootNode(optionScript, root))
                    result = 0;
                else
                	printf("Failed executing JavaScript\n");
            } else {
                result = 0;
            }
			
            if(result == 0) {
                if(outFile) {
                    NSString* newPath = [[NSString stringWithUTF8String:argv[offset + 1]] stringByStandardizingPath];
                    if([root writeContentToFile:outFile encoding:NSUTF8StringEncoding]) {
                        if(optionDiff) {
                            NSTask* task = [[NSTask alloc] init];
                            [task setLaunchPath:@"/usr/bin/opendiff"];
                            [task setArguments:[NSArray arrayWithObjects:inFile, newPath, nil]];
                            @try {
                                [task launch];
                            }
                            @catch(NSException* exception) {
                                printf("Failed running %s\n", [[task launchPath] UTF8String]);
                            }
                            [task waitUntilExit];
                            [task release];
                        }
                    } else {
                        printf("Failed writing source file to \"%s\"\n", [outFile UTF8String]);
                    }
                } else {
                    printf("%s\n", [[root fullDescription] UTF8String]);
                }
            }
        } else {
            printf("Failed parsing source file from \"%s\"\n", [inFile UTF8String]);
        }
    } else {
        printf("%s [-refactor JavaScriptFilePath] [-diff] inFile [outFile]\n", basename((char*)argv[0]));
    }
    
Exit:
    [pool drain];
    return result;
}
