#import "SourceParser.h"

int main(int argc, const char* argv[]) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
    if(argc >= 2) {
    	NSString* path = [[NSString stringWithUTF8String:argv[1]] stringByStandardizingPath];
        SourceNodeRoot* root = [SourceLanguage parseSourceFile:path];
    	if(root) {
            printf("%s\n", [[root fullDescription] UTF8String]);
            if(argc >= 3) {
            	path = [[NSString stringWithUTF8String:argv[2]] stringByStandardizingPath];
                [root writeSourceFromTreeToFile:path];
            }
        }
    }
    
	[pool drain];
    return 0;
}
