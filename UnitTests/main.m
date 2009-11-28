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

extern BOOL RunJavaScriptOnRootNode(NSString* script, SourceNode* root);

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
    NSString* basePath;
    
    NSMutableSet* filteredFiles = [NSMutableSet set];
    for(int i = 1; i < argc; ++i) {
        if(argv[i][0] == '-') {
            ;
        } else {
            [filteredFiles addObject:[NSString stringWithUTF8String:argv[i]]];
        }
    }
    
    basePath = @"SourceParser";
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
                    NSString* source = [parts objectAtIndex:0];
                    SourceLanguage* language = [SourceLanguage defaultLanguageForFileExtension:[path pathExtension]];
                    SourceNodeRoot* root = [language parseSourceString:source syntaxAnalysis:YES];
                    if(root == nil) {
                        NSLog(@"<FAILED PARSING SOURCE FROM \"%@\">", path);
                    } else {
                        BOOL success = YES;
                        if((parts.count > 1) && [[parts objectAtIndex:1] length]) {
                        	NSMutableString* expected = [NSMutableString stringWithString:[parts objectAtIndex:1]];
                            [expected replaceOccurrencesOfString:@"\n" withString:@"" options:NSAnchoredSearch range:NSMakeRange(0, expected.length)];
                            [expected replaceOccurrencesOfString:@"\n" withString:@"" options:(NSBackwardsSearch | NSAnchoredSearch) range:NSMakeRange(0, expected.length)];
                            if(!_ValidateResult([path lastPathComponent], root.compactDescription, expected))
                            	success = NO;
                        }
                        if((parts.count > 2) && [[parts objectAtIndex:2] length]) {
                        	NSMutableString* expected = [NSMutableString stringWithString:[parts objectAtIndex:2]];
                            [expected replaceOccurrencesOfString:@"\n" withString:@"" options:NSAnchoredSearch range:NSMakeRange(0, expected.length)];
                            [expected replaceOccurrencesOfString:@"\n" withString:@"" options:(NSBackwardsSearch | NSAnchoredSearch) range:NSMakeRange(0, expected.length)];
                            if(!_ValidateResult([path lastPathComponent], root.fullDescription, expected))
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
    
    NSMutableDictionary* roots = [NSMutableDictionary dictionary];
    basePath = @"SampleSource";
    for(NSString* path in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:NULL]) {
    	if([path hasPrefix:@"."])
        	continue;
        path = [basePath stringByAppendingPathComponent:path];
        
        NSAutoreleasePool* localPool = [[NSAutoreleasePool alloc] init];
        SourceNodeRoot* root = [SourceLanguage parseSourceFile:path encoding:NSUTF8StringEncoding syntaxAnalysis:YES];
        if(root == nil)
        	NSLog(@"<FAILED PARSING SOURCE \"%@\">", path);
        else
            [roots setObject:root forKey:[path lastPathComponent]];
        [localPool release];
    }
    basePath = @"JavaScriptBindings";
    for(NSString* path in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:NULL]) {
    	if([path hasPrefix:@"."])
        	continue;
        if([[path pathExtension] caseInsensitiveCompare:@"js"] != NSOrderedSame) //FIXME: This can't work if we ever support JavaScript parsing
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
            if(parts.count == 0) {
            	NSLog(@"<INVALID TEST CONTENT IN \"%@\">", path);
            } else {
                for(NSString* name in roots) {
                    BOOL success = NO;
                    SourceNodeRoot* root = [[roots objectForKey:name] copy];
                    if(root) {
                        @try {
                            success = YES;
                            for(NSUInteger i = 0; i < parts.count; ++i) {
                            	if(!RunJavaScriptOnRootNode([parts objectAtIndex:i], root)) {
                                	NSLog(@"<FAILED EXECUTING JAVASCRIPT \"%@\" on \"%@\">", path, name);
                                    success = NO;
                                    break;
                                }
                            }
                           	if(success) {
                                NSString* newName = [NSString stringWithFormat:@"%@-%@", [[path lastPathComponent] stringByDeletingPathExtension], name];
                                NSString* expected = [NSString stringWithContentsOfFile:[basePath stringByAppendingPathComponent:newName] encoding:NSUTF8StringEncoding error:NULL];
                                if(!_ValidateResult(newName, root.content, expected))
                                    success = NO;
                            }
                        }
                        @catch(NSException* exception) {
                            NSLog(@"<EXCEPTION \"%@\">", [exception reason]);
                        }
                        [root release];
                    }
                    if(success)
                        printf("%s [%s]: ok\n", [path UTF8String], [name UTF8String]);
                    else
                        printf("%s [%s]: FAILED\n", [path UTF8String], [name UTF8String]);
                }
            }
        }
        [localPool drain];
    }
    
    [pool drain];
    return 0;
}
