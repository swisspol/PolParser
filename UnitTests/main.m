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

#import "Parser.h"
#import "JavaScriptBindings.h"

static BOOL _ValidateResult(NSString* name, NSString* actualResult, NSString* expectedResult) {
	if(!actualResult)
    	actualResult = @"";
    if(!expectedResult)
    	expectedResult = @"";
    if(![actualResult isEqualToString:expectedResult]) {
        NSString* expectedPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@ [Expected].txt", name]];
        [expectedResult writeToFile:expectedPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        
        NSString* resultPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@ [Actual].txt", name]];
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
    BOOL skipParser = NO;
    BOOL skipBindings = NO;
    NSString* basePath;
    
    NSMutableSet* filteredFiles = [NSMutableSet set];
    for(int i = 1; i < argc; ++i) {
        if(argv[i][0] == '-') {
            if(strcmp(argv[i], "--skipParser") == 0)
            	skipParser = YES;
            else if(strcmp(argv[i], "--skipBindings") == 0)
            	skipBindings = YES;
        } else {
            [filteredFiles addObject:[NSString stringWithUTF8String:argv[i]]];
        }
    }
    
    if(!skipParser) {
        basePath = @"Parser";
        for(NSString* path in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:NULL]) {
            if([path hasPrefix:@"."])
                continue;
            if(filteredFiles.count && ![filteredFiles containsObject:path])
                continue;
            path = [basePath stringByAppendingPathComponent:path];
            
            NSAutoreleasePool* localPool = [[NSAutoreleasePool alloc] init];
            NSString* content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
            if(content == nil) {
                NSLog(@"<FAILED LOADING TEST CONTENT \"%@\">", path);
            } else {
                NSArray* parts = [content componentsSeparatedByString:@"<----->"];
                if(parts.count < 1) {
                    NSLog(@"<INVALID TEST CONTENT IN \"%@\">", path);
                } else {
                    @try {
                        NSString* string = [parts objectAtIndex:0];
                        ParserLanguage* language = [ParserLanguage defaultLanguageForFileExtension:[path pathExtension]];
                        ParserNodeRoot* root = [language parseText:string syntaxAnalysis:YES];
                        if(root == nil) {
                            NSLog(@"<FAILED PARSING SOURCE FROM \"%@\">", path);
                        } else {
                            BOOL success = YES;
                            if((parts.count > 1) && [[parts objectAtIndex:1] length]) {
                                NSMutableString* expected = [NSMutableString stringWithString:[parts objectAtIndex:1]];
                                [expected replaceOccurrencesOfString:@"\r\n" withString:@"\n" options:0 range:NSMakeRange(0, expected.length)];
                                [expected replaceOccurrencesOfString:@"\r" withString:@"\n" options:0 range:NSMakeRange(0, expected.length)];
                                [expected replaceOccurrencesOfString:@"\n" withString:@"" options:NSAnchoredSearch range:NSMakeRange(0, expected.length)];
                                [expected replaceOccurrencesOfString:@"\n" withString:@"" options:(NSBackwardsSearch | NSAnchoredSearch) range:NSMakeRange(0, expected.length)];
                                if(!_ValidateResult([NSString stringWithFormat:@"%@-Compact", [[path lastPathComponent] stringByDeletingPathExtension]], root.compactDescription, expected))
                                    success = NO;
                            }
                            if((parts.count > 2) && [[parts objectAtIndex:2] length]) {
                                NSMutableString* expected = [NSMutableString stringWithString:[parts objectAtIndex:2]];
                                [expected replaceOccurrencesOfString:@"\r\n" withString:@"\n" options:0 range:NSMakeRange(0, expected.length)];
                                [expected replaceOccurrencesOfString:@"\r" withString:@"\n" options:0 range:NSMakeRange(0, expected.length)];
                                [expected replaceOccurrencesOfString:@"\n" withString:@"" options:NSAnchoredSearch range:NSMakeRange(0, expected.length)];
                                [expected replaceOccurrencesOfString:@"\n" withString:@"" options:(NSBackwardsSearch | NSAnchoredSearch) range:NSMakeRange(0, expected.length)];
                                if(!_ValidateResult([NSString stringWithFormat:@"%@-Detailed", [[path lastPathComponent] stringByDeletingPathExtension]], root.detailedDescription, expected))
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
    }
    
    if(!skipBindings) {
        basePath = @"JavaScriptBindings";
        NSArray* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:NULL];
        for(NSString* path in files) {
            if([path hasPrefix:@"."])
                continue;
            if([[path pathExtension] caseInsensitiveCompare:@"js"] != NSOrderedSame) //FIXME: This can't work if we ever support JavaScript parsing
                continue;
            if(filteredFiles.count && ![filteredFiles containsObject:path])
                continue;
            NSString* prefix = [[path componentsSeparatedByString:@"-"] objectAtIndex:0];
            path = [basePath stringByAppendingPathComponent:path];
            
            for(NSString* subpath in files) {
            	if(![[[subpath stringByDeletingPathExtension] pathExtension] isEqualToString:@"in"] || ![subpath hasPrefix:prefix])
                    continue;
                subpath = [basePath stringByAppendingPathComponent:subpath];
                
            	NSAutoreleasePool* localPool = [[NSAutoreleasePool alloc] init];
                ParserNodeRoot* root = [ParserLanguage parseTextFile:subpath encoding:NSUTF8StringEncoding syntaxAnalysis:YES];
                if(root == nil) {
                    NSLog(@"<FAILED PARSING SOURCE \"%@\">", path);
                } else {
                    NSString* content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
                    if(content == nil) {
                        NSLog(@"<FAILED LOADING TEST CONTENT \"%@\">", path);
                    } else {
                        NSArray* parts = [content componentsSeparatedByString:@"<----->"];
                        if(parts.count == 0) {
                            NSLog(@"<INVALID TEST CONTENT IN \"%@\">", path);
                        } else {
                            BOOL success = NO;
                            @try {
                                success = YES;
                                for(NSUInteger i = 0; i < parts.count; ++i) {
                                    if(!RunJavaScriptOnRootNode([parts objectAtIndex:i], root)) {
                                        NSLog(@"<FAILED EXECUTING JAVASCRIPT \"%@\" on \"%@\">", path, subpath);
                                        success = NO;
                                        break;
                                    }
                                }
                                if(success) {
                                    NSString* newPath = [[[[subpath stringByDeletingPathExtension] stringByDeletingPathExtension] stringByAppendingPathExtension:@"out"] stringByAppendingPathExtension:[subpath pathExtension]];
                                    NSString* expected = [NSString stringWithContentsOfFile:newPath encoding:NSUTF8StringEncoding error:NULL];
                                    if(!_ValidateResult([newPath lastPathComponent], root.content, expected))
                                        success = NO;
                                }
                            }
                            @catch(NSException* exception) {
                                NSLog(@"<EXCEPTION \"%@\">", [exception reason]);
                            }
                            if(success)
                                printf("%s | %s: ok\n", [path UTF8String], [subpath UTF8String]);
                            else
                                printf("%s | %s: FAILED\n", [path UTF8String], [subpath UTF8String]);
                        }
                    }
                }
                [localPool drain];
            }
        }
    }
    
    [pool drain];
    return 0;
}
