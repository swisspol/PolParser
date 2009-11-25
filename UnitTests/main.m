#import "SourceParser.h"

int main(int argc, const char* argv[]) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    NSString* basePath = @"Tests";
    NSArray* testFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:NULL];
    for(NSString* path in testFiles) {
    	if([path hasPrefix:@"."])
        	continue;
        
        NSAutoreleasePool* localPool = [[NSAutoreleasePool alloc] init];
        NSString* content = [NSString stringWithContentsOfFile:[basePath stringByAppendingPathComponent:path] encoding:NSUTF8StringEncoding error:NULL];
        if(content == nil) {
        	NSLog(@"<FAILED LOADING TEST CONTENT FROM \"%@\">", path);
        } else {
            NSArray* parts = [content componentsSeparatedByString:@"-----"];
            if(parts.count != 2) {
            	NSLog(@"<INVALID TEST CONTENT IN \"%@\">", path);
            } else {
                @try {
                    NSString* source = [parts objectAtIndex:0];
                    SourceLanguage* language = [SourceLanguage defaultLanguageForFileExtension:[path pathExtension]];
                    SourceNodeRoot* root = [language parseSourceString:source syntaxAnalysis:YES];
                    if(root == nil) {
                        NSLog(@"<FAILED PARSING SOURCE FROM \"%@\">", path);
                    } else {
                        NSMutableString* expected = [NSMutableString stringWithString:[parts objectAtIndex:1]];
                        [expected replaceOccurrencesOfString:@"\n" withString:@"" options:NSAnchoredSearch range:NSMakeRange(0, expected.length)];
                        [expected replaceOccurrencesOfString:@"\n" withString:@"" options:(NSBackwardsSearch | NSAnchoredSearch) range:NSMakeRange(0, expected.length)];
                        
                        NSString* result = [root compactDescription];
                        if(![result isEqualToString:expected]) {
                        	printf("%s: FAILED\n", [path UTF8String]);
                            
                            NSString* suffix = [[NSCalendarDate date] descriptionWithCalendarFormat:@"%Y-%m-%d-%I%M%S%F"];
                            
                            NSString* expectedPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Expected-%@.out", suffix]];
                            [expected writeToFile:expectedPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
                            
                            NSString* resultPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Result-%@.out", suffix]];
                            [result writeToFile:resultPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
                            
                            NSTask* task = [[NSTask alloc] init];
                            [task setLaunchPath:@"/usr/bin/opendiff"];
                            [task setArguments:[NSArray arrayWithObjects:expectedPath, resultPath, nil]];
                            @try {
                                [task launch];
                            }
                            @catch(NSException* exception) {
                                NSLog(@"<FAILED LAUNCHING OPENDIFF: \"%@\">", [exception reason]);
                            }
                            [task release];
                        } else {
                            printf("%s: ok\n", [path UTF8String]);
                        }
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
