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

#import "SourceParser.h"

static BOOL _ValidateResult(NSString* path, NSString* actualResult, NSString* expectedResult) {
	NSMutableString* expected = [NSMutableString stringWithString:expectedResult];
    [expected replaceOccurrencesOfString:@"\n" withString:@"" options:NSAnchoredSearch range:NSMakeRange(0, expected.length)];
    [expected replaceOccurrencesOfString:@"\n" withString:@"" options:(NSBackwardsSearch | NSAnchoredSearch) range:NSMakeRange(0, expected.length)];
    if(![actualResult isEqualToString:expected]) {
        NSString* expectedPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@ [Expected].out", path]];
        [expected writeToFile:expectedPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        
        NSString* resultPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@ [Result].out", path]];
        [actualResult writeToFile:resultPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        
        NSTask* task = [[NSTask alloc] init];
        [task setLaunchPath:@"/usr/bin/opendiff"];
        [task setArguments:[NSArray arrayWithObjects:expectedPath, resultPath, nil]];
        @try {
            [task launch];
        }
        @catch(NSException* exception) {
            NSLog(@"<FAILED LAUNCHING OPENDIFF: \"%@\">", [exception reason]);
        }
        //[task waitUntilExit];
        //[task release];
        return NO;
    }
    return YES;
}

int main(int argc, const char* argv[]) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    BOOL optionPrintRoot = NO;
    
    NSString* basePath = @"Tests";
    NSArray* testFiles;
    if(argc > 1) {
    	testFiles = [NSMutableArray array];
        for(int i = 1; i < argc; ++i) {
        	if(argv[i][0] == '-') {
            	if(strcmp(argv[i], "-print") == 0)
                	optionPrintRoot = YES;
            } else {
                [(NSMutableArray*)testFiles addObject:[NSString stringWithUTF8String:argv[i]]];
            }
        }
    } else {
    	testFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:NULL];
    }
    for(NSString* path in testFiles) {
    	if([path hasPrefix:@"."])
        	continue;
        
        NSAutoreleasePool* localPool = [[NSAutoreleasePool alloc] init];
        NSString* content = [NSString stringWithContentsOfFile:[basePath stringByAppendingPathComponent:path] encoding:NSUTF8StringEncoding error:NULL];
        if(content == nil) {
        	NSLog(@"<FAILED LOADING TEST CONTENT FROM \"%@\">", path);
        } else {
            NSArray* parts = [content componentsSeparatedByString:@"-----"];
            if(parts.count < 2) {
            	NSLog(@"<INVALID TEST CONTENT IN \"%@\">", path);
            } else {
                @try {
                    NSString* source = [parts objectAtIndex:0];
                    SourceLanguage* language = [SourceLanguage defaultLanguageForFileExtension:[path pathExtension]];
                    SourceNodeRoot* root = [language parseSourceString:source syntaxAnalysis:YES];
                    if(root == nil) {
                        NSLog(@"<FAILED PARSING SOURCE FROM \"%@\">", path);
                    } else {
                        if(optionPrintRoot)
                        	printf("<%s>\n%s\n", [path UTF8String], [root.fullDescription UTF8String]);
                        
                        BOOL success = YES;
                        if((parts.count > 1) && [[parts objectAtIndex:1] length]) {
                        	if(!_ValidateResult(path, root.compactDescription, [parts objectAtIndex:1]))
                            	success = NO;
                        }
                        if((parts.count > 2) && [[parts objectAtIndex:2] length]) {
                        	if(!_ValidateResult(path, root.fullDescription, [parts objectAtIndex:2]))
                            	success = NO;
                        }
                        if(success)
                        	printf("%s: ok\n", [path UTF8String]);
                        else
                        	printf("%s: FAILED\n", [path UTF8String]);
                    }
                }
                @catch(NSException* exception) {
                    NSLog(@"<EXCEPTION \"%@\">", [exception reason]);
                }
            }
        }
        [localPool drain];
    }
    
    [pool drain];
    return 0;
}
