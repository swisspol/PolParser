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

#import "Parser.h"

extern BOOL RunJavaScriptOnRootNode(NSString* script, ParserNode* root);

int main(int argc, const char* argv[]) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    int result = 1;
    NSString* optionScript = nil;
    BOOL compactOption = NO;
    BOOL detailedOption = NO;
    NSString* inFile = nil;
    
    if(argc >= 2) {
        int offset = 1;
        while(argv[offset][0] == '-') {
            if(strcmp(argv[offset], "--compact") == 0) {
                compactOption = YES;
            } else if(strcmp(argv[offset], "--detailed") == 0) {
                detailedOption = YES;
            } else if((strcmp(argv[offset], "-script") == 0) && (offset + 1 < argc)) {
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
            ++offset;
            if(offset >= argc)
            	break;
        }
        if(offset < argc)
            inFile = [[NSString stringWithUTF8String:argv[offset]] stringByStandardizingPath];
    }
    if(inFile == nil) {
    	printf("%s [--compact | --detailed] [-script JavaScriptFilePath] inFile\n", basename((char*)argv[0]));
        goto Exit;
    }
    
    ParserNodeRoot* root = [ParserLanguage parseTextFile:inFile encoding:NSUTF8StringEncoding syntaxAnalysis:YES];
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
            if(compactOption)
                printf("%s\n", [root.compactDescription UTF8String]);
            else if(detailedOption)
                printf("%s\n", [root.detailedDescription UTF8String]);
            else
                printf("%s\n", [root.content UTF8String]);
        }
    } else {
        printf("Failed parsing string file from \"%s\"\n", [inFile UTF8String]);
    }
    
Exit:
    [pool drain];
    return result;
}
