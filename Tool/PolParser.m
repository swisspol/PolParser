#import "SourceParser.h"

int main(int argc, const char* argv[]) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
    if(argc == 2) {
    	NSString* path = [[NSString stringWithUTF8String:argv[1]] stringByStandardizingPath];
    	printf("%s\n", [[[SourceLanguage parseSourceFile:path] fullDescription] UTF8String]);
    }
    
	[pool drain];
    return 0;
}
