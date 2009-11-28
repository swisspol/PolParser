/*
        Document.m
        Copyright (c) 1995-2009 by Apple Computer, Inc., all rights reserved.
        Author: Ali Ozer

        Document object for TextEdit. 
	As of TextEdit 1.5, a subclass of NSDocument.
*/
/*
 IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc. ("Apple") in
 consideration of your agreement to the following terms, and your use, installation, 
 modification or redistribution of this Apple software constitutes acceptance of these 
 terms.  If you do not agree with these terms, please do not use, install, modify or 
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and subject to these 
 terms, Apple grants you a personal, non-exclusive license, under Apple's copyrights in 
 this original Apple software (the "Apple Software"), to use, reproduce, modify and 
 redistribute the Apple Software, with or without modifications, in source and/or binary 
 forms; provided that if you redistribute the Apple Software in its entirety and without 
 modifications, you must retain this notice and the following text and disclaimers in all 
 such redistributions of the Apple Software.  Neither the name, trademarks, service marks 
 or logos of Apple Computer, Inc. may be used to endorse or promote products derived from 
 the Apple Software without specific prior written permission from Apple. Except as expressly
 stated in this notice, no other rights or licenses, express or implied, are granted by Apple
 herein, including but not limited to any patent rights that may be infringed by your 
 derivative works or by other works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO WARRANTIES, 
 EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, 
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS 
 USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR CONSEQUENTIAL 
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS 
 OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, 
 REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND 
 WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR 
 OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import <Cocoa/Cocoa.h>
#import "EncodingManager.h"
#import "Document.h"
#import "DocumentController.h"
#import "DocumentWindowController.h"
#import "PrintPanelAccessoryController.h"
#import "TextEditDefaultsKeys.h"
#import "TextEditErrors.h"
#import "TextEditMisc.h"

#define oldEditPaddingCompensation 12.0

NSString *SimpleTextType = @"com.apple.traditional-mac-plain-text";
NSString *Word97Type = @"com.microsoft.word.doc";
NSString *Word2007Type = @"org.openxmlformats.wordprocessingml.document";
NSString *Word2003XMLType = @"com.microsoft.word.wordml";
NSString *OpenDocumentTextType = @"org.oasis-open.opendocument.text";


@implementation Document

- (id)init {
    if (self = [super init]) {
        [[self undoManager] disableUndoRegistration];
        
	textStorage = [[NSTextStorage allocWithZone:[self zone]] init];
	
	[self setBackgroundColor:[NSColor whiteColor]];
	[self setEncoding:NoStringEncoding];
	[self setEncodingForSaving:NoStringEncoding];
	[self setScaleFactor:1.0];
	[self setDocumentPropertiesToDefaults];
	
	 // Assume the default file type for now, since -initWithType:error: does not currently get called when creating documents using AppleScript. (4165700)
	[self setFileType:[[NSDocumentController sharedDocumentController] defaultType]];
	
        [self setPrintInfo:[self printInfo]];
        
	hasMultiplePages = [[NSUserDefaults standardUserDefaults] boolForKey:ShowPageBreaks];
        
        [[self undoManager] enableUndoRegistration];
    }
    return self;
}

/* Return an NSDictionary which maps Cocoa text system document identifiers (as declared in AppKit/NSAttributedString.h) to document types declared in TextEdit's Info.plist.
*/
- (NSDictionary *)textDocumentTypeToTextEditDocumentTypeMappingTable {
    static NSDictionary *documentMappings = nil;
    if (documentMappings == nil) {
	documentMappings = [[NSDictionary alloc] initWithObjectsAndKeys:
            (NSString *)kUTTypePlainText, NSPlainTextDocumentType,
            (NSString *)kUTTypeRTF, NSRTFTextDocumentType,
            (NSString *)kUTTypeRTFD, NSRTFDTextDocumentType,
            SimpleTextType, NSMacSimpleTextDocumentType,
            (NSString *)kUTTypeHTML, NSHTMLTextDocumentType,
	    Word97Type, NSDocFormatTextDocumentType,
	    Word2007Type, NSOfficeOpenXMLTextDocumentType,
	    Word2003XMLType, NSWordMLTextDocumentType,
	    OpenDocumentTextType, NSOpenDocumentTextDocumentType,
            (NSString *)kUTTypeWebArchive, NSWebArchiveTextDocumentType,
	    nil];
    }
    return documentMappings;
}

/* This method is called by the document controller. The message is passed on after information about the selected encoding (from our controller subclass) and preference regarding HTML and RTF formatting has been added. -lastSelectedEncodingForURL: returns the encoding specified in the Open panel, or the default encoding if the document was opened without an open panel.
*/
- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
    DocumentController *docController = [DocumentController sharedDocumentController];
    return [self readFromURL:absoluteURL ofType:typeName encoding:[docController lastSelectedEncodingForURL:absoluteURL] ignoreRTF:[docController lastSelectedIgnoreRichForURL:absoluteURL] ignoreHTML:[docController lastSelectedIgnoreHTMLForURL:absoluteURL] error:outError];
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName encoding:(NSStringEncoding)encoding ignoreRTF:(BOOL)ignoreRTF ignoreHTML:(BOOL)ignoreHTML error:(NSError **)outError {
    NSMutableDictionary *options = [NSMutableDictionary dictionaryWithCapacity:5];
    NSDictionary *docAttrs;
    id val, paperSizeVal, viewSizeVal;
    NSTextStorage *text = [self textStorage];
    
    [[self undoManager] disableUndoRegistration];
    
    [options setObject:absoluteURL forKey:NSBaseURLDocumentOption];
    if (encoding != NoStringEncoding) {
        [options setObject:[NSNumber numberWithUnsignedInteger:encoding] forKey:NSCharacterEncodingDocumentOption];
    }
    [self setEncoding:encoding];
    
    // Check type to see if we should load the document as plain. Note that this check isn't always conclusive, which is why we do another check below, after the document has been loaded (and correctly categorized).
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    if ((ignoreRTF && ([workspace type:typeName conformsToType:(NSString *)kUTTypeRTF] || [workspace type:typeName conformsToType:Word2003XMLType])) || (ignoreHTML && [workspace type:typeName conformsToType:(NSString *)kUTTypeHTML]) || [self isOpenedIgnoringRichText]) {
        [options setObject:NSPlainTextDocumentType forKey:NSDocumentTypeDocumentOption]; // Force plain
	[self setFileType:(NSString *)kUTTypePlainText];
	[self setOpenedIgnoringRichText:YES];
    }
    
    [[text mutableString] setString:@""];
    // Remove the layout managers while loading the text; mutableCopy retains the array so the layout managers aren't released
    NSMutableArray *layoutMgrs = [[text layoutManagers] mutableCopy];
    NSEnumerator *layoutMgrEnum = [layoutMgrs objectEnumerator];
    NSLayoutManager *layoutMgr = nil;
    while (layoutMgr = [layoutMgrEnum nextObject]) [text removeLayoutManager:layoutMgr];
    
    // We can do this loop twice, if the document is loaded as rich text although the user requested plain
    BOOL retry;
    do {
	BOOL success;
	NSString *docType;
	
	retry = NO;

	[text beginEditing];
	success = [text readFromURL:absoluteURL options:options documentAttributes:&docAttrs error:outError];

        if (!success) {
	    [text endEditing];
	    layoutMgrEnum = [layoutMgrs objectEnumerator]; // rewind
	    while (layoutMgr = [layoutMgrEnum nextObject]) [text addLayoutManager:layoutMgr];   // Add the layout managers back
	    [layoutMgrs release];
	    return NO;	// return NO on error; outError has already been set
	}
	
	docType = [docAttrs objectForKey:NSDocumentTypeDocumentAttribute];

	// First check to see if the document was rich and should have been loaded as plain
	if (![[options objectForKey:NSDocumentTypeDocumentOption] isEqualToString:NSPlainTextDocumentType] && ((ignoreHTML && [docType isEqual:NSHTMLTextDocumentType]) || (ignoreRTF && ([docType isEqual:NSRTFTextDocumentType] || [docType isEqual:NSWordMLTextDocumentType])))) {
	    [text endEditing];
	    [[text mutableString] setString:@""];
	    [options setObject:NSPlainTextDocumentType forKey:NSDocumentTypeDocumentOption];
	    [self setFileType:(NSString *)kUTTypePlainText];
	    [self setOpenedIgnoringRichText:YES];
	    retry = YES;
	} else {
	    NSString *newFileType = [[self textDocumentTypeToTextEditDocumentTypeMappingTable] objectForKey:docType];
	    if (newFileType) {
		[self setFileType:newFileType];
	    } else {
		[self setFileType:(NSString *)kUTTypeRTF];	// Hmm, a new type in the Cocoa text system. Treat it as rich. ??? Should set the converted flag too?
	    }
	    if ([workspace type:[self fileType] conformsToType:(NSString *)kUTTypePlainText]) [self applyDefaultTextAttributes:NO];
	    [text endEditing];
	}
    } while(retry);

    layoutMgrEnum = [layoutMgrs objectEnumerator]; // rewind
    while (layoutMgr = [layoutMgrEnum nextObject]) [text addLayoutManager:layoutMgr];   // Add the layout managers back
    [layoutMgrs release];
    
    val = [docAttrs objectForKey:NSCharacterEncodingDocumentAttribute];
    [self setEncoding:(val ? [val unsignedIntegerValue] : NoStringEncoding)];
    
    if (val = [docAttrs objectForKey:NSConvertedDocumentAttribute]) {
        [self setConverted:([val integerValue] > 0)];	// Indicates filtered
        [self setLossy:([val integerValue] < 0)];	// Indicates lossily loaded
    }
    
    /* If the document has a stored value for view mode, use it. Otherwise wrap to window. */
    if ((val = [docAttrs objectForKey:NSViewModeDocumentAttribute])) {
        [self setHasMultiplePages:([val integerValue] == 1)];
        if ((val = [docAttrs objectForKey:NSViewZoomDocumentAttribute])) {
            [self setScaleFactor:([val doubleValue] / 100.0)];
        }
    } else [self setHasMultiplePages:NO];
    
    [self willChangeValueForKey:@"printInfo"];
    if ((val = [docAttrs objectForKey:NSLeftMarginDocumentAttribute])) [[self printInfo] setLeftMargin:[val doubleValue]];
    if ((val = [docAttrs objectForKey:NSRightMarginDocumentAttribute])) [[self printInfo] setRightMargin:[val doubleValue]];
    if ((val = [docAttrs objectForKey:NSBottomMarginDocumentAttribute])) [[self printInfo] setBottomMargin:[val doubleValue]];
    if ((val = [docAttrs objectForKey:NSTopMarginDocumentAttribute])) [[self printInfo] setTopMargin:[val doubleValue]];
    [self didChangeValueForKey:@"printInfo"];
    
    /* Pre MacOSX versions of TextEdit wrote out the view (window) size in PaperSize.
	If we encounter a non-MacOSX RTF file, and it's written by TextEdit, use PaperSize as ViewSize */
    viewSizeVal = [docAttrs objectForKey:NSViewSizeDocumentAttribute];
    paperSizeVal = [docAttrs objectForKey:NSPaperSizeDocumentAttribute];
    if (paperSizeVal && NSEqualSizes([paperSizeVal sizeValue], NSZeroSize)) paperSizeVal = nil;	// Protect against some old documents with 0 paper size
    
    if (viewSizeVal) {
        [self setViewSize:[viewSizeVal sizeValue]];
        if (paperSizeVal) [self setPaperSize:[paperSizeVal sizeValue]];
    } else {	// No ViewSize...
        if (paperSizeVal) {	// See if PaperSize should be used as ViewSize; if so, we also have some tweaking to do on it
            val = [docAttrs objectForKey:NSCocoaVersionDocumentAttribute];
            if (val && ([val integerValue] < 100)) {	// Indicates old RTF file; value described in AppKit/NSAttributedString.h
                NSSize size = [paperSizeVal sizeValue];
                if (size.width > 0 && size.height > 0 && ![self hasMultiplePages]) {
                    size.width = size.width - oldEditPaddingCompensation;
                    [self setViewSize:size];
                }
            } else {
		[self setPaperSize:[paperSizeVal sizeValue]];
            }
        }
    }
    
    [self setHyphenationFactor:(val = [docAttrs objectForKey:NSHyphenationFactorDocumentAttribute]) ? [val floatValue] : 0];
    [self setBackgroundColor:(val = [docAttrs objectForKey:NSBackgroundColorDocumentAttribute]) ? val : [NSColor whiteColor]];
    
    // Set the document properties, generically, going through key value coding
    NSDictionary *map = [self documentPropertyToAttributeNameMappings];
    for (NSString *property in [self knownDocumentProperties]) [self setValue:[docAttrs objectForKey:[map objectForKey:property]] forKey:property];	// OK to set nil to clear
    
    [self setReadOnly:((val = [docAttrs objectForKey:NSReadOnlyDocumentAttribute]) && ([val integerValue] > 0))];
    
    [[self undoManager] enableUndoRegistration];
    
    return YES;
}

- (NSDictionary *)defaultTextAttributes:(BOOL)forRichText {
    static NSParagraphStyle *defaultRichParaStyle = nil;
    NSMutableDictionary *textAttributes = [[[NSMutableDictionary alloc] initWithCapacity:2] autorelease];
    if (forRichText) {
	[textAttributes setObject:[NSFont userFontOfSize:0.0] forKey:NSFontAttributeName];
	if (defaultRichParaStyle == nil) {	// We do this once...
	    NSInteger cnt;
            NSString *measurementUnits = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleMeasurementUnits"];
            CGFloat tabInterval = ([@"Centimeters" isEqual:measurementUnits]) ? (72.0 / 2.54) : (72.0 / 2.0);  // Every cm or half inch
	    NSMutableParagraphStyle *paraStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
	    [paraStyle setTabStops:[NSArray array]];	// This first clears all tab stops
	    for (cnt = 0; cnt < 12; cnt++) {	// Add 12 tab stops, at desired intervals...
                NSTextTab *tabStop = [[NSTextTab alloc] initWithType:NSLeftTabStopType location:tabInterval * (cnt + 1)];
		[paraStyle addTabStop:tabStop];
	 	[tabStop release];
	    }
	    defaultRichParaStyle = [paraStyle copy];
	}
	[textAttributes setObject:defaultRichParaStyle forKey:NSParagraphStyleAttributeName];
    } else {
	NSFont *plainFont = [NSFont userFixedPitchFontOfSize:0.0];
	NSInteger tabWidth = [[NSUserDefaults standardUserDefaults] integerForKey:TabWidth];
	CGFloat charWidth = [@" " sizeWithAttributes:[NSDictionary dictionaryWithObject:plainFont forKey:NSFontAttributeName]].width;
        if (charWidth == 0) charWidth = [[plainFont screenFontWithRenderingMode:NSFontDefaultRenderingMode] maximumAdvancement].width;
	
	// Now use a default paragraph style, but with the tab width adjusted
	NSMutableParagraphStyle *mStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[mStyle setTabStops:[NSArray array]];
	[mStyle setDefaultTabInterval:(charWidth * tabWidth)];
        [textAttributes setObject:[[mStyle copy] autorelease] forKey:NSParagraphStyleAttributeName];
	
	// Also set the font
	[textAttributes setObject:plainFont forKey:NSFontAttributeName];
    }
    return textAttributes;
}

- (void)applyDefaultTextAttributes:(BOOL)forRichText {
    NSDictionary *textAttributes = [self defaultTextAttributes:forRichText];
    NSTextStorage *text = [self textStorage];
    // We now preserve base writing direction even for plain text, using the 10.6-introduced attribute enumeration API
    [text enumerateAttribute:NSParagraphStyleAttributeName inRange:NSMakeRange(0, [text length]) options:0 usingBlock:^(id paragraphStyle, NSRange paragraphStyleRange, BOOL *stop){
        NSWritingDirection writingDirection = paragraphStyle ? [(NSParagraphStyle *)paragraphStyle baseWritingDirection] : NSWritingDirectionNatural;
        // We also preserve NSWritingDirectionAttributeName (new in 10.6)
        [text enumerateAttribute:NSWritingDirectionAttributeName inRange:paragraphStyleRange options:0 usingBlock:^(id value, NSRange attributeRange, BOOL *stop){
            [value retain];
            [text setAttributes:textAttributes range:attributeRange];
            if (value) [text addAttribute:NSWritingDirectionAttributeName value:value range:attributeRange];
            [value release];
        }];
        if (writingDirection != NSWritingDirectionNatural) [text setBaseWritingDirection:writingDirection range:paragraphStyleRange];
    }];
}


/* This method will return a suggested encoding for the document. In Leopard, unless the user has specified a favorite encoding for saving that applies to the document, we use UTF-8.
*/
- (NSStringEncoding)suggestedDocumentEncoding {
    NSUInteger enc = NoStringEncoding;
    NSNumber *val = [[NSUserDefaults standardUserDefaults] objectForKey:PlainTextEncodingForWrite];
    if (val) {
	NSStringEncoding chosenEncoding = [val unsignedIntegerValue];
	if ((chosenEncoding != NoStringEncoding)  && (chosenEncoding != NSUnicodeStringEncoding) && (chosenEncoding != NSUTF8StringEncoding)) {
	    if ([[[self textStorage] string] canBeConvertedToEncoding:chosenEncoding]) enc = chosenEncoding;
	}
    }
    if (enc == NoStringEncoding) enc = NSUTF8StringEncoding;	// Default to UTF-8
    return enc;
}

/* Returns an object that represents the document to be written to file. 
*/
- (id)fileWrapperOfType:(NSString *)typeName error:(NSError **)outError {
    NSTextStorage *text = [self textStorage];
    NSRange range = NSMakeRange(0, [text length]);

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
	[NSValue valueWithSize:[self paperSize]], NSPaperSizeDocumentAttribute, 
	[NSNumber numberWithInteger:[self isReadOnly] ? 1 : 0], NSReadOnlyDocumentAttribute, 
	[NSNumber numberWithFloat:[self hyphenationFactor]], NSHyphenationFactorDocumentAttribute, 
	[NSNumber numberWithDouble:[[self printInfo] leftMargin]], NSLeftMarginDocumentAttribute, 
	[NSNumber numberWithDouble:[[self printInfo] rightMargin]], NSRightMarginDocumentAttribute, 
	[NSNumber numberWithDouble:[[self printInfo] bottomMargin]], NSBottomMarginDocumentAttribute, 
	[NSNumber numberWithDouble:[[self printInfo] topMargin]], NSTopMarginDocumentAttribute, 
	[NSNumber numberWithInteger:[self hasMultiplePages] ? 1 : 0], NSViewModeDocumentAttribute,
	nil];
    NSString *docType = nil;
    id val = nil; // temporary values
    
    NSSize size = [self viewSize];
    if (!NSEqualSizes(size, NSZeroSize)) {
	[dict setObject:[NSValue valueWithSize:size] forKey:NSViewSizeDocumentAttribute];
    }
    
    // TextEdit knows how to save all these types, including their super-types. It does not know how to save any of their potential subtypes. Hence, the conformance check is the reverse of the usual pattern.
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    if ([workspace type:(NSString *)kUTTypeRTF conformsToType:typeName]) docType = NSRTFTextDocumentType;
    else if ([workspace type:(NSString *)kUTTypeRTFD conformsToType:typeName]) docType = NSRTFDTextDocumentType;
    else if ([workspace type:(NSString *)kUTTypePlainText conformsToType:typeName]) docType = NSPlainTextDocumentType;
    else if ([workspace type:SimpleTextType conformsToType:typeName]) docType = NSMacSimpleTextDocumentType;
    else if ([workspace type:Word97Type conformsToType:typeName]) docType = NSDocFormatTextDocumentType;
    else if ([workspace type:Word2007Type conformsToType:typeName]) docType = NSOfficeOpenXMLTextDocumentType;
    else if ([workspace type:Word2003XMLType conformsToType:typeName]) docType = NSWordMLTextDocumentType;
    else if ([workspace type:OpenDocumentTextType conformsToType:typeName]) docType = NSOpenDocumentTextDocumentType;
    else if ([workspace type:(NSString *)kUTTypeHTML conformsToType:typeName]) docType = NSHTMLTextDocumentType;
    else if ([workspace type:(NSString *)kUTTypeWebArchive conformsToType:typeName]) docType = NSWebArchiveTextDocumentType;
    else [NSException raise:NSInvalidArgumentException format:@"%@ is not a recognized document type.", typeName];
    
    if (docType) [dict setObject:docType forKey:NSDocumentTypeDocumentAttribute];
    if ([self hasMultiplePages] && ([self scaleFactor] != 1.0)) [dict setObject:[NSNumber numberWithDouble:[self scaleFactor] * 100.0] forKey:NSViewZoomDocumentAttribute];
    if (val = [self backgroundColor]) [dict setObject:val forKey:NSBackgroundColorDocumentAttribute];
    
    if (docType == NSPlainTextDocumentType) {
        NSStringEncoding enc = [self encodingForSaving];

	// check here in case this didn't go through save panel (i.e. scripting)
        if (enc == NoStringEncoding) {
	    enc = [self encoding];
	    if (enc == NoStringEncoding) enc = [self suggestedDocumentEncoding];
	}
	[dict setObject:[NSNumber numberWithUnsignedInteger:enc] forKey:NSCharacterEncodingDocumentAttribute];
    } else if (docType == NSHTMLTextDocumentType || docType == NSWebArchiveTextDocumentType) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
	NSMutableArray *excludedElements = [NSMutableArray array];
	if (![defaults boolForKey:UseXHTMLDocType]) [excludedElements addObject:@"XML"];
	if (![defaults boolForKey:UseTransitionalDocType]) [excludedElements addObjectsFromArray:[NSArray arrayWithObjects:@"APPLET", @"BASEFONT", @"CENTER", @"DIR", @"FONT", @"ISINDEX", @"MENU", @"S", @"STRIKE", @"U", nil]];
	if (![defaults boolForKey:UseEmbeddedCSS]) {
	    [excludedElements addObject:@"STYLE"];
	    if (![defaults boolForKey:UseInlineCSS]) [excludedElements addObject:@"SPAN"];
	}
	if (![defaults boolForKey:PreserveWhitespace]) {
	    [excludedElements addObject:@"Apple-converted-space"];
	    [excludedElements addObject:@"Apple-converted-tab"];
	    [excludedElements addObject:@"Apple-interchange-newline"];
	}
	[dict setObject:excludedElements forKey:NSExcludedElementsDocumentAttribute];
	[dict setObject:[defaults objectForKey:HTMLEncoding] forKey:NSCharacterEncodingDocumentAttribute];
	[dict setObject:[NSNumber numberWithInteger:2] forKey:NSPrefixSpacesDocumentAttribute];
    }
    
    // Set the document properties, generically, going through key value coding
    for (NSString *property in [self knownDocumentProperties]) {
	id value = [self valueForKey:property];
	if (value && ![value isEqual:@""] && ![value isEqual:[NSArray array]]) [dict setObject:value forKey:[[self documentPropertyToAttributeNameMappings] objectForKey:property]];
    }
    
    NSFileWrapper *result = nil;
    if (docType == NSRTFDTextDocumentType || (docType == NSPlainTextDocumentType && ![self isOpenedIgnoringRichText])) {	// We obtain a file wrapper from the text storage for RTFD (to produce a directory), or for true plain-text documents (to write out encoding in extended attributes)
        result = [text fileWrapperFromRange:range documentAttributes:dict error:outError]; // returns NSFileWrapper
    } else {
    	NSData *data = [text dataFromRange:range documentAttributes:dict error:outError]; // returns NSData
	if (data) {
	    result = [[[NSFileWrapper alloc] initRegularFileWithContents:data] autorelease];
	    if (!result && outError) *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:nil];    // Unlikely, but just in case we should generate an NSError for this case
        }
    }
    
    return result;
}

/* Clear the delegates of the text views and window, then release all resources and go away...
*/
- (void)dealloc {
    [textStorage release];
    [backgroundColor release];
    
    [author release];
    [comment release];
    [subject release];
    [title release];
    [keywords release];
    [copyright release];
    
    [defaultDestination release];

    if (uniqueZone) NSRecycleZone([self zone]);

    [super dealloc];
}

- (CGFloat)scaleFactor {
    return scaleFactor;
}

- (void)setScaleFactor:(CGFloat)newScaleFactor {
    scaleFactor = newScaleFactor;
}

- (NSSize)viewSize {
    return viewSize;
}

- (void)setViewSize:(NSSize)size {
    viewSize = size;
}

- (void)setReadOnly:(BOOL)flag {
    isReadOnly = flag;
}

- (BOOL)isReadOnly {
    return isReadOnly;
}

- (void)setBackgroundColor:(NSColor *)color {
    id oldCol = backgroundColor;
    backgroundColor = [color copy];
    [oldCol release];
}

- (NSColor *)backgroundColor {
    return backgroundColor;
}

- (NSTextStorage *)textStorage {
    return textStorage;
}

- (NSSize)paperSize {
    return [[self printInfo] paperSize];
}

- (void)setPaperSize:(NSSize)size {
    NSPrintInfo *oldPrintInfo = [self printInfo];
    if (!NSEqualSizes(size, [oldPrintInfo paperSize])) {
	NSPrintInfo *newPrintInfo = [oldPrintInfo copy];
	[newPrintInfo setPaperSize:size];
	[self setPrintInfo:newPrintInfo];
	[newPrintInfo release];
    }
}

/* Hyphenation related methods.
*/
- (void)setHyphenationFactor:(float)factor {
    hyphenationFactor = factor;
}

- (float)hyphenationFactor {
    return hyphenationFactor;
}

/* Encoding...
*/
- (NSUInteger)encoding {
    return documentEncoding;
}

- (void)setEncoding:(NSUInteger)encoding {
    documentEncoding = encoding;
}

/* This is the encoding used for saving; valid only during a save operation
*/
- (NSUInteger)encodingForSaving {
    return documentEncodingForSaving;
}

- (void)setEncodingForSaving:(NSUInteger)encoding {
    documentEncodingForSaving = encoding;
}


- (BOOL)isConverted {
    return convertedDocument;
}

- (void)setConverted:(BOOL)flag {
    convertedDocument = flag;
}

- (BOOL)isLossy {
    return lossyDocument;
}

- (void)setLossy:(BOOL)flag {
    lossyDocument = flag;
}

- (BOOL)isOpenedIgnoringRichText {
    return openedIgnoringRichText;
}

- (void)setOpenedIgnoringRichText:(BOOL)flag {
    openedIgnoringRichText = flag;
}

/* A transient document is an untitled document that was opened automatically. If a real document is opened before the transient document is edited, the real document should replace the transient. If a transient document is edited, it ceases to be transient. 
*/
- (BOOL)isTransient {
    return transient;
}

- (void)setTransient:(BOOL)flag {
    transient = flag;
}

/* We can't replace transient document that have sheets on them.
*/
- (BOOL)isTransientAndCanBeReplaced {
    if (![self isTransient]) return NO;
    for (NSWindowController *controller in [self windowControllers]) if ([[controller window] attachedSheet]) return NO;
    return YES;
}


/* The rich text status is dependent on the document type, and vice versa. Making a plain document rich, will -setFileType: to RTF. 
*/
- (void)setRichText:(BOOL)flag {
    if (flag != [self isRichText]) {
	[self setFileType:(NSString *)(flag ? kUTTypeRTF : kUTTypePlainText)];
	if (flag) {
	    [self setDocumentPropertiesToDefaults];
	} else {
	    [self clearDocumentProperties];
	}
    }
}

- (BOOL)isRichText {
    return ![[NSWorkspace sharedWorkspace] type:[self fileType] conformsToType:(NSString *)kUTTypePlainText];
}


/* Document properties management */

/* Table mapping document property keys "company", etc, to text system document attribute keys (NSCompanyDocumentAttribute, etc)
*/
- (NSDictionary *)documentPropertyToAttributeNameMappings {
    static NSDictionary *dict = nil;
    if (!dict) dict = [[NSDictionary alloc] initWithObjectsAndKeys:
	NSCompanyDocumentAttribute, @"company", 
	NSAuthorDocumentAttribute, @"author", 
	NSKeywordsDocumentAttribute, @"keywords", 
  	NSCopyrightDocumentAttribute, @"copyright", 
	NSTitleDocumentAttribute, @"title", 
	NSSubjectDocumentAttribute, @"subject", 
	NSCommentDocumentAttribute, @"comment", nil];
    return dict;
}

- (NSArray *)knownDocumentProperties {
    return [[self documentPropertyToAttributeNameMappings] allKeys];
}

/* If there are document properties and they are not the same as the defaults established in preferences, return YES
*/
- (BOOL)hasDocumentProperties {
    for (NSString *key in [self knownDocumentProperties]) {
	id value = [self valueForKey:key];
	if (value && ![value isEqual:[[NSUserDefaults standardUserDefaults] objectForKey:key]]) return YES;
    }
    return NO;
}

/* This actually clears all properties (rather than setting them to default values established in preferences)
*/
- (void)clearDocumentProperties {
    for (NSString *key in [self knownDocumentProperties]) [self setValue:nil forKey:key];
}

/* This sets document properties to values established in defaults
*/
- (void)setDocumentPropertiesToDefaults {
    for (NSString *key in [self knownDocumentProperties]) [self setValue:[[NSUserDefaults standardUserDefaults] objectForKey:key] forKey:key];
}

/* We implement a setValue:forDocumentProperty: to work around NSUndoManager bug where prepareWithInvocationTarget: fails to freeze-dry invocations with "known" methods such as setValue:forKey:.  
*/
- (void)setValue:(id)value forDocumentProperty:(NSString *)property {
    id oldValue = [self valueForKey:property];
    [[[self undoManager] prepareWithInvocationTarget:self] setValue:oldValue forDocumentProperty:property];
    [[self undoManager] setActionName:NSLocalizedString(property, "")];	// Potential strings for action names are listed below (for genstrings to pick up)

    // Call the regular KVC mechanism to get the value to be properly set
    [super setValue:value forKey:property];
}

- (void)setValue:(id)value forKey:(NSString *)key {
    if ([[self knownDocumentProperties] containsObject:key]) { 
	[self setValue:value forDocumentProperty:key];	// We take a side-trip to this method to register for undo
    } else {
	[super setValue:value forKey:key];  // In case some other KVC call is sent to Document, we treat it normally
    }
}

/* For genstrings:
    NSLocalizedStringWithDefaultValue(@"author", @"", @"", @"Change Author", @"Undo menu change string, without the 'Undo'");
    NSLocalizedStringWithDefaultValue(@"copyright", @"", @"", @"Change Copyright", @"Undo menu change string, without the 'Undo'");
    NSLocalizedStringWithDefaultValue(@"subject", @"", @"", @"Change Subject", @"Undo menu change string, without the 'Undo'");
    NSLocalizedStringWithDefaultValue(@"title", @"", @"", @"Change Title", @"Undo menu change string, without the 'Undo'");
    NSLocalizedStringWithDefaultValue(@"company", @"", @"", @"Change Company", @"Undo menu change string, without the 'Undo'");
    NSLocalizedStringWithDefaultValue(@"comment", @"", @"", @"Change Comment", @"Undo menu change string, without the 'Undo'");
    NSLocalizedStringWithDefaultValue(@"keywords", @"", @"", @"Change Keywords", @"Undo menu change string, without the 'Undo'");
*/



- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error:(NSError **)outError {
    NSPrintInfo *tempPrintInfo = [self printInfo];
    BOOL numberPages = [[NSUserDefaults standardUserDefaults] boolForKey:NumberPagesWhenPrinting];
    if ([printSettings count] || numberPages) {
	tempPrintInfo = [[tempPrintInfo copy] autorelease];
	[[tempPrintInfo dictionary] addEntriesFromDictionary:printSettings];
	if (numberPages) {
	    [[tempPrintInfo dictionary] setValue:[NSNumber numberWithBool:YES] forKey:NSPrintHeaderAndFooter];
	}
    }
    if ([[self windowControllers] count] == 0) {
	[self makeWindowControllers];
    }
    
    NSPrintOperation *op = [NSPrintOperation printOperationWithView:[[[self windowControllers] objectAtIndex:0] documentView] printInfo:tempPrintInfo];
    [op setShowsPrintPanel:YES];
    [op setShowsProgressPanel:YES];
    
    [[[self windowControllers] objectAtIndex:0] doForegroundLayoutToCharacterIndex:NSIntegerMax];	// Make sure the whole document is laid out before printing
    
    NSPrintPanel *printPanel = [op printPanel];
    [printPanel addAccessoryController:[[[PrintPanelAccessoryController alloc] init] autorelease]];
    // We allow changing print parameters if not in "Wrap to Page" mode, where the page setup settings are used
    if (![self hasMultiplePages]) [printPanel setOptions:[printPanel options] | NSPrintPanelShowsPaperSize | NSPrintPanelShowsOrientation];
        
    return op;
}

- (NSPrintInfo *)printInfo {
    NSPrintInfo *printInfo = [super printInfo];
    if (!setUpPrintInfoDefaults) {
	setUpPrintInfoDefaults = YES;
	[printInfo setHorizontalPagination:NSFitPagination];
	[printInfo setHorizontallyCentered:NO];
	[printInfo setVerticallyCentered:NO];
	[printInfo setLeftMargin:72.0];
	[printInfo setRightMargin:72.0];
	[printInfo setTopMargin:72.0];
	[printInfo setBottomMargin:72.0];
    }
    return printInfo;
}

/* Toggles read-only state of the document
*/
- (IBAction)toggleReadOnly:(id)sender {
    [[self undoManager] registerUndoWithTarget:self selector:@selector(toggleReadOnly:) object:nil];
    [[self undoManager] setActionName:[self isReadOnly] ?
        NSLocalizedString(@"Allow Editing", @"Menu item to make the current document editable (not read-only)") :
        NSLocalizedString(@"Prevent Editing", @"Menu item to make the current document read-only")];
    [self setReadOnly:![self isReadOnly]];
}

- (BOOL)toggleRichWillLoseInformation {
    NSInteger length = [textStorage length];
    NSRange range;
    NSDictionary *attrs;
    return ( [self isRichText] // Only rich -> plain can lose information.
	     && ((length > 0) // If the document contains characters and...
		 && (attrs = [textStorage attributesAtIndex:0 effectiveRange:&range])  // ...they have attributes...
		 && ((range.length < length) // ...which either are not the same for the whole document...
		     || ![[self defaultTextAttributes:YES] isEqual:attrs]) // ...or differ from the default, then...
		 ) // ...we will lose styling information.
	     || [self hasDocumentProperties]); // We will also lose information if the document has properties.
}

- (BOOL)hasMultiplePages {
    return hasMultiplePages;
}

- (void)setHasMultiplePages:(BOOL)flag {
    hasMultiplePages = flag;
}

- (IBAction)togglePageBreaks:(id)sender {
    [self setHasMultiplePages:![self hasMultiplePages]];
}

- (void)toggleHyphenation:(id)sender {
    float currentHyphenation = [self hyphenationFactor];
    [[[self undoManager] prepareWithInvocationTarget:self] setHyphenationFactor:currentHyphenation];
    [self setHyphenationFactor:(currentHyphenation > 0.0) ? 0.0 : 0.9];	/* Toggle between 0.0 and 0.9 */
}

/* Action method for the "Append '.txt' extension" button
*/
- (void)appendPlainTextExtensionChanged:(id)sender {
    NSSavePanel *panel = (NSSavePanel *)[sender window];
    [panel setAllowsOtherFileTypes:[sender state]];
    [panel setAllowedFileTypes:[sender state] ? [NSArray arrayWithObject:(NSString *)kUTTypePlainText] : nil];
}

- (void)encodingPopupChanged:(NSPopUpButton *)popup {
    [self setEncodingForSaving:[[[popup selectedItem] representedObject] unsignedIntegerValue]];
}

/* Menu validation: Arbitrary numbers to determine the state of the menu items whose titles change. Speeds up the validation... Not zero. */   
#define TagForFirst 42
#define TagForSecond 43

void validateToggleItem(NSMenuItem *aCell, BOOL useFirst, NSString *first, NSString *second) {
    if (useFirst) {
        if ([aCell tag] != TagForFirst) {
            [aCell setTitleWithMnemonic:first];
            [aCell setTag:TagForFirst];
        }
    } else {
        if ([aCell tag] != TagForSecond) {
            [aCell setTitleWithMnemonic:second];
            [aCell setTag:TagForSecond];
        }
    }
}

/* Menu validation
*/
- (BOOL)validateMenuItem:(NSMenuItem *)aCell {
    SEL action = [aCell action];
    
    if (action == @selector(toggleReadOnly:)) {
	validateToggleItem(aCell, [self isReadOnly], NSLocalizedString(@"Allow Editing", @"Menu item to make the current document editable (not read-only)"), NSLocalizedString(@"Prevent Editing", @"Menu item to make the current document read-only"));
    } else if (action == @selector(togglePageBreaks:)) {
        validateToggleItem(aCell, [self hasMultiplePages], NSLocalizedString(@"&Wrap to Window", @"Menu item to cause text to be laid out to size of the window"), NSLocalizedString(@"&Wrap to Page", @"Menu item to cause text to be laid out to the size of the currently selected page type"));
    } else if (action == @selector(toggleHyphenation:)) {
        validateToggleItem(aCell, ([self hyphenationFactor] > 0.0), NSLocalizedString(@"Do not Allow Hyphenation", @"Menu item to disallow hyphenation in the document"), NSLocalizedString(@"Allow Hyphenation", @"Menu item to allow hyphenation in the document"));
        if ([self isReadOnly]) return NO;
    }
    
    return YES;
}

// For scripting. We already have a -textStorage method implemented above.
- (void)setTextStorage:(id)ts {
    // Warning, undo support can eat a lot of memory if a long text is changed frequently
    NSAttributedString *textStorageCopy = [[self textStorage] copy];
    [[self undoManager] registerUndoWithTarget:self selector:@selector(setTextStorage:) object:textStorageCopy];
    [textStorageCopy release];

    // ts can actually be a string or an attributed string.
    if ([ts isKindOfClass:[NSAttributedString class]]) {
        [[self textStorage] replaceCharactersInRange:NSMakeRange(0, [[self textStorage] length]) withAttributedString:ts];
    } else {
        [[self textStorage] replaceCharactersInRange:NSMakeRange(0, [[self textStorage] length]) withString:ts];
    }
}

- (IBAction)revertDocumentToSaved:(id)sender {
    // This is necessary, because document reverting doesn't happen within NSDocument if the fileURL is nil.
    // However, this is only a temporary workaround because it would be better if fileURL was never set to nil.
    if( [self fileURL] == nil && defaultDestination != nil ) {
        [self setFileURL: defaultDestination];
    }
    [super revertDocumentToSaved:sender];
}

- (BOOL)revertToContentsOfURL:(NSURL *)url ofType:(NSString *)type error:(NSError **)outError {
    // See the comment in the above override of -revertDocumentToSaved:.
    BOOL success = [super revertToContentsOfURL:url ofType:type error:outError];
    if (success) {
        [defaultDestination release];
        defaultDestination = nil;
        [self setHasMultiplePages:hasMultiplePages];
        [[self windowControllers] makeObjectsPerformSelector:@selector(setupTextViewForDocument)];
        [[self undoManager] removeAllActions];
    } else {
        // The document failed to revert correctly, or the user decided to cancel the revert.
        // This just restores the file URL to how it was before the sheet was displayed.
        [self setFileURL:nil];
    }
    return success;
}

/* Target/action method for saving as (actually "saving to") PDF. Note that this approach of omitting the path will not work on Leopard; see TextEdit's README.rtf
*/
- (IBAction)saveDocumentAsPDFTo:(id)sender {
    [self printDocumentWithSettings:[NSDictionary dictionaryWithObjectsAndKeys:NSPrintSaveJob, NSPrintJobDisposition, nil] showPrintPanel:NO delegate:nil didPrintSelector:NULL contextInfo:NULL];
}

@end


/* Returns the default padding on the left/right edges of text views
*/
CGFloat defaultTextPadding(void) {
    static CGFloat padding = -1;
    if (padding < 0.0) {
        NSTextContainer *container = [[NSTextContainer alloc] init];
        padding = [container lineFragmentPadding];
        [container release];
    }
    return padding;
}

@implementation Document (TextEditNSDocumentOverrides)

+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)typeName {
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    return !([workspace type:typeName conformsToType:(NSString *)kUTTypeHTML] || [workspace type:typeName conformsToType:(NSString *)kUTTypeWebArchive]);
}

- (id)initForURL:(NSURL *)absoluteDocumentURL withContentsOfURL:(NSURL *)absoluteDocumentContentsURL ofType:(NSString *)typeName error:(NSError **)outError {
    // This is the method that NSDocumentController invokes during reopening of an autosaved document after a crash. The passed-in type name might be NSRTFDPboardType, but absoluteDocumentURL might point to an RTF document, and if we did nothing this document's fileURL and fileType might not agree, which would cause trouble the next time the user saved this document. absoluteDocumentURL might also be nil, if the document being reopened has never been saved before. It's an oddity of NSDocument that if you override -autosavingFileType you probably have to override this method too.
    if (absoluteDocumentURL) {
	NSString *realTypeName = [[NSDocumentController sharedDocumentController] typeForContentsOfURL:absoluteDocumentURL error:outError];
	if (realTypeName) {
	    self = [super initForURL:absoluteDocumentURL withContentsOfURL:absoluteDocumentContentsURL ofType:typeName error:outError];
	    [self setFileType:realTypeName];
	} else {
	    [self release];
	    self = nil;
	}
    } else {
	self = [super initForURL:absoluteDocumentURL withContentsOfURL:absoluteDocumentContentsURL ofType:typeName error:outError];
    }
    return self;
}

- (void)makeWindowControllers {
    NSArray *myControllers = [self windowControllers];
    
    /* If this document displaced a transient document, it will already have been assigned a window controller. If that is not the case, create one. */
    if ([myControllers count] == 0) {
        [self addWindowController:[[[DocumentWindowController allocWithZone:[self zone]] init] autorelease]];
    }
}

- (NSArray *)writableTypesForSaveOperation:(NSSaveOperationType)saveOperation {
    NSMutableArray *outArray = [[[[self class] writableTypes] mutableCopy] autorelease];
    if (saveOperation == NSSaveAsOperation) {
	/* Rich-text documents cannot be saved as plain text. */
	if ([self isRichText]) {
	    [outArray removeObject:(NSString *)kUTTypePlainText];
	}
	
	/* Documents that contain attacments can only be saved in formats that support embedded graphics. */
	if ([textStorage containsAttachments]) {
	    [outArray setArray:[NSArray arrayWithObjects:(NSString *)kUTTypeRTFD, (NSString *)kUTTypeWebArchive, nil]];
	}
    }
    return outArray;
}

/* Whether to keep the backup file
*/
- (BOOL)keepBackupFile {
    return ![[NSUserDefaults standardUserDefaults] boolForKey:DeleteBackup];
}

/* When a document is changed, it ceases to be transient. 
*/
- (void)updateChangeCount:(NSDocumentChangeType)change {
    [self setTransient:NO];
    [super updateChangeCount:change];
}

/* When we save, we send a notification so that views that are currently coalescing undo actions can break that. This is done for two reasons, one technical and the other HI oriented. 

Firstly, since the dirty state tracking is based on undo, for a coalesced set of changes that span over a save operation, the changes that occur between the save and the next time the undo coalescing stops will not mark the document as dirty. Secondly, allowing the user to undo back to the precise point of a save is good UI. 

In addition we overwrite this method as a way to tell that the document has been saved successfully. If so, we set the save time parameters in the document.
*/
- (BOOL)saveToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError {
    // Note that we do the breakUndoCoalescing call even during autosave, which means the user's undo of long typing will take them back to the last spot an autosave occured. This might seem confusing, and a more elaborate solution may be possible (cause an autosave without having to breakUndoCoalescing), but since this change is coming late in Leopard, we decided to go with the lower risk fix.
    [[self windowControllers] makeObjectsPerformSelector:@selector(breakUndoCoalescing)];

    BOOL success = [super saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation error:outError];
    if (success && (saveOperation == NSSaveOperation || (saveOperation == NSSaveAsOperation))) {    // If successful, set document parameters changed during the save operation
	if ([self encodingForSaving] != NoStringEncoding) [self setEncoding:[self encodingForSaving]];
    }
    [self setEncodingForSaving:NoStringEncoding];   // This is set during prepareSavePanel:, but should be cleared for future save operation without save panel
    return success;    
}

/* Since a document into which the user has dragged graphics should autosave as RTFD, we override this method to return RTFD, unless the document was already RTFD, WebArchive, or plain (the last one done for optimization, to avoid calling containsAttachments).
*/
- (NSString *)autosavingFileType {
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    NSString *type = [super autosavingFileType];
    if ([workspace type:type conformsToType:(NSString *)kUTTypeRTFD] || [workspace type:type conformsToType:(NSString *)kUTTypeWebArchive] || [workspace type:type conformsToType:(NSString *)kUTTypePlainText]) return type;
    if ([textStorage containsAttachments]) return (NSString *)kUTTypeRTFD;
    return type;
}


/* When the file URL is set to nil, we store away the old URL. This happens when a document is converted to and from rich text. If the document exists on disk, we default to use the same base file when subsequently saving the document. 
*/
- (void)setFileURL:(NSURL *)url {
    NSURL *previousURL = [self fileURL];
    if (!url && previousURL) {
	[defaultDestination release];
	defaultDestination = [previousURL copy];
    }
    [super setFileURL:url];
}

- (void)didPresentErrorWithRecovery:(BOOL)didRecover contextInfo:(void *)contextInfo {
    if (didRecover) {
	[self performSelector:@selector(saveDocument:) withObject:self afterDelay:0.0];
    }
}

- (void)attemptRecoveryFromError:(NSError *)error optionIndex:(NSUInteger)recoveryOptionIndex delegate:(id)delegate didRecoverSelector:(SEL)didRecoverSelector contextInfo:(void *)contextInfo {
    BOOL saveAgain = NO;
    if ([[error domain] isEqualToString:TextEditErrorDomain]) {
	switch ([error code]) {
	    case TextEditSaveErrorConvertedDocument:
		if (recoveryOptionIndex == 0) { // Save with new name
		    [self setFileType:(NSString *)([textStorage containsAttachments] ? kUTTypeRTFD : kUTTypeRTF)];
		    [self setFileURL:nil];
		    [self setConverted:NO];
		    saveAgain = YES;
		} 
		break;
	    case TextEditSaveErrorLossyDocument:
		if (recoveryOptionIndex == 0) { // Save with new name
		    [self setFileURL:nil];
		    [self setLossy:NO];
		    saveAgain = YES;
		} else if (recoveryOptionIndex == 1) { // Overwrite
		    [self setLossy:NO];
		    saveAgain = YES;
		} 
		break;
	    case TextEditSaveErrorRTFDRequired:
		if (recoveryOptionIndex == 0) { // Save with new name; enable the user to choose a new name to save with
		    [self setFileType:(NSString *)kUTTypeRTFD];
		    [self setFileURL:nil];
		    saveAgain = YES;
		} else if (recoveryOptionIndex == 1) { // Save as RTFD with the same name
		    NSString *oldFilename = [[self fileURL] path];
		    NSError *newError;
		    if (![self saveToURL:[NSURL fileURLWithPath:[[oldFilename stringByDeletingPathExtension] stringByAppendingPathExtension:@"rtfd"]] ofType:(NSString *)kUTTypeRTFD forSaveOperation:NSSaveAsOperation error:&newError]) {
			// If attempt to save as RTFD fails, let the user know
			[self presentError:newError modalForWindow:[self windowForSheet] delegate:nil didPresentSelector:NULL contextInfo:contextInfo];
		    } else {
			// The RTFD is saved; we ignore error from trying to delete the RTF file
			(void)[[NSFileManager defaultManager] removeItemAtPath:oldFilename error:NULL];
		    }
		    saveAgain = NO;
		} 
		break;
	    case TextEditSaveErrorEncodingInapplicable:
		[self setEncodingForSaving:NoStringEncoding];
		[self setFileURL:nil];
		saveAgain = YES;
		break;
	}
    }

    [delegate didPresentErrorWithRecovery:saveAgain contextInfo:contextInfo];
}

- (void)saveDocumentWithDelegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo {
    NSString *currType = [self fileType];
    NSError *error = nil;
    BOOL containsAttachments = [textStorage containsAttachments];
    
    if ([self fileURL]) {
	if ([self isConverted]) {
	    NSString *newFormatName = containsAttachments ? NSLocalizedString(@"rich text with graphics (RTFD)", @"Rich text with graphics file format name, displayed in alert") 
							  : NSLocalizedString(@"rich text", @"Rich text file format name, displayed in alert");
	    error = [NSError errorWithDomain:TextEditErrorDomain code:TextEditSaveErrorConvertedDocument userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
		NSLocalizedString(@"Please supply a new name.", @"Title of alert panel which brings up a warning while saving, asking for new name"), NSLocalizedDescriptionKey,
		[NSString stringWithFormat:NSLocalizedString(@"This document was converted from a format that TextEdit cannot save. It will be saved in %@ format with a new name.", @"Contents of alert panel informing user that they need to supply a new file name because the file needs to be saved using a different format than originally read in"), newFormatName], NSLocalizedRecoverySuggestionErrorKey, 
		[NSArray arrayWithObjects:NSLocalizedString(@"Save with new name", @"Button choice allowing user to choose a new name"), NSLocalizedString(@"Cancel", @"Button choice allowing user to cancel."), nil], NSLocalizedRecoveryOptionsErrorKey,
		self, NSRecoveryAttempterErrorKey,
		nil]];
	} else if ([self isLossy]) {
	    error = [NSError errorWithDomain:TextEditErrorDomain code:TextEditSaveErrorLossyDocument userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
		NSLocalizedString(@"Are you sure you want to overwrite the document?", @"Title of alert panel which brings up a warning about saving over the same document"), NSLocalizedDescriptionKey,
		NSLocalizedString(@"Overwriting this document might cause you to lose some of the original formatting.  Would you like to save the document using a new name?", @"Contents of alert panel informing user that they need to supply a new file name because the save might be lossy"), NSLocalizedRecoverySuggestionErrorKey,
		[NSArray arrayWithObjects:NSLocalizedString(@"Save with new name", @"Button choice allowing user to choose a new name"), NSLocalizedString(@"Overwrite", @"Button choice allowing user to overwrite the document."), NSLocalizedString(@"Cancel", @"Button choice allowing user to cancel."), nil], NSLocalizedRecoveryOptionsErrorKey,
		self, NSRecoveryAttempterErrorKey,
		nil]];
	} else if (containsAttachments && ![[self writableTypesForSaveOperation:NSSaveAsOperation] containsObject:currType]) {
	    error = [NSError errorWithDomain:TextEditErrorDomain code:TextEditSaveErrorRTFDRequired userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
		NSLocalizedString(@"Are you sure you want to save using RTFD format?", @"Title of alert panel which brings up a warning while saving"), NSLocalizedDescriptionKey,
		NSLocalizedString(@"This document contains graphics and will be saved using RTFD (RTF with graphics) format. RTFD documents are not compatible with some applications. Save anyway?", @"Contents of alert panel informing user that the document is being converted from RTF to RTFD, and allowing them to cancel, save anyway, or save with new name"), NSLocalizedRecoverySuggestionErrorKey,
		[NSArray arrayWithObjects:NSLocalizedString(@"Save with new name", @"Button choice allowing user to choose a new name"), NSLocalizedString(@"Save", @"Button choice which allows the user to save the document."), NSLocalizedString(@"Cancel", @"Button choice allowing user to cancel."), nil], NSLocalizedRecoveryOptionsErrorKey,
		self, NSRecoveryAttempterErrorKey,
		nil]];
	} else if (![self isRichText]) {
	    NSUInteger enc = [self encodingForSaving];
	    if (enc == NoStringEncoding) enc = [self encoding];
	    if (![[textStorage string] canBeConvertedToEncoding:enc]) {
		error = [NSError errorWithDomain:TextEditErrorDomain code:TextEditSaveErrorEncodingInapplicable userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
		    [NSString stringWithFormat:NSLocalizedString(@"This document can no longer be saved using its original %@ encoding.", @"Title of alert panel informing user that the file's string encoding needs to be changed."), [NSString localizedNameOfStringEncoding:enc]], NSLocalizedDescriptionKey,
		    NSLocalizedString(@"Please choose another encoding (such as UTF-8).", @"Subtitle of alert panel informing user that the file's string encoding needs to be changed"), NSLocalizedRecoverySuggestionErrorKey,
		    self, NSRecoveryAttempterErrorKey,
		    nil]];
	    }
	}
    }
    
    if (error) {
	[self presentError:error modalForWindow:[self windowForSheet] delegate:self didPresentSelector:@selector(didPresentErrorWithRecovery:contextInfo:) contextInfo:NULL];
    } else {
	[super saveDocumentWithDelegate:delegate didSaveSelector:didSaveSelector contextInfo:contextInfo];
    }
}

/* For plain-text documents, we add our own accessory view for selecting encodings. The plain text case does not require a format popup. 
*/
- (BOOL)shouldRunSavePanelWithAccessoryView {
    return [self isRichText];
}

/* If the document is a converted version of a document that existed on disk, set the default directory to the directory in which the source file (converted file) resided at the time the document was converted. If the document is plain text, we additionally add an encoding popup. 
*/
- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel {
    NSPopUpButton *encodingPopup;
    NSButton *extCheckbox;
    NSUInteger cnt;
    NSString *string;
    
    if (defaultDestination) {
	NSString *dirPath = [[defaultDestination path] stringByDeletingPathExtension];
	BOOL isDir;
	if ([[NSFileManager defaultManager] fileExistsAtPath:dirPath isDirectory:&isDir] && isDir) {
	    [savePanel setDirectory:dirPath];
	}
    }
    
    if (![self isRichText]) {
	BOOL addExt = [[NSUserDefaults standardUserDefaults] boolForKey:AddExtensionToNewPlainTextFiles];
	// If no encoding, figure out which encoding should be default in encoding popup, set as document encoding.
	NSStringEncoding enc = [self encoding];
	[self setEncodingForSaving:(enc == NoStringEncoding) ? [self suggestedDocumentEncoding] : enc];
	[savePanel setAccessoryView:[[[NSDocumentController sharedDocumentController] class] encodingAccessory:[self encodingForSaving] includeDefaultEntry:NO encodingPopUp:&encodingPopup checkBox:&extCheckbox]];
	
	// Set up the checkbox
	[extCheckbox setTitle:NSLocalizedString(@"If no extension is provided, use \\U201c.txt\\U201d.", @"Checkbox indicating that if the user does not specify an extension when saving a plain text file, .txt will be used")];
	[extCheckbox setToolTip:NSLocalizedString(@"Automatically append \\U201c.txt\\U201d to the file name if no known file name extension is provided.", @"Tooltip for checkbox indicating that if the user does not specify an extension when saving a plain text file, .txt will be used")];
	[extCheckbox setState:addExt];
	[extCheckbox setAction:@selector(appendPlainTextExtensionChanged:)];
	[extCheckbox setTarget:self];
	if (addExt) {
	    [savePanel setAllowedFileTypes:[NSArray arrayWithObject:(NSString *)kUTTypePlainText]];
	    [savePanel setAllowsOtherFileTypes:YES];
	} else {
            // NSDocument defaults to setting the allowedFileType to kUTTypePlainText, which gives the fileName a ".txt" extension. We want don't want to append the extension for Untitled documents.
            // First we clear out the allowedFileType that NSDocument set. We want to allow anything, so we pass 'nil'. This will prevent NSSavePanel from appending an extension.
            [savePanel setAllowedFileTypes:nil];
            // If this document was previously saved, use the URL's name.
            NSString *fileName;
            BOOL gotFileName = [[self fileURL] getResourceValue:&fileName forKey:NSURLNameKey error:nil];
            // If the document has not yet been seaved, or we couldn't find the fileName, then use the displayName. 
            if (!gotFileName || fileName == nil) {
                fileName = [self displayName];
            }
            [savePanel setNameFieldStringValue:fileName];
        }
	
	// Further set up the encoding popup
	cnt = [encodingPopup numberOfItems];
	string = [textStorage string];
	if (cnt * [string length] < 5000000) {	// Otherwise it's just too slow; would be nice to make this more dynamic. With large docs and many encodings, the items just won't be validated.
	    while (cnt--) {	// No reason go backwards except to use one variable instead of two
                NSStringEncoding encoding = (NSStringEncoding)[[[encodingPopup itemAtIndex:cnt] representedObject] unsignedIntegerValue];
		// Hardwire some encodings known to allow any content
		if ((encoding != NoStringEncoding) && (encoding != NSUnicodeStringEncoding) && (encoding != NSUTF8StringEncoding) && (encoding != NSNonLossyASCIIStringEncoding) && ![string canBeConvertedToEncoding:encoding]) {
		    [[encodingPopup itemAtIndex:cnt] setEnabled:NO];
		}
	    }
	}
	[encodingPopup setAction:@selector(encodingPopupChanged:)];
	[encodingPopup setTarget:self];
    }
    
    return YES;
}

/* If the document does not exist on disk, but it has been converted from a document that existed on disk, return the base file name without the path extension. Otherwise return the default ("Untitled"). This is used for the window title and for the default name when saving. 
*/
- (NSString *)displayName {
    if (![self fileURL] && defaultDestination) {
	return [[[NSFileManager defaultManager] displayNameAtPath:[defaultDestination path]] stringByDeletingPathExtension];
    } else {
	return [super displayName];
    }
}

@end


/* Truncate string to no longer than truncationLength; should be > 10
*/
NSString *truncatedString(NSString *str, NSUInteger truncationLength) {
    NSUInteger len = [str length];
    if (len < truncationLength) return str;
    return [[str substringToIndex:truncationLength - 10] stringByAppendingString:@"\u2026"];	// Unicode character 2026 is ellipsis
}

<----->

<Root>
·  ♢|/*¶••••••••Document.m¶••••••••Copyright•(c)•1995-2009•by•Apple•Computer,•Inc.,•all•rights•reserved.¶••••••••Author:•Ali•Ozer¶¶••••••••Document•object•for•TextEdit.•¶→As•of•TextEdit•1.5,•a•subclass•of•NSDocument.¶*/|♢¶♢|/*¶•IMPORTANT:••This•Apple•software•is•supplied•to•you•by•Apple•Computer,•Inc.•("Apple")•in¶•consideration•of•your•agreement•to•the•following•terms,•and•your•use,•installation,•¶•modification•or•redistribution•of•this•Apple•software•constitutes•acceptance•of•these•¶•terms.••If•you•do•not•agree•with•these•terms,•please•do•not•use,•install,•modify•or•¶•redistribute•this•Apple•software.¶•¶•In•consideration•of•your•agreement•to•abide•by•the•following•terms,•and•subject•to•these•¶•terms,•Apple•grants•you•a•personal,•non-exclusive•license,•under•Apple's•copyrights•in•¶•this•original•Apple•software•(the•"Apple•Software"),•to•use,•reproduce,•modify•and•¶•redistribute•the•Apple•Software,•with•or•without•modifications,•in•source•and/or•binary•¶•forms;•provided•that•if•you•redistribute•the•Apple•Software•in•its•entirety•and•without•¶•modifications,•you•must•retain•this•notice•and•the•following•text•and•disclaimers•in•all•¶•such•redistributions•of•the•Apple•Software.••Neither•the•name,•trademarks,•service•marks•¶•or•logos•of•Apple•Computer,•Inc.•may•be•used•to•endorse•or•promote•products•derived•from•¶•the•Apple•Software•without•specific•prior•written•permission•from•Apple.•Except•as•expressly¶•stated•in•this•notice,•no•other•rights•or•licenses,•express•or•implied,•are•granted•by•Apple¶•herein,•including•but•not•limited•to•any•patent•rights•that•may•be•infringed•by•your•¶•derivative•works•or•by•other•works•in•which•the•Apple•Software•may•be•incorporated.¶•¶•The•Apple•Software•is•provided•by•Apple•on•an•"AS•IS"•basis.••APPLE•MAKES•NO•WARRANTIES,•¶•EXPRESS•OR•IMPLIED,•INCLUDING•WITHOUT•LIMITATION•THE•IMPLIED•WARRANTIES•OF•NON-INFRINGEMENT,•¶•MERCHANTABILITY•AND•FITNESS•FOR•A•PARTICULAR•PURPOSE,•REGARDING•THE•APPLE•SOFTWARE•OR•ITS•¶•USE•AND•OPERATION•ALONE•OR•IN•COMBINATION•WITH•YOUR•PRODUCTS.¶•¶•IN•NO•EVENT•SHALL•APPLE•BE•LIABLE•FOR•ANY•SPECIAL,•INDIRECT,•INCIDENTAL•OR•CONSEQUENTIAL•¶•DAMAGES•(INCLUDING,•BUT•NOT•LIMITED•TO,•PROCUREMENT•OF•SUBSTITUTE•GOODS•OR•SERVICES;•LOSS•¶•OF•USE,•DATA,•OR•PROFITS;•OR•BUSINESS•INTERRUPTION)•ARISING•IN•ANY•WAY•OUT•OF•THE•USE,•¶•REPRODUCTION,•MODIFICATION•AND/OR•DISTRIBUTION•OF•THE•APPLE•SOFTWARE,•HOWEVER•CAUSED•AND•¶•WHETHER•UNDER•THEORY•OF•CONTRACT,•TORT•(INCLUDING•NEGLIGENCE),•STRICT•LIABILITY•OR•¶•OTHERWISE,•EVEN•IF•APPLE•HAS•BEEN•ADVISED•OF•THE•POSSIBILITY•OF•SUCH•DAMAGE.¶*/|♢¶♢¶♢
·  <ObjCPreprocessorImport>
·  ·  ♢|#import|♢•♢<Cocoa/Cocoa.h>♢
·  ♢¶♢
·  <ObjCPreprocessorImport>
·  ·  ♢|#import|♢•♢|"EncodingManager.h"|♢
·  ♢¶♢
·  <ObjCPreprocessorImport>
·  ·  ♢|#import|♢•♢|"Document.h"|♢
·  ♢¶♢
·  <ObjCPreprocessorImport>
·  ·  ♢|#import|♢•♢|"DocumentController.h"|♢
·  ♢¶♢
·  <ObjCPreprocessorImport>
·  ·  ♢|#import|♢•♢|"DocumentWindowController.h"|♢
·  ♢¶♢
·  <ObjCPreprocessorImport>
·  ·  ♢|#import|♢•♢|"PrintPanelAccessoryController.h"|♢
·  ♢¶♢
·  <ObjCPreprocessorImport>
·  ·  ♢|#import|♢•♢|"TextEditDefaultsKeys.h"|♢
·  ♢¶♢
·  <ObjCPreprocessorImport>
·  ·  ♢|#import|♢•♢|"TextEditErrors.h"|♢
·  ♢¶♢
·  <ObjCPreprocessorImport>
·  ·  ♢|#import|♢•♢|"TextEditMisc.h"|♢
·  ♢¶♢¶♢
·  <CPreprocessorDefine>
·  ·  ♢|#define|♢•♢oldEditPaddingCompensation♢•♢12.0♢
·  ♢¶♢¶♢NSString♢•♢|*|♢SimpleTextType♢•♢=♢•♢|@"com.apple.traditional-mac-plain-text"|♢|;|♢¶♢NSString♢•♢|*|♢Word97Type♢•♢=♢•♢|@"com.microsoft.word.doc"|♢|;|♢¶♢NSString♢•♢|*|♢Word2007Type♢•♢=♢•♢|@"org.openxmlformats.wordprocessingml.document"|♢|;|♢¶♢NSString♢•♢|*|♢Word2003XMLType♢•♢=♢•♢|@"com.microsoft.word.wordml"|♢|;|♢¶♢NSString♢•♢|*|♢OpenDocumentTextType♢•♢=♢•♢|@"org.oasis-open.opendocument.text"|♢|;|♢¶♢¶♢¶♢
·  <ObjCImplementation>
·  ·  ♢|@implementation•Document|♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢id♢|)|♢
·  ·  ·  ♢init♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢|self|♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|super|♢•♢init♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢undoManager♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢disableUndoRegistration♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••|♢¶♢|→|♢textStorage♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSTextStorage|♢•♢allocWithZone♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢zone♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢init♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setBackgroundColor♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSColor|♢•♢whiteColor♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setEncoding♢|:|♢NoStringEncoding♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setEncodingForSaving♢|:|♢NoStringEncoding♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setScaleFactor♢|:|♢1.0♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setDocumentPropertiesToDefaults♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢¶♢|→•|♢|//•Assume•the•default•file•type•for•now,•since•-initWithType:error:•does•not•currently•get•called•when•creating•documents•using•AppleScript.•(4165700)|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setFileType♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSDocumentController|♢•♢sharedDocumentController♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢defaultType♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setPrintInfo♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢printInfo♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••|♢¶♢|→|♢hasMultiplePages♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSUserDefaults|♢•♢standardUserDefaults♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢boolForKey♢|:|♢ShowPageBreaks♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢undoManager♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢enableUndoRegistration♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢|self|♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•Return•an•NSDictionary•which•maps•Cocoa•text•system•document•identifiers•(as•declared•in•AppKit/NSAttributedString.h)•to•document•types•declared•in•TextEdit's•Info.plist.¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSDictionary♢•♢|*|♢|)|♢
·  ·  ·  ♢textDocumentTypeToTextEditDocumentTypeMappingTable♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢|static|♢•♢NSDictionary♢•♢|*|♢documentMappings♢•♢=♢•♢|nil|♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢documentMappings♢•♢==♢•♢|nil|♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢documentMappings♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSDictionary|♢•♢alloc♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢initWithObjectsAndKeys♢|:|♢¶♢|••••••••••••|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢kUTTypePlainText,♢•♢NSPlainTextDocumentType,♢¶♢|••••••••••••|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢kUTTypeRTF,♢•♢NSRTFTextDocumentType,♢¶♢|••••••••••••|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢kUTTypeRTFD,♢•♢NSRTFDTextDocumentType,♢¶♢|••••••••••••|♢SimpleTextType,♢•♢NSMacSimpleTextDocumentType,♢¶♢|••••••••••••|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢kUTTypeHTML,♢•♢NSHTMLTextDocumentType,♢¶♢|→••••|♢Word97Type,♢•♢NSDocFormatTextDocumentType,♢¶♢|→••••|♢Word2007Type,♢•♢NSOfficeOpenXMLTextDocumentType,♢¶♢|→••••|♢Word2003XMLType,♢•♢NSWordMLTextDocumentType,♢¶♢|→••••|♢OpenDocumentTextType,♢•♢NSOpenDocumentTextDocumentType,♢¶♢|••••••••••••|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢kUTTypeWebArchive,♢•♢NSWebArchiveTextDocumentType,♢¶♢|→••••|♢|nil|♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢documentMappings♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•This•method•is•called•by•the•document•controller.•The•message•is•passed•on•after•information•about•the•selected•encoding•(from•our•controller•subclass)•and•preference•regarding•HTML•and•RTF•formatting•has•been•added.•-lastSelectedEncodingForURL:•returns•the•encoding•specified•in•the•Open•panel,•or•the•default•encoding•if•the•document•was•opened•without•an•open•panel.¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢readFromURL♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSURL♢•♢|*|♢|)|♢
·  ·  ·  ♢absoluteURL♢•♢ofType♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ♢typeName♢•♢error♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSError♢•♢|*|♢|*|♢|)|♢
·  ·  ·  ♢outError♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢DocumentController♢•♢|*|♢docController♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|DocumentController|♢•♢sharedDocumentController♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢readFromURL♢|:|♢absoluteURL♢•♢ofType♢|:|♢typeName♢•♢encoding♢|:|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|docController|♢•♢lastSelectedEncodingForURL♢|:|♢absoluteURL♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢ignoreRTF♢|:|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|docController|♢•♢lastSelectedIgnoreRichForURL♢|:|♢absoluteURL♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢ignoreHTML♢|:|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|docController|♢•♢lastSelectedIgnoreHTMLForURL♢|:|♢absoluteURL♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢error♢|:|♢outError♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢readFromURL♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSURL♢•♢|*|♢|)|♢
·  ·  ·  ♢absoluteURL♢•♢ofType♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ♢typeName♢•♢encoding♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSStringEncoding♢|)|♢
·  ·  ·  ♢encoding♢•♢ignoreRTF♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢ignoreRTF♢•♢ignoreHTML♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢ignoreHTML♢•♢error♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSError♢•♢|*|♢|*|♢|)|♢
·  ·  ·  ♢outError♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢NSMutableDictionary♢•♢|*|♢options♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|NSMutableDictionary|♢•♢dictionaryWithCapacity♢|:|♢5♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢NSDictionary♢•♢|*|♢docAttrs♢|;|♢¶♢|••••|♢id♢•♢val,♢•♢paperSizeVal,♢•♢viewSizeVal♢|;|♢¶♢|••••|♢NSTextStorage♢•♢|*|♢text♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢textStorage♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢undoManager♢|]|♢
·  ·  ·  ·  ·  ♢•♢disableUndoRegistration♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|options|♢•♢setObject♢|:|♢absoluteURL♢•♢forKey♢|:|♢NSBaseURLDocumentOption♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢encoding♢•♢|!|♢=♢•♢NoStringEncoding♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|options|♢•♢setObject♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSNumber|♢•♢numberWithUnsignedInteger♢|:|♢encoding♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢forKey♢|:|♢NSCharacterEncodingDocumentOption♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setEncoding♢|:|♢encoding♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢¶♢|••••|♢|//•Check•type•to•see•if•we•should•load•the•document•as•plain.•Note•that•this•check•isn't•always•conclusive,•which•is•why•we•do•another•check•below,•after•the•document•has•been•loaded•(and•correctly•categorized).|♢¶♢|••••|♢NSWorkspace♢•♢|*|♢workspace♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|NSWorkspace|♢•♢sharedWorkspace♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢ignoreRTF♢•♢|&|♢|&|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|workspace|♢•♢type♢|:|♢typeName♢•♢conformsToType♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢kUTTypeRTF♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢||♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|workspace|♢•♢type♢|:|♢typeName♢•♢conformsToType♢|:|♢Word2003XMLType♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ♢•♢||♢•♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢ignoreHTML♢•♢|&|♢|&|♢•♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|workspace|♢•♢type♢|:|♢typeName♢•♢conformsToType♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢kUTTypeHTML♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ♢•♢||♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢isOpenedIgnoringRichText♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|options|♢•♢setObject♢|:|♢NSPlainTextDocumentType♢•♢forKey♢|:|♢NSDocumentTypeDocumentOption♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢•♢|//•Force•plain|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setFileType♢|:|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢kUTTypePlainText♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setOpenedIgnoringRichText♢|:|♢YES♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|text|♢•♢mutableString♢|]|♢
·  ·  ·  ·  ·  ♢•♢setString♢|:|♢|@""|♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|//•Remove•the•layout•managers•while•loading•the•text;•mutableCopy•retains•the•array•so•the•layout•managers•aren't•released|♢¶♢|••••|♢NSMutableArray♢•♢|*|♢layoutMgrs♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|text|♢•♢layoutManagers♢|]|♢
·  ·  ·  ·  ·  ♢•♢mutableCopy♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢NSEnumerator♢•♢|*|♢layoutMgrEnum♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|layoutMgrs|♢•♢objectEnumerator♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢NSLayoutManager♢•♢|*|♢layoutMgr♢•♢=♢•♢|nil|♢|;|♢¶♢|••••|♢|while|♢•♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢|(|♢layoutMgr♢•♢=♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|layoutMgrEnum|♢•♢nextObject♢|]|♢
·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|text|♢•♢removeLayoutManager♢|:|♢layoutMgr♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢¶♢|••••|♢|//•We•can•do•this•loop•twice,•if•the•document•is•loaded•as•rich•text•although•the•user•requested•plain|♢¶♢|••••|♢BOOL♢•♢retry♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowDoWhile>
·  ·  ·  ·  ·  ♢|do|♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢BOOL♢•♢success♢|;|♢¶♢|→|♢NSString♢•♢|*|♢docType♢|;|♢¶♢|→|♢¶♢|→|♢retry♢•♢=♢•♢NO♢|;|♢¶♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|text|♢•♢beginEditing♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢success♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|text|♢•♢readFromURL♢|:|♢absoluteURL♢•♢options♢|:|♢options♢•♢documentAttributes♢|:|♢|&|♢docAttrs♢•♢error♢|:|♢outError♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|!|♢success♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|text|♢•♢endEditing♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢layoutMgrEnum♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|layoutMgrs|♢•♢objectEnumerator♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢•♢|//•rewind|♢¶♢|→••••|♢|while|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢layoutMgr♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|layoutMgrEnum|♢•♢nextObject♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|text|♢•♢addLayoutManager♢|:|♢layoutMgr♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢•••♢|//•Add•the•layout•managers•back|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|layoutMgrs|♢•♢release♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|return|♢•♢NO♢|;|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢→♢|//•return•NO•on•error;•outError•has•already•been•set|♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|→|♢¶♢|→|♢docType♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|docAttrs|♢•♢objectForKey♢|:|♢NSDocumentTypeDocumentAttribute♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢¶♢|→|♢|//•First•check•to•see•if•the•document•was•rich•and•should•have•been•loaded•as•plain|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|!|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|options|♢•♢objectForKey♢|:|♢NSDocumentTypeDocumentOption♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢isEqualToString♢|:|♢NSPlainTextDocumentType♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢|&|♢|&|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢ignoreHTML♢•♢|&|♢|&|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|docType|♢•♢isEqual♢|:|♢NSHTMLTextDocumentType♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢||♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢ignoreRTF♢•♢|&|♢|&|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|docType|♢•♢isEqual♢|:|♢NSRTFTextDocumentType♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢||♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|docType|♢•♢isEqual♢|:|♢NSWordMLTextDocumentType♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|text|♢•♢endEditing♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|text|♢•♢mutableString♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢setString♢|:|♢|@""|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|options|♢•♢setObject♢|:|♢NSPlainTextDocumentType♢•♢forKey♢|:|♢NSDocumentTypeDocumentOption♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setFileType♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢kUTTypePlainText♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setOpenedIgnoringRichText♢|:|♢YES♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢retry♢•♢=♢•♢YES♢|;|♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  <CConditionElse>
·  ·  ·  ·  ·  ·  ·  ♢|else|♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢NSString♢•♢|*|♢newFileType♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢textDocumentTypeToTextEditDocumentTypeMappingTable♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢objectForKey♢|:|♢docType♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢newFileType♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setFileType♢|:|♢newFileType♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <CConditionElse>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|else|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setFileType♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢kUTTypeRTF♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢→♢|//•Hmm,•a•new•type•in•the•Cocoa•text•system.•Treat•it•as•rich.•???•Should•set•the•converted•flag•too?|♢¶♢|→••••|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|workspace|♢•♢type♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢fileType♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢conformsToType♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢kUTTypePlainText♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢applyDefaultTextAttributes♢|:|♢NO♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|text|♢•♢endEditing♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ·  ♢•♢|while|♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢retry♢|)|♢
·  ·  ·  ·  ♢|;|♢¶♢¶♢|••••|♢layoutMgrEnum♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|layoutMgrs|♢•♢objectEnumerator♢|]|♢
·  ·  ·  ·  ♢|;|♢•♢|//•rewind|♢¶♢|••••|♢|while|♢•♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢|(|♢layoutMgr♢•♢=♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|layoutMgrEnum|♢•♢nextObject♢|]|♢
·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|text|♢•♢addLayoutManager♢|:|♢layoutMgr♢|]|♢
·  ·  ·  ·  ♢|;|♢•••♢|//•Add•the•layout•managers•back|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|layoutMgrs|♢•♢release♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢¶♢|••••|♢val♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|docAttrs|♢•♢objectForKey♢|:|♢NSCharacterEncodingDocumentAttribute♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setEncoding♢|:|♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢val♢•♢|?|♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|val|♢•♢unsignedIntegerValue♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢|:|♢•♢NoStringEncoding♢|)|♢
·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢val♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|docAttrs|♢•♢objectForKey♢|:|♢NSConvertedDocumentAttribute♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setConverted♢|:|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|val|♢•♢integerValue♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢>♢•♢0♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢→♢|//•Indicates•filtered|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setLossy♢|:|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|val|♢•♢integerValue♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢<♢•♢0♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢→♢|//•Indicates•lossily•loaded|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢¶♢|••••|♢|/*•If•the•document•has•a•stored•value•for•view•mode,•use•it.•Otherwise•wrap•to•window.•*/|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢val♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|docAttrs|♢•♢objectForKey♢|:|♢NSViewModeDocumentAttribute♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setHasMultiplePages♢|:|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|val|♢•♢integerValue♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢==♢•♢1♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢val♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|docAttrs|♢•♢objectForKey♢|:|♢NSViewZoomDocumentAttribute♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setScaleFactor♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|val|♢•♢doubleValue♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢/♢•♢100.0♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢•♢
·  ·  ·  ·  <CConditionElse>
·  ·  ·  ·  ·  ♢|else|♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setHasMultiplePages♢|:|♢NO♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢willChangeValueForKey♢|:|♢|@"printInfo"|♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢val♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|docAttrs|♢•♢objectForKey♢|:|♢NSLeftMarginDocumentAttribute♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢printInfo♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢setLeftMargin♢|:|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|val|♢•♢doubleValue♢|]|♢
·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢val♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|docAttrs|♢•♢objectForKey♢|:|♢NSRightMarginDocumentAttribute♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢printInfo♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢setRightMargin♢|:|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|val|♢•♢doubleValue♢|]|♢
·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢val♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|docAttrs|♢•♢objectForKey♢|:|♢NSBottomMarginDocumentAttribute♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢printInfo♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢setBottomMargin♢|:|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|val|♢•♢doubleValue♢|]|♢
·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢val♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|docAttrs|♢•♢objectForKey♢|:|♢NSTopMarginDocumentAttribute♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢printInfo♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢setTopMargin♢|:|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|val|♢•♢doubleValue♢|]|♢
·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢didChangeValueForKey♢|:|♢|@"printInfo"|♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢¶♢|••••|♢|/*•Pre•MacOSX•versions•of•TextEdit•wrote•out•the•view•(window)•size•in•PaperSize.¶→If•we•encounter•a•non-MacOSX•RTF•file,•and•it's•written•by•TextEdit,•use•PaperSize•as•ViewSize•*/|♢¶♢|••••|♢viewSizeVal♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|docAttrs|♢•♢objectForKey♢|:|♢NSViewSizeDocumentAttribute♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢paperSizeVal♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|docAttrs|♢•♢objectForKey♢|:|♢NSPaperSizeDocumentAttribute♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢paperSizeVal♢•♢|&|♢|&|♢•♢
·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ♢|NSEqualSizes|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|paperSizeVal|♢•♢sizeValue♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢NSZeroSize♢|)|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢paperSizeVal♢•♢=♢•♢|nil|♢|;|♢
·  ·  ·  ·  ♢→♢|//•Protect•against•some•old•documents•with•0•paper•size|♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢viewSizeVal♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setViewSize♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|viewSizeVal|♢•♢sizeValue♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢paperSizeVal♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setPaperSize♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|paperSizeVal|♢•♢sizeValue♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢•♢
·  ·  ·  ·  <CConditionElse>
·  ·  ·  ·  ·  ♢|else|♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢→♢|//•No•ViewSize...|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢paperSizeVal♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢→♢|//•See•if•PaperSize•should•be•used•as•ViewSize;•if•so,•we•also•have•some•tweaking•to•do•on•it|♢¶♢|••••••••••••|♢val♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|docAttrs|♢•♢objectForKey♢|:|♢NSCocoaVersionDocumentAttribute♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢val♢•♢|&|♢|&|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|val|♢•♢integerValue♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢<♢•♢100♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢→♢|//•Indicates•old•RTF•file;•value•described•in•AppKit/NSAttributedString.h|♢¶♢|••••••••••••••••|♢NSSize♢•♢size♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|paperSizeVal|♢•♢sizeValue♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••••••••••|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢size.width♢•♢>♢•♢0♢•♢|&|♢|&|♢•♢size.height♢•♢>♢•♢0♢•♢|&|♢|&|♢•♢|!|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢hasMultiplePages♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••••••••••••••|♢size.width♢•♢=♢•♢size.width♢•♢-♢•♢oldEditPaddingCompensation♢|;|♢¶♢|••••••••••••••••••••|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setViewSize♢|:|♢size♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••••••••••|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|••••••••••••|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <CConditionElse>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|else|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setPaperSize♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|paperSizeVal|♢•♢sizeValue♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••••••|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|••••••••|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setHyphenationFactor♢|:|♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢val♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|docAttrs|♢•♢objectForKey♢|:|♢NSHyphenationFactorDocumentAttribute♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢|?|♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|val|♢•♢floatValue♢|]|♢
·  ·  ·  ·  ·  ♢•♢|:|♢•♢0♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setBackgroundColor♢|:|♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢val♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|docAttrs|♢•♢objectForKey♢|:|♢NSBackgroundColorDocumentAttribute♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢|?|♢•♢val♢•♢|:|♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|NSColor|♢•♢whiteColor♢|]|♢
·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢¶♢|••••|♢|//•Set•the•document•properties,•generically,•going•through•key•value•coding|♢¶♢|••••|♢NSDictionary♢•♢|*|♢map♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢documentPropertyToAttributeNameMappings♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowFor>
·  ·  ·  ·  ·  ♢|for|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢property♢•♢in♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢knownDocumentProperties♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setValue♢|:|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|docAttrs|♢•♢objectForKey♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|map|♢•♢objectForKey♢|:|♢property♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢forKey♢|:|♢property♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢→♢|//•OK•to•set•nil•to•clear|♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setReadOnly♢|:|♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢val♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|docAttrs|♢•♢objectForKey♢|:|♢NSReadOnlyDocumentAttribute♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ♢•♢|&|♢|&|♢•♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|val|♢•♢integerValue♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢>♢•♢0♢|)|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢undoManager♢|]|♢
·  ·  ·  ·  ·  ♢•♢enableUndoRegistration♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢YES♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSDictionary♢•♢|*|♢|)|♢
·  ·  ·  ♢defaultTextAttributes♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢forRichText♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢|static|♢•♢NSParagraphStyle♢•♢|*|♢defaultRichParaStyle♢•♢=♢•♢|nil|♢|;|♢¶♢|••••|♢NSMutableDictionary♢•♢|*|♢textAttributes♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSMutableDictionary|♢•♢alloc♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢initWithCapacity♢|:|♢2♢|]|♢
·  ·  ·  ·  ·  ♢•♢autorelease♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢forRichText♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|textAttributes|♢•♢setObject♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSFont|♢•♢userFontOfSize♢|:|♢0.0♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢forKey♢|:|♢NSFontAttributeName♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢defaultRichParaStyle♢•♢==♢•♢|nil|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢→♢|//•We•do•this•once...|♢¶♢|→••••|♢NSInteger♢•♢cnt♢|;|♢¶♢|••••••••••••|♢NSString♢•♢|*|♢measurementUnits♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSUserDefaults|♢•♢standardUserDefaults♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢objectForKey♢|:|♢|@"AppleMeasurementUnits"|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••••••|♢CGFloat♢•♢tabInterval♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <CConditionalOperator>
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|@"Centimeters"|♢•♢isEqual♢|:|♢measurementUnits♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢|?|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢72.0♢•♢/♢•♢2.54♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢|:|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢72.0♢•♢/♢•♢2.0♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢••♢|//•Every•cm•or•half•inch|♢¶♢|→••••|♢NSMutableParagraphStyle♢•♢|*|♢paraStyle♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSMutableParagraphStyle|♢•♢alloc♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢init♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢autorelease♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|paraStyle|♢•♢setTabStops♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSArray|♢•♢array♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢→♢|//•This•first•clears•all•tab•stops|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CFlowFor>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|for|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢cnt♢•♢=♢•♢0♢|;|♢•♢cnt♢•♢<♢•♢12♢|;|♢•♢cnt++♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢→♢|//•Add•12•tab•stops,•at•desired•intervals...|♢¶♢|••••••••••••••••|♢NSTextTab♢•♢|*|♢tabStop♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSTextTab|♢•♢alloc♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢initWithType♢|:|♢NSLeftTabStopType♢•♢location♢|:|♢tabInterval♢•♢|*|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢cnt♢•♢+♢•♢1♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|paraStyle|♢•♢addTabStop♢|:|♢tabStop♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→•→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|tabStop|♢•♢release♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|→••••|♢defaultRichParaStyle♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|paraStyle|♢•♢copy♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|textAttributes|♢•♢setObject♢|:|♢defaultRichParaStyle♢•♢forKey♢|:|♢NSParagraphStyleAttributeName♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢•♢
·  ·  ·  ·  <CConditionElse>
·  ·  ·  ·  ·  ♢|else|♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢NSFont♢•♢|*|♢plainFont♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSFont|♢•♢userFixedPitchFontOfSize♢|:|♢0.0♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢NSInteger♢•♢tabWidth♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSUserDefaults|♢•♢standardUserDefaults♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢integerForKey♢|:|♢TabWidth♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢CGFloat♢•♢charWidth♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|@"•"|♢•♢sizeWithAttributes♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSDictionary|♢•♢dictionaryWithObject♢|:|♢plainFont♢•♢forKey♢|:|♢NSFontAttributeName♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ♢.width♢|;|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢charWidth♢•♢==♢•♢0♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢charWidth♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|plainFont|♢•♢screenFontWithRenderingMode♢|:|♢NSFontDefaultRenderingMode♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢maximumAdvancement♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢.width♢|;|♢
·  ·  ·  ·  ·  ·  ♢¶♢|→|♢¶♢|→|♢|//•Now•use•a•default•paragraph•style,•but•with•the•tab•width•adjusted|♢¶♢|→|♢NSMutableParagraphStyle♢•♢|*|♢mStyle♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSParagraphStyle|♢•♢defaultParagraphStyle♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢mutableCopy♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢autorelease♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|mStyle|♢•♢setTabStops♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSArray|♢•♢array♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|mStyle|♢•♢setDefaultTabInterval♢|:|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢charWidth♢•♢|*|♢•♢tabWidth♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|textAttributes|♢•♢setObject♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|mStyle|♢•♢copy♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢autorelease♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢forKey♢|:|♢NSParagraphStyleAttributeName♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢¶♢|→|♢|//•Also•set•the•font|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|textAttributes|♢•♢setObject♢|:|♢plainFont♢•♢forKey♢|:|♢NSFontAttributeName♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢textAttributes♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢applyDefaultTextAttributes♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢forRichText♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢NSDictionary♢•♢|*|♢textAttributes♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢defaultTextAttributes♢|:|♢forRichText♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢NSTextStorage♢•♢|*|♢text♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢textStorage♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|//•We•now•preserve•base•writing•direction•even•for•plain•text,•using•the•10.6-introduced•attribute•enumeration•API|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|text|♢•♢enumerateAttribute♢|:|♢NSParagraphStyleAttributeName♢•♢inRange♢|:|♢
·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ♢|NSMakeRange|♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢0,♢•♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|text|♢•♢length♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢options♢|:|♢0♢•♢usingBlock♢|:|♢|^|♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢id♢•♢paragraphStyle,♢•♢NSRange♢•♢paragraphStyleRange,♢•♢BOOL♢•♢|*|♢stop♢|)|♢
·  ·  ·  ·  ·  ♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢NSWritingDirection♢•♢writingDirection♢•♢=♢•♢paragraphStyle♢•♢|?|♢•♢
·  ·  ·  ·  ·  ·  <Brackets>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSParagraphStyle♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢paragraphStyle♢•♢baseWritingDirection♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢|:|♢•♢NSWritingDirectionNatural♢|;|♢¶♢|••••••••|♢|//•We•also•preserve•NSWritingDirectionAttributeName•(new•in•10.6)|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|text|♢•♢enumerateAttribute♢|:|♢NSWritingDirectionAttributeName♢•♢inRange♢|:|♢paragraphStyleRange♢•♢options♢|:|♢0♢•♢usingBlock♢|:|♢|^|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢id♢•♢value,♢•♢NSRange♢•♢attributeRange,♢•♢BOOL♢•♢|*|♢stop♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|value|♢•♢retain♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|text|♢•♢setAttributes♢|:|♢textAttributes♢•♢range♢|:|♢attributeRange♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢value♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|text|♢•♢addAttribute♢|:|♢NSWritingDirectionAttributeName♢•♢value♢|:|♢value♢•♢range♢|:|♢attributeRange♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|••••••••••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|value|♢•♢release♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢writingDirection♢•♢|!|♢=♢•♢NSWritingDirectionNatural♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|text|♢•♢setBaseWritingDirection♢|:|♢writingDirection♢•♢range♢|:|♢paragraphStyleRange♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢¶♢|/*•This•method•will•return•a•suggested•encoding•for•the•document.•In•Leopard,•unless•the•user•has•specified•a•favorite•encoding•for•saving•that•applies•to•the•document,•we•use•UTF-8.¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSStringEncoding♢|)|♢
·  ·  ·  ♢suggestedDocumentEncoding♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢NSUInteger♢•♢enc♢•♢=♢•♢NoStringEncoding♢|;|♢¶♢|••••|♢NSNumber♢•♢|*|♢val♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|NSUserDefaults|♢•♢standardUserDefaults♢|]|♢
·  ·  ·  ·  ·  ♢•♢objectForKey♢|:|♢PlainTextEncodingForWrite♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢val♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢NSStringEncoding♢•♢chosenEncoding♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|val|♢•♢unsignedIntegerValue♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢chosenEncoding♢•♢|!|♢=♢•♢NoStringEncoding♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢••♢|&|♢|&|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢chosenEncoding♢•♢|!|♢=♢•♢NSUnicodeStringEncoding♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢|&|♢|&|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢chosenEncoding♢•♢|!|♢=♢•♢NSUTF8StringEncoding♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢textStorage♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢string♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢canBeConvertedToEncoding♢|:|♢chosenEncoding♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢enc♢•♢=♢•♢chosenEncoding♢|;|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢enc♢•♢==♢•♢NoStringEncoding♢|)|♢
·  ·  ·  ·  ·  ♢•♢enc♢•♢=♢•♢NSUTF8StringEncoding♢|;|♢
·  ·  ·  ·  ♢→♢|//•Default•to•UTF-8|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢enc♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•Returns•an•object•that•represents•the•document•to•be•written•to•file.•¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢id♢|)|♢
·  ·  ·  ♢fileWrapperOfType♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ♢typeName♢•♢error♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSError♢•♢|*|♢|*|♢|)|♢
·  ·  ·  ♢outError♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢NSTextStorage♢•♢|*|♢text♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢textStorage♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢NSRange♢•♢range♢•♢=♢•♢
·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ♢|NSMakeRange|♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢0,♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|text|♢•♢length♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ♢|;|♢¶♢¶♢|••••|♢NSMutableDictionary♢•♢|*|♢dict♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|NSMutableDictionary|♢•♢dictionaryWithObjectsAndKeys♢|:|♢¶♢|→|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|NSValue|♢•♢valueWithSize♢|:|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢paperSize♢|]|♢
·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ♢,♢•♢NSPaperSizeDocumentAttribute,♢•♢¶♢|→|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|NSNumber|♢•♢numberWithInteger♢|:|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢isReadOnly♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢|?|♢•♢1♢•♢|:|♢•♢0♢|]|♢
·  ·  ·  ·  ·  ♢,♢•♢NSReadOnlyDocumentAttribute,♢•♢¶♢|→|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|NSNumber|♢•♢numberWithFloat♢|:|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢hyphenationFactor♢|]|♢
·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ♢,♢•♢NSHyphenationFactorDocumentAttribute,♢•♢¶♢|→|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|NSNumber|♢•♢numberWithDouble♢|:|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢printInfo♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢leftMargin♢|]|♢
·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ♢,♢•♢NSLeftMarginDocumentAttribute,♢•♢¶♢|→|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|NSNumber|♢•♢numberWithDouble♢|:|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢printInfo♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢rightMargin♢|]|♢
·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ♢,♢•♢NSRightMarginDocumentAttribute,♢•♢¶♢|→|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|NSNumber|♢•♢numberWithDouble♢|:|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢printInfo♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢bottomMargin♢|]|♢
·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ♢,♢•♢NSBottomMarginDocumentAttribute,♢•♢¶♢|→|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|NSNumber|♢•♢numberWithDouble♢|:|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢printInfo♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢topMargin♢|]|♢
·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ♢,♢•♢NSTopMarginDocumentAttribute,♢•♢¶♢|→|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|NSNumber|♢•♢numberWithInteger♢|:|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢hasMultiplePages♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢|?|♢•♢1♢•♢|:|♢•♢0♢|]|♢
·  ·  ·  ·  ·  ♢,♢•♢NSViewModeDocumentAttribute,♢¶♢|→|♢|nil|♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢NSString♢•♢|*|♢docType♢•♢=♢•♢|nil|♢|;|♢¶♢|••••|♢id♢•♢val♢•♢=♢•♢|nil|♢|;|♢•♢|//•temporary•values|♢¶♢|••••|♢¶♢|••••|♢NSSize♢•♢size♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢viewSize♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢|!|♢
·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ♢|NSEqualSizes|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢size,♢•♢NSZeroSize♢|)|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|dict|♢•♢setObject♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSValue|♢•♢valueWithSize♢|:|♢size♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢forKey♢|:|♢NSViewSizeDocumentAttribute♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢¶♢|••••|♢|//•TextEdit•knows•how•to•save•all•these•types,•including•their•super-types.•It•does•not•know•how•to•save•any•of•their•potential•subtypes.•Hence,•the•conformance•check•is•the•reverse•of•the•usual•pattern.|♢¶♢|••••|♢NSWorkspace♢•♢|*|♢workspace♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|NSWorkspace|♢•♢sharedWorkspace♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|workspace|♢•♢type♢|:|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢kUTTypeRTF♢•♢conformsToType♢|:|♢typeName♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢docType♢•♢=♢•♢NSRTFTextDocumentType♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CConditionElseIf>
·  ·  ·  ·  ·  ♢|else•if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|workspace|♢•♢type♢|:|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢kUTTypeRTFD♢•♢conformsToType♢|:|♢typeName♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢docType♢•♢=♢•♢NSRTFDTextDocumentType♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CConditionElseIf>
·  ·  ·  ·  ·  ♢|else•if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|workspace|♢•♢type♢|:|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢kUTTypePlainText♢•♢conformsToType♢|:|♢typeName♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢docType♢•♢=♢•♢NSPlainTextDocumentType♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CConditionElseIf>
·  ·  ·  ·  ·  ♢|else•if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|workspace|♢•♢type♢|:|♢SimpleTextType♢•♢conformsToType♢|:|♢typeName♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢docType♢•♢=♢•♢NSMacSimpleTextDocumentType♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CConditionElseIf>
·  ·  ·  ·  ·  ♢|else•if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|workspace|♢•♢type♢|:|♢Word97Type♢•♢conformsToType♢|:|♢typeName♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢docType♢•♢=♢•♢NSDocFormatTextDocumentType♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CConditionElseIf>
·  ·  ·  ·  ·  ♢|else•if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|workspace|♢•♢type♢|:|♢Word2007Type♢•♢conformsToType♢|:|♢typeName♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢docType♢•♢=♢•♢NSOfficeOpenXMLTextDocumentType♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CConditionElseIf>
·  ·  ·  ·  ·  ♢|else•if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|workspace|♢•♢type♢|:|♢Word2003XMLType♢•♢conformsToType♢|:|♢typeName♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢docType♢•♢=♢•♢NSWordMLTextDocumentType♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CConditionElseIf>
·  ·  ·  ·  ·  ♢|else•if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|workspace|♢•♢type♢|:|♢OpenDocumentTextType♢•♢conformsToType♢|:|♢typeName♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢docType♢•♢=♢•♢NSOpenDocumentTextDocumentType♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CConditionElseIf>
·  ·  ·  ·  ·  ♢|else•if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|workspace|♢•♢type♢|:|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢kUTTypeHTML♢•♢conformsToType♢|:|♢typeName♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢docType♢•♢=♢•♢NSHTMLTextDocumentType♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CConditionElseIf>
·  ·  ·  ·  ·  ♢|else•if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|workspace|♢•♢type♢|:|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢kUTTypeWebArchive♢•♢conformsToType♢|:|♢typeName♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢docType♢•♢=♢•♢NSWebArchiveTextDocumentType♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CConditionElse>
·  ·  ·  ·  ·  ♢|else|♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|NSException|♢•♢raise♢|:|♢NSInvalidArgumentException♢•♢format♢|:|♢|@"%@•is•not•a•recognized•document•type."|♢,♢•♢typeName♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢docType♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|dict|♢•♢setObject♢|:|♢docType♢•♢forKey♢|:|♢NSDocumentTypeDocumentAttribute♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢hasMultiplePages♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢|&|♢|&|♢•♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢scaleFactor♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢|!|♢=♢•♢1.0♢|)|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|dict|♢•♢setObject♢|:|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSNumber|♢•♢numberWithDouble♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢scaleFactor♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢|*|♢•♢100.0♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢forKey♢|:|♢NSViewZoomDocumentAttribute♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢val♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢backgroundColor♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|dict|♢•♢setObject♢|:|♢val♢•♢forKey♢|:|♢NSBackgroundColorDocumentAttribute♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢docType♢•♢==♢•♢NSPlainTextDocumentType♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢NSStringEncoding♢•♢enc♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢encodingForSaving♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢¶♢|→|♢|//•check•here•in•case•this•didn't•go•through•save•panel•(i.e.•scripting)|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢enc♢•♢==♢•♢NoStringEncoding♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢enc♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢encoding♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢enc♢•♢==♢•♢NoStringEncoding♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢enc♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢suggestedDocumentEncoding♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|dict|♢•♢setObject♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSNumber|♢•♢numberWithUnsignedInteger♢|:|♢enc♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢forKey♢|:|♢NSCharacterEncodingDocumentAttribute♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢•♢
·  ·  ·  ·  <CConditionElseIf>
·  ·  ·  ·  ·  ♢|else•if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢docType♢•♢==♢•♢NSHTMLTextDocumentType♢•♢||♢•♢docType♢•♢==♢•♢NSWebArchiveTextDocumentType♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢NSUserDefaults♢•♢|*|♢defaults♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSUserDefaults|♢•♢standardUserDefaults♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••|♢¶♢|→|♢NSMutableArray♢•♢|*|♢excludedElements♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSMutableArray|♢•♢array♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|!|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|defaults|♢•♢boolForKey♢|:|♢UseXHTMLDocType♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|excludedElements|♢•♢addObject♢|:|♢|@"XML"|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ·  ·  ♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|!|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|defaults|♢•♢boolForKey♢|:|♢UseTransitionalDocType♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|excludedElements|♢•♢addObjectsFromArray♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSArray|♢•♢arrayWithObjects♢|:|♢|@"APPLET"|♢,♢•♢|@"BASEFONT"|♢,♢•♢|@"CENTER"|♢,♢•♢|@"DIR"|♢,♢•♢|@"FONT"|♢,♢•♢|@"ISINDEX"|♢,♢•♢|@"MENU"|♢,♢•♢|@"S"|♢,♢•♢|@"STRIKE"|♢,♢•♢|@"U"|♢,♢•♢|nil|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ·  ·  ♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|!|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|defaults|♢•♢boolForKey♢|:|♢UseEmbeddedCSS♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|excludedElements|♢•♢addObject♢|:|♢|@"STYLE"|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|!|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|defaults|♢•♢boolForKey♢|:|♢UseInlineCSS♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|excludedElements|♢•♢addObject♢|:|♢|@"SPAN"|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|!|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|defaults|♢•♢boolForKey♢|:|♢PreserveWhitespace♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|excludedElements|♢•♢addObject♢|:|♢|@"Apple-converted-space"|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|excludedElements|♢•♢addObject♢|:|♢|@"Apple-converted-tab"|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|excludedElements|♢•♢addObject♢|:|♢|@"Apple-interchange-newline"|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|dict|♢•♢setObject♢|:|♢excludedElements♢•♢forKey♢|:|♢NSExcludedElementsDocumentAttribute♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|dict|♢•♢setObject♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|defaults|♢•♢objectForKey♢|:|♢HTMLEncoding♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢forKey♢|:|♢NSCharacterEncodingDocumentAttribute♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|dict|♢•♢setObject♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSNumber|♢•♢numberWithInteger♢|:|♢2♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢forKey♢|:|♢NSPrefixSpacesDocumentAttribute♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢¶♢|••••|♢|//•Set•the•document•properties,•generically,•going•through•key•value•coding|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowFor>
·  ·  ·  ·  ·  ♢|for|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢property♢•♢in♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢knownDocumentProperties♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢id♢•♢value♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢valueForKey♢|:|♢property♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢value♢•♢|&|♢|&|♢•♢|!|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|value|♢•♢isEqual♢|:|♢|@""|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢|&|♢|&|♢•♢|!|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|value|♢•♢isEqual♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSArray|♢•♢array♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|dict|♢•♢setObject♢|:|♢value♢•♢forKey♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢documentPropertyToAttributeNameMappings♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢objectForKey♢|:|♢property♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢¶♢|••••|♢NSFileWrapper♢•♢|*|♢result♢•♢=♢•♢|nil|♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢docType♢•♢==♢•♢NSRTFDTextDocumentType♢•♢||♢•♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢docType♢•♢==♢•♢NSPlainTextDocumentType♢•♢|&|♢|&|♢•♢|!|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢isOpenedIgnoringRichText♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢→♢|//•We•obtain•a•file•wrapper•from•the•text•storage•for•RTFD•(to•produce•a•directory),•or•for•true•plain-text•documents•(to•write•out•encoding•in•extended•attributes)|♢¶♢|••••••••|♢result♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|text|♢•♢fileWrapperFromRange♢|:|♢range♢•♢documentAttributes♢|:|♢dict♢•♢error♢|:|♢outError♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢•♢|//•returns•NSFileWrapper|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢•♢
·  ·  ·  ·  <CConditionElse>
·  ·  ·  ·  ·  ♢|else|♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••→|♢NSData♢•♢|*|♢data♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|text|♢•♢dataFromRange♢|:|♢range♢•♢documentAttributes♢|:|♢dict♢•♢error♢|:|♢outError♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢•♢|//•returns•NSData|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢data♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢result♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSFileWrapper|♢•♢alloc♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢initRegularFileWithContents♢|:|♢data♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢autorelease♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|!|♢result♢•♢|&|♢|&|♢•♢outError♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢|*|♢outError♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSError|♢•♢errorWithDomain♢|:|♢NSCocoaErrorDomain♢•♢code♢|:|♢NSFileWriteUnknownError♢•♢userInfo♢|:|♢|nil|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢••••♢|//•Unlikely,•but•just•in•case•we•should•generate•an•NSError•for•this•case|♢¶♢|••••••••|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢result♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•Clear•the•delegates•of•the•text•views•and•window,•then•release•all•resources•and•go•away...¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢dealloc♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|textStorage|♢•♢release♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|backgroundColor|♢•♢release♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|author|♢•♢release♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|comment|♢•♢release♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|subject|♢•♢release♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|title|♢•♢release♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|keywords|♢•♢release♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|copyright|♢•♢release♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|defaultDestination|♢•♢release♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢uniqueZone♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ♢|NSRecycleZone|♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢zone♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|super|♢•♢dealloc♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢CGFloat♢|)|♢
·  ·  ·  ♢scaleFactor♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢scaleFactor♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢setScaleFactor♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢CGFloat♢|)|♢
·  ·  ·  ♢newScaleFactor♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢scaleFactor♢•♢=♢•♢newScaleFactor♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSSize♢|)|♢
·  ·  ·  ♢viewSize♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢viewSize♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢setViewSize♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSSize♢|)|♢
·  ·  ·  ♢size♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢viewSize♢•♢=♢•♢size♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢setReadOnly♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢flag♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢isReadOnly♢•♢=♢•♢flag♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢isReadOnly♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢isReadOnly♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢setBackgroundColor♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSColor♢•♢|*|♢|)|♢
·  ·  ·  ♢color♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢id♢•♢oldCol♢•♢=♢•♢backgroundColor♢|;|♢¶♢|••••|♢backgroundColor♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|color|♢•♢copy♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|oldCol|♢•♢release♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSColor♢•♢|*|♢|)|♢
·  ·  ·  ♢backgroundColor♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢backgroundColor♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSTextStorage♢•♢|*|♢|)|♢
·  ·  ·  ♢textStorage♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢textStorage♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSSize♢|)|♢
·  ·  ·  ♢paperSize♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢printInfo♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢paperSize♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢setPaperSize♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSSize♢|)|♢
·  ·  ·  ♢size♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢NSPrintInfo♢•♢|*|♢oldPrintInfo♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢printInfo♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢|!|♢
·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ♢|NSEqualSizes|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢size,♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|oldPrintInfo|♢•♢paperSize♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢NSPrintInfo♢•♢|*|♢newPrintInfo♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|oldPrintInfo|♢•♢copy♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|newPrintInfo|♢•♢setPaperSize♢|:|♢size♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setPrintInfo♢|:|♢newPrintInfo♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|newPrintInfo|♢•♢release♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•Hyphenation•related•methods.¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢setHyphenationFactor♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|float|♢|)|♢
·  ·  ·  ♢factor♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢hyphenationFactor♢•♢=♢•♢factor♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|float|♢|)|♢
·  ·  ·  ♢hyphenationFactor♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢hyphenationFactor♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•Encoding...¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSUInteger♢|)|♢
·  ·  ·  ♢encoding♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢documentEncoding♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢setEncoding♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSUInteger♢|)|♢
·  ·  ·  ♢encoding♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢documentEncoding♢•♢=♢•♢encoding♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•This•is•the•encoding•used•for•saving;•valid•only•during•a•save•operation¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSUInteger♢|)|♢
·  ·  ·  ♢encodingForSaving♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢documentEncodingForSaving♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢setEncodingForSaving♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSUInteger♢|)|♢
·  ·  ·  ♢encoding♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢documentEncodingForSaving♢•♢=♢•♢encoding♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢isConverted♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢convertedDocument♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢setConverted♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢flag♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢convertedDocument♢•♢=♢•♢flag♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢isLossy♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢lossyDocument♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢setLossy♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢flag♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢lossyDocument♢•♢=♢•♢flag♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢isOpenedIgnoringRichText♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢openedIgnoringRichText♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢setOpenedIgnoringRichText♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢flag♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢openedIgnoringRichText♢•♢=♢•♢flag♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•A•transient•document•is•an•untitled•document•that•was•opened•automatically.•If•a•real•document•is•opened•before•the•transient•document•is•edited,•the•real•document•should•replace•the•transient.•If•a•transient•document•is•edited,•it•ceases•to•be•transient.•¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢isTransient♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢transient♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢setTransient♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢flag♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢transient♢•♢=♢•♢flag♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•We•can't•replace•transient•document•that•have•sheets•on•them.¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢isTransientAndCanBeReplaced♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢|!|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢isTransient♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ·  ♢|return|♢•♢NO♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CFlowFor>
·  ·  ·  ·  ·  ♢|for|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢NSWindowController♢•♢|*|♢controller♢•♢in♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢windowControllers♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|controller|♢•♢window♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢attachedSheet♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ·  ·  ♢|return|♢•♢NO♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢YES♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢¶♢|/*•The•rich•text•status•is•dependent•on•the•document•type,•and•vice•versa.•Making•a•plain•document•rich,•will•-setFileType:•to•RTF.•¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢setRichText♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢flag♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢flag♢•♢|!|♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢isRichText♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setFileType♢|:|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  <CConditionalOperator>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢flag♢•♢|?|♢•♢kUTTypeRTF♢•♢|:|♢•♢kUTTypePlainText♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢flag♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setDocumentPropertiesToDefaults♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  <CConditionElse>
·  ·  ·  ·  ·  ·  ·  ♢|else|♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢clearDocumentProperties♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢isRichText♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢|!|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSWorkspace|♢•♢sharedWorkspace♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢type♢|:|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢fileType♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢conformsToType♢|:|♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ♢kUTTypePlainText♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢¶♢|/*•Document•properties•management•*/|♢¶♢¶♢|/*•Table•mapping•document•property•keys•"company",•etc,•to•text•system•document•attribute•keys•(NSCompanyDocumentAttribute,•etc)¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSDictionary♢•♢|*|♢|)|♢
·  ·  ·  ♢documentPropertyToAttributeNameMappings♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢|static|♢•♢NSDictionary♢•♢|*|♢dict♢•♢=♢•♢|nil|♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢|!|♢dict♢|)|♢
·  ·  ·  ·  ·  ♢•♢dict♢•♢=♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSDictionary|♢•♢alloc♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢initWithObjectsAndKeys♢|:|♢¶♢|→|♢NSCompanyDocumentAttribute,♢•♢|@"company"|♢,♢•♢¶♢|→|♢NSAuthorDocumentAttribute,♢•♢|@"author"|♢,♢•♢¶♢|→|♢NSKeywordsDocumentAttribute,♢•♢|@"keywords"|♢,♢•♢¶♢|••→|♢NSCopyrightDocumentAttribute,♢•♢|@"copyright"|♢,♢•♢¶♢|→|♢NSTitleDocumentAttribute,♢•♢|@"title"|♢,♢•♢¶♢|→|♢NSSubjectDocumentAttribute,♢•♢|@"subject"|♢,♢•♢¶♢|→|♢NSCommentDocumentAttribute,♢•♢|@"comment"|♢,♢•♢|nil|♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢dict♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSArray♢•♢|*|♢|)|♢
·  ·  ·  ♢knownDocumentProperties♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢documentPropertyToAttributeNameMappings♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢allKeys♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•If•there•are•document•properties•and•they•are•not•the•same•as•the•defaults•established•in•preferences,•return•YES¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢hasDocumentProperties♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowFor>
·  ·  ·  ·  ·  ♢|for|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢key♢•♢in♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢knownDocumentProperties♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢id♢•♢value♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢valueForKey♢|:|♢key♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢value♢•♢|&|♢|&|♢•♢|!|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|value|♢•♢isEqual♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSUserDefaults|♢•♢standardUserDefaults♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢objectForKey♢|:|♢key♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ·  ·  ·  ♢|return|♢•♢YES♢|;|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢NO♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•This•actually•clears•all•properties•(rather•than•setting•them•to•default•values•established•in•preferences)¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢clearDocumentProperties♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowFor>
·  ·  ·  ·  ·  ♢|for|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢key♢•♢in♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢knownDocumentProperties♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setValue♢|:|♢|nil|♢•♢forKey♢|:|♢key♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•This•sets•document•properties•to•values•established•in•defaults¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢setDocumentPropertiesToDefaults♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowFor>
·  ·  ·  ·  ·  ♢|for|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢key♢•♢in♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢knownDocumentProperties♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setValue♢|:|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSUserDefaults|♢•♢standardUserDefaults♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢objectForKey♢|:|♢key♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢forKey♢|:|♢key♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•We•implement•a•setValue:forDocumentProperty:•to•work•around•NSUndoManager•bug•where•prepareWithInvocationTarget:•fails•to•freeze-dry•invocations•with•"known"•methods•such•as•setValue:forKey:.••¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢setValue♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢id♢|)|♢
·  ·  ·  ♢value♢•♢forDocumentProperty♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ♢property♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢id♢•♢oldValue♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢valueForKey♢|:|♢property♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢undoManager♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢prepareWithInvocationTarget♢|:|♢|self|♢|]|♢
·  ·  ·  ·  ·  ♢•♢setValue♢|:|♢oldValue♢•♢forDocumentProperty♢|:|♢property♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢undoManager♢|]|♢
·  ·  ·  ·  ·  ♢•♢setActionName♢|:|♢
·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢property,♢•♢|""|♢|)|♢
·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ♢|;|♢→♢|//•Potential•strings•for•action•names•are•listed•below•(for•genstrings•to•pick•up)|♢¶♢¶♢|••••|♢|//•Call•the•regular•KVC•mechanism•to•get•the•value•to•be•properly•set|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|super|♢•♢setValue♢|:|♢value♢•♢forKey♢|:|♢property♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢setValue♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢id♢|)|♢
·  ·  ·  ♢value♢•♢forKey♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ♢key♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢knownDocumentProperties♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢containsObject♢|:|♢key♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢•♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setValue♢|:|♢value♢•♢forDocumentProperty♢|:|♢key♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢→♢|//•We•take•a•side-trip•to•this•method•to•register•for•undo|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢•♢
·  ·  ·  ·  <CConditionElse>
·  ·  ·  ·  ·  ♢|else|♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|super|♢•♢setValue♢|:|♢value♢•♢forKey♢|:|♢key♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢••♢|//•In•case•some•other•KVC•call•is•sent•to•Document,•we•treat•it•normally|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•For•genstrings:¶••••NSLocalizedStringWithDefaultValue(@"author",•@"",•@"",•@"Change•Author",•@"Undo•menu•change•string,•without•the•'Undo'");¶••••NSLocalizedStringWithDefaultValue(@"copyright",•@"",•@"",•@"Change•Copyright",•@"Undo•menu•change•string,•without•the•'Undo'");¶••••NSLocalizedStringWithDefaultValue(@"subject",•@"",•@"",•@"Change•Subject",•@"Undo•menu•change•string,•without•the•'Undo'");¶••••NSLocalizedStringWithDefaultValue(@"title",•@"",•@"",•@"Change•Title",•@"Undo•menu•change•string,•without•the•'Undo'");¶••••NSLocalizedStringWithDefaultValue(@"company",•@"",•@"",•@"Change•Company",•@"Undo•menu•change•string,•without•the•'Undo'");¶••••NSLocalizedStringWithDefaultValue(@"comment",•@"",•@"",•@"Change•Comment",•@"Undo•menu•change•string,•without•the•'Undo'");¶••••NSLocalizedStringWithDefaultValue(@"keywords",•@"",•@"",•@"Change•Keywords",•@"Undo•menu•change•string,•without•the•'Undo'");¶*/|♢¶♢¶♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSPrintOperation♢•♢|*|♢|)|♢
·  ·  ·  ♢printOperationWithSettings♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSDictionary♢•♢|*|♢|)|♢
·  ·  ·  ♢printSettings♢•♢error♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSError♢•♢|*|♢|*|♢|)|♢
·  ·  ·  ♢outError♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢NSPrintInfo♢•♢|*|♢tempPrintInfo♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢printInfo♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢BOOL♢•♢numberPages♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|NSUserDefaults|♢•♢standardUserDefaults♢|]|♢
·  ·  ·  ·  ·  ♢•♢boolForKey♢|:|♢NumberPagesWhenPrinting♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|printSettings|♢•♢count♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢||♢•♢numberPages♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢tempPrintInfo♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|tempPrintInfo|♢•♢copy♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢autorelease♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|tempPrintInfo|♢•♢dictionary♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢addEntriesFromDictionary♢|:|♢printSettings♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢numberPages♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|tempPrintInfo|♢•♢dictionary♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢setValue♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSNumber|♢•♢numberWithBool♢|:|♢YES♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢forKey♢|:|♢NSPrintHeaderAndFooter♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢windowControllers♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢count♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢==♢•♢0♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢makeWindowControllers♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢¶♢|••••|♢NSPrintOperation♢•♢|*|♢op♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|NSPrintOperation|♢•♢printOperationWithView♢|:|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢windowControllers♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢objectAtIndex♢|:|♢0♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢documentView♢|]|♢
·  ·  ·  ·  ·  ♢•♢printInfo♢|:|♢tempPrintInfo♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|op|♢•♢setShowsPrintPanel♢|:|♢YES♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|op|♢•♢setShowsProgressPanel♢|:|♢YES♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢windowControllers♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢objectAtIndex♢|:|♢0♢|]|♢
·  ·  ·  ·  ·  ♢•♢doForegroundLayoutToCharacterIndex♢|:|♢NSIntegerMax♢|]|♢
·  ·  ·  ·  ♢|;|♢→♢|//•Make•sure•the•whole•document•is•laid•out•before•printing|♢¶♢|••••|♢¶♢|••••|♢NSPrintPanel♢•♢|*|♢printPanel♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|op|♢•♢printPanel♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|printPanel|♢•♢addAccessoryController♢|:|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|PrintPanelAccessoryController|♢•♢alloc♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢init♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢autorelease♢|]|♢
·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|//•We•allow•changing•print•parameters•if•not•in•"Wrap•to•Page"•mode,•where•the•page•setup•settings•are•used|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢|!|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢hasMultiplePages♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|printPanel|♢•♢setOptions♢|:|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|printPanel|♢•♢options♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢|♢•♢NSPrintPanelShowsPaperSize♢•♢|♢•♢NSPrintPanelShowsOrientation♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢|••••••••|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢op♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSPrintInfo♢•♢|*|♢|)|♢
·  ·  ·  ♢printInfo♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢NSPrintInfo♢•♢|*|♢printInfo♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|super|♢•♢printInfo♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢|!|♢setUpPrintInfoDefaults♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢setUpPrintInfoDefaults♢•♢=♢•♢YES♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|printInfo|♢•♢setHorizontalPagination♢|:|♢NSFitPagination♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|printInfo|♢•♢setHorizontallyCentered♢|:|♢NO♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|printInfo|♢•♢setVerticallyCentered♢|:|♢NO♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|printInfo|♢•♢setLeftMargin♢|:|♢72.0♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|printInfo|♢•♢setRightMargin♢|:|♢72.0♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|printInfo|♢•♢setTopMargin♢|:|♢72.0♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|printInfo|♢•♢setBottomMargin♢|:|♢72.0♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢printInfo♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•Toggles•read-only•state•of•the•document¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢IBAction♢|)|♢
·  ·  ·  ♢toggleReadOnly♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢id♢|)|♢
·  ·  ·  ♢sender♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢undoManager♢|]|♢
·  ·  ·  ·  ·  ♢•♢registerUndoWithTarget♢|:|♢|self|♢•♢selector♢|:|♢
·  ·  ·  ·  ·  <ObjCSelector>
·  ·  ·  ·  ·  ·  ♢|@selector|♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢toggleReadOnly♢|:|♢|)|♢
·  ·  ·  ·  ·  ♢•♢object♢|:|♢|nil|♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢undoManager♢|]|♢
·  ·  ·  ·  ·  ♢•♢setActionName♢|:|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢isReadOnly♢|]|♢
·  ·  ·  ·  ·  ♢•♢|?|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"Allow•Editing"|♢,♢•♢|@"Menu•item•to•make•the•current•document•editable•(not•read-only)"|♢|)|♢
·  ·  ·  ·  ·  ♢•♢|:|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"Prevent•Editing"|♢,♢•♢|@"Menu•item•to•make•the•current•document•read-only"|♢|)|♢
·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setReadOnly♢|:|♢|!|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢isReadOnly♢|]|♢
·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢toggleRichWillLoseInformation♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢NSInteger♢•♢length♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|textStorage|♢•♢length♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢NSRange♢•♢range♢|;|♢¶♢|••••|♢NSDictionary♢•♢|*|♢attrs♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢isRichText♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢|//•Only•rich•->•plain•can•lose•information.|♢¶♢|→•••••|♢|&|♢|&|♢•♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢length♢•♢>♢•♢0♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢|//•If•the•document•contains•characters•and...|♢¶♢|→→•|♢|&|♢|&|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢attrs♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|textStorage|♢•♢attributesAtIndex♢|:|♢0♢•♢effectiveRange♢|:|♢|&|♢range♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢••♢|//•...they•have•attributes...|♢¶♢|→→•|♢|&|♢|&|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢range.length♢•♢<♢•♢length♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢|//•...which•either•are•not•the•same•for•the•whole•document...|♢¶♢|→→•••••|♢||♢•♢|!|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢defaultTextAttributes♢|:|♢YES♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢isEqual♢|:|♢attrs♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢|//•...or•differ•from•the•default,•then...|♢¶♢|→→•|♢|)|♢
·  ·  ·  ·  ·  ·  ♢•♢|//•...we•will•lose•styling•information.|♢¶♢|→•••••|♢||♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢hasDocumentProperties♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢•♢|//•We•will•also•lose•information•if•the•document•has•properties.|♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢hasMultiplePages♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢hasMultiplePages♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢setHasMultiplePages♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢flag♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢hasMultiplePages♢•♢=♢•♢flag♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢IBAction♢|)|♢
·  ·  ·  ♢togglePageBreaks♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢id♢|)|♢
·  ·  ·  ♢sender♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setHasMultiplePages♢|:|♢|!|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢hasMultiplePages♢|]|♢
·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢toggleHyphenation♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢id♢|)|♢
·  ·  ·  ♢sender♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢|float|♢•♢currentHyphenation♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢hyphenationFactor♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢undoManager♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢prepareWithInvocationTarget♢|:|♢|self|♢|]|♢
·  ·  ·  ·  ·  ♢•♢setHyphenationFactor♢|:|♢currentHyphenation♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setHyphenationFactor♢|:|♢
·  ·  ·  ·  ·  <CConditionalOperator>
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢currentHyphenation♢•♢>♢•♢0.0♢|)|♢
·  ·  ·  ·  ·  ·  ♢•♢|?|♢•♢0.0♢•♢|:|♢•♢0.9♢
·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ♢|;|♢→♢|/*•Toggle•between•0.0•and•0.9•*/|♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•Action•method•for•the•"Append•'.txt'•extension"•button¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢appendPlainTextExtensionChanged♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢id♢|)|♢
·  ·  ·  ♢sender♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢NSSavePanel♢•♢|*|♢panel♢•♢=♢•♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢|(|♢NSSavePanel♢•♢|*|♢|)|♢
·  ·  ·  ·  ♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|sender|♢•♢window♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|panel|♢•♢setAllowsOtherFileTypes♢|:|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|sender|♢•♢state♢|]|♢
·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|panel|♢•♢setAllowedFileTypes♢|:|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|sender|♢•♢state♢|]|♢
·  ·  ·  ·  ·  ♢•♢|?|♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|NSArray|♢•♢arrayWithObject♢|:|♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ♢kUTTypePlainText♢|]|♢
·  ·  ·  ·  ·  ♢•♢|:|♢•♢|nil|♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢encodingPopupChanged♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSPopUpButton♢•♢|*|♢|)|♢
·  ·  ·  ♢popup♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setEncodingForSaving♢|:|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|popup|♢•♢selectedItem♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢representedObject♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢unsignedIntegerValue♢|]|♢
·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•Menu•validation:•Arbitrary•numbers•to•determine•the•state•of•the•menu•items•whose•titles•change.•Speeds•up•the•validation...•Not•zero.•*/|♢•••♢¶♢
·  ·  <CPreprocessorDefine>
·  ·  ·  ♢|#define|♢•♢TagForFirst♢•♢42♢
·  ·  ♢¶♢
·  ·  <CPreprocessorDefine>
·  ·  ·  ♢|#define|♢•♢TagForSecond♢•♢43♢
·  ·  ♢¶♢¶♢
·  ·  <CFunctionDefinition>
·  ·  ·  ♢|void|♢•♢|validateToggleItem|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSMenuItem♢•♢|*|♢aCell,♢•♢BOOL♢•♢useFirst,♢•♢NSString♢•♢|*|♢first,♢•♢NSString♢•♢|*|♢second♢|)|♢
·  ·  ·  ♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢useFirst♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|aCell|♢•♢tag♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢|!|♢=♢•♢TagForFirst♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|aCell|♢•♢setTitleWithMnemonic♢|:|♢first♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|aCell|♢•♢setTag♢|:|♢TagForFirst♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢•♢
·  ·  ·  ·  <CConditionElse>
·  ·  ·  ·  ·  ♢|else|♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|aCell|♢•♢tag♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢|!|♢=♢•♢TagForSecond♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|aCell|♢•♢setTitleWithMnemonic♢|:|♢second♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|aCell|♢•♢setTag♢|:|♢TagForSecond♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•Menu•validation¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢validateMenuItem♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSMenuItem♢•♢|*|♢|)|♢
·  ·  ·  ♢aCell♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢SEL♢•♢action♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|aCell|♢•♢action♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢action♢•♢==♢•♢
·  ·  ·  ·  ·  ·  <ObjCSelector>
·  ·  ·  ·  ·  ·  ·  ♢|@selector|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢toggleReadOnly♢|:|♢|)|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ♢|validateToggleItem|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢aCell,♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢isReadOnly♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"Allow•Editing"|♢,♢•♢|@"Menu•item•to•make•the•current•document•editable•(not•read-only)"|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"Prevent•Editing"|♢,♢•♢|@"Menu•item•to•make•the•current•document•read-only"|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢•♢
·  ·  ·  ·  <CConditionElseIf>
·  ·  ·  ·  ·  ♢|else•if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢action♢•♢==♢•♢
·  ·  ·  ·  ·  ·  <ObjCSelector>
·  ·  ·  ·  ·  ·  ·  ♢|@selector|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢togglePageBreaks♢|:|♢|)|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ♢|validateToggleItem|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢aCell,♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢hasMultiplePages♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"&Wrap•to•Window"|♢,♢•♢|@"Menu•item•to•cause•text•to•be•laid•out•to•size•of•the•window"|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"&Wrap•to•Page"|♢,♢•♢|@"Menu•item•to•cause•text•to•be•laid•out•to•the•size•of•the•currently•selected•page•type"|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢•♢
·  ·  ·  ·  <CConditionElseIf>
·  ·  ·  ·  ·  ♢|else•if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢action♢•♢==♢•♢
·  ·  ·  ·  ·  ·  <ObjCSelector>
·  ·  ·  ·  ·  ·  ·  ♢|@selector|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢toggleHyphenation♢|:|♢|)|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ♢|validateToggleItem|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢aCell,♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢hyphenationFactor♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢>♢•♢0.0♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"Do•not•Allow•Hyphenation"|♢,♢•♢|@"Menu•item•to•disallow•hyphenation•in•the•document"|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"Allow•Hyphenation"|♢,♢•♢|@"Menu•item•to•allow•hyphenation•in•the•document"|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢isReadOnly♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ·  ·  ·  ♢|return|♢•♢NO♢|;|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢YES♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|//•For•scripting.•We•already•have•a•-textStorage•method•implemented•above.|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢setTextStorage♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢id♢|)|♢
·  ·  ·  ♢ts♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢|//•Warning,•undo•support•can•eat•a•lot•of•memory•if•a•long•text•is•changed•frequently|♢¶♢|••••|♢NSAttributedString♢•♢|*|♢textStorageCopy♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢textStorage♢|]|♢
·  ·  ·  ·  ·  ♢•♢copy♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢undoManager♢|]|♢
·  ·  ·  ·  ·  ♢•♢registerUndoWithTarget♢|:|♢|self|♢•♢selector♢|:|♢
·  ·  ·  ·  ·  <ObjCSelector>
·  ·  ·  ·  ·  ·  ♢|@selector|♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢setTextStorage♢|:|♢|)|♢
·  ·  ·  ·  ·  ♢•♢object♢|:|♢textStorageCopy♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|textStorageCopy|♢•♢release♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢¶♢|••••|♢|//•ts•can•actually•be•a•string•or•an•attributed•string.|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|ts|♢•♢isKindOfClass♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSAttributedString|♢•♢class♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢textStorage♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢replaceCharactersInRange♢|:|♢
·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|NSMakeRange|♢
·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢0,♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢textStorage♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢length♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢withAttributedString♢|:|♢ts♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢•♢
·  ·  ·  ·  <CConditionElse>
·  ·  ·  ·  ·  ♢|else|♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢textStorage♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢replaceCharactersInRange♢|:|♢
·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|NSMakeRange|♢
·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢0,♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢textStorage♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢length♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢withString♢|:|♢ts♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢IBAction♢|)|♢
·  ·  ·  ♢revertDocumentToSaved♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢id♢|)|♢
·  ·  ·  ♢sender♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢|//•This•is•necessary,•because•document•reverting•doesn't•happen•within•NSDocument•if•the•fileURL•is•nil.|♢¶♢|••••|♢|//•However,•this•is•only•a•temporary•workaround•because•it•would•be•better•if•fileURL•was•never•set•to•nil.|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢fileURL♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢==♢•♢|nil|♢•♢|&|♢|&|♢•♢defaultDestination♢•♢|!|♢=♢•♢|nil|♢•♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setFileURL♢|:|♢•♢defaultDestination♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|super|♢•♢revertDocumentToSaved♢|:|♢sender♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢revertToContentsOfURL♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSURL♢•♢|*|♢|)|♢
·  ·  ·  ♢url♢•♢ofType♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ♢type♢•♢error♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSError♢•♢|*|♢|*|♢|)|♢
·  ·  ·  ♢outError♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢|//•See•the•comment•in•the•above•override•of•-revertDocumentToSaved:.|♢¶♢|••••|♢BOOL♢•♢success♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|super|♢•♢revertToContentsOfURL♢|:|♢url♢•♢ofType♢|:|♢type♢•♢error♢|:|♢outError♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢success♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|defaultDestination|♢•♢release♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••|♢defaultDestination♢•♢=♢•♢|nil|♢|;|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setHasMultiplePages♢|:|♢hasMultiplePages♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢windowControllers♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢makeObjectsPerformSelector♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCSelector>
·  ·  ·  ·  ·  ·  ·  ·  ♢|@selector|♢
·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢setupTextViewForDocument♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢undoManager♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢removeAllActions♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢•♢
·  ·  ·  ·  <CConditionElse>
·  ·  ·  ·  ·  ♢|else|♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢|//•The•document•failed•to•revert•correctly,•or•the•user•decided•to•cancel•the•revert.|♢¶♢|••••••••|♢|//•This•just•restores•the•file•URL•to•how•it•was•before•the•sheet•was•displayed.|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setFileURL♢|:|♢|nil|♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢success♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•Target/action•method•for•saving•as•(actually•"saving•to")•PDF.•Note•that•this•approach•of•omitting•the•path•will•not•work•on•Leopard;•see•TextEdit's•README.rtf¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢IBAction♢|)|♢
·  ·  ·  ♢saveDocumentAsPDFTo♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢id♢|)|♢
·  ·  ·  ♢sender♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢printDocumentWithSettings♢|:|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|NSDictionary|♢•♢dictionaryWithObjectsAndKeys♢|:|♢NSPrintSaveJob,♢•♢NSPrintJobDisposition,♢•♢|nil|♢|]|♢
·  ·  ·  ·  ·  ♢•♢showPrintPanel♢|:|♢NO♢•♢delegate♢|:|♢|nil|♢•♢didPrintSelector♢|:|♢|NULL|♢•♢contextInfo♢|:|♢|NULL|♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢|@end|♢
·  ♢¶♢¶♢¶♢|/*•Returns•the•default•padding•on•the•left/right•edges•of•text•views¶*/|♢¶♢
·  <CFunctionDefinition>
·  ·  ♢CGFloat♢•♢|defaultTextPadding|♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ♢•♢
·  ·  <Braces>
·  ·  ·  ♢|{|♢¶♢|••••|♢|static|♢•♢CGFloat♢•♢padding♢•♢=♢•♢-1♢|;|♢¶♢|••••|♢
·  ·  ·  <CConditionIf>
·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢|(|♢padding♢•♢<♢•♢0.0♢|)|♢
·  ·  ·  ·  ♢•♢
·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢NSTextContainer♢•♢|*|♢container♢•♢=♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSTextContainer|♢•♢alloc♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢init♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••|♢padding♢•♢=♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|container|♢•♢lineFragmentPadding♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|container|♢•♢release♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ♢|return|♢•♢padding♢|;|♢
·  ·  ·  ♢¶♢|}|♢
·  ♢¶♢¶♢
·  <ObjCImplementation>
·  ·  ♢|@implementation•Document•(TextEditNSDocumentOverrides)|♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|+|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢canConcurrentlyReadDocumentsOfType♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ♢typeName♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢NSWorkspace♢•♢|*|♢workspace♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|NSWorkspace|♢•♢sharedWorkspace♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢|!|♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|workspace|♢•♢type♢|:|♢typeName♢•♢conformsToType♢|:|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢kUTTypeHTML♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢||♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|workspace|♢•♢type♢|:|♢typeName♢•♢conformsToType♢|:|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢kUTTypeWebArchive♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢id♢|)|♢
·  ·  ·  ♢initForURL♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSURL♢•♢|*|♢|)|♢
·  ·  ·  ♢absoluteDocumentURL♢•♢withContentsOfURL♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSURL♢•♢|*|♢|)|♢
·  ·  ·  ♢absoluteDocumentContentsURL♢•♢ofType♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ♢typeName♢•♢error♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSError♢•♢|*|♢|*|♢|)|♢
·  ·  ·  ♢outError♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢|//•This•is•the•method•that•NSDocumentController•invokes•during•reopening•of•an•autosaved•document•after•a•crash.•The•passed-in•type•name•might•be•NSRTFDPboardType,•but•absoluteDocumentURL•might•point•to•an•RTF•document,•and•if•we•did•nothing•this•document's•fileURL•and•fileType•might•not•agree,•which•would•cause•trouble•the•next•time•the•user•saved•this•document.•absoluteDocumentURL•might•also•be•nil,•if•the•document•being•reopened•has•never•been•saved•before.•It's•an•oddity•of•NSDocument•that•if•you•override•-autosavingFileType•you•probably•have•to•override•this•method•too.|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢absoluteDocumentURL♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢NSString♢•♢|*|♢realTypeName♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSDocumentController|♢•♢sharedDocumentController♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢typeForContentsOfURL♢|:|♢absoluteDocumentURL♢•♢error♢|:|♢outError♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢realTypeName♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢|self|♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|super|♢•♢initForURL♢|:|♢absoluteDocumentURL♢•♢withContentsOfURL♢|:|♢absoluteDocumentContentsURL♢•♢ofType♢|:|♢typeName♢•♢error♢|:|♢outError♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setFileType♢|:|♢realTypeName♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  <CConditionElse>
·  ·  ·  ·  ·  ·  ·  ♢|else|♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢release♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢|self|♢•♢=♢•♢|nil|♢|;|♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢•♢
·  ·  ·  ·  <CConditionElse>
·  ·  ·  ·  ·  ♢|else|♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢|self|♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|super|♢•♢initForURL♢|:|♢absoluteDocumentURL♢•♢withContentsOfURL♢|:|♢absoluteDocumentContentsURL♢•♢ofType♢|:|♢typeName♢•♢error♢|:|♢outError♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢|self|♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢makeWindowControllers♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢NSArray♢•♢|*|♢myControllers♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢windowControllers♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢¶♢|••••|♢|/*•If•this•document•displaced•a•transient•document,•it•will•already•have•been•assigned•a•window•controller.•If•that•is•not•the•case,•create•one.•*/|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|myControllers|♢•♢count♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢==♢•♢0♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢addWindowController♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|DocumentWindowController|♢•♢allocWithZone♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢zone♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢init♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢autorelease♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSArray♢•♢|*|♢|)|♢
·  ·  ·  ♢writableTypesForSaveOperation♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSSaveOperationType♢|)|♢
·  ·  ·  ♢saveOperation♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢NSMutableArray♢•♢|*|♢outArray♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢class♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢writableTypes♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢mutableCopy♢|]|♢
·  ·  ·  ·  ·  ♢•♢autorelease♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢saveOperation♢•♢==♢•♢NSSaveAsOperation♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢|/*•Rich-text•documents•cannot•be•saved•as•plain•text.•*/|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢isRichText♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|outArray|♢•♢removeObject♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢kUTTypePlainText♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|→|♢¶♢|→|♢|/*•Documents•that•contain•attacments•can•only•be•saved•in•formats•that•support•embedded•graphics.•*/|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|textStorage|♢•♢containsAttachments♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|outArray|♢•♢setArray♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSArray|♢•♢arrayWithObjects♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢kUTTypeRTFD,♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢kUTTypeWebArchive,♢•♢|nil|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢outArray♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•Whether•to•keep•the•backup•file¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢keepBackupFile♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢|!|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSUserDefaults|♢•♢standardUserDefaults♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢boolForKey♢|:|♢DeleteBackup♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•When•a•document•is•changed,•it•ceases•to•be•transient.•¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢updateChangeCount♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSDocumentChangeType♢|)|♢
·  ·  ·  ♢change♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setTransient♢|:|♢NO♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|super|♢•♢updateChangeCount♢|:|♢change♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•When•we•save,•we•send•a•notification•so•that•views•that•are•currently•coalescing•undo•actions•can•break•that.•This•is•done•for•two•reasons,•one•technical•and•the•other•HI•oriented.•¶¶Firstly,•since•the•dirty•state•tracking•is•based•on•undo,•for•a•coalesced•set•of•changes•that•span•over•a•save•operation,•the•changes•that•occur•between•the•save•and•the•next•time•the•undo•coalescing•stops•will•not•mark•the•document•as•dirty.•Secondly,•allowing•the•user•to•undo•back•to•the•precise•point•of•a•save•is•good•UI.•¶¶In•addition•we•overwrite•this•method•as•a•way•to•tell•that•the•document•has•been•saved•successfully.•If•so,•we•set•the•save•time•parameters•in•the•document.¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢saveToURL♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSURL♢•♢|*|♢|)|♢
·  ·  ·  ♢absoluteURL♢•♢ofType♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ♢typeName♢•♢forSaveOperation♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSSaveOperationType♢|)|♢
·  ·  ·  ♢saveOperation♢•♢error♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSError♢•♢|*|♢|*|♢|)|♢
·  ·  ·  ♢outError♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢|//•Note•that•we•do•the•breakUndoCoalescing•call•even•during•autosave,•which•means•the•user's•undo•of•long•typing•will•take•them•back•to•the•last•spot•an•autosave•occured.•This•might•seem•confusing,•and•a•more•elaborate•solution•may•be•possible•(cause•an•autosave•without•having•to•breakUndoCoalescing),•but•since•this•change•is•coming•late•in•Leopard,•we•decided•to•go•with•the•lower•risk•fix.|♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢windowControllers♢|]|♢
·  ·  ·  ·  ·  ♢•♢makeObjectsPerformSelector♢|:|♢
·  ·  ·  ·  ·  <ObjCSelector>
·  ·  ·  ·  ·  ·  ♢|@selector|♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢breakUndoCoalescing♢|)|♢
·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢¶♢|••••|♢BOOL♢•♢success♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|super|♢•♢saveToURL♢|:|♢absoluteURL♢•♢ofType♢|:|♢typeName♢•♢forSaveOperation♢|:|♢saveOperation♢•♢error♢|:|♢outError♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢success♢•♢|&|♢|&|♢•♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢saveOperation♢•♢==♢•♢NSSaveOperation♢•♢||♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢saveOperation♢•♢==♢•♢NSSaveAsOperation♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢••••♢|//•If•successful,•set•document•parameters•changed•during•the•save•operation|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢encodingForSaving♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢|!|♢=♢•♢NoStringEncoding♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setEncoding♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢encodingForSaving♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setEncodingForSaving♢|:|♢NoStringEncoding♢|]|♢
·  ·  ·  ·  ♢|;|♢•••♢|//•This•is•set•during•prepareSavePanel:,•but•should•be•cleared•for•future•save•operation•without•save•panel|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢success♢|;|♢
·  ·  ·  ·  ♢••••♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•Since•a•document•into•which•the•user•has•dragged•graphics•should•autosave•as•RTFD,•we•override•this•method•to•return•RTFD,•unless•the•document•was•already•RTFD,•WebArchive,•or•plain•(the•last•one•done•for•optimization,•to•avoid•calling•containsAttachments).¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ♢autosavingFileType♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢NSWorkspace♢•♢|*|♢workspace♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|NSWorkspace|♢•♢sharedWorkspace♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢NSString♢•♢|*|♢type♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|super|♢•♢autosavingFileType♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|workspace|♢•♢type♢|:|♢type♢•♢conformsToType♢|:|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢kUTTypeRTFD♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢||♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|workspace|♢•♢type♢|:|♢type♢•♢conformsToType♢|:|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢kUTTypeWebArchive♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢||♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|workspace|♢•♢type♢|:|♢type♢•♢conformsToType♢|:|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢kUTTypePlainText♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ·  ♢|return|♢•♢type♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|textStorage|♢•♢containsAttachments♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ·  ♢|return|♢•♢
·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ♢kUTTypeRTFD♢|;|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢type♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢¶♢|/*•When•the•file•URL•is•set•to•nil,•we•store•away•the•old•URL.•This•happens•when•a•document•is•converted•to•and•from•rich•text.•If•the•document•exists•on•disk,•we•default•to•use•the•same•base•file•when•subsequently•saving•the•document.•¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢setFileURL♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSURL♢•♢|*|♢|)|♢
·  ·  ·  ♢url♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢NSURL♢•♢|*|♢previousURL♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢fileURL♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢|!|♢url♢•♢|&|♢|&|♢•♢previousURL♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|defaultDestination|♢•♢release♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢defaultDestination♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|previousURL|♢•♢copy♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|super|♢•♢setFileURL♢|:|♢url♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢didPresentErrorWithRecovery♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢didRecover♢•♢contextInfo♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢•♢|*|♢|)|♢
·  ·  ·  ♢contextInfo♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢didRecover♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢performSelector♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCSelector>
·  ·  ·  ·  ·  ·  ·  ·  ♢|@selector|♢
·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢saveDocument♢|:|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢withObject♢|:|♢|self|♢•♢afterDelay♢|:|♢0.0♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢attemptRecoveryFromError♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSError♢•♢|*|♢|)|♢
·  ·  ·  ♢error♢•♢optionIndex♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSUInteger♢|)|♢
·  ·  ·  ♢recoveryOptionIndex♢•♢delegate♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢id♢|)|♢
·  ·  ·  ♢delegate♢•♢didRecoverSelector♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢SEL♢|)|♢
·  ·  ·  ♢didRecoverSelector♢•♢contextInfo♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢•♢|*|♢|)|♢
·  ·  ·  ♢contextInfo♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢BOOL♢•♢saveAgain♢•♢=♢•♢NO♢|;|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|error|♢•♢domain♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢isEqualToString♢|:|♢TextEditErrorDomain♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CFlowSwitch>
·  ·  ·  ·  ·  ·  ·  ♢|switch|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|error|♢•♢code♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CFlowCase>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|case|♢•♢TextEditSaveErrorConvertedDocument♢|:|♢¶♢|→→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢recoveryOptionIndex♢•♢==♢•♢0♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢•♢|//•Save•with•new•name|♢¶♢|→→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setFileType♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|textStorage|♢•♢containsAttachments♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢|?|♢•♢kUTTypeRTFD♢•♢|:|♢•♢kUTTypeRTF♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setFileURL♢|:|♢|nil|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setConverted♢|:|♢NO♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→→••••|♢saveAgain♢•♢=♢•♢YES♢|;|♢¶♢|→→|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢¶♢|→→|♢|break|♢|;|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CFlowCase>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|case|♢•♢TextEditSaveErrorLossyDocument♢|:|♢¶♢|→→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢recoveryOptionIndex♢•♢==♢•♢0♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢•♢|//•Save•with•new•name|♢¶♢|→→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setFileURL♢|:|♢|nil|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setLossy♢|:|♢NO♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→→••••|♢saveAgain♢•♢=♢•♢YES♢|;|♢¶♢|→→|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <CConditionElseIf>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|else•if|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢recoveryOptionIndex♢•♢==♢•♢1♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢•♢|//•Overwrite|♢¶♢|→→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setLossy♢|:|♢NO♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→→••••|♢saveAgain♢•♢=♢•♢YES♢|;|♢¶♢|→→|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢¶♢|→→|♢|break|♢|;|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CFlowCase>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|case|♢•♢TextEditSaveErrorRTFDRequired♢|:|♢¶♢|→→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢recoveryOptionIndex♢•♢==♢•♢0♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢•♢|//•Save•with•new•name;•enable•the•user•to•choose•a•new•name•to•save•with|♢¶♢|→→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setFileType♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢kUTTypeRTFD♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setFileURL♢|:|♢|nil|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→→••••|♢saveAgain♢•♢=♢•♢YES♢|;|♢¶♢|→→|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <CConditionElseIf>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|else•if|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢recoveryOptionIndex♢•♢==♢•♢1♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢•♢|//•Save•as•RTFD•with•the•same•name|♢¶♢|→→••••|♢NSString♢•♢|*|♢oldFilename♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢fileURL♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢path♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→→••••|♢NSError♢•♢|*|♢newError♢|;|♢¶♢|→→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|!|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢saveToURL♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSURL|♢•♢fileURLWithPath♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|oldFilename|♢•♢stringByDeletingPathExtension♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢stringByAppendingPathExtension♢|:|♢|@"rtfd"|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢ofType♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢kUTTypeRTFD♢•♢forSaveOperation♢|:|♢NSSaveAsOperation♢•♢error♢|:|♢|&|♢newError♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→→→|♢|//•If•attempt•to•save•as•RTFD•fails,•let•the•user•know|♢¶♢|→→→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢presentError♢|:|♢newError♢•♢modalForWindow♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢windowForSheet♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢delegate♢|:|♢|nil|♢•♢didPresentSelector♢|:|♢|NULL|♢•♢contextInfo♢|:|♢contextInfo♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→→••••|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CConditionElse>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|else|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→→→|♢|//•The•RTFD•is•saved;•we•ignore•error•from•trying•to•delete•the•RTF•file|♢¶♢|→→→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSFileManager|♢•♢defaultManager♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢removeItemAtPath♢|:|♢oldFilename♢•♢error♢|:|♢|NULL|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→→••••|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|→→••••|♢saveAgain♢•♢=♢•♢NO♢|;|♢¶♢|→→|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢¶♢|→→|♢|break|♢|;|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CFlowCase>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|case|♢•♢TextEditSaveErrorEncodingInapplicable♢|:|♢¶♢|→→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setEncodingForSaving♢|:|♢NoStringEncoding♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setFileURL♢|:|♢|nil|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→→|♢saveAgain♢•♢=♢•♢YES♢|;|♢¶♢|→→|♢|break|♢|;|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢¶♢|••••|♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|delegate|♢•♢didPresentErrorWithRecovery♢|:|♢saveAgain♢•♢contextInfo♢|:|♢contextInfo♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|}|♢
·  ·  ♢¶♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢|)|♢
·  ·  ·  ♢saveDocumentWithDelegate♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢id♢|)|♢
·  ·  ·  ♢delegate♢•♢didSaveSelector♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢SEL♢|)|♢
·  ·  ·  ♢didSaveSelector♢•♢contextInfo♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢|void|♢•♢|*|♢|)|♢
·  ·  ·  ♢contextInfo♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢NSString♢•♢|*|♢currType♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢fileType♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢NSError♢•♢|*|♢error♢•♢=♢•♢|nil|♢|;|♢¶♢|••••|♢BOOL♢•♢containsAttachments♢•♢=♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢|textStorage|♢•♢containsAttachments♢|]|♢
·  ·  ·  ·  ♢|;|♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢fileURL♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢isConverted♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢NSString♢•♢|*|♢newFormatName♢•♢=♢•♢containsAttachments♢•♢|?|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"rich•text•with•graphics•(RTFD)"|♢,♢•♢|@"Rich•text•with•graphics•file•format•name,•displayed•in•alert"|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢¶♢|→→→→→→→••|♢|:|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"rich•text"|♢,♢•♢|@"Rich•text•file•format•name,•displayed•in•alert"|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢error♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSError|♢•♢errorWithDomain♢|:|♢TextEditErrorDomain♢•♢code♢|:|♢TextEditSaveErrorConvertedDocument♢•♢userInfo♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSDictionary|♢•♢dictionaryWithObjectsAndKeys♢|:|♢¶♢|→→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"Please•supply•a•new•name."|♢,♢•♢|@"Title•of•alert•panel•which•brings•up•a•warning•while•saving,•asking•for•new•name"|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢NSLocalizedDescriptionKey,♢¶♢|→→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSString|♢•♢stringWithFormat♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"This•document•was•converted•from•a•format•that•TextEdit•cannot•save.•It•will•be•saved•in•%@•format•with•a•new•name."|♢,♢•♢|@"Contents•of•alert•panel•informing•user•that•they•need•to•supply•a•new•file•name•because•the•file•needs•to•be•saved•using•a•different•format•than•originally•read•in"|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢newFormatName♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢NSLocalizedRecoverySuggestionErrorKey,♢•♢¶♢|→→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSArray|♢•♢arrayWithObjects♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"Save•with•new•name"|♢,♢•♢|@"Button•choice•allowing•user•to•choose•a•new•name"|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"Cancel"|♢,♢•♢|@"Button•choice•allowing•user•to•cancel."|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢|nil|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢NSLocalizedRecoveryOptionsErrorKey,♢¶♢|→→|♢self,♢•♢NSRecoveryAttempterErrorKey,♢¶♢|→→|♢|nil|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  <CConditionElseIf>
·  ·  ·  ·  ·  ·  ·  ♢|else•if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢isLossy♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢error♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSError|♢•♢errorWithDomain♢|:|♢TextEditErrorDomain♢•♢code♢|:|♢TextEditSaveErrorLossyDocument♢•♢userInfo♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSDictionary|♢•♢dictionaryWithObjectsAndKeys♢|:|♢¶♢|→→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"Are•you•sure•you•want•to•overwrite•the•document?"|♢,♢•♢|@"Title•of•alert•panel•which•brings•up•a•warning•about•saving•over•the•same•document"|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢NSLocalizedDescriptionKey,♢¶♢|→→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"Overwriting•this•document•might•cause•you•to•lose•some•of•the•original•formatting.••Would•you•like•to•save•the•document•using•a•new•name?"|♢,♢•♢|@"Contents•of•alert•panel•informing•user•that•they•need•to•supply•a•new•file•name•because•the•save•might•be•lossy"|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢NSLocalizedRecoverySuggestionErrorKey,♢¶♢|→→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSArray|♢•♢arrayWithObjects♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"Save•with•new•name"|♢,♢•♢|@"Button•choice•allowing•user•to•choose•a•new•name"|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"Overwrite"|♢,♢•♢|@"Button•choice•allowing•user•to•overwrite•the•document."|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"Cancel"|♢,♢•♢|@"Button•choice•allowing•user•to•cancel."|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢|nil|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢NSLocalizedRecoveryOptionsErrorKey,♢¶♢|→→|♢self,♢•♢NSRecoveryAttempterErrorKey,♢¶♢|→→|♢|nil|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  <CConditionElseIf>
·  ·  ·  ·  ·  ·  ·  ♢|else•if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢containsAttachments♢•♢|&|♢|&|♢•♢|!|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢writableTypesForSaveOperation♢|:|♢NSSaveAsOperation♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢containsObject♢|:|♢currType♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢error♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSError|♢•♢errorWithDomain♢|:|♢TextEditErrorDomain♢•♢code♢|:|♢TextEditSaveErrorRTFDRequired♢•♢userInfo♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSDictionary|♢•♢dictionaryWithObjectsAndKeys♢|:|♢¶♢|→→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"Are•you•sure•you•want•to•save•using•RTFD•format?"|♢,♢•♢|@"Title•of•alert•panel•which•brings•up•a•warning•while•saving"|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢NSLocalizedDescriptionKey,♢¶♢|→→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"This•document•contains•graphics•and•will•be•saved•using•RTFD•(RTF•with•graphics)•format.•RTFD•documents•are•not•compatible•with•some•applications.•Save•anyway?"|♢,♢•♢|@"Contents•of•alert•panel•informing•user•that•the•document•is•being•converted•from•RTF•to•RTFD,•and•allowing•them•to•cancel,•save•anyway,•or•save•with•new•name"|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢NSLocalizedRecoverySuggestionErrorKey,♢¶♢|→→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSArray|♢•♢arrayWithObjects♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"Save•with•new•name"|♢,♢•♢|@"Button•choice•allowing•user•to•choose•a•new•name"|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"Save"|♢,♢•♢|@"Button•choice•which•allows•the•user•to•save•the•document."|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"Cancel"|♢,♢•♢|@"Button•choice•allowing•user•to•cancel."|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢|nil|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢NSLocalizedRecoveryOptionsErrorKey,♢¶♢|→→|♢self,♢•♢NSRecoveryAttempterErrorKey,♢¶♢|→→|♢|nil|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  <CConditionElseIf>
·  ·  ·  ·  ·  ·  ·  ♢|else•if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|!|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢isRichText♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢NSUInteger♢•♢enc♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢encodingForSaving♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢enc♢•♢==♢•♢NoStringEncoding♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢enc♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢encoding♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|!|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|textStorage|♢•♢string♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢canBeConvertedToEncoding♢|:|♢enc♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→→|♢error♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSError|♢•♢errorWithDomain♢|:|♢TextEditErrorDomain♢•♢code♢|:|♢TextEditSaveErrorEncodingInapplicable♢•♢userInfo♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSDictionary|♢•♢dictionaryWithObjectsAndKeys♢|:|♢¶♢|→→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSString|♢•♢stringWithFormat♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"This•document•can•no•longer•be•saved•using•its•original•%@•encoding."|♢,♢•♢|@"Title•of•alert•panel•informing•user•that•the•file's•string•encoding•needs•to•be•changed."|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSString|♢•♢localizedNameOfStringEncoding♢|:|♢enc♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢NSLocalizedDescriptionKey,♢¶♢|→→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"Please•choose•another•encoding•(such•as•UTF-8)."|♢,♢•♢|@"Subtitle•of•alert•panel•informing•user•that•the•file's•string•encoding•needs•to•be•changed"|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢,♢•♢NSLocalizedRecoverySuggestionErrorKey,♢¶♢|→→••••|♢self,♢•♢NSRecoveryAttempterErrorKey,♢¶♢|→→••••|♢|nil|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢error♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢presentError♢|:|♢error♢•♢modalForWindow♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢windowForSheet♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢delegate♢|:|♢|self|♢•♢didPresentSelector♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCSelector>
·  ·  ·  ·  ·  ·  ·  ·  ♢|@selector|♢
·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢didPresentErrorWithRecovery♢|:|♢contextInfo♢|:|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢contextInfo♢|:|♢|NULL|♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢•♢
·  ·  ·  ·  <CConditionElse>
·  ·  ·  ·  ·  ♢|else|♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|super|♢•♢saveDocumentWithDelegate♢|:|♢delegate♢•♢didSaveSelector♢|:|♢didSaveSelector♢•♢contextInfo♢|:|♢contextInfo♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•For•plain-text•documents,•we•add•our•own•accessory•view•for•selecting•encodings.•The•plain•text•case•does•not•require•a•format•popup.•¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢shouldRunSavePanelWithAccessoryView♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢isRichText♢|]|♢
·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•If•the•document•is•a•converted•version•of•a•document•that•existed•on•disk,•set•the•default•directory•to•the•directory•in•which•the•source•file•(converted•file)•resided•at•the•time•the•document•was•converted.•If•the•document•is•plain•text,•we•additionally•add•an•encoding•popup.•¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢BOOL♢|)|♢
·  ·  ·  ♢prepareSavePanel♢|:|♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSSavePanel♢•♢|*|♢|)|♢
·  ·  ·  ♢savePanel♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢NSPopUpButton♢•♢|*|♢encodingPopup♢|;|♢¶♢|••••|♢NSButton♢•♢|*|♢extCheckbox♢|;|♢¶♢|••••|♢NSUInteger♢•♢cnt♢|;|♢¶♢|••••|♢NSString♢•♢|*|♢string♢|;|♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢defaultDestination♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢NSString♢•♢|*|♢dirPath♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|defaultDestination|♢•♢path♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢stringByDeletingPathExtension♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢BOOL♢•♢isDir♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSFileManager|♢•♢defaultManager♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢fileExistsAtPath♢|:|♢dirPath♢•♢isDirectory♢|:|♢|&|♢isDir♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢|&|♢|&|♢•♢isDir♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|savePanel|♢•♢setDirectory♢|:|♢dirPath♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢|!|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢isRichText♢|]|♢
·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢BOOL♢•♢addExt♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSUserDefaults|♢•♢standardUserDefaults♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢boolForKey♢|:|♢AddExtensionToNewPlainTextFiles♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢|//•If•no•encoding,•figure•out•which•encoding•should•be•default•in•encoding•popup,•set•as•document•encoding.|♢¶♢|→|♢NSStringEncoding♢•♢enc♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢encoding♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢setEncodingForSaving♢|:|♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢enc♢•♢==♢•♢NoStringEncoding♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢|?|♢•♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢suggestedDocumentEncoding♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢|:|♢•♢enc♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|savePanel|♢•♢setAccessoryView♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSDocumentController|♢•♢sharedDocumentController♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢class♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢encodingAccessory♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢encodingForSaving♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢includeDefaultEntry♢|:|♢NO♢•♢encodingPopUp♢|:|♢|&|♢encodingPopup♢•♢checkBox♢|:|♢|&|♢extCheckbox♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢¶♢|→|♢|//•Set•up•the•checkbox|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|extCheckbox|♢•♢setTitle♢|:|♢
·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"If•no•extension•is•provided,•use•\\U201c.txt\\U201d."|♢,♢•♢|@"Checkbox•indicating•that•if•the•user•does•not•specify•an•extension•when•saving•a•plain•text•file,•.txt•will•be•used"|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|extCheckbox|♢•♢setToolTip♢|:|♢
·  ·  ·  ·  ·  ·  ·  <CFunctionCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|NSLocalizedString|♢
·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|@"Automatically•append•\\U201c.txt\\U201d•to•the•file•name•if•no•known•file•name•extension•is•provided."|♢,♢•♢|@"Tooltip•for•checkbox•indicating•that•if•the•user•does•not•specify•an•extension•when•saving•a•plain•text•file,•.txt•will•be•used"|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|extCheckbox|♢•♢setState♢|:|♢addExt♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|extCheckbox|♢•♢setAction♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCSelector>
·  ·  ·  ·  ·  ·  ·  ·  ♢|@selector|♢
·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢appendPlainTextExtensionChanged♢|:|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|extCheckbox|♢•♢setTarget♢|:|♢|self|♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢addExt♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|savePanel|♢•♢setAllowedFileTypes♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSArray|♢•♢arrayWithObject♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢kUTTypePlainText♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|savePanel|♢•♢setAllowsOtherFileTypes♢|:|♢YES♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  <CConditionElse>
·  ·  ·  ·  ·  ·  ·  ♢|else|♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••••••|♢|//•NSDocument•defaults•to•setting•the•allowedFileType•to•kUTTypePlainText,•which•gives•the•fileName•a•".txt"•extension.•We•want•don't•want•to•append•the•extension•for•Untitled•documents.|♢¶♢|••••••••••••|♢|//•First•we•clear•out•the•allowedFileType•that•NSDocument•set.•We•want•to•allow•anything,•so•we•pass•'nil'.•This•will•prevent•NSSavePanel•from•appending•an•extension.|♢¶♢|••••••••••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|savePanel|♢•♢setAllowedFileTypes♢|:|♢|nil|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••••••|♢|//•If•this•document•was•previously•saved,•use•the•URL's•name.|♢¶♢|••••••••••••|♢NSString♢•♢|*|♢fileName♢|;|♢¶♢|••••••••••••|♢BOOL♢•♢gotFileName♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢fileURL♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢getResourceValue♢|:|♢|&|♢fileName♢•♢forKey♢|:|♢NSURLNameKey♢•♢error♢|:|♢|nil|♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••••••|♢|//•If•the•document•has•not•yet•been•seaved,•or•we•couldn't•find•the•fileName,•then•use•the•displayName.|♢•♢¶♢|••••••••••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢|!|♢gotFileName♢•♢||♢•♢fileName♢•♢==♢•♢|nil|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|••••••••••••••••|♢fileName♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢displayName♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••••••|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|••••••••••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|savePanel|♢•♢setNameFieldStringValue♢|:|♢fileName♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••••••|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|→|♢¶♢|→|♢|//•Further•set•up•the•encoding•popup|♢¶♢|→|♢cnt♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|encodingPopup|♢•♢numberOfItems♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢string♢•♢=♢•♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|textStorage|♢•♢string♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢cnt♢•♢|*|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|string|♢•♢length♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢<♢•♢5000000♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢→♢|//•Otherwise•it's•just•too•slow;•would•be•nice•to•make•this•more•dynamic.•With•large•docs•and•many•encodings,•the•items•just•won't•be•validated.|♢¶♢|→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  <CFlowWhile>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|while|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢cnt--♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢→♢|//•No•reason•go•backwards•except•to•use•one•variable•instead•of•two|♢¶♢|••••••••••••••••|♢NSStringEncoding♢•♢encoding♢•♢=♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢NSStringEncoding♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|encodingPopup|♢•♢itemAtIndex♢|:|♢cnt♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢representedObject♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢unsignedIntegerValue♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→→|♢|//•Hardwire•some•encodings•known•to•allow•any•content|♢¶♢|→→|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢encoding♢•♢|!|♢=♢•♢NoStringEncoding♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢|&|♢|&|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢encoding♢•♢|!|♢=♢•♢NSUnicodeStringEncoding♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢|&|♢|&|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢encoding♢•♢|!|♢=♢•♢NSUTF8StringEncoding♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢|&|♢|&|♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢encoding♢•♢|!|♢=♢•♢NSNonLossyASCIIStringEncoding♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢|&|♢|&|♢•♢|!|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|string|♢•♢canBeConvertedToEncoding♢|:|♢encoding♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|)|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→→••••|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|encodingPopup|♢•♢itemAtIndex♢|:|♢cnt♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢setEnabled♢|:|♢NO♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→→|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|→••••|♢|}|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢¶♢|→|♢|}|♢
·  ·  ·  ·  ·  ·  ♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|encodingPopup|♢•♢setAction♢|:|♢
·  ·  ·  ·  ·  ·  ·  <ObjCSelector>
·  ·  ·  ·  ·  ·  ·  ·  ♢|@selector|♢
·  ·  ·  ·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|(|♢encodingPopupChanged♢|:|♢|)|♢
·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|encodingPopup|♢•♢setTarget♢|:|♢|self|♢|]|♢
·  ·  ·  ·  ·  ·  ♢|;|♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|••••|♢¶♢|••••|♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢YES♢|;|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|/*•If•the•document•does•not•exist•on•disk,•but•it•has•been•converted•from•a•document•that•existed•on•disk,•return•the•base•file•name•without•the•path•extension.•Otherwise•return•the•default•("Untitled").•This•is•used•for•the•window•title•and•for•the•default•name•when•saving.•¶*/|♢¶♢
·  ·  <ObjCMethodImplementation>
·  ·  ·  ♢|-|♢•♢
·  ·  ·  <Parenthesis>
·  ·  ·  ·  ♢|(|♢NSString♢•♢|*|♢|)|♢
·  ·  ·  ♢displayName♢•♢
·  ·  ·  <Braces>
·  ·  ·  ·  ♢|{|♢¶♢|••••|♢
·  ·  ·  ·  <CConditionIf>
·  ·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ·  ♢|(|♢|!|♢
·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ♢|[|♢|self|♢•♢fileURL♢|]|♢
·  ·  ·  ·  ·  ·  ♢•♢|&|♢|&|♢•♢defaultDestination♢|)|♢
·  ·  ·  ·  ·  ♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ·  ·  ♢|return|♢•♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|NSFileManager|♢•♢defaultManager♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢•♢displayNameAtPath♢|:|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|defaultDestination|♢•♢path♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ·  ♢|]|♢
·  ·  ·  ·  ·  ·  ·  ·  ♢•♢stringByDeletingPathExtension♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢•♢
·  ·  ·  ·  <CConditionElse>
·  ·  ·  ·  ·  ♢|else|♢•♢
·  ·  ·  ·  ·  <Braces>
·  ·  ·  ·  ·  ·  ♢|{|♢¶♢|→|♢
·  ·  ·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ·  ·  ♢|return|♢•♢
·  ·  ·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ·  ·  ♢|[|♢|super|♢•♢displayName♢|]|♢
·  ·  ·  ·  ·  ·  ·  ♢|;|♢
·  ·  ·  ·  ·  ·  ♢¶♢|••••|♢|}|♢
·  ·  ·  ·  ♢¶♢|}|♢
·  ·  ♢¶♢¶♢|@end|♢
·  ♢¶♢¶♢¶♢|/*•Truncate•string•to•no•longer•than•truncationLength;•should•be•>•10¶*/|♢¶♢
·  <CFunctionDefinition>
·  ·  ♢NSString♢•♢|*|♢|truncatedString|♢
·  ·  <Parenthesis>
·  ·  ·  ♢|(|♢NSString♢•♢|*|♢str,♢•♢NSUInteger♢•♢truncationLength♢|)|♢
·  ·  ♢•♢
·  ·  <Braces>
·  ·  ·  ♢|{|♢¶♢|••••|♢NSUInteger♢•♢len♢•♢=♢•♢
·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ♢|[|♢|str|♢•♢length♢|]|♢
·  ·  ·  ♢|;|♢¶♢|••••|♢
·  ·  ·  <CConditionIf>
·  ·  ·  ·  ♢|if|♢•♢
·  ·  ·  ·  <Parenthesis>
·  ·  ·  ·  ·  ♢|(|♢len♢•♢<♢•♢truncationLength♢|)|♢
·  ·  ·  ·  ♢•♢
·  ·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ·  ♢|return|♢•♢str♢|;|♢
·  ·  ·  ♢¶♢|••••|♢
·  ·  ·  <CFlowReturn>
·  ·  ·  ·  ♢|return|♢•♢
·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ♢|[|♢
·  ·  ·  ·  ·  <ObjCMethodCall>
·  ·  ·  ·  ·  ·  ♢|[|♢|str|♢•♢substringToIndex♢|:|♢truncationLength♢•♢-♢•♢10♢|]|♢
·  ·  ·  ·  ·  ♢•♢stringByAppendingString♢|:|♢|@"\u2026"|♢|]|♢
·  ·  ·  ·  ♢|;|♢
·  ·  ·  ♢→♢|//•Unicode•character•2026•is•ellipsis|♢¶♢|}|♢
·  ♢¶♢¶♢

<----->

[1:1142] <Root>
|    [1:8] <CComment> = ♢/*¶••••••••Document.m¶••••••••Copyright•(c)•1995-2009•by•Apple•Computer,•Inc.,•all•rights•reserved.¶••••••••Author:•Ali•Ozer¶¶••••••••Document•object•for•TextEdit.•¶→As•of•TextEdit•1.5,•a•subclass•of•NSDocument.¶*/♢
|    [8:9] <Newline> = ♢¶♢
|    [9:40] <CComment> = ♢/*¶•IMPORTANT:••This•Apple•software•is•supplied•to•you•by•Apple•Computer,•Inc.•("Apple")•in¶•consideration•of•your•agreement•to•the•following•terms,•and•your•use,•installation,•¶•modification•or•redistribution•of•this•Apple•software•constitutes•acceptance•of•these•¶•terms.••If•you•do•not•agree•with•these•terms,•please•do•not•use,•install,•modify•or•¶•redistribute•this•Apple•software.¶•¶•In•consideration•of•your•agreement•to•abide•by•the•following•terms,•and•subject•to•these•¶•terms,•Apple•grants•you•a•personal,•non-exclusive•license,•under•Apple's•copyrights•in•¶•this•original•Apple•software•(the•"Apple•Software"),•to•use,•reproduce,•modify•and•¶•redistribute•the•Apple•Software,•with•or•without•modifications,•in•source•and/or•binary•¶•forms;•provided•that•if•you•redistribute•the•Apple•Software•in•its•entirety•and•without•¶•modifications,•you•must•retain•this•notice•and•the•following•text•and•disclaimers•in•all•¶•such•redistributions•of•the•Apple•Software.••Neither•the•name,•trademarks,•service•marks•¶•or•logos•of•Apple•Computer,•Inc.•may•be•used•to•endorse•or•promote•products•derived•from•¶•the•Apple•Software•without•specific•prior•written•permission•from•Apple.•Except•as•expressly¶•stated•in•this•notice,•no•other•rights•or•licenses,•express•or•implied,•are•granted•by•Apple¶•herein,•including•but•not•limited•to•any•patent•rights•that•may•be•infringed•by•your•¶•derivative•works•or•by•other•works•in•which•the•Apple•Software•may•be•incorporated.¶•¶•The•Apple•Software•is•provided•by•Apple•on•an•"AS•IS"•basis.••APPLE•MAKES•NO•WARRANTIES,•¶•EXPRESS•OR•IMPLIED,•INCLUDING•WITHOUT•LIMITATION•THE•IMPLIED•WARRANTIES•OF•NON-INFRINGEMENT,•¶•MERCHANTABILITY•AND•FITNESS•FOR•A•PARTICULAR•PURPOSE,•REGARDING•THE•APPLE•SOFTWARE•OR•ITS•¶•USE•AND•OPERATION•ALONE•OR•IN•COMBINATION•WITH•YOUR•PRODUCTS.¶•¶•IN•NO•EVENT•SHALL•APPLE•BE•LIABLE•FOR•ANY•SPECIAL,•INDIRECT,•INCIDENTAL•OR•CONSEQUENTIAL•¶•DAMAGES•(INCLUDING,•BUT•NOT•LIMITED•TO,•PROCUREMENT•OF•SUBSTITUTE•GOODS•OR•SERVICES;•LOSS•¶•OF•USE,•DATA,•OR•PROFITS;•OR•BUSINESS•INTERRUPTION)•ARISING•IN•ANY•WAY•OUT•OF•THE•USE,•¶•REPRODUCTION,•MODIFICATION•AND/OR•DISTRIBUTION•OF•THE•APPLE•SOFTWARE,•HOWEVER•CAUSED•AND•¶•WHETHER•UNDER•THEORY•OF•CONTRACT,•TORT•(INCLUDING•NEGLIGENCE),•STRICT•LIABILITY•OR•¶•OTHERWISE,•EVEN•IF•APPLE•HAS•BEEN•ADVISED•OF•THE•POSSIBILITY•OF•SUCH•DAMAGE.¶*/♢
|    [40:41] <Newline> = ♢¶♢
|    [41:42] <Newline> = ♢¶♢
|    [42:42] <ObjCPreprocessorImport>
|    |    [42:42] <Match> = ♢#import♢
|    |    [42:42] <Whitespace> = ♢•♢
|    |    [42:42] <Text> = ♢<Cocoa/Cocoa.h>♢
|    [42:43] <Newline> = ♢¶♢
|    [43:43] <ObjCPreprocessorImport>
|    |    [43:43] <Match> = ♢#import♢
|    |    [43:43] <Whitespace> = ♢•♢
|    |    [43:43] <CStringDoubleQuote> = ♢"EncodingManager.h"♢
|    [43:44] <Newline> = ♢¶♢
|    [44:44] <ObjCPreprocessorImport>
|    |    [44:44] <Match> = ♢#import♢
|    |    [44:44] <Whitespace> = ♢•♢
|    |    [44:44] <CStringDoubleQuote> = ♢"Document.h"♢
|    [44:45] <Newline> = ♢¶♢
|    [45:45] <ObjCPreprocessorImport>
|    |    [45:45] <Match> = ♢#import♢
|    |    [45:45] <Whitespace> = ♢•♢
|    |    [45:45] <CStringDoubleQuote> = ♢"DocumentController.h"♢
|    [45:46] <Newline> = ♢¶♢
|    [46:46] <ObjCPreprocessorImport>
|    |    [46:46] <Match> = ♢#import♢
|    |    [46:46] <Whitespace> = ♢•♢
|    |    [46:46] <CStringDoubleQuote> = ♢"DocumentWindowController.h"♢
|    [46:47] <Newline> = ♢¶♢
|    [47:47] <ObjCPreprocessorImport>
|    |    [47:47] <Match> = ♢#import♢
|    |    [47:47] <Whitespace> = ♢•♢
|    |    [47:47] <CStringDoubleQuote> = ♢"PrintPanelAccessoryController.h"♢
|    [47:48] <Newline> = ♢¶♢
|    [48:48] <ObjCPreprocessorImport>
|    |    [48:48] <Match> = ♢#import♢
|    |    [48:48] <Whitespace> = ♢•♢
|    |    [48:48] <CStringDoubleQuote> = ♢"TextEditDefaultsKeys.h"♢
|    [48:49] <Newline> = ♢¶♢
|    [49:49] <ObjCPreprocessorImport>
|    |    [49:49] <Match> = ♢#import♢
|    |    [49:49] <Whitespace> = ♢•♢
|    |    [49:49] <CStringDoubleQuote> = ♢"TextEditErrors.h"♢
|    [49:50] <Newline> = ♢¶♢
|    [50:50] <ObjCPreprocessorImport>
|    |    [50:50] <Match> = ♢#import♢
|    |    [50:50] <Whitespace> = ♢•♢
|    |    [50:50] <CStringDoubleQuote> = ♢"TextEditMisc.h"♢
|    [50:51] <Newline> = ♢¶♢
|    [51:52] <Newline> = ♢¶♢
|    [52:52] <CPreprocessorDefine>
|    |    [52:52] <Match> = ♢#define♢
|    |    [52:52] <Whitespace> = ♢•♢
|    |    [52:52] <Text> = ♢oldEditPaddingCompensation♢
|    |    [52:52] <Whitespace> = ♢•♢
|    |    [52:52] <Text> = ♢12.0♢
|    [52:53] <Newline> = ♢¶♢
|    [53:54] <Newline> = ♢¶♢
|    [54:54] <Text> = ♢NSString♢
|    [54:54] <Whitespace> = ♢•♢
|    [54:54] <Asterisk> = ♢*♢
|    [54:54] <Text> = ♢SimpleTextType♢
|    [54:54] <Whitespace> = ♢•♢
|    [54:54] <Text> = ♢=♢
|    [54:54] <Whitespace> = ♢•♢
|    [54:54] <ObjCString> = ♢@"com.apple.traditional-mac-plain-text"♢
|    [54:54] <Semicolon> = ♢;♢
|    [54:55] <Newline> = ♢¶♢
|    [55:55] <Text> = ♢NSString♢
|    [55:55] <Whitespace> = ♢•♢
|    [55:55] <Asterisk> = ♢*♢
|    [55:55] <Text> = ♢Word97Type♢
|    [55:55] <Whitespace> = ♢•♢
|    [55:55] <Text> = ♢=♢
|    [55:55] <Whitespace> = ♢•♢
|    [55:55] <ObjCString> = ♢@"com.microsoft.word.doc"♢
|    [55:55] <Semicolon> = ♢;♢
|    [55:56] <Newline> = ♢¶♢
|    [56:56] <Text> = ♢NSString♢
|    [56:56] <Whitespace> = ♢•♢
|    [56:56] <Asterisk> = ♢*♢
|    [56:56] <Text> = ♢Word2007Type♢
|    [56:56] <Whitespace> = ♢•♢
|    [56:56] <Text> = ♢=♢
|    [56:56] <Whitespace> = ♢•♢
|    [56:56] <ObjCString> = ♢@"org.openxmlformats.wordprocessingml.document"♢
|    [56:56] <Semicolon> = ♢;♢
|    [56:57] <Newline> = ♢¶♢
|    [57:57] <Text> = ♢NSString♢
|    [57:57] <Whitespace> = ♢•♢
|    [57:57] <Asterisk> = ♢*♢
|    [57:57] <Text> = ♢Word2003XMLType♢
|    [57:57] <Whitespace> = ♢•♢
|    [57:57] <Text> = ♢=♢
|    [57:57] <Whitespace> = ♢•♢
|    [57:57] <ObjCString> = ♢@"com.microsoft.word.wordml"♢
|    [57:57] <Semicolon> = ♢;♢
|    [57:58] <Newline> = ♢¶♢
|    [58:58] <Text> = ♢NSString♢
|    [58:58] <Whitespace> = ♢•♢
|    [58:58] <Asterisk> = ♢*♢
|    [58:58] <Text> = ♢OpenDocumentTextType♢
|    [58:58] <Whitespace> = ♢•♢
|    [58:58] <Text> = ♢=♢
|    [58:58] <Whitespace> = ♢•♢
|    [58:58] <ObjCString> = ♢@"org.oasis-open.opendocument.text"♢
|    [58:58] <Semicolon> = ♢;♢
|    [58:59] <Newline> = ♢¶♢
|    [59:60] <Newline> = ♢¶♢
|    [60:61] <Newline> = ♢¶♢
|    [61:827] <ObjCImplementation>
|    |    [61:61] <Match> = ♢@implementation•Document♢
|    |    [61:62] <Newline> = ♢¶♢
|    |    [62:63] <Newline> = ♢¶♢
|    |    [63:85] <ObjCMethodImplementation>
|    |    |    [63:63] <Match> = ♢-♢
|    |    |    [63:63] <Whitespace> = ♢•♢
|    |    |    [63:63] <Parenthesis>
|    |    |    |    [63:63] <Match> = ♢(♢
|    |    |    |    [63:63] <Text> = ♢id♢
|    |    |    |    [63:63] <Match> = ♢)♢
|    |    |    [63:63] <Text> = ♢init♢
|    |    |    [63:63] <Whitespace> = ♢•♢
|    |    |    [63:85] <Braces>
|    |    |    |    [63:63] <Match> = ♢{♢
|    |    |    |    [63:64] <Newline> = ♢¶♢
|    |    |    |    [64:64] <Indenting> = ♢••••♢
|    |    |    |    [64:83] <CConditionIf>
|    |    |    |    |    [64:64] <Match> = ♢if♢
|    |    |    |    |    [64:64] <Whitespace> = ♢•♢
|    |    |    |    |    [64:64] <Parenthesis>
|    |    |    |    |    |    [64:64] <Match> = ♢(♢
|    |    |    |    |    |    [64:64] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    [64:64] <Whitespace> = ♢•♢
|    |    |    |    |    |    [64:64] <Text> = ♢=♢
|    |    |    |    |    |    [64:64] <Whitespace> = ♢•♢
|    |    |    |    |    |    [64:64] <ObjCMethodCall>
|    |    |    |    |    |    |    [64:64] <Match> = ♢[♢
|    |    |    |    |    |    |    [64:64] <ObjCSuper> = ♢super♢
|    |    |    |    |    |    |    [64:64] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [64:64] <Text> = ♢init♢
|    |    |    |    |    |    |    [64:64] <Match> = ♢]♢
|    |    |    |    |    |    [64:64] <Match> = ♢)♢
|    |    |    |    |    [64:64] <Whitespace> = ♢•♢
|    |    |    |    |    [64:83] <Braces>
|    |    |    |    |    |    [64:64] <Match> = ♢{♢
|    |    |    |    |    |    [64:65] <Newline> = ♢¶♢
|    |    |    |    |    |    [65:65] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [65:65] <ObjCMethodCall>
|    |    |    |    |    |    |    [65:65] <Match> = ♢[♢
|    |    |    |    |    |    |    [65:65] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [65:65] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [65:65] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [65:65] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [65:65] <Text> = ♢undoManager♢
|    |    |    |    |    |    |    |    [65:65] <Match> = ♢]♢
|    |    |    |    |    |    |    [65:65] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [65:65] <Text> = ♢disableUndoRegistration♢
|    |    |    |    |    |    |    [65:65] <Match> = ♢]♢
|    |    |    |    |    |    [65:65] <Semicolon> = ♢;♢
|    |    |    |    |    |    [65:66] <Newline> = ♢¶♢
|    |    |    |    |    |    [66:66] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [66:67] <Newline> = ♢¶♢
|    |    |    |    |    |    [67:67] <Indenting> = ♢→♢
|    |    |    |    |    |    [67:67] <Text> = ♢textStorage♢
|    |    |    |    |    |    [67:67] <Whitespace> = ♢•♢
|    |    |    |    |    |    [67:67] <Text> = ♢=♢
|    |    |    |    |    |    [67:67] <Whitespace> = ♢•♢
|    |    |    |    |    |    [67:67] <ObjCMethodCall>
|    |    |    |    |    |    |    [67:67] <Match> = ♢[♢
|    |    |    |    |    |    |    [67:67] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [67:67] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [67:67] <Match> = ♢NSTextStorage♢
|    |    |    |    |    |    |    |    [67:67] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [67:67] <Text> = ♢allocWithZone♢
|    |    |    |    |    |    |    |    [67:67] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [67:67] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [67:67] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [67:67] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    [67:67] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [67:67] <Text> = ♢zone♢
|    |    |    |    |    |    |    |    |    [67:67] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [67:67] <Match> = ♢]♢
|    |    |    |    |    |    |    [67:67] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [67:67] <Text> = ♢init♢
|    |    |    |    |    |    |    [67:67] <Match> = ♢]♢
|    |    |    |    |    |    [67:67] <Semicolon> = ♢;♢
|    |    |    |    |    |    [67:68] <Newline> = ♢¶♢
|    |    |    |    |    |    [68:68] <Indenting> = ♢→♢
|    |    |    |    |    |    [68:69] <Newline> = ♢¶♢
|    |    |    |    |    |    [69:69] <Indenting> = ♢→♢
|    |    |    |    |    |    [69:69] <ObjCMethodCall>
|    |    |    |    |    |    |    [69:69] <Match> = ♢[♢
|    |    |    |    |    |    |    [69:69] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [69:69] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [69:69] <Text> = ♢setBackgroundColor♢
|    |    |    |    |    |    |    [69:69] <Colon> = ♢:♢
|    |    |    |    |    |    |    [69:69] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [69:69] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [69:69] <Match> = ♢NSColor♢
|    |    |    |    |    |    |    |    [69:69] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [69:69] <Text> = ♢whiteColor♢
|    |    |    |    |    |    |    |    [69:69] <Match> = ♢]♢
|    |    |    |    |    |    |    [69:69] <Match> = ♢]♢
|    |    |    |    |    |    [69:69] <Semicolon> = ♢;♢
|    |    |    |    |    |    [69:70] <Newline> = ♢¶♢
|    |    |    |    |    |    [70:70] <Indenting> = ♢→♢
|    |    |    |    |    |    [70:70] <ObjCMethodCall>
|    |    |    |    |    |    |    [70:70] <Match> = ♢[♢
|    |    |    |    |    |    |    [70:70] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [70:70] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [70:70] <Text> = ♢setEncoding♢
|    |    |    |    |    |    |    [70:70] <Colon> = ♢:♢
|    |    |    |    |    |    |    [70:70] <Text> = ♢NoStringEncoding♢
|    |    |    |    |    |    |    [70:70] <Match> = ♢]♢
|    |    |    |    |    |    [70:70] <Semicolon> = ♢;♢
|    |    |    |    |    |    [70:71] <Newline> = ♢¶♢
|    |    |    |    |    |    [71:71] <Indenting> = ♢→♢
|    |    |    |    |    |    [71:71] <ObjCMethodCall>
|    |    |    |    |    |    |    [71:71] <Match> = ♢[♢
|    |    |    |    |    |    |    [71:71] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [71:71] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [71:71] <Text> = ♢setEncodingForSaving♢
|    |    |    |    |    |    |    [71:71] <Colon> = ♢:♢
|    |    |    |    |    |    |    [71:71] <Text> = ♢NoStringEncoding♢
|    |    |    |    |    |    |    [71:71] <Match> = ♢]♢
|    |    |    |    |    |    [71:71] <Semicolon> = ♢;♢
|    |    |    |    |    |    [71:72] <Newline> = ♢¶♢
|    |    |    |    |    |    [72:72] <Indenting> = ♢→♢
|    |    |    |    |    |    [72:72] <ObjCMethodCall>
|    |    |    |    |    |    |    [72:72] <Match> = ♢[♢
|    |    |    |    |    |    |    [72:72] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [72:72] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [72:72] <Text> = ♢setScaleFactor♢
|    |    |    |    |    |    |    [72:72] <Colon> = ♢:♢
|    |    |    |    |    |    |    [72:72] <Text> = ♢1.0♢
|    |    |    |    |    |    |    [72:72] <Match> = ♢]♢
|    |    |    |    |    |    [72:72] <Semicolon> = ♢;♢
|    |    |    |    |    |    [72:73] <Newline> = ♢¶♢
|    |    |    |    |    |    [73:73] <Indenting> = ♢→♢
|    |    |    |    |    |    [73:73] <ObjCMethodCall>
|    |    |    |    |    |    |    [73:73] <Match> = ♢[♢
|    |    |    |    |    |    |    [73:73] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [73:73] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [73:73] <Text> = ♢setDocumentPropertiesToDefaults♢
|    |    |    |    |    |    |    [73:73] <Match> = ♢]♢
|    |    |    |    |    |    [73:73] <Semicolon> = ♢;♢
|    |    |    |    |    |    [73:74] <Newline> = ♢¶♢
|    |    |    |    |    |    [74:74] <Indenting> = ♢→♢
|    |    |    |    |    |    [74:75] <Newline> = ♢¶♢
|    |    |    |    |    |    [75:75] <Indenting> = ♢→•♢
|    |    |    |    |    |    [75:75] <CPPComment> = ♢//•Assume•the•default•file•type•for•now,•since•-initWithType:error:•does•not•currently•get•called•when•creating•documents•using•AppleScript.•(4165700)♢
|    |    |    |    |    |    [75:76] <Newline> = ♢¶♢
|    |    |    |    |    |    [76:76] <Indenting> = ♢→♢
|    |    |    |    |    |    [76:76] <ObjCMethodCall>
|    |    |    |    |    |    |    [76:76] <Match> = ♢[♢
|    |    |    |    |    |    |    [76:76] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [76:76] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [76:76] <Text> = ♢setFileType♢
|    |    |    |    |    |    |    [76:76] <Colon> = ♢:♢
|    |    |    |    |    |    |    [76:76] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [76:76] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [76:76] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [76:76] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [76:76] <Match> = ♢NSDocumentController♢
|    |    |    |    |    |    |    |    |    [76:76] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [76:76] <Text> = ♢sharedDocumentController♢
|    |    |    |    |    |    |    |    |    [76:76] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [76:76] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [76:76] <Text> = ♢defaultType♢
|    |    |    |    |    |    |    |    [76:76] <Match> = ♢]♢
|    |    |    |    |    |    |    [76:76] <Match> = ♢]♢
|    |    |    |    |    |    [76:76] <Semicolon> = ♢;♢
|    |    |    |    |    |    [76:77] <Newline> = ♢¶♢
|    |    |    |    |    |    [77:77] <Indenting> = ♢→♢
|    |    |    |    |    |    [77:78] <Newline> = ♢¶♢
|    |    |    |    |    |    [78:78] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [78:78] <ObjCMethodCall>
|    |    |    |    |    |    |    [78:78] <Match> = ♢[♢
|    |    |    |    |    |    |    [78:78] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [78:78] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [78:78] <Text> = ♢setPrintInfo♢
|    |    |    |    |    |    |    [78:78] <Colon> = ♢:♢
|    |    |    |    |    |    |    [78:78] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [78:78] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [78:78] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [78:78] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [78:78] <Text> = ♢printInfo♢
|    |    |    |    |    |    |    |    [78:78] <Match> = ♢]♢
|    |    |    |    |    |    |    [78:78] <Match> = ♢]♢
|    |    |    |    |    |    [78:78] <Semicolon> = ♢;♢
|    |    |    |    |    |    [78:79] <Newline> = ♢¶♢
|    |    |    |    |    |    [79:79] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [79:80] <Newline> = ♢¶♢
|    |    |    |    |    |    [80:80] <Indenting> = ♢→♢
|    |    |    |    |    |    [80:80] <Text> = ♢hasMultiplePages♢
|    |    |    |    |    |    [80:80] <Whitespace> = ♢•♢
|    |    |    |    |    |    [80:80] <Text> = ♢=♢
|    |    |    |    |    |    [80:80] <Whitespace> = ♢•♢
|    |    |    |    |    |    [80:80] <ObjCMethodCall>
|    |    |    |    |    |    |    [80:80] <Match> = ♢[♢
|    |    |    |    |    |    |    [80:80] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [80:80] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [80:80] <Match> = ♢NSUserDefaults♢
|    |    |    |    |    |    |    |    [80:80] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [80:80] <Text> = ♢standardUserDefaults♢
|    |    |    |    |    |    |    |    [80:80] <Match> = ♢]♢
|    |    |    |    |    |    |    [80:80] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [80:80] <Text> = ♢boolForKey♢
|    |    |    |    |    |    |    [80:80] <Colon> = ♢:♢
|    |    |    |    |    |    |    [80:80] <Text> = ♢ShowPageBreaks♢
|    |    |    |    |    |    |    [80:80] <Match> = ♢]♢
|    |    |    |    |    |    [80:80] <Semicolon> = ♢;♢
|    |    |    |    |    |    [80:81] <Newline> = ♢¶♢
|    |    |    |    |    |    [81:81] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [81:82] <Newline> = ♢¶♢
|    |    |    |    |    |    [82:82] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [82:82] <ObjCMethodCall>
|    |    |    |    |    |    |    [82:82] <Match> = ♢[♢
|    |    |    |    |    |    |    [82:82] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [82:82] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [82:82] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [82:82] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [82:82] <Text> = ♢undoManager♢
|    |    |    |    |    |    |    |    [82:82] <Match> = ♢]♢
|    |    |    |    |    |    |    [82:82] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [82:82] <Text> = ♢enableUndoRegistration♢
|    |    |    |    |    |    |    [82:82] <Match> = ♢]♢
|    |    |    |    |    |    [82:82] <Semicolon> = ♢;♢
|    |    |    |    |    |    [82:83] <Newline> = ♢¶♢
|    |    |    |    |    |    [83:83] <Indenting> = ♢••••♢
|    |    |    |    |    |    [83:83] <Match> = ♢}♢
|    |    |    |    [83:84] <Newline> = ♢¶♢
|    |    |    |    [84:84] <Indenting> = ♢••••♢
|    |    |    |    [84:84] <CFlowReturn>
|    |    |    |    |    [84:84] <Match> = ♢return♢
|    |    |    |    |    [84:84] <Whitespace> = ♢•♢
|    |    |    |    |    [84:84] <ObjCSelf> = ♢self♢
|    |    |    |    |    [84:84] <Semicolon> = ♢;♢
|    |    |    |    [84:85] <Newline> = ♢¶♢
|    |    |    |    [85:85] <Match> = ♢}♢
|    |    [85:86] <Newline> = ♢¶♢
|    |    [86:87] <Newline> = ♢¶♢
|    |    [87:88] <CComment> = ♢/*•Return•an•NSDictionary•which•maps•Cocoa•text•system•document•identifiers•(as•declared•in•AppKit/NSAttributedString.h)•to•document•types•declared•in•TextEdit's•Info.plist.¶*/♢
|    |    [88:89] <Newline> = ♢¶♢
|    |    [89:106] <ObjCMethodImplementation>
|    |    |    [89:89] <Match> = ♢-♢
|    |    |    [89:89] <Whitespace> = ♢•♢
|    |    |    [89:89] <Parenthesis>
|    |    |    |    [89:89] <Match> = ♢(♢
|    |    |    |    [89:89] <Text> = ♢NSDictionary♢
|    |    |    |    [89:89] <Whitespace> = ♢•♢
|    |    |    |    [89:89] <Asterisk> = ♢*♢
|    |    |    |    [89:89] <Match> = ♢)♢
|    |    |    [89:89] <Text> = ♢textDocumentTypeToTextEditDocumentTypeMappingTable♢
|    |    |    [89:89] <Whitespace> = ♢•♢
|    |    |    [89:106] <Braces>
|    |    |    |    [89:89] <Match> = ♢{♢
|    |    |    |    [89:90] <Newline> = ♢¶♢
|    |    |    |    [90:90] <Indenting> = ♢••••♢
|    |    |    |    [90:90] <CStatic> = ♢static♢
|    |    |    |    [90:90] <Whitespace> = ♢•♢
|    |    |    |    [90:90] <Text> = ♢NSDictionary♢
|    |    |    |    [90:90] <Whitespace> = ♢•♢
|    |    |    |    [90:90] <Asterisk> = ♢*♢
|    |    |    |    [90:90] <Text> = ♢documentMappings♢
|    |    |    |    [90:90] <Whitespace> = ♢•♢
|    |    |    |    [90:90] <Text> = ♢=♢
|    |    |    |    [90:90] <Whitespace> = ♢•♢
|    |    |    |    [90:90] <ObjCNil> = ♢nil♢
|    |    |    |    [90:90] <Semicolon> = ♢;♢
|    |    |    |    [90:91] <Newline> = ♢¶♢
|    |    |    |    [91:91] <Indenting> = ♢••••♢
|    |    |    |    [91:104] <CConditionIf>
|    |    |    |    |    [91:91] <Match> = ♢if♢
|    |    |    |    |    [91:91] <Whitespace> = ♢•♢
|    |    |    |    |    [91:91] <Parenthesis>
|    |    |    |    |    |    [91:91] <Match> = ♢(♢
|    |    |    |    |    |    [91:91] <Text> = ♢documentMappings♢
|    |    |    |    |    |    [91:91] <Whitespace> = ♢•♢
|    |    |    |    |    |    [91:91] <Text> = ♢==♢
|    |    |    |    |    |    [91:91] <Whitespace> = ♢•♢
|    |    |    |    |    |    [91:91] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    [91:91] <Match> = ♢)♢
|    |    |    |    |    [91:91] <Whitespace> = ♢•♢
|    |    |    |    |    [91:104] <Braces>
|    |    |    |    |    |    [91:91] <Match> = ♢{♢
|    |    |    |    |    |    [91:92] <Newline> = ♢¶♢
|    |    |    |    |    |    [92:92] <Indenting> = ♢→♢
|    |    |    |    |    |    [92:92] <Text> = ♢documentMappings♢
|    |    |    |    |    |    [92:92] <Whitespace> = ♢•♢
|    |    |    |    |    |    [92:92] <Text> = ♢=♢
|    |    |    |    |    |    [92:92] <Whitespace> = ♢•♢
|    |    |    |    |    |    [92:103] <ObjCMethodCall>
|    |    |    |    |    |    |    [92:92] <Match> = ♢[♢
|    |    |    |    |    |    |    [92:92] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [92:92] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [92:92] <Match> = ♢NSDictionary♢
|    |    |    |    |    |    |    |    [92:92] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [92:92] <Text> = ♢alloc♢
|    |    |    |    |    |    |    |    [92:92] <Match> = ♢]♢
|    |    |    |    |    |    |    [92:92] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [92:92] <Text> = ♢initWithObjectsAndKeys♢
|    |    |    |    |    |    |    [92:92] <Colon> = ♢:♢
|    |    |    |    |    |    |    [92:93] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [93:93] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    [93:93] <Parenthesis>
|    |    |    |    |    |    |    |    [93:93] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [93:93] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    [93:93] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [93:93] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [93:93] <Match> = ♢)♢
|    |    |    |    |    |    |    [93:93] <Text> = ♢kUTTypePlainText,♢
|    |    |    |    |    |    |    [93:93] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [93:93] <Text> = ♢NSPlainTextDocumentType,♢
|    |    |    |    |    |    |    [93:94] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [94:94] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    [94:94] <Parenthesis>
|    |    |    |    |    |    |    |    [94:94] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [94:94] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    [94:94] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [94:94] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [94:94] <Match> = ♢)♢
|    |    |    |    |    |    |    [94:94] <Text> = ♢kUTTypeRTF,♢
|    |    |    |    |    |    |    [94:94] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [94:94] <Text> = ♢NSRTFTextDocumentType,♢
|    |    |    |    |    |    |    [94:95] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [95:95] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    [95:95] <Parenthesis>
|    |    |    |    |    |    |    |    [95:95] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [95:95] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    [95:95] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [95:95] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [95:95] <Match> = ♢)♢
|    |    |    |    |    |    |    [95:95] <Text> = ♢kUTTypeRTFD,♢
|    |    |    |    |    |    |    [95:95] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [95:95] <Text> = ♢NSRTFDTextDocumentType,♢
|    |    |    |    |    |    |    [95:96] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [96:96] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    [96:96] <Text> = ♢SimpleTextType,♢
|    |    |    |    |    |    |    [96:96] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [96:96] <Text> = ♢NSMacSimpleTextDocumentType,♢
|    |    |    |    |    |    |    [96:97] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [97:97] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    [97:97] <Parenthesis>
|    |    |    |    |    |    |    |    [97:97] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [97:97] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    [97:97] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [97:97] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [97:97] <Match> = ♢)♢
|    |    |    |    |    |    |    [97:97] <Text> = ♢kUTTypeHTML,♢
|    |    |    |    |    |    |    [97:97] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [97:97] <Text> = ♢NSHTMLTextDocumentType,♢
|    |    |    |    |    |    |    [97:98] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [98:98] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    [98:98] <Text> = ♢Word97Type,♢
|    |    |    |    |    |    |    [98:98] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [98:98] <Text> = ♢NSDocFormatTextDocumentType,♢
|    |    |    |    |    |    |    [98:99] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [99:99] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    [99:99] <Text> = ♢Word2007Type,♢
|    |    |    |    |    |    |    [99:99] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [99:99] <Text> = ♢NSOfficeOpenXMLTextDocumentType,♢
|    |    |    |    |    |    |    [99:100] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [100:100] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    [100:100] <Text> = ♢Word2003XMLType,♢
|    |    |    |    |    |    |    [100:100] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [100:100] <Text> = ♢NSWordMLTextDocumentType,♢
|    |    |    |    |    |    |    [100:101] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [101:101] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    [101:101] <Text> = ♢OpenDocumentTextType,♢
|    |    |    |    |    |    |    [101:101] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [101:101] <Text> = ♢NSOpenDocumentTextDocumentType,♢
|    |    |    |    |    |    |    [101:102] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [102:102] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    [102:102] <Parenthesis>
|    |    |    |    |    |    |    |    [102:102] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [102:102] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    [102:102] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [102:102] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [102:102] <Match> = ♢)♢
|    |    |    |    |    |    |    [102:102] <Text> = ♢kUTTypeWebArchive,♢
|    |    |    |    |    |    |    [102:102] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [102:102] <Text> = ♢NSWebArchiveTextDocumentType,♢
|    |    |    |    |    |    |    [102:103] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [103:103] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    [103:103] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    [103:103] <Match> = ♢]♢
|    |    |    |    |    |    [103:103] <Semicolon> = ♢;♢
|    |    |    |    |    |    [103:104] <Newline> = ♢¶♢
|    |    |    |    |    |    [104:104] <Indenting> = ♢••••♢
|    |    |    |    |    |    [104:104] <Match> = ♢}♢
|    |    |    |    [104:105] <Newline> = ♢¶♢
|    |    |    |    [105:105] <Indenting> = ♢••••♢
|    |    |    |    [105:105] <CFlowReturn>
|    |    |    |    |    [105:105] <Match> = ♢return♢
|    |    |    |    |    [105:105] <Whitespace> = ♢•♢
|    |    |    |    |    [105:105] <Text> = ♢documentMappings♢
|    |    |    |    |    [105:105] <Semicolon> = ♢;♢
|    |    |    |    [105:106] <Newline> = ♢¶♢
|    |    |    |    [106:106] <Match> = ♢}♢
|    |    [106:107] <Newline> = ♢¶♢
|    |    [107:108] <Newline> = ♢¶♢
|    |    [108:109] <CComment> = ♢/*•This•method•is•called•by•the•document•controller.•The•message•is•passed•on•after•information•about•the•selected•encoding•(from•our•controller•subclass)•and•preference•regarding•HTML•and•RTF•formatting•has•been•added.•-lastSelectedEncodingForURL:•returns•the•encoding•specified•in•the•Open•panel,•or•the•default•encoding•if•the•document•was•opened•without•an•open•panel.¶*/♢
|    |    [109:110] <Newline> = ♢¶♢
|    |    [110:113] <ObjCMethodImplementation>
|    |    |    [110:110] <Match> = ♢-♢
|    |    |    [110:110] <Whitespace> = ♢•♢
|    |    |    [110:110] <Parenthesis>
|    |    |    |    [110:110] <Match> = ♢(♢
|    |    |    |    [110:110] <Text> = ♢BOOL♢
|    |    |    |    [110:110] <Match> = ♢)♢
|    |    |    [110:110] <Text> = ♢readFromURL♢
|    |    |    [110:110] <Colon> = ♢:♢
|    |    |    [110:110] <Parenthesis>
|    |    |    |    [110:110] <Match> = ♢(♢
|    |    |    |    [110:110] <Text> = ♢NSURL♢
|    |    |    |    [110:110] <Whitespace> = ♢•♢
|    |    |    |    [110:110] <Asterisk> = ♢*♢
|    |    |    |    [110:110] <Match> = ♢)♢
|    |    |    [110:110] <Text> = ♢absoluteURL♢
|    |    |    [110:110] <Whitespace> = ♢•♢
|    |    |    [110:110] <Text> = ♢ofType♢
|    |    |    [110:110] <Colon> = ♢:♢
|    |    |    [110:110] <Parenthesis>
|    |    |    |    [110:110] <Match> = ♢(♢
|    |    |    |    [110:110] <Text> = ♢NSString♢
|    |    |    |    [110:110] <Whitespace> = ♢•♢
|    |    |    |    [110:110] <Asterisk> = ♢*♢
|    |    |    |    [110:110] <Match> = ♢)♢
|    |    |    [110:110] <Text> = ♢typeName♢
|    |    |    [110:110] <Whitespace> = ♢•♢
|    |    |    [110:110] <Text> = ♢error♢
|    |    |    [110:110] <Colon> = ♢:♢
|    |    |    [110:110] <Parenthesis>
|    |    |    |    [110:110] <Match> = ♢(♢
|    |    |    |    [110:110] <Text> = ♢NSError♢
|    |    |    |    [110:110] <Whitespace> = ♢•♢
|    |    |    |    [110:110] <Asterisk> = ♢*♢
|    |    |    |    [110:110] <Asterisk> = ♢*♢
|    |    |    |    [110:110] <Match> = ♢)♢
|    |    |    [110:110] <Text> = ♢outError♢
|    |    |    [110:110] <Whitespace> = ♢•♢
|    |    |    [110:113] <Braces>
|    |    |    |    [110:110] <Match> = ♢{♢
|    |    |    |    [110:111] <Newline> = ♢¶♢
|    |    |    |    [111:111] <Indenting> = ♢••••♢
|    |    |    |    [111:111] <Text> = ♢DocumentController♢
|    |    |    |    [111:111] <Whitespace> = ♢•♢
|    |    |    |    [111:111] <Asterisk> = ♢*♢
|    |    |    |    [111:111] <Text> = ♢docController♢
|    |    |    |    [111:111] <Whitespace> = ♢•♢
|    |    |    |    [111:111] <Text> = ♢=♢
|    |    |    |    [111:111] <Whitespace> = ♢•♢
|    |    |    |    [111:111] <ObjCMethodCall>
|    |    |    |    |    [111:111] <Match> = ♢[♢
|    |    |    |    |    [111:111] <Match> = ♢DocumentController♢
|    |    |    |    |    [111:111] <Whitespace> = ♢•♢
|    |    |    |    |    [111:111] <Text> = ♢sharedDocumentController♢
|    |    |    |    |    [111:111] <Match> = ♢]♢
|    |    |    |    [111:111] <Semicolon> = ♢;♢
|    |    |    |    [111:112] <Newline> = ♢¶♢
|    |    |    |    [112:112] <Indenting> = ♢••••♢
|    |    |    |    [112:112] <CFlowReturn>
|    |    |    |    |    [112:112] <Match> = ♢return♢
|    |    |    |    |    [112:112] <Whitespace> = ♢•♢
|    |    |    |    |    [112:112] <ObjCMethodCall>
|    |    |    |    |    |    [112:112] <Match> = ♢[♢
|    |    |    |    |    |    [112:112] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    [112:112] <Whitespace> = ♢•♢
|    |    |    |    |    |    [112:112] <Text> = ♢readFromURL♢
|    |    |    |    |    |    [112:112] <Colon> = ♢:♢
|    |    |    |    |    |    [112:112] <Text> = ♢absoluteURL♢
|    |    |    |    |    |    [112:112] <Whitespace> = ♢•♢
|    |    |    |    |    |    [112:112] <Text> = ♢ofType♢
|    |    |    |    |    |    [112:112] <Colon> = ♢:♢
|    |    |    |    |    |    [112:112] <Text> = ♢typeName♢
|    |    |    |    |    |    [112:112] <Whitespace> = ♢•♢
|    |    |    |    |    |    [112:112] <Text> = ♢encoding♢
|    |    |    |    |    |    [112:112] <Colon> = ♢:♢
|    |    |    |    |    |    [112:112] <ObjCMethodCall>
|    |    |    |    |    |    |    [112:112] <Match> = ♢[♢
|    |    |    |    |    |    |    [112:112] <Match> = ♢docController♢
|    |    |    |    |    |    |    [112:112] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [112:112] <Text> = ♢lastSelectedEncodingForURL♢
|    |    |    |    |    |    |    [112:112] <Colon> = ♢:♢
|    |    |    |    |    |    |    [112:112] <Text> = ♢absoluteURL♢
|    |    |    |    |    |    |    [112:112] <Match> = ♢]♢
|    |    |    |    |    |    [112:112] <Whitespace> = ♢•♢
|    |    |    |    |    |    [112:112] <Text> = ♢ignoreRTF♢
|    |    |    |    |    |    [112:112] <Colon> = ♢:♢
|    |    |    |    |    |    [112:112] <ObjCMethodCall>
|    |    |    |    |    |    |    [112:112] <Match> = ♢[♢
|    |    |    |    |    |    |    [112:112] <Match> = ♢docController♢
|    |    |    |    |    |    |    [112:112] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [112:112] <Text> = ♢lastSelectedIgnoreRichForURL♢
|    |    |    |    |    |    |    [112:112] <Colon> = ♢:♢
|    |    |    |    |    |    |    [112:112] <Text> = ♢absoluteURL♢
|    |    |    |    |    |    |    [112:112] <Match> = ♢]♢
|    |    |    |    |    |    [112:112] <Whitespace> = ♢•♢
|    |    |    |    |    |    [112:112] <Text> = ♢ignoreHTML♢
|    |    |    |    |    |    [112:112] <Colon> = ♢:♢
|    |    |    |    |    |    [112:112] <ObjCMethodCall>
|    |    |    |    |    |    |    [112:112] <Match> = ♢[♢
|    |    |    |    |    |    |    [112:112] <Match> = ♢docController♢
|    |    |    |    |    |    |    [112:112] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [112:112] <Text> = ♢lastSelectedIgnoreHTMLForURL♢
|    |    |    |    |    |    |    [112:112] <Colon> = ♢:♢
|    |    |    |    |    |    |    [112:112] <Text> = ♢absoluteURL♢
|    |    |    |    |    |    |    [112:112] <Match> = ♢]♢
|    |    |    |    |    |    [112:112] <Whitespace> = ♢•♢
|    |    |    |    |    |    [112:112] <Text> = ♢error♢
|    |    |    |    |    |    [112:112] <Colon> = ♢:♢
|    |    |    |    |    |    [112:112] <Text> = ♢outError♢
|    |    |    |    |    |    [112:112] <Match> = ♢]♢
|    |    |    |    |    [112:112] <Semicolon> = ♢;♢
|    |    |    |    [112:113] <Newline> = ♢¶♢
|    |    |    |    [113:113] <Match> = ♢}♢
|    |    [113:114] <Newline> = ♢¶♢
|    |    [114:115] <Newline> = ♢¶♢
|    |    [115:248] <ObjCMethodImplementation>
|    |    |    [115:115] <Match> = ♢-♢
|    |    |    [115:115] <Whitespace> = ♢•♢
|    |    |    [115:115] <Parenthesis>
|    |    |    |    [115:115] <Match> = ♢(♢
|    |    |    |    [115:115] <Text> = ♢BOOL♢
|    |    |    |    [115:115] <Match> = ♢)♢
|    |    |    [115:115] <Text> = ♢readFromURL♢
|    |    |    [115:115] <Colon> = ♢:♢
|    |    |    [115:115] <Parenthesis>
|    |    |    |    [115:115] <Match> = ♢(♢
|    |    |    |    [115:115] <Text> = ♢NSURL♢
|    |    |    |    [115:115] <Whitespace> = ♢•♢
|    |    |    |    [115:115] <Asterisk> = ♢*♢
|    |    |    |    [115:115] <Match> = ♢)♢
|    |    |    [115:115] <Text> = ♢absoluteURL♢
|    |    |    [115:115] <Whitespace> = ♢•♢
|    |    |    [115:115] <Text> = ♢ofType♢
|    |    |    [115:115] <Colon> = ♢:♢
|    |    |    [115:115] <Parenthesis>
|    |    |    |    [115:115] <Match> = ♢(♢
|    |    |    |    [115:115] <Text> = ♢NSString♢
|    |    |    |    [115:115] <Whitespace> = ♢•♢
|    |    |    |    [115:115] <Asterisk> = ♢*♢
|    |    |    |    [115:115] <Match> = ♢)♢
|    |    |    [115:115] <Text> = ♢typeName♢
|    |    |    [115:115] <Whitespace> = ♢•♢
|    |    |    [115:115] <Text> = ♢encoding♢
|    |    |    [115:115] <Colon> = ♢:♢
|    |    |    [115:115] <Parenthesis>
|    |    |    |    [115:115] <Match> = ♢(♢
|    |    |    |    [115:115] <Text> = ♢NSStringEncoding♢
|    |    |    |    [115:115] <Match> = ♢)♢
|    |    |    [115:115] <Text> = ♢encoding♢
|    |    |    [115:115] <Whitespace> = ♢•♢
|    |    |    [115:115] <Text> = ♢ignoreRTF♢
|    |    |    [115:115] <Colon> = ♢:♢
|    |    |    [115:115] <Parenthesis>
|    |    |    |    [115:115] <Match> = ♢(♢
|    |    |    |    [115:115] <Text> = ♢BOOL♢
|    |    |    |    [115:115] <Match> = ♢)♢
|    |    |    [115:115] <Text> = ♢ignoreRTF♢
|    |    |    [115:115] <Whitespace> = ♢•♢
|    |    |    [115:115] <Text> = ♢ignoreHTML♢
|    |    |    [115:115] <Colon> = ♢:♢
|    |    |    [115:115] <Parenthesis>
|    |    |    |    [115:115] <Match> = ♢(♢
|    |    |    |    [115:115] <Text> = ♢BOOL♢
|    |    |    |    [115:115] <Match> = ♢)♢
|    |    |    [115:115] <Text> = ♢ignoreHTML♢
|    |    |    [115:115] <Whitespace> = ♢•♢
|    |    |    [115:115] <Text> = ♢error♢
|    |    |    [115:115] <Colon> = ♢:♢
|    |    |    [115:115] <Parenthesis>
|    |    |    |    [115:115] <Match> = ♢(♢
|    |    |    |    [115:115] <Text> = ♢NSError♢
|    |    |    |    [115:115] <Whitespace> = ♢•♢
|    |    |    |    [115:115] <Asterisk> = ♢*♢
|    |    |    |    [115:115] <Asterisk> = ♢*♢
|    |    |    |    [115:115] <Match> = ♢)♢
|    |    |    [115:115] <Text> = ♢outError♢
|    |    |    [115:115] <Whitespace> = ♢•♢
|    |    |    [115:248] <Braces>
|    |    |    |    [115:115] <Match> = ♢{♢
|    |    |    |    [115:116] <Newline> = ♢¶♢
|    |    |    |    [116:116] <Indenting> = ♢••••♢
|    |    |    |    [116:116] <Text> = ♢NSMutableDictionary♢
|    |    |    |    [116:116] <Whitespace> = ♢•♢
|    |    |    |    [116:116] <Asterisk> = ♢*♢
|    |    |    |    [116:116] <Text> = ♢options♢
|    |    |    |    [116:116] <Whitespace> = ♢•♢
|    |    |    |    [116:116] <Text> = ♢=♢
|    |    |    |    [116:116] <Whitespace> = ♢•♢
|    |    |    |    [116:116] <ObjCMethodCall>
|    |    |    |    |    [116:116] <Match> = ♢[♢
|    |    |    |    |    [116:116] <Match> = ♢NSMutableDictionary♢
|    |    |    |    |    [116:116] <Whitespace> = ♢•♢
|    |    |    |    |    [116:116] <Text> = ♢dictionaryWithCapacity♢
|    |    |    |    |    [116:116] <Colon> = ♢:♢
|    |    |    |    |    [116:116] <Text> = ♢5♢
|    |    |    |    |    [116:116] <Match> = ♢]♢
|    |    |    |    [116:116] <Semicolon> = ♢;♢
|    |    |    |    [116:117] <Newline> = ♢¶♢
|    |    |    |    [117:117] <Indenting> = ♢••••♢
|    |    |    |    [117:117] <Text> = ♢NSDictionary♢
|    |    |    |    [117:117] <Whitespace> = ♢•♢
|    |    |    |    [117:117] <Asterisk> = ♢*♢
|    |    |    |    [117:117] <Text> = ♢docAttrs♢
|    |    |    |    [117:117] <Semicolon> = ♢;♢
|    |    |    |    [117:118] <Newline> = ♢¶♢
|    |    |    |    [118:118] <Indenting> = ♢••••♢
|    |    |    |    [118:118] <Text> = ♢id♢
|    |    |    |    [118:118] <Whitespace> = ♢•♢
|    |    |    |    [118:118] <Text> = ♢val,♢
|    |    |    |    [118:118] <Whitespace> = ♢•♢
|    |    |    |    [118:118] <Text> = ♢paperSizeVal,♢
|    |    |    |    [118:118] <Whitespace> = ♢•♢
|    |    |    |    [118:118] <Text> = ♢viewSizeVal♢
|    |    |    |    [118:118] <Semicolon> = ♢;♢
|    |    |    |    [118:119] <Newline> = ♢¶♢
|    |    |    |    [119:119] <Indenting> = ♢••••♢
|    |    |    |    [119:119] <Text> = ♢NSTextStorage♢
|    |    |    |    [119:119] <Whitespace> = ♢•♢
|    |    |    |    [119:119] <Asterisk> = ♢*♢
|    |    |    |    [119:119] <Text> = ♢text♢
|    |    |    |    [119:119] <Whitespace> = ♢•♢
|    |    |    |    [119:119] <Text> = ♢=♢
|    |    |    |    [119:119] <Whitespace> = ♢•♢
|    |    |    |    [119:119] <ObjCMethodCall>
|    |    |    |    |    [119:119] <Match> = ♢[♢
|    |    |    |    |    [119:119] <ObjCSelf> = ♢self♢
|    |    |    |    |    [119:119] <Whitespace> = ♢•♢
|    |    |    |    |    [119:119] <Text> = ♢textStorage♢
|    |    |    |    |    [119:119] <Match> = ♢]♢
|    |    |    |    [119:119] <Semicolon> = ♢;♢
|    |    |    |    [119:120] <Newline> = ♢¶♢
|    |    |    |    [120:120] <Indenting> = ♢••••♢
|    |    |    |    [120:121] <Newline> = ♢¶♢
|    |    |    |    [121:121] <Indenting> = ♢••••♢
|    |    |    |    [121:121] <ObjCMethodCall>
|    |    |    |    |    [121:121] <Match> = ♢[♢
|    |    |    |    |    [121:121] <ObjCMethodCall>
|    |    |    |    |    |    [121:121] <Match> = ♢[♢
|    |    |    |    |    |    [121:121] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    [121:121] <Whitespace> = ♢•♢
|    |    |    |    |    |    [121:121] <Text> = ♢undoManager♢
|    |    |    |    |    |    [121:121] <Match> = ♢]♢
|    |    |    |    |    [121:121] <Whitespace> = ♢•♢
|    |    |    |    |    [121:121] <Text> = ♢disableUndoRegistration♢
|    |    |    |    |    [121:121] <Match> = ♢]♢
|    |    |    |    [121:121] <Semicolon> = ♢;♢
|    |    |    |    [121:122] <Newline> = ♢¶♢
|    |    |    |    [122:122] <Indenting> = ♢••••♢
|    |    |    |    [122:123] <Newline> = ♢¶♢
|    |    |    |    [123:123] <Indenting> = ♢••••♢
|    |    |    |    [123:123] <ObjCMethodCall>
|    |    |    |    |    [123:123] <Match> = ♢[♢
|    |    |    |    |    [123:123] <Match> = ♢options♢
|    |    |    |    |    [123:123] <Whitespace> = ♢•♢
|    |    |    |    |    [123:123] <Text> = ♢setObject♢
|    |    |    |    |    [123:123] <Colon> = ♢:♢
|    |    |    |    |    [123:123] <Text> = ♢absoluteURL♢
|    |    |    |    |    [123:123] <Whitespace> = ♢•♢
|    |    |    |    |    [123:123] <Text> = ♢forKey♢
|    |    |    |    |    [123:123] <Colon> = ♢:♢
|    |    |    |    |    [123:123] <Text> = ♢NSBaseURLDocumentOption♢
|    |    |    |    |    [123:123] <Match> = ♢]♢
|    |    |    |    [123:123] <Semicolon> = ♢;♢
|    |    |    |    [123:124] <Newline> = ♢¶♢
|    |    |    |    [124:124] <Indenting> = ♢••••♢
|    |    |    |    [124:126] <CConditionIf>
|    |    |    |    |    [124:124] <Match> = ♢if♢
|    |    |    |    |    [124:124] <Whitespace> = ♢•♢
|    |    |    |    |    [124:124] <Parenthesis>
|    |    |    |    |    |    [124:124] <Match> = ♢(♢
|    |    |    |    |    |    [124:124] <Text> = ♢encoding♢
|    |    |    |    |    |    [124:124] <Whitespace> = ♢•♢
|    |    |    |    |    |    [124:124] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    [124:124] <Text> = ♢=♢
|    |    |    |    |    |    [124:124] <Whitespace> = ♢•♢
|    |    |    |    |    |    [124:124] <Text> = ♢NoStringEncoding♢
|    |    |    |    |    |    [124:124] <Match> = ♢)♢
|    |    |    |    |    [124:124] <Whitespace> = ♢•♢
|    |    |    |    |    [124:126] <Braces>
|    |    |    |    |    |    [124:124] <Match> = ♢{♢
|    |    |    |    |    |    [124:125] <Newline> = ♢¶♢
|    |    |    |    |    |    [125:125] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [125:125] <ObjCMethodCall>
|    |    |    |    |    |    |    [125:125] <Match> = ♢[♢
|    |    |    |    |    |    |    [125:125] <Match> = ♢options♢
|    |    |    |    |    |    |    [125:125] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [125:125] <Text> = ♢setObject♢
|    |    |    |    |    |    |    [125:125] <Colon> = ♢:♢
|    |    |    |    |    |    |    [125:125] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [125:125] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [125:125] <Match> = ♢NSNumber♢
|    |    |    |    |    |    |    |    [125:125] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [125:125] <Text> = ♢numberWithUnsignedInteger♢
|    |    |    |    |    |    |    |    [125:125] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [125:125] <Text> = ♢encoding♢
|    |    |    |    |    |    |    |    [125:125] <Match> = ♢]♢
|    |    |    |    |    |    |    [125:125] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [125:125] <Text> = ♢forKey♢
|    |    |    |    |    |    |    [125:125] <Colon> = ♢:♢
|    |    |    |    |    |    |    [125:125] <Text> = ♢NSCharacterEncodingDocumentOption♢
|    |    |    |    |    |    |    [125:125] <Match> = ♢]♢
|    |    |    |    |    |    [125:125] <Semicolon> = ♢;♢
|    |    |    |    |    |    [125:126] <Newline> = ♢¶♢
|    |    |    |    |    |    [126:126] <Indenting> = ♢••••♢
|    |    |    |    |    |    [126:126] <Match> = ♢}♢
|    |    |    |    [126:127] <Newline> = ♢¶♢
|    |    |    |    [127:127] <Indenting> = ♢••••♢
|    |    |    |    [127:127] <ObjCMethodCall>
|    |    |    |    |    [127:127] <Match> = ♢[♢
|    |    |    |    |    [127:127] <ObjCSelf> = ♢self♢
|    |    |    |    |    [127:127] <Whitespace> = ♢•♢
|    |    |    |    |    [127:127] <Text> = ♢setEncoding♢
|    |    |    |    |    [127:127] <Colon> = ♢:♢
|    |    |    |    |    [127:127] <Text> = ♢encoding♢
|    |    |    |    |    [127:127] <Match> = ♢]♢
|    |    |    |    [127:127] <Semicolon> = ♢;♢
|    |    |    |    [127:128] <Newline> = ♢¶♢
|    |    |    |    [128:128] <Indenting> = ♢••••♢
|    |    |    |    [128:129] <Newline> = ♢¶♢
|    |    |    |    [129:129] <Indenting> = ♢••••♢
|    |    |    |    [129:129] <CPPComment> = ♢//•Check•type•to•see•if•we•should•load•the•document•as•plain.•Note•that•this•check•isn't•always•conclusive,•which•is•why•we•do•another•check•below,•after•the•document•has•been•loaded•(and•correctly•categorized).♢
|    |    |    |    [129:130] <Newline> = ♢¶♢
|    |    |    |    [130:130] <Indenting> = ♢••••♢
|    |    |    |    [130:130] <Text> = ♢NSWorkspace♢
|    |    |    |    [130:130] <Whitespace> = ♢•♢
|    |    |    |    [130:130] <Asterisk> = ♢*♢
|    |    |    |    [130:130] <Text> = ♢workspace♢
|    |    |    |    [130:130] <Whitespace> = ♢•♢
|    |    |    |    [130:130] <Text> = ♢=♢
|    |    |    |    [130:130] <Whitespace> = ♢•♢
|    |    |    |    [130:130] <ObjCMethodCall>
|    |    |    |    |    [130:130] <Match> = ♢[♢
|    |    |    |    |    [130:130] <Match> = ♢NSWorkspace♢
|    |    |    |    |    [130:130] <Whitespace> = ♢•♢
|    |    |    |    |    [130:130] <Text> = ♢sharedWorkspace♢
|    |    |    |    |    [130:130] <Match> = ♢]♢
|    |    |    |    [130:130] <Semicolon> = ♢;♢
|    |    |    |    [130:131] <Newline> = ♢¶♢
|    |    |    |    [131:131] <Indenting> = ♢••••♢
|    |    |    |    [131:135] <CConditionIf>
|    |    |    |    |    [131:131] <Match> = ♢if♢
|    |    |    |    |    [131:131] <Whitespace> = ♢•♢
|    |    |    |    |    [131:131] <Parenthesis>
|    |    |    |    |    |    [131:131] <Match> = ♢(♢
|    |    |    |    |    |    [131:131] <Parenthesis>
|    |    |    |    |    |    |    [131:131] <Match> = ♢(♢
|    |    |    |    |    |    |    [131:131] <Text> = ♢ignoreRTF♢
|    |    |    |    |    |    |    [131:131] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [131:131] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    [131:131] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    [131:131] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [131:131] <Parenthesis>
|    |    |    |    |    |    |    |    [131:131] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [131:131] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [131:131] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [131:131] <Match> = ♢workspace♢
|    |    |    |    |    |    |    |    |    [131:131] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [131:131] <Text> = ♢type♢
|    |    |    |    |    |    |    |    |    [131:131] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [131:131] <Text> = ♢typeName♢
|    |    |    |    |    |    |    |    |    [131:131] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [131:131] <Text> = ♢conformsToType♢
|    |    |    |    |    |    |    |    |    [131:131] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [131:131] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [131:131] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [131:131] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    |    |    [131:131] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [131:131] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    |    |    [131:131] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [131:131] <Text> = ♢kUTTypeRTF♢
|    |    |    |    |    |    |    |    |    [131:131] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [131:131] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [131:131] <Text> = ♢||♢
|    |    |    |    |    |    |    |    [131:131] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [131:131] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [131:131] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [131:131] <Match> = ♢workspace♢
|    |    |    |    |    |    |    |    |    [131:131] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [131:131] <Text> = ♢type♢
|    |    |    |    |    |    |    |    |    [131:131] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [131:131] <Text> = ♢typeName♢
|    |    |    |    |    |    |    |    |    [131:131] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [131:131] <Text> = ♢conformsToType♢
|    |    |    |    |    |    |    |    |    [131:131] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [131:131] <Text> = ♢Word2003XMLType♢
|    |    |    |    |    |    |    |    |    [131:131] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [131:131] <Match> = ♢)♢
|    |    |    |    |    |    |    [131:131] <Match> = ♢)♢
|    |    |    |    |    |    [131:131] <Whitespace> = ♢•♢
|    |    |    |    |    |    [131:131] <Text> = ♢||♢
|    |    |    |    |    |    [131:131] <Whitespace> = ♢•♢
|    |    |    |    |    |    [131:131] <Parenthesis>
|    |    |    |    |    |    |    [131:131] <Match> = ♢(♢
|    |    |    |    |    |    |    [131:131] <Text> = ♢ignoreHTML♢
|    |    |    |    |    |    |    [131:131] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [131:131] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    [131:131] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    [131:131] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [131:131] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [131:131] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [131:131] <Match> = ♢workspace♢
|    |    |    |    |    |    |    |    [131:131] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [131:131] <Text> = ♢type♢
|    |    |    |    |    |    |    |    [131:131] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [131:131] <Text> = ♢typeName♢
|    |    |    |    |    |    |    |    [131:131] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [131:131] <Text> = ♢conformsToType♢
|    |    |    |    |    |    |    |    [131:131] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [131:131] <Parenthesis>
|    |    |    |    |    |    |    |    |    [131:131] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    [131:131] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    |    [131:131] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [131:131] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    |    [131:131] <Match> = ♢)♢
|    |    |    |    |    |    |    |    [131:131] <Text> = ♢kUTTypeHTML♢
|    |    |    |    |    |    |    |    [131:131] <Match> = ♢]♢
|    |    |    |    |    |    |    [131:131] <Match> = ♢)♢
|    |    |    |    |    |    [131:131] <Whitespace> = ♢•♢
|    |    |    |    |    |    [131:131] <Text> = ♢||♢
|    |    |    |    |    |    [131:131] <Whitespace> = ♢•♢
|    |    |    |    |    |    [131:131] <ObjCMethodCall>
|    |    |    |    |    |    |    [131:131] <Match> = ♢[♢
|    |    |    |    |    |    |    [131:131] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [131:131] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [131:131] <Text> = ♢isOpenedIgnoringRichText♢
|    |    |    |    |    |    |    [131:131] <Match> = ♢]♢
|    |    |    |    |    |    [131:131] <Match> = ♢)♢
|    |    |    |    |    [131:131] <Whitespace> = ♢•♢
|    |    |    |    |    [131:135] <Braces>
|    |    |    |    |    |    [131:131] <Match> = ♢{♢
|    |    |    |    |    |    [131:132] <Newline> = ♢¶♢
|    |    |    |    |    |    [132:132] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [132:132] <ObjCMethodCall>
|    |    |    |    |    |    |    [132:132] <Match> = ♢[♢
|    |    |    |    |    |    |    [132:132] <Match> = ♢options♢
|    |    |    |    |    |    |    [132:132] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [132:132] <Text> = ♢setObject♢
|    |    |    |    |    |    |    [132:132] <Colon> = ♢:♢
|    |    |    |    |    |    |    [132:132] <Text> = ♢NSPlainTextDocumentType♢
|    |    |    |    |    |    |    [132:132] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [132:132] <Text> = ♢forKey♢
|    |    |    |    |    |    |    [132:132] <Colon> = ♢:♢
|    |    |    |    |    |    |    [132:132] <Text> = ♢NSDocumentTypeDocumentOption♢
|    |    |    |    |    |    |    [132:132] <Match> = ♢]♢
|    |    |    |    |    |    [132:132] <Semicolon> = ♢;♢
|    |    |    |    |    |    [132:132] <Whitespace> = ♢•♢
|    |    |    |    |    |    [132:132] <CPPComment> = ♢//•Force•plain♢
|    |    |    |    |    |    [132:133] <Newline> = ♢¶♢
|    |    |    |    |    |    [133:133] <Indenting> = ♢→♢
|    |    |    |    |    |    [133:133] <ObjCMethodCall>
|    |    |    |    |    |    |    [133:133] <Match> = ♢[♢
|    |    |    |    |    |    |    [133:133] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [133:133] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [133:133] <Text> = ♢setFileType♢
|    |    |    |    |    |    |    [133:133] <Colon> = ♢:♢
|    |    |    |    |    |    |    [133:133] <Parenthesis>
|    |    |    |    |    |    |    |    [133:133] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [133:133] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    [133:133] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [133:133] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [133:133] <Match> = ♢)♢
|    |    |    |    |    |    |    [133:133] <Text> = ♢kUTTypePlainText♢
|    |    |    |    |    |    |    [133:133] <Match> = ♢]♢
|    |    |    |    |    |    [133:133] <Semicolon> = ♢;♢
|    |    |    |    |    |    [133:134] <Newline> = ♢¶♢
|    |    |    |    |    |    [134:134] <Indenting> = ♢→♢
|    |    |    |    |    |    [134:134] <ObjCMethodCall>
|    |    |    |    |    |    |    [134:134] <Match> = ♢[♢
|    |    |    |    |    |    |    [134:134] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [134:134] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [134:134] <Text> = ♢setOpenedIgnoringRichText♢
|    |    |    |    |    |    |    [134:134] <Colon> = ♢:♢
|    |    |    |    |    |    |    [134:134] <Text> = ♢YES♢
|    |    |    |    |    |    |    [134:134] <Match> = ♢]♢
|    |    |    |    |    |    [134:134] <Semicolon> = ♢;♢
|    |    |    |    |    |    [134:135] <Newline> = ♢¶♢
|    |    |    |    |    |    [135:135] <Indenting> = ♢••••♢
|    |    |    |    |    |    [135:135] <Match> = ♢}♢
|    |    |    |    [135:136] <Newline> = ♢¶♢
|    |    |    |    [136:136] <Indenting> = ♢••••♢
|    |    |    |    [136:137] <Newline> = ♢¶♢
|    |    |    |    [137:137] <Indenting> = ♢••••♢
|    |    |    |    [137:137] <ObjCMethodCall>
|    |    |    |    |    [137:137] <Match> = ♢[♢
|    |    |    |    |    [137:137] <ObjCMethodCall>
|    |    |    |    |    |    [137:137] <Match> = ♢[♢
|    |    |    |    |    |    [137:137] <Match> = ♢text♢
|    |    |    |    |    |    [137:137] <Whitespace> = ♢•♢
|    |    |    |    |    |    [137:137] <Text> = ♢mutableString♢
|    |    |    |    |    |    [137:137] <Match> = ♢]♢
|    |    |    |    |    [137:137] <Whitespace> = ♢•♢
|    |    |    |    |    [137:137] <Text> = ♢setString♢
|    |    |    |    |    [137:137] <Colon> = ♢:♢
|    |    |    |    |    [137:137] <ObjCString> = ♢@""♢
|    |    |    |    |    [137:137] <Match> = ♢]♢
|    |    |    |    [137:137] <Semicolon> = ♢;♢
|    |    |    |    [137:138] <Newline> = ♢¶♢
|    |    |    |    [138:138] <Indenting> = ♢••••♢
|    |    |    |    [138:138] <CPPComment> = ♢//•Remove•the•layout•managers•while•loading•the•text;•mutableCopy•retains•the•array•so•the•layout•managers•aren't•released♢
|    |    |    |    [138:139] <Newline> = ♢¶♢
|    |    |    |    [139:139] <Indenting> = ♢••••♢
|    |    |    |    [139:139] <Text> = ♢NSMutableArray♢
|    |    |    |    [139:139] <Whitespace> = ♢•♢
|    |    |    |    [139:139] <Asterisk> = ♢*♢
|    |    |    |    [139:139] <Text> = ♢layoutMgrs♢
|    |    |    |    [139:139] <Whitespace> = ♢•♢
|    |    |    |    [139:139] <Text> = ♢=♢
|    |    |    |    [139:139] <Whitespace> = ♢•♢
|    |    |    |    [139:139] <ObjCMethodCall>
|    |    |    |    |    [139:139] <Match> = ♢[♢
|    |    |    |    |    [139:139] <ObjCMethodCall>
|    |    |    |    |    |    [139:139] <Match> = ♢[♢
|    |    |    |    |    |    [139:139] <Match> = ♢text♢
|    |    |    |    |    |    [139:139] <Whitespace> = ♢•♢
|    |    |    |    |    |    [139:139] <Text> = ♢layoutManagers♢
|    |    |    |    |    |    [139:139] <Match> = ♢]♢
|    |    |    |    |    [139:139] <Whitespace> = ♢•♢
|    |    |    |    |    [139:139] <Text> = ♢mutableCopy♢
|    |    |    |    |    [139:139] <Match> = ♢]♢
|    |    |    |    [139:139] <Semicolon> = ♢;♢
|    |    |    |    [139:140] <Newline> = ♢¶♢
|    |    |    |    [140:140] <Indenting> = ♢••••♢
|    |    |    |    [140:140] <Text> = ♢NSEnumerator♢
|    |    |    |    [140:140] <Whitespace> = ♢•♢
|    |    |    |    [140:140] <Asterisk> = ♢*♢
|    |    |    |    [140:140] <Text> = ♢layoutMgrEnum♢
|    |    |    |    [140:140] <Whitespace> = ♢•♢
|    |    |    |    [140:140] <Text> = ♢=♢
|    |    |    |    [140:140] <Whitespace> = ♢•♢
|    |    |    |    [140:140] <ObjCMethodCall>
|    |    |    |    |    [140:140] <Match> = ♢[♢
|    |    |    |    |    [140:140] <Match> = ♢layoutMgrs♢
|    |    |    |    |    [140:140] <Whitespace> = ♢•♢
|    |    |    |    |    [140:140] <Text> = ♢objectEnumerator♢
|    |    |    |    |    [140:140] <Match> = ♢]♢
|    |    |    |    [140:140] <Semicolon> = ♢;♢
|    |    |    |    [140:141] <Newline> = ♢¶♢
|    |    |    |    [141:141] <Indenting> = ♢••••♢
|    |    |    |    [141:141] <Text> = ♢NSLayoutManager♢
|    |    |    |    [141:141] <Whitespace> = ♢•♢
|    |    |    |    [141:141] <Asterisk> = ♢*♢
|    |    |    |    [141:141] <Text> = ♢layoutMgr♢
|    |    |    |    [141:141] <Whitespace> = ♢•♢
|    |    |    |    [141:141] <Text> = ♢=♢
|    |    |    |    [141:141] <Whitespace> = ♢•♢
|    |    |    |    [141:141] <ObjCNil> = ♢nil♢
|    |    |    |    [141:141] <Semicolon> = ♢;♢
|    |    |    |    [141:142] <Newline> = ♢¶♢
|    |    |    |    [142:142] <Indenting> = ♢••••♢
|    |    |    |    [142:142] <CFlowWhile> = ♢while♢
|    |    |    |    [142:142] <Whitespace> = ♢•♢
|    |    |    |    [142:142] <Parenthesis>
|    |    |    |    |    [142:142] <Match> = ♢(♢
|    |    |    |    |    [142:142] <Text> = ♢layoutMgr♢
|    |    |    |    |    [142:142] <Whitespace> = ♢•♢
|    |    |    |    |    [142:142] <Text> = ♢=♢
|    |    |    |    |    [142:142] <Whitespace> = ♢•♢
|    |    |    |    |    [142:142] <ObjCMethodCall>
|    |    |    |    |    |    [142:142] <Match> = ♢[♢
|    |    |    |    |    |    [142:142] <Match> = ♢layoutMgrEnum♢
|    |    |    |    |    |    [142:142] <Whitespace> = ♢•♢
|    |    |    |    |    |    [142:142] <Text> = ♢nextObject♢
|    |    |    |    |    |    [142:142] <Match> = ♢]♢
|    |    |    |    |    [142:142] <Match> = ♢)♢
|    |    |    |    [142:142] <Whitespace> = ♢•♢
|    |    |    |    [142:142] <ObjCMethodCall>
|    |    |    |    |    [142:142] <Match> = ♢[♢
|    |    |    |    |    [142:142] <Match> = ♢text♢
|    |    |    |    |    [142:142] <Whitespace> = ♢•♢
|    |    |    |    |    [142:142] <Text> = ♢removeLayoutManager♢
|    |    |    |    |    [142:142] <Colon> = ♢:♢
|    |    |    |    |    [142:142] <Text> = ♢layoutMgr♢
|    |    |    |    |    [142:142] <Match> = ♢]♢
|    |    |    |    [142:142] <Semicolon> = ♢;♢
|    |    |    |    [142:143] <Newline> = ♢¶♢
|    |    |    |    [143:143] <Indenting> = ♢••••♢
|    |    |    |    [143:144] <Newline> = ♢¶♢
|    |    |    |    [144:144] <Indenting> = ♢••••♢
|    |    |    |    [144:144] <CPPComment> = ♢//•We•can•do•this•loop•twice,•if•the•document•is•loaded•as•rich•text•although•the•user•requested•plain♢
|    |    |    |    [144:145] <Newline> = ♢¶♢
|    |    |    |    [145:145] <Indenting> = ♢••••♢
|    |    |    |    [145:145] <Text> = ♢BOOL♢
|    |    |    |    [145:145] <Whitespace> = ♢•♢
|    |    |    |    [145:145] <Text> = ♢retry♢
|    |    |    |    [145:145] <Semicolon> = ♢;♢
|    |    |    |    [145:146] <Newline> = ♢¶♢
|    |    |    |    [146:146] <Indenting> = ♢••••♢
|    |    |    |    [146:183] <CFlowDoWhile>
|    |    |    |    |    [146:146] <Match> = ♢do♢
|    |    |    |    |    [146:146] <Whitespace> = ♢•♢
|    |    |    |    |    [146:183] <Braces>
|    |    |    |    |    |    [146:146] <Match> = ♢{♢
|    |    |    |    |    |    [146:147] <Newline> = ♢¶♢
|    |    |    |    |    |    [147:147] <Indenting> = ♢→♢
|    |    |    |    |    |    [147:147] <Text> = ♢BOOL♢
|    |    |    |    |    |    [147:147] <Whitespace> = ♢•♢
|    |    |    |    |    |    [147:147] <Text> = ♢success♢
|    |    |    |    |    |    [147:147] <Semicolon> = ♢;♢
|    |    |    |    |    |    [147:148] <Newline> = ♢¶♢
|    |    |    |    |    |    [148:148] <Indenting> = ♢→♢
|    |    |    |    |    |    [148:148] <Text> = ♢NSString♢
|    |    |    |    |    |    [148:148] <Whitespace> = ♢•♢
|    |    |    |    |    |    [148:148] <Asterisk> = ♢*♢
|    |    |    |    |    |    [148:148] <Text> = ♢docType♢
|    |    |    |    |    |    [148:148] <Semicolon> = ♢;♢
|    |    |    |    |    |    [148:149] <Newline> = ♢¶♢
|    |    |    |    |    |    [149:149] <Indenting> = ♢→♢
|    |    |    |    |    |    [149:150] <Newline> = ♢¶♢
|    |    |    |    |    |    [150:150] <Indenting> = ♢→♢
|    |    |    |    |    |    [150:150] <Text> = ♢retry♢
|    |    |    |    |    |    [150:150] <Whitespace> = ♢•♢
|    |    |    |    |    |    [150:150] <Text> = ♢=♢
|    |    |    |    |    |    [150:150] <Whitespace> = ♢•♢
|    |    |    |    |    |    [150:150] <Text> = ♢NO♢
|    |    |    |    |    |    [150:150] <Semicolon> = ♢;♢
|    |    |    |    |    |    [150:151] <Newline> = ♢¶♢
|    |    |    |    |    |    [151:152] <Newline> = ♢¶♢
|    |    |    |    |    |    [152:152] <Indenting> = ♢→♢
|    |    |    |    |    |    [152:152] <ObjCMethodCall>
|    |    |    |    |    |    |    [152:152] <Match> = ♢[♢
|    |    |    |    |    |    |    [152:152] <Match> = ♢text♢
|    |    |    |    |    |    |    [152:152] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [152:152] <Text> = ♢beginEditing♢
|    |    |    |    |    |    |    [152:152] <Match> = ♢]♢
|    |    |    |    |    |    [152:152] <Semicolon> = ♢;♢
|    |    |    |    |    |    [152:153] <Newline> = ♢¶♢
|    |    |    |    |    |    [153:153] <Indenting> = ♢→♢
|    |    |    |    |    |    [153:153] <Text> = ♢success♢
|    |    |    |    |    |    [153:153] <Whitespace> = ♢•♢
|    |    |    |    |    |    [153:153] <Text> = ♢=♢
|    |    |    |    |    |    [153:153] <Whitespace> = ♢•♢
|    |    |    |    |    |    [153:153] <ObjCMethodCall>
|    |    |    |    |    |    |    [153:153] <Match> = ♢[♢
|    |    |    |    |    |    |    [153:153] <Match> = ♢text♢
|    |    |    |    |    |    |    [153:153] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [153:153] <Text> = ♢readFromURL♢
|    |    |    |    |    |    |    [153:153] <Colon> = ♢:♢
|    |    |    |    |    |    |    [153:153] <Text> = ♢absoluteURL♢
|    |    |    |    |    |    |    [153:153] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [153:153] <Text> = ♢options♢
|    |    |    |    |    |    |    [153:153] <Colon> = ♢:♢
|    |    |    |    |    |    |    [153:153] <Text> = ♢options♢
|    |    |    |    |    |    |    [153:153] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [153:153] <Text> = ♢documentAttributes♢
|    |    |    |    |    |    |    [153:153] <Colon> = ♢:♢
|    |    |    |    |    |    |    [153:153] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    [153:153] <Text> = ♢docAttrs♢
|    |    |    |    |    |    |    [153:153] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [153:153] <Text> = ♢error♢
|    |    |    |    |    |    |    [153:153] <Colon> = ♢:♢
|    |    |    |    |    |    |    [153:153] <Text> = ♢outError♢
|    |    |    |    |    |    |    [153:153] <Match> = ♢]♢
|    |    |    |    |    |    [153:153] <Semicolon> = ♢;♢
|    |    |    |    |    |    [153:154] <Newline> = ♢¶♢
|    |    |    |    |    |    [154:155] <Newline> = ♢¶♢
|    |    |    |    |    |    [155:155] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [155:161] <CConditionIf>
|    |    |    |    |    |    |    [155:155] <Match> = ♢if♢
|    |    |    |    |    |    |    [155:155] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [155:155] <Parenthesis>
|    |    |    |    |    |    |    |    [155:155] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [155:155] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    [155:155] <Text> = ♢success♢
|    |    |    |    |    |    |    |    [155:155] <Match> = ♢)♢
|    |    |    |    |    |    |    [155:155] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [155:161] <Braces>
|    |    |    |    |    |    |    |    [155:155] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [155:156] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [156:156] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [156:156] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [156:156] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [156:156] <Match> = ♢text♢
|    |    |    |    |    |    |    |    |    [156:156] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [156:156] <Text> = ♢endEditing♢
|    |    |    |    |    |    |    |    |    [156:156] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [156:156] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [156:157] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [157:157] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [157:157] <Text> = ♢layoutMgrEnum♢
|    |    |    |    |    |    |    |    [157:157] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [157:157] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [157:157] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [157:157] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [157:157] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [157:157] <Match> = ♢layoutMgrs♢
|    |    |    |    |    |    |    |    |    [157:157] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [157:157] <Text> = ♢objectEnumerator♢
|    |    |    |    |    |    |    |    |    [157:157] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [157:157] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [157:157] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [157:157] <CPPComment> = ♢//•rewind♢
|    |    |    |    |    |    |    |    [157:158] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [158:158] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [158:158] <CFlowWhile> = ♢while♢
|    |    |    |    |    |    |    |    [158:158] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [158:158] <Parenthesis>
|    |    |    |    |    |    |    |    |    [158:158] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    [158:158] <Text> = ♢layoutMgr♢
|    |    |    |    |    |    |    |    |    [158:158] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [158:158] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    [158:158] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [158:158] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [158:158] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [158:158] <Match> = ♢layoutMgrEnum♢
|    |    |    |    |    |    |    |    |    |    [158:158] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [158:158] <Text> = ♢nextObject♢
|    |    |    |    |    |    |    |    |    |    [158:158] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [158:158] <Match> = ♢)♢
|    |    |    |    |    |    |    |    [158:158] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [158:158] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [158:158] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [158:158] <Match> = ♢text♢
|    |    |    |    |    |    |    |    |    [158:158] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [158:158] <Text> = ♢addLayoutManager♢
|    |    |    |    |    |    |    |    |    [158:158] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [158:158] <Text> = ♢layoutMgr♢
|    |    |    |    |    |    |    |    |    [158:158] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [158:158] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [158:158] <Whitespace> = ♢•••♢
|    |    |    |    |    |    |    |    [158:158] <CPPComment> = ♢//•Add•the•layout•managers•back♢
|    |    |    |    |    |    |    |    [158:159] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [159:159] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [159:159] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [159:159] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [159:159] <Match> = ♢layoutMgrs♢
|    |    |    |    |    |    |    |    |    [159:159] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [159:159] <Text> = ♢release♢
|    |    |    |    |    |    |    |    |    [159:159] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [159:159] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [159:160] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [160:160] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [160:160] <CFlowReturn>
|    |    |    |    |    |    |    |    |    [160:160] <Match> = ♢return♢
|    |    |    |    |    |    |    |    |    [160:160] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [160:160] <Text> = ♢NO♢
|    |    |    |    |    |    |    |    |    [160:160] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [160:160] <Whitespace> = ♢→♢
|    |    |    |    |    |    |    |    [160:160] <CPPComment> = ♢//•return•NO•on•error;•outError•has•already•been•set♢
|    |    |    |    |    |    |    |    [160:161] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [161:161] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [161:161] <Match> = ♢}♢
|    |    |    |    |    |    [161:162] <Newline> = ♢¶♢
|    |    |    |    |    |    [162:162] <Indenting> = ♢→♢
|    |    |    |    |    |    [162:163] <Newline> = ♢¶♢
|    |    |    |    |    |    [163:163] <Indenting> = ♢→♢
|    |    |    |    |    |    [163:163] <Text> = ♢docType♢
|    |    |    |    |    |    [163:163] <Whitespace> = ♢•♢
|    |    |    |    |    |    [163:163] <Text> = ♢=♢
|    |    |    |    |    |    [163:163] <Whitespace> = ♢•♢
|    |    |    |    |    |    [163:163] <ObjCMethodCall>
|    |    |    |    |    |    |    [163:163] <Match> = ♢[♢
|    |    |    |    |    |    |    [163:163] <Match> = ♢docAttrs♢
|    |    |    |    |    |    |    [163:163] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [163:163] <Text> = ♢objectForKey♢
|    |    |    |    |    |    |    [163:163] <Colon> = ♢:♢
|    |    |    |    |    |    |    [163:163] <Text> = ♢NSDocumentTypeDocumentAttribute♢
|    |    |    |    |    |    |    [163:163] <Match> = ♢]♢
|    |    |    |    |    |    [163:163] <Semicolon> = ♢;♢
|    |    |    |    |    |    [163:164] <Newline> = ♢¶♢
|    |    |    |    |    |    [164:165] <Newline> = ♢¶♢
|    |    |    |    |    |    [165:165] <Indenting> = ♢→♢
|    |    |    |    |    |    [165:165] <CPPComment> = ♢//•First•check•to•see•if•the•document•was•rich•and•should•have•been•loaded•as•plain♢
|    |    |    |    |    |    [165:166] <Newline> = ♢¶♢
|    |    |    |    |    |    [166:166] <Indenting> = ♢→♢
|    |    |    |    |    |    [166:173] <CConditionIf>
|    |    |    |    |    |    |    [166:166] <Match> = ♢if♢
|    |    |    |    |    |    |    [166:166] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [166:166] <Parenthesis>
|    |    |    |    |    |    |    |    [166:166] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [166:166] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    [166:166] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [166:166] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢options♢
|    |    |    |    |    |    |    |    |    |    [166:166] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [166:166] <Text> = ♢objectForKey♢
|    |    |    |    |    |    |    |    |    |    [166:166] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [166:166] <Text> = ♢NSDocumentTypeDocumentOption♢
|    |    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [166:166] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [166:166] <Text> = ♢isEqualToString♢
|    |    |    |    |    |    |    |    |    [166:166] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [166:166] <Text> = ♢NSPlainTextDocumentType♢
|    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [166:166] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [166:166] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    [166:166] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    [166:166] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [166:166] <Parenthesis>
|    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    [166:166] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [166:166] <Text> = ♢ignoreHTML♢
|    |    |    |    |    |    |    |    |    |    [166:166] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [166:166] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    |    [166:166] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    |    [166:166] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [166:166] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢docType♢
|    |    |    |    |    |    |    |    |    |    |    [166:166] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [166:166] <Text> = ♢isEqual♢
|    |    |    |    |    |    |    |    |    |    |    [166:166] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    [166:166] <Text> = ♢NSHTMLTextDocumentType♢
|    |    |    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [166:166] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [166:166] <Text> = ♢||♢
|    |    |    |    |    |    |    |    |    [166:166] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [166:166] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [166:166] <Text> = ♢ignoreRTF♢
|    |    |    |    |    |    |    |    |    |    [166:166] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [166:166] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    |    [166:166] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    |    [166:166] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [166:166] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    [166:166] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢docType♢
|    |    |    |    |    |    |    |    |    |    |    |    [166:166] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [166:166] <Text> = ♢isEqual♢
|    |    |    |    |    |    |    |    |    |    |    |    [166:166] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    [166:166] <Text> = ♢NSRTFTextDocumentType♢
|    |    |    |    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    [166:166] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [166:166] <Text> = ♢||♢
|    |    |    |    |    |    |    |    |    |    |    [166:166] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [166:166] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢docType♢
|    |    |    |    |    |    |    |    |    |    |    |    [166:166] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [166:166] <Text> = ♢isEqual♢
|    |    |    |    |    |    |    |    |    |    |    |    [166:166] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    [166:166] <Text> = ♢NSWordMLTextDocumentType♢
|    |    |    |    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [166:166] <Match> = ♢)♢
|    |    |    |    |    |    |    |    [166:166] <Match> = ♢)♢
|    |    |    |    |    |    |    [166:166] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [166:173] <Braces>
|    |    |    |    |    |    |    |    [166:166] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [166:167] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [167:167] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [167:167] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [167:167] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [167:167] <Match> = ♢text♢
|    |    |    |    |    |    |    |    |    [167:167] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [167:167] <Text> = ♢endEditing♢
|    |    |    |    |    |    |    |    |    [167:167] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [167:167] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [167:168] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [168:168] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [168:168] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [168:168] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [168:168] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [168:168] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [168:168] <Match> = ♢text♢
|    |    |    |    |    |    |    |    |    |    [168:168] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [168:168] <Text> = ♢mutableString♢
|    |    |    |    |    |    |    |    |    |    [168:168] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [168:168] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [168:168] <Text> = ♢setString♢
|    |    |    |    |    |    |    |    |    [168:168] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [168:168] <ObjCString> = ♢@""♢
|    |    |    |    |    |    |    |    |    [168:168] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [168:168] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [168:169] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [169:169] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [169:169] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [169:169] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [169:169] <Match> = ♢options♢
|    |    |    |    |    |    |    |    |    [169:169] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [169:169] <Text> = ♢setObject♢
|    |    |    |    |    |    |    |    |    [169:169] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [169:169] <Text> = ♢NSPlainTextDocumentType♢
|    |    |    |    |    |    |    |    |    [169:169] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [169:169] <Text> = ♢forKey♢
|    |    |    |    |    |    |    |    |    [169:169] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [169:169] <Text> = ♢NSDocumentTypeDocumentOption♢
|    |    |    |    |    |    |    |    |    [169:169] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [169:169] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [169:170] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [170:170] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [170:170] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [170:170] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [170:170] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    [170:170] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [170:170] <Text> = ♢setFileType♢
|    |    |    |    |    |    |    |    |    [170:170] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [170:170] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [170:170] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [170:170] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    |    |    [170:170] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [170:170] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    |    |    [170:170] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [170:170] <Text> = ♢kUTTypePlainText♢
|    |    |    |    |    |    |    |    |    [170:170] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [170:170] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [170:171] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [171:171] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [171:171] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [171:171] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [171:171] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    [171:171] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [171:171] <Text> = ♢setOpenedIgnoringRichText♢
|    |    |    |    |    |    |    |    |    [171:171] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [171:171] <Text> = ♢YES♢
|    |    |    |    |    |    |    |    |    [171:171] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [171:171] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [171:172] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [172:172] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [172:172] <Text> = ♢retry♢
|    |    |    |    |    |    |    |    [172:172] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [172:172] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [172:172] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [172:172] <Text> = ♢YES♢
|    |    |    |    |    |    |    |    [172:172] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [172:173] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [173:173] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [173:173] <Match> = ♢}♢
|    |    |    |    |    |    [173:173] <Whitespace> = ♢•♢
|    |    |    |    |    |    [173:182] <CConditionElse>
|    |    |    |    |    |    |    [173:173] <Match> = ♢else♢
|    |    |    |    |    |    |    [173:173] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [173:182] <Braces>
|    |    |    |    |    |    |    |    [173:173] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [173:174] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [174:174] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [174:174] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    [174:174] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [174:174] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [174:174] <Text> = ♢newFileType♢
|    |    |    |    |    |    |    |    [174:174] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [174:174] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [174:174] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [174:174] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [174:174] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [174:174] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [174:174] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [174:174] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    [174:174] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [174:174] <Text> = ♢textDocumentTypeToTextEditDocumentTypeMappingTable♢
|    |    |    |    |    |    |    |    |    |    [174:174] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [174:174] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [174:174] <Text> = ♢objectForKey♢
|    |    |    |    |    |    |    |    |    [174:174] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [174:174] <Text> = ♢docType♢
|    |    |    |    |    |    |    |    |    [174:174] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [174:174] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [174:175] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [175:175] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [175:177] <CConditionIf>
|    |    |    |    |    |    |    |    |    [175:175] <Match> = ♢if♢
|    |    |    |    |    |    |    |    |    [175:175] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [175:175] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [175:175] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [175:175] <Text> = ♢newFileType♢
|    |    |    |    |    |    |    |    |    |    [175:175] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [175:175] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [175:177] <Braces>
|    |    |    |    |    |    |    |    |    |    [175:175] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    [175:176] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [176:176] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [176:176] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [176:176] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [176:176] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    [176:176] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [176:176] <Text> = ♢setFileType♢
|    |    |    |    |    |    |    |    |    |    |    [176:176] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    [176:176] <Text> = ♢newFileType♢
|    |    |    |    |    |    |    |    |    |    |    [176:176] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [176:176] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    [176:177] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [177:177] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    |    |    [177:177] <Match> = ♢}♢
|    |    |    |    |    |    |    |    [177:177] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [177:179] <CConditionElse>
|    |    |    |    |    |    |    |    |    [177:177] <Match> = ♢else♢
|    |    |    |    |    |    |    |    |    [177:177] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [177:179] <Braces>
|    |    |    |    |    |    |    |    |    |    [177:177] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    [177:178] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [178:178] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [178:178] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [178:178] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [178:178] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    [178:178] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [178:178] <Text> = ♢setFileType♢
|    |    |    |    |    |    |    |    |    |    |    [178:178] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    [178:178] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    [178:178] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    [178:178] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    |    |    |    |    [178:178] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [178:178] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    |    |    |    |    [178:178] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    [178:178] <Text> = ♢kUTTypeRTF♢
|    |    |    |    |    |    |    |    |    |    |    [178:178] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [178:178] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    [178:178] <Whitespace> = ♢→♢
|    |    |    |    |    |    |    |    |    |    [178:178] <CPPComment> = ♢//•Hmm,•a•new•type•in•the•Cocoa•text•system.•Treat•it•as•rich.•???•Should•set•the•converted•flag•too?♢
|    |    |    |    |    |    |    |    |    |    [178:179] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [179:179] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    |    |    [179:179] <Match> = ♢}♢
|    |    |    |    |    |    |    |    [179:180] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [180:180] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [180:180] <CConditionIf>
|    |    |    |    |    |    |    |    |    [180:180] <Match> = ♢if♢
|    |    |    |    |    |    |    |    |    [180:180] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [180:180] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [180:180] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [180:180] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [180:180] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [180:180] <Match> = ♢workspace♢
|    |    |    |    |    |    |    |    |    |    |    [180:180] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [180:180] <Text> = ♢type♢
|    |    |    |    |    |    |    |    |    |    |    [180:180] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    [180:180] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    [180:180] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    [180:180] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    |    [180:180] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [180:180] <Text> = ♢fileType♢
|    |    |    |    |    |    |    |    |    |    |    |    [180:180] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    [180:180] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [180:180] <Text> = ♢conformsToType♢
|    |    |    |    |    |    |    |    |    |    |    [180:180] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    [180:180] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    [180:180] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    [180:180] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    |    |    |    |    [180:180] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [180:180] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    |    |    |    |    [180:180] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    [180:180] <Text> = ♢kUTTypePlainText♢
|    |    |    |    |    |    |    |    |    |    |    [180:180] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [180:180] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [180:180] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [180:180] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [180:180] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [180:180] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    [180:180] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [180:180] <Text> = ♢applyDefaultTextAttributes♢
|    |    |    |    |    |    |    |    |    |    [180:180] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [180:180] <Text> = ♢NO♢
|    |    |    |    |    |    |    |    |    |    [180:180] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [180:180] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [180:181] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [181:181] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [181:181] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [181:181] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [181:181] <Match> = ♢text♢
|    |    |    |    |    |    |    |    |    [181:181] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [181:181] <Text> = ♢endEditing♢
|    |    |    |    |    |    |    |    |    [181:181] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [181:181] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [181:182] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [182:182] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [182:182] <Match> = ♢}♢
|    |    |    |    |    |    [182:183] <Newline> = ♢¶♢
|    |    |    |    |    |    [183:183] <Indenting> = ♢••••♢
|    |    |    |    |    |    [183:183] <Match> = ♢}♢
|    |    |    |    |    [183:183] <Whitespace> = ♢•♢
|    |    |    |    |    [183:183] <Match> = ♢while♢
|    |    |    |    |    [183:183] <Parenthesis>
|    |    |    |    |    |    [183:183] <Match> = ♢(♢
|    |    |    |    |    |    [183:183] <Text> = ♢retry♢
|    |    |    |    |    |    [183:183] <Match> = ♢)♢
|    |    |    |    [183:183] <Semicolon> = ♢;♢
|    |    |    |    [183:184] <Newline> = ♢¶♢
|    |    |    |    [184:185] <Newline> = ♢¶♢
|    |    |    |    [185:185] <Indenting> = ♢••••♢
|    |    |    |    [185:185] <Text> = ♢layoutMgrEnum♢
|    |    |    |    [185:185] <Whitespace> = ♢•♢
|    |    |    |    [185:185] <Text> = ♢=♢
|    |    |    |    [185:185] <Whitespace> = ♢•♢
|    |    |    |    [185:185] <ObjCMethodCall>
|    |    |    |    |    [185:185] <Match> = ♢[♢
|    |    |    |    |    [185:185] <Match> = ♢layoutMgrs♢
|    |    |    |    |    [185:185] <Whitespace> = ♢•♢
|    |    |    |    |    [185:185] <Text> = ♢objectEnumerator♢
|    |    |    |    |    [185:185] <Match> = ♢]♢
|    |    |    |    [185:185] <Semicolon> = ♢;♢
|    |    |    |    [185:185] <Whitespace> = ♢•♢
|    |    |    |    [185:185] <CPPComment> = ♢//•rewind♢
|    |    |    |    [185:186] <Newline> = ♢¶♢
|    |    |    |    [186:186] <Indenting> = ♢••••♢
|    |    |    |    [186:186] <CFlowWhile> = ♢while♢
|    |    |    |    [186:186] <Whitespace> = ♢•♢
|    |    |    |    [186:186] <Parenthesis>
|    |    |    |    |    [186:186] <Match> = ♢(♢
|    |    |    |    |    [186:186] <Text> = ♢layoutMgr♢
|    |    |    |    |    [186:186] <Whitespace> = ♢•♢
|    |    |    |    |    [186:186] <Text> = ♢=♢
|    |    |    |    |    [186:186] <Whitespace> = ♢•♢
|    |    |    |    |    [186:186] <ObjCMethodCall>
|    |    |    |    |    |    [186:186] <Match> = ♢[♢
|    |    |    |    |    |    [186:186] <Match> = ♢layoutMgrEnum♢
|    |    |    |    |    |    [186:186] <Whitespace> = ♢•♢
|    |    |    |    |    |    [186:186] <Text> = ♢nextObject♢
|    |    |    |    |    |    [186:186] <Match> = ♢]♢
|    |    |    |    |    [186:186] <Match> = ♢)♢
|    |    |    |    [186:186] <Whitespace> = ♢•♢
|    |    |    |    [186:186] <ObjCMethodCall>
|    |    |    |    |    [186:186] <Match> = ♢[♢
|    |    |    |    |    [186:186] <Match> = ♢text♢
|    |    |    |    |    [186:186] <Whitespace> = ♢•♢
|    |    |    |    |    [186:186] <Text> = ♢addLayoutManager♢
|    |    |    |    |    [186:186] <Colon> = ♢:♢
|    |    |    |    |    [186:186] <Text> = ♢layoutMgr♢
|    |    |    |    |    [186:186] <Match> = ♢]♢
|    |    |    |    [186:186] <Semicolon> = ♢;♢
|    |    |    |    [186:186] <Whitespace> = ♢•••♢
|    |    |    |    [186:186] <CPPComment> = ♢//•Add•the•layout•managers•back♢
|    |    |    |    [186:187] <Newline> = ♢¶♢
|    |    |    |    [187:187] <Indenting> = ♢••••♢
|    |    |    |    [187:187] <ObjCMethodCall>
|    |    |    |    |    [187:187] <Match> = ♢[♢
|    |    |    |    |    [187:187] <Match> = ♢layoutMgrs♢
|    |    |    |    |    [187:187] <Whitespace> = ♢•♢
|    |    |    |    |    [187:187] <Text> = ♢release♢
|    |    |    |    |    [187:187] <Match> = ♢]♢
|    |    |    |    [187:187] <Semicolon> = ♢;♢
|    |    |    |    [187:188] <Newline> = ♢¶♢
|    |    |    |    [188:188] <Indenting> = ♢••••♢
|    |    |    |    [188:189] <Newline> = ♢¶♢
|    |    |    |    [189:189] <Indenting> = ♢••••♢
|    |    |    |    [189:189] <Text> = ♢val♢
|    |    |    |    [189:189] <Whitespace> = ♢•♢
|    |    |    |    [189:189] <Text> = ♢=♢
|    |    |    |    [189:189] <Whitespace> = ♢•♢
|    |    |    |    [189:189] <ObjCMethodCall>
|    |    |    |    |    [189:189] <Match> = ♢[♢
|    |    |    |    |    [189:189] <Match> = ♢docAttrs♢
|    |    |    |    |    [189:189] <Whitespace> = ♢•♢
|    |    |    |    |    [189:189] <Text> = ♢objectForKey♢
|    |    |    |    |    [189:189] <Colon> = ♢:♢
|    |    |    |    |    [189:189] <Text> = ♢NSCharacterEncodingDocumentAttribute♢
|    |    |    |    |    [189:189] <Match> = ♢]♢
|    |    |    |    [189:189] <Semicolon> = ♢;♢
|    |    |    |    [189:190] <Newline> = ♢¶♢
|    |    |    |    [190:190] <Indenting> = ♢••••♢
|    |    |    |    [190:190] <ObjCMethodCall>
|    |    |    |    |    [190:190] <Match> = ♢[♢
|    |    |    |    |    [190:190] <ObjCSelf> = ♢self♢
|    |    |    |    |    [190:190] <Whitespace> = ♢•♢
|    |    |    |    |    [190:190] <Text> = ♢setEncoding♢
|    |    |    |    |    [190:190] <Colon> = ♢:♢
|    |    |    |    |    [190:190] <Parenthesis>
|    |    |    |    |    |    [190:190] <Match> = ♢(♢
|    |    |    |    |    |    [190:190] <Text> = ♢val♢
|    |    |    |    |    |    [190:190] <Whitespace> = ♢•♢
|    |    |    |    |    |    [190:190] <QuestionMark> = ♢?♢
|    |    |    |    |    |    [190:190] <Whitespace> = ♢•♢
|    |    |    |    |    |    [190:190] <ObjCMethodCall>
|    |    |    |    |    |    |    [190:190] <Match> = ♢[♢
|    |    |    |    |    |    |    [190:190] <Match> = ♢val♢
|    |    |    |    |    |    |    [190:190] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [190:190] <Text> = ♢unsignedIntegerValue♢
|    |    |    |    |    |    |    [190:190] <Match> = ♢]♢
|    |    |    |    |    |    [190:190] <Whitespace> = ♢•♢
|    |    |    |    |    |    [190:190] <Colon> = ♢:♢
|    |    |    |    |    |    [190:190] <Whitespace> = ♢•♢
|    |    |    |    |    |    [190:190] <Text> = ♢NoStringEncoding♢
|    |    |    |    |    |    [190:190] <Match> = ♢)♢
|    |    |    |    |    [190:190] <Match> = ♢]♢
|    |    |    |    [190:190] <Semicolon> = ♢;♢
|    |    |    |    [190:191] <Newline> = ♢¶♢
|    |    |    |    [191:191] <Indenting> = ♢••••♢
|    |    |    |    [191:192] <Newline> = ♢¶♢
|    |    |    |    [192:192] <Indenting> = ♢••••♢
|    |    |    |    [192:195] <CConditionIf>
|    |    |    |    |    [192:192] <Match> = ♢if♢
|    |    |    |    |    [192:192] <Whitespace> = ♢•♢
|    |    |    |    |    [192:192] <Parenthesis>
|    |    |    |    |    |    [192:192] <Match> = ♢(♢
|    |    |    |    |    |    [192:192] <Text> = ♢val♢
|    |    |    |    |    |    [192:192] <Whitespace> = ♢•♢
|    |    |    |    |    |    [192:192] <Text> = ♢=♢
|    |    |    |    |    |    [192:192] <Whitespace> = ♢•♢
|    |    |    |    |    |    [192:192] <ObjCMethodCall>
|    |    |    |    |    |    |    [192:192] <Match> = ♢[♢
|    |    |    |    |    |    |    [192:192] <Match> = ♢docAttrs♢
|    |    |    |    |    |    |    [192:192] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [192:192] <Text> = ♢objectForKey♢
|    |    |    |    |    |    |    [192:192] <Colon> = ♢:♢
|    |    |    |    |    |    |    [192:192] <Text> = ♢NSConvertedDocumentAttribute♢
|    |    |    |    |    |    |    [192:192] <Match> = ♢]♢
|    |    |    |    |    |    [192:192] <Match> = ♢)♢
|    |    |    |    |    [192:192] <Whitespace> = ♢•♢
|    |    |    |    |    [192:195] <Braces>
|    |    |    |    |    |    [192:192] <Match> = ♢{♢
|    |    |    |    |    |    [192:193] <Newline> = ♢¶♢
|    |    |    |    |    |    [193:193] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [193:193] <ObjCMethodCall>
|    |    |    |    |    |    |    [193:193] <Match> = ♢[♢
|    |    |    |    |    |    |    [193:193] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [193:193] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [193:193] <Text> = ♢setConverted♢
|    |    |    |    |    |    |    [193:193] <Colon> = ♢:♢
|    |    |    |    |    |    |    [193:193] <Parenthesis>
|    |    |    |    |    |    |    |    [193:193] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [193:193] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [193:193] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [193:193] <Match> = ♢val♢
|    |    |    |    |    |    |    |    |    [193:193] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [193:193] <Text> = ♢integerValue♢
|    |    |    |    |    |    |    |    |    [193:193] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [193:193] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [193:193] <Text> = ♢>♢
|    |    |    |    |    |    |    |    [193:193] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [193:193] <Text> = ♢0♢
|    |    |    |    |    |    |    |    [193:193] <Match> = ♢)♢
|    |    |    |    |    |    |    [193:193] <Match> = ♢]♢
|    |    |    |    |    |    [193:193] <Semicolon> = ♢;♢
|    |    |    |    |    |    [193:193] <Whitespace> = ♢→♢
|    |    |    |    |    |    [193:193] <CPPComment> = ♢//•Indicates•filtered♢
|    |    |    |    |    |    [193:194] <Newline> = ♢¶♢
|    |    |    |    |    |    [194:194] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [194:194] <ObjCMethodCall>
|    |    |    |    |    |    |    [194:194] <Match> = ♢[♢
|    |    |    |    |    |    |    [194:194] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [194:194] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [194:194] <Text> = ♢setLossy♢
|    |    |    |    |    |    |    [194:194] <Colon> = ♢:♢
|    |    |    |    |    |    |    [194:194] <Parenthesis>
|    |    |    |    |    |    |    |    [194:194] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [194:194] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [194:194] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [194:194] <Match> = ♢val♢
|    |    |    |    |    |    |    |    |    [194:194] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [194:194] <Text> = ♢integerValue♢
|    |    |    |    |    |    |    |    |    [194:194] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [194:194] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [194:194] <Text> = ♢<♢
|    |    |    |    |    |    |    |    [194:194] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [194:194] <Text> = ♢0♢
|    |    |    |    |    |    |    |    [194:194] <Match> = ♢)♢
|    |    |    |    |    |    |    [194:194] <Match> = ♢]♢
|    |    |    |    |    |    [194:194] <Semicolon> = ♢;♢
|    |    |    |    |    |    [194:194] <Whitespace> = ♢→♢
|    |    |    |    |    |    [194:194] <CPPComment> = ♢//•Indicates•lossily•loaded♢
|    |    |    |    |    |    [194:195] <Newline> = ♢¶♢
|    |    |    |    |    |    [195:195] <Indenting> = ♢••••♢
|    |    |    |    |    |    [195:195] <Match> = ♢}♢
|    |    |    |    [195:196] <Newline> = ♢¶♢
|    |    |    |    [196:196] <Indenting> = ♢••••♢
|    |    |    |    [196:197] <Newline> = ♢¶♢
|    |    |    |    [197:197] <Indenting> = ♢••••♢
|    |    |    |    [197:197] <CComment> = ♢/*•If•the•document•has•a•stored•value•for•view•mode,•use•it.•Otherwise•wrap•to•window.•*/♢
|    |    |    |    [197:198] <Newline> = ♢¶♢
|    |    |    |    [198:198] <Indenting> = ♢••••♢
|    |    |    |    [198:203] <CConditionIf>
|    |    |    |    |    [198:198] <Match> = ♢if♢
|    |    |    |    |    [198:198] <Whitespace> = ♢•♢
|    |    |    |    |    [198:198] <Parenthesis>
|    |    |    |    |    |    [198:198] <Match> = ♢(♢
|    |    |    |    |    |    [198:198] <Parenthesis>
|    |    |    |    |    |    |    [198:198] <Match> = ♢(♢
|    |    |    |    |    |    |    [198:198] <Text> = ♢val♢
|    |    |    |    |    |    |    [198:198] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [198:198] <Text> = ♢=♢
|    |    |    |    |    |    |    [198:198] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [198:198] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [198:198] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [198:198] <Match> = ♢docAttrs♢
|    |    |    |    |    |    |    |    [198:198] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [198:198] <Text> = ♢objectForKey♢
|    |    |    |    |    |    |    |    [198:198] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [198:198] <Text> = ♢NSViewModeDocumentAttribute♢
|    |    |    |    |    |    |    |    [198:198] <Match> = ♢]♢
|    |    |    |    |    |    |    [198:198] <Match> = ♢)♢
|    |    |    |    |    |    [198:198] <Match> = ♢)♢
|    |    |    |    |    [198:198] <Whitespace> = ♢•♢
|    |    |    |    |    [198:203] <Braces>
|    |    |    |    |    |    [198:198] <Match> = ♢{♢
|    |    |    |    |    |    [198:199] <Newline> = ♢¶♢
|    |    |    |    |    |    [199:199] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [199:199] <ObjCMethodCall>
|    |    |    |    |    |    |    [199:199] <Match> = ♢[♢
|    |    |    |    |    |    |    [199:199] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [199:199] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [199:199] <Text> = ♢setHasMultiplePages♢
|    |    |    |    |    |    |    [199:199] <Colon> = ♢:♢
|    |    |    |    |    |    |    [199:199] <Parenthesis>
|    |    |    |    |    |    |    |    [199:199] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [199:199] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [199:199] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [199:199] <Match> = ♢val♢
|    |    |    |    |    |    |    |    |    [199:199] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [199:199] <Text> = ♢integerValue♢
|    |    |    |    |    |    |    |    |    [199:199] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [199:199] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [199:199] <Text> = ♢==♢
|    |    |    |    |    |    |    |    [199:199] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [199:199] <Text> = ♢1♢
|    |    |    |    |    |    |    |    [199:199] <Match> = ♢)♢
|    |    |    |    |    |    |    [199:199] <Match> = ♢]♢
|    |    |    |    |    |    [199:199] <Semicolon> = ♢;♢
|    |    |    |    |    |    [199:200] <Newline> = ♢¶♢
|    |    |    |    |    |    [200:200] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [200:202] <CConditionIf>
|    |    |    |    |    |    |    [200:200] <Match> = ♢if♢
|    |    |    |    |    |    |    [200:200] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [200:200] <Parenthesis>
|    |    |    |    |    |    |    |    [200:200] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [200:200] <Parenthesis>
|    |    |    |    |    |    |    |    |    [200:200] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    [200:200] <Text> = ♢val♢
|    |    |    |    |    |    |    |    |    [200:200] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [200:200] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    [200:200] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [200:200] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [200:200] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [200:200] <Match> = ♢docAttrs♢
|    |    |    |    |    |    |    |    |    |    [200:200] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [200:200] <Text> = ♢objectForKey♢
|    |    |    |    |    |    |    |    |    |    [200:200] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [200:200] <Text> = ♢NSViewZoomDocumentAttribute♢
|    |    |    |    |    |    |    |    |    |    [200:200] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [200:200] <Match> = ♢)♢
|    |    |    |    |    |    |    |    [200:200] <Match> = ♢)♢
|    |    |    |    |    |    |    [200:200] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [200:202] <Braces>
|    |    |    |    |    |    |    |    [200:200] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [200:201] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [201:201] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [201:201] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [201:201] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [201:201] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    [201:201] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [201:201] <Text> = ♢setScaleFactor♢
|    |    |    |    |    |    |    |    |    [201:201] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [201:201] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [201:201] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [201:201] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [201:201] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [201:201] <Match> = ♢val♢
|    |    |    |    |    |    |    |    |    |    |    [201:201] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [201:201] <Text> = ♢doubleValue♢
|    |    |    |    |    |    |    |    |    |    |    [201:201] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [201:201] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [201:201] <Text> = ♢/♢
|    |    |    |    |    |    |    |    |    |    [201:201] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [201:201] <Text> = ♢100.0♢
|    |    |    |    |    |    |    |    |    |    [201:201] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [201:201] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [201:201] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [201:202] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [202:202] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    |    |    [202:202] <Match> = ♢}♢
|    |    |    |    |    |    [202:203] <Newline> = ♢¶♢
|    |    |    |    |    |    [203:203] <Indenting> = ♢••••♢
|    |    |    |    |    |    [203:203] <Match> = ♢}♢
|    |    |    |    [203:203] <Whitespace> = ♢•♢
|    |    |    |    [203:203] <CConditionElse>
|    |    |    |    |    [203:203] <Match> = ♢else♢
|    |    |    |    |    [203:203] <Whitespace> = ♢•♢
|    |    |    |    |    [203:203] <ObjCMethodCall>
|    |    |    |    |    |    [203:203] <Match> = ♢[♢
|    |    |    |    |    |    [203:203] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    [203:203] <Whitespace> = ♢•♢
|    |    |    |    |    |    [203:203] <Text> = ♢setHasMultiplePages♢
|    |    |    |    |    |    [203:203] <Colon> = ♢:♢
|    |    |    |    |    |    [203:203] <Text> = ♢NO♢
|    |    |    |    |    |    [203:203] <Match> = ♢]♢
|    |    |    |    |    [203:203] <Semicolon> = ♢;♢
|    |    |    |    [203:204] <Newline> = ♢¶♢
|    |    |    |    [204:204] <Indenting> = ♢••••♢
|    |    |    |    [204:205] <Newline> = ♢¶♢
|    |    |    |    [205:205] <Indenting> = ♢••••♢
|    |    |    |    [205:205] <ObjCMethodCall>
|    |    |    |    |    [205:205] <Match> = ♢[♢
|    |    |    |    |    [205:205] <ObjCSelf> = ♢self♢
|    |    |    |    |    [205:205] <Whitespace> = ♢•♢
|    |    |    |    |    [205:205] <Text> = ♢willChangeValueForKey♢
|    |    |    |    |    [205:205] <Colon> = ♢:♢
|    |    |    |    |    [205:205] <ObjCString> = ♢@"printInfo"♢
|    |    |    |    |    [205:205] <Match> = ♢]♢
|    |    |    |    [205:205] <Semicolon> = ♢;♢
|    |    |    |    [205:206] <Newline> = ♢¶♢
|    |    |    |    [206:206] <Indenting> = ♢••••♢
|    |    |    |    [206:206] <CConditionIf>
|    |    |    |    |    [206:206] <Match> = ♢if♢
|    |    |    |    |    [206:206] <Whitespace> = ♢•♢
|    |    |    |    |    [206:206] <Parenthesis>
|    |    |    |    |    |    [206:206] <Match> = ♢(♢
|    |    |    |    |    |    [206:206] <Parenthesis>
|    |    |    |    |    |    |    [206:206] <Match> = ♢(♢
|    |    |    |    |    |    |    [206:206] <Text> = ♢val♢
|    |    |    |    |    |    |    [206:206] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [206:206] <Text> = ♢=♢
|    |    |    |    |    |    |    [206:206] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [206:206] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [206:206] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [206:206] <Match> = ♢docAttrs♢
|    |    |    |    |    |    |    |    [206:206] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [206:206] <Text> = ♢objectForKey♢
|    |    |    |    |    |    |    |    [206:206] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [206:206] <Text> = ♢NSLeftMarginDocumentAttribute♢
|    |    |    |    |    |    |    |    [206:206] <Match> = ♢]♢
|    |    |    |    |    |    |    [206:206] <Match> = ♢)♢
|    |    |    |    |    |    [206:206] <Match> = ♢)♢
|    |    |    |    |    [206:206] <Whitespace> = ♢•♢
|    |    |    |    |    [206:206] <ObjCMethodCall>
|    |    |    |    |    |    [206:206] <Match> = ♢[♢
|    |    |    |    |    |    [206:206] <ObjCMethodCall>
|    |    |    |    |    |    |    [206:206] <Match> = ♢[♢
|    |    |    |    |    |    |    [206:206] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [206:206] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [206:206] <Text> = ♢printInfo♢
|    |    |    |    |    |    |    [206:206] <Match> = ♢]♢
|    |    |    |    |    |    [206:206] <Whitespace> = ♢•♢
|    |    |    |    |    |    [206:206] <Text> = ♢setLeftMargin♢
|    |    |    |    |    |    [206:206] <Colon> = ♢:♢
|    |    |    |    |    |    [206:206] <ObjCMethodCall>
|    |    |    |    |    |    |    [206:206] <Match> = ♢[♢
|    |    |    |    |    |    |    [206:206] <Match> = ♢val♢
|    |    |    |    |    |    |    [206:206] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [206:206] <Text> = ♢doubleValue♢
|    |    |    |    |    |    |    [206:206] <Match> = ♢]♢
|    |    |    |    |    |    [206:206] <Match> = ♢]♢
|    |    |    |    |    [206:206] <Semicolon> = ♢;♢
|    |    |    |    [206:207] <Newline> = ♢¶♢
|    |    |    |    [207:207] <Indenting> = ♢••••♢
|    |    |    |    [207:207] <CConditionIf>
|    |    |    |    |    [207:207] <Match> = ♢if♢
|    |    |    |    |    [207:207] <Whitespace> = ♢•♢
|    |    |    |    |    [207:207] <Parenthesis>
|    |    |    |    |    |    [207:207] <Match> = ♢(♢
|    |    |    |    |    |    [207:207] <Parenthesis>
|    |    |    |    |    |    |    [207:207] <Match> = ♢(♢
|    |    |    |    |    |    |    [207:207] <Text> = ♢val♢
|    |    |    |    |    |    |    [207:207] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [207:207] <Text> = ♢=♢
|    |    |    |    |    |    |    [207:207] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [207:207] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [207:207] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [207:207] <Match> = ♢docAttrs♢
|    |    |    |    |    |    |    |    [207:207] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [207:207] <Text> = ♢objectForKey♢
|    |    |    |    |    |    |    |    [207:207] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [207:207] <Text> = ♢NSRightMarginDocumentAttribute♢
|    |    |    |    |    |    |    |    [207:207] <Match> = ♢]♢
|    |    |    |    |    |    |    [207:207] <Match> = ♢)♢
|    |    |    |    |    |    [207:207] <Match> = ♢)♢
|    |    |    |    |    [207:207] <Whitespace> = ♢•♢
|    |    |    |    |    [207:207] <ObjCMethodCall>
|    |    |    |    |    |    [207:207] <Match> = ♢[♢
|    |    |    |    |    |    [207:207] <ObjCMethodCall>
|    |    |    |    |    |    |    [207:207] <Match> = ♢[♢
|    |    |    |    |    |    |    [207:207] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [207:207] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [207:207] <Text> = ♢printInfo♢
|    |    |    |    |    |    |    [207:207] <Match> = ♢]♢
|    |    |    |    |    |    [207:207] <Whitespace> = ♢•♢
|    |    |    |    |    |    [207:207] <Text> = ♢setRightMargin♢
|    |    |    |    |    |    [207:207] <Colon> = ♢:♢
|    |    |    |    |    |    [207:207] <ObjCMethodCall>
|    |    |    |    |    |    |    [207:207] <Match> = ♢[♢
|    |    |    |    |    |    |    [207:207] <Match> = ♢val♢
|    |    |    |    |    |    |    [207:207] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [207:207] <Text> = ♢doubleValue♢
|    |    |    |    |    |    |    [207:207] <Match> = ♢]♢
|    |    |    |    |    |    [207:207] <Match> = ♢]♢
|    |    |    |    |    [207:207] <Semicolon> = ♢;♢
|    |    |    |    [207:208] <Newline> = ♢¶♢
|    |    |    |    [208:208] <Indenting> = ♢••••♢
|    |    |    |    [208:208] <CConditionIf>
|    |    |    |    |    [208:208] <Match> = ♢if♢
|    |    |    |    |    [208:208] <Whitespace> = ♢•♢
|    |    |    |    |    [208:208] <Parenthesis>
|    |    |    |    |    |    [208:208] <Match> = ♢(♢
|    |    |    |    |    |    [208:208] <Parenthesis>
|    |    |    |    |    |    |    [208:208] <Match> = ♢(♢
|    |    |    |    |    |    |    [208:208] <Text> = ♢val♢
|    |    |    |    |    |    |    [208:208] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [208:208] <Text> = ♢=♢
|    |    |    |    |    |    |    [208:208] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [208:208] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [208:208] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [208:208] <Match> = ♢docAttrs♢
|    |    |    |    |    |    |    |    [208:208] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [208:208] <Text> = ♢objectForKey♢
|    |    |    |    |    |    |    |    [208:208] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [208:208] <Text> = ♢NSBottomMarginDocumentAttribute♢
|    |    |    |    |    |    |    |    [208:208] <Match> = ♢]♢
|    |    |    |    |    |    |    [208:208] <Match> = ♢)♢
|    |    |    |    |    |    [208:208] <Match> = ♢)♢
|    |    |    |    |    [208:208] <Whitespace> = ♢•♢
|    |    |    |    |    [208:208] <ObjCMethodCall>
|    |    |    |    |    |    [208:208] <Match> = ♢[♢
|    |    |    |    |    |    [208:208] <ObjCMethodCall>
|    |    |    |    |    |    |    [208:208] <Match> = ♢[♢
|    |    |    |    |    |    |    [208:208] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [208:208] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [208:208] <Text> = ♢printInfo♢
|    |    |    |    |    |    |    [208:208] <Match> = ♢]♢
|    |    |    |    |    |    [208:208] <Whitespace> = ♢•♢
|    |    |    |    |    |    [208:208] <Text> = ♢setBottomMargin♢
|    |    |    |    |    |    [208:208] <Colon> = ♢:♢
|    |    |    |    |    |    [208:208] <ObjCMethodCall>
|    |    |    |    |    |    |    [208:208] <Match> = ♢[♢
|    |    |    |    |    |    |    [208:208] <Match> = ♢val♢
|    |    |    |    |    |    |    [208:208] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [208:208] <Text> = ♢doubleValue♢
|    |    |    |    |    |    |    [208:208] <Match> = ♢]♢
|    |    |    |    |    |    [208:208] <Match> = ♢]♢
|    |    |    |    |    [208:208] <Semicolon> = ♢;♢
|    |    |    |    [208:209] <Newline> = ♢¶♢
|    |    |    |    [209:209] <Indenting> = ♢••••♢
|    |    |    |    [209:209] <CConditionIf>
|    |    |    |    |    [209:209] <Match> = ♢if♢
|    |    |    |    |    [209:209] <Whitespace> = ♢•♢
|    |    |    |    |    [209:209] <Parenthesis>
|    |    |    |    |    |    [209:209] <Match> = ♢(♢
|    |    |    |    |    |    [209:209] <Parenthesis>
|    |    |    |    |    |    |    [209:209] <Match> = ♢(♢
|    |    |    |    |    |    |    [209:209] <Text> = ♢val♢
|    |    |    |    |    |    |    [209:209] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [209:209] <Text> = ♢=♢
|    |    |    |    |    |    |    [209:209] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [209:209] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [209:209] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [209:209] <Match> = ♢docAttrs♢
|    |    |    |    |    |    |    |    [209:209] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [209:209] <Text> = ♢objectForKey♢
|    |    |    |    |    |    |    |    [209:209] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [209:209] <Text> = ♢NSTopMarginDocumentAttribute♢
|    |    |    |    |    |    |    |    [209:209] <Match> = ♢]♢
|    |    |    |    |    |    |    [209:209] <Match> = ♢)♢
|    |    |    |    |    |    [209:209] <Match> = ♢)♢
|    |    |    |    |    [209:209] <Whitespace> = ♢•♢
|    |    |    |    |    [209:209] <ObjCMethodCall>
|    |    |    |    |    |    [209:209] <Match> = ♢[♢
|    |    |    |    |    |    [209:209] <ObjCMethodCall>
|    |    |    |    |    |    |    [209:209] <Match> = ♢[♢
|    |    |    |    |    |    |    [209:209] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [209:209] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [209:209] <Text> = ♢printInfo♢
|    |    |    |    |    |    |    [209:209] <Match> = ♢]♢
|    |    |    |    |    |    [209:209] <Whitespace> = ♢•♢
|    |    |    |    |    |    [209:209] <Text> = ♢setTopMargin♢
|    |    |    |    |    |    [209:209] <Colon> = ♢:♢
|    |    |    |    |    |    [209:209] <ObjCMethodCall>
|    |    |    |    |    |    |    [209:209] <Match> = ♢[♢
|    |    |    |    |    |    |    [209:209] <Match> = ♢val♢
|    |    |    |    |    |    |    [209:209] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [209:209] <Text> = ♢doubleValue♢
|    |    |    |    |    |    |    [209:209] <Match> = ♢]♢
|    |    |    |    |    |    [209:209] <Match> = ♢]♢
|    |    |    |    |    [209:209] <Semicolon> = ♢;♢
|    |    |    |    [209:210] <Newline> = ♢¶♢
|    |    |    |    [210:210] <Indenting> = ♢••••♢
|    |    |    |    [210:210] <ObjCMethodCall>
|    |    |    |    |    [210:210] <Match> = ♢[♢
|    |    |    |    |    [210:210] <ObjCSelf> = ♢self♢
|    |    |    |    |    [210:210] <Whitespace> = ♢•♢
|    |    |    |    |    [210:210] <Text> = ♢didChangeValueForKey♢
|    |    |    |    |    [210:210] <Colon> = ♢:♢
|    |    |    |    |    [210:210] <ObjCString> = ♢@"printInfo"♢
|    |    |    |    |    [210:210] <Match> = ♢]♢
|    |    |    |    [210:210] <Semicolon> = ♢;♢
|    |    |    |    [210:211] <Newline> = ♢¶♢
|    |    |    |    [211:211] <Indenting> = ♢••••♢
|    |    |    |    [211:212] <Newline> = ♢¶♢
|    |    |    |    [212:212] <Indenting> = ♢••••♢
|    |    |    |    [212:213] <CComment> = ♢/*•Pre•MacOSX•versions•of•TextEdit•wrote•out•the•view•(window)•size•in•PaperSize.¶→If•we•encounter•a•non-MacOSX•RTF•file,•and•it's•written•by•TextEdit,•use•PaperSize•as•ViewSize•*/♢
|    |    |    |    [213:214] <Newline> = ♢¶♢
|    |    |    |    [214:214] <Indenting> = ♢••••♢
|    |    |    |    [214:214] <Text> = ♢viewSizeVal♢
|    |    |    |    [214:214] <Whitespace> = ♢•♢
|    |    |    |    [214:214] <Text> = ♢=♢
|    |    |    |    [214:214] <Whitespace> = ♢•♢
|    |    |    |    [214:214] <ObjCMethodCall>
|    |    |    |    |    [214:214] <Match> = ♢[♢
|    |    |    |    |    [214:214] <Match> = ♢docAttrs♢
|    |    |    |    |    [214:214] <Whitespace> = ♢•♢
|    |    |    |    |    [214:214] <Text> = ♢objectForKey♢
|    |    |    |    |    [214:214] <Colon> = ♢:♢
|    |    |    |    |    [214:214] <Text> = ♢NSViewSizeDocumentAttribute♢
|    |    |    |    |    [214:214] <Match> = ♢]♢
|    |    |    |    [214:214] <Semicolon> = ♢;♢
|    |    |    |    [214:215] <Newline> = ♢¶♢
|    |    |    |    [215:215] <Indenting> = ♢••••♢
|    |    |    |    [215:215] <Text> = ♢paperSizeVal♢
|    |    |    |    [215:215] <Whitespace> = ♢•♢
|    |    |    |    [215:215] <Text> = ♢=♢
|    |    |    |    [215:215] <Whitespace> = ♢•♢
|    |    |    |    [215:215] <ObjCMethodCall>
|    |    |    |    |    [215:215] <Match> = ♢[♢
|    |    |    |    |    [215:215] <Match> = ♢docAttrs♢
|    |    |    |    |    [215:215] <Whitespace> = ♢•♢
|    |    |    |    |    [215:215] <Text> = ♢objectForKey♢
|    |    |    |    |    [215:215] <Colon> = ♢:♢
|    |    |    |    |    [215:215] <Text> = ♢NSPaperSizeDocumentAttribute♢
|    |    |    |    |    [215:215] <Match> = ♢]♢
|    |    |    |    [215:215] <Semicolon> = ♢;♢
|    |    |    |    [215:216] <Newline> = ♢¶♢
|    |    |    |    [216:216] <Indenting> = ♢••••♢
|    |    |    |    [216:216] <CConditionIf>
|    |    |    |    |    [216:216] <Match> = ♢if♢
|    |    |    |    |    [216:216] <Whitespace> = ♢•♢
|    |    |    |    |    [216:216] <Parenthesis>
|    |    |    |    |    |    [216:216] <Match> = ♢(♢
|    |    |    |    |    |    [216:216] <Text> = ♢paperSizeVal♢
|    |    |    |    |    |    [216:216] <Whitespace> = ♢•♢
|    |    |    |    |    |    [216:216] <Ampersand> = ♢&♢
|    |    |    |    |    |    [216:216] <Ampersand> = ♢&♢
|    |    |    |    |    |    [216:216] <Whitespace> = ♢•♢
|    |    |    |    |    |    [216:216] <CFunctionCall>
|    |    |    |    |    |    |    [216:216] <Match> = ♢NSEqualSizes♢
|    |    |    |    |    |    |    [216:216] <Parenthesis>
|    |    |    |    |    |    |    |    [216:216] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [216:216] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [216:216] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [216:216] <Match> = ♢paperSizeVal♢
|    |    |    |    |    |    |    |    |    [216:216] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [216:216] <Text> = ♢sizeValue♢
|    |    |    |    |    |    |    |    |    [216:216] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [216:216] <Text> = ♢,♢
|    |    |    |    |    |    |    |    [216:216] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [216:216] <Text> = ♢NSZeroSize♢
|    |    |    |    |    |    |    |    [216:216] <Match> = ♢)♢
|    |    |    |    |    |    [216:216] <Match> = ♢)♢
|    |    |    |    |    [216:216] <Whitespace> = ♢•♢
|    |    |    |    |    [216:216] <Text> = ♢paperSizeVal♢
|    |    |    |    |    [216:216] <Whitespace> = ♢•♢
|    |    |    |    |    [216:216] <Text> = ♢=♢
|    |    |    |    |    [216:216] <Whitespace> = ♢•♢
|    |    |    |    |    [216:216] <ObjCNil> = ♢nil♢
|    |    |    |    |    [216:216] <Semicolon> = ♢;♢
|    |    |    |    [216:216] <Whitespace> = ♢→♢
|    |    |    |    [216:216] <CPPComment> = ♢//•Protect•against•some•old•documents•with•0•paper•size♢
|    |    |    |    [216:217] <Newline> = ♢¶♢
|    |    |    |    [217:217] <Indenting> = ♢••••♢
|    |    |    |    [217:218] <Newline> = ♢¶♢
|    |    |    |    [218:218] <Indenting> = ♢••••♢
|    |    |    |    [218:221] <CConditionIf>
|    |    |    |    |    [218:218] <Match> = ♢if♢
|    |    |    |    |    [218:218] <Whitespace> = ♢•♢
|    |    |    |    |    [218:218] <Parenthesis>
|    |    |    |    |    |    [218:218] <Match> = ♢(♢
|    |    |    |    |    |    [218:218] <Text> = ♢viewSizeVal♢
|    |    |    |    |    |    [218:218] <Match> = ♢)♢
|    |    |    |    |    [218:218] <Whitespace> = ♢•♢
|    |    |    |    |    [218:221] <Braces>
|    |    |    |    |    |    [218:218] <Match> = ♢{♢
|    |    |    |    |    |    [218:219] <Newline> = ♢¶♢
|    |    |    |    |    |    [219:219] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [219:219] <ObjCMethodCall>
|    |    |    |    |    |    |    [219:219] <Match> = ♢[♢
|    |    |    |    |    |    |    [219:219] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [219:219] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [219:219] <Text> = ♢setViewSize♢
|    |    |    |    |    |    |    [219:219] <Colon> = ♢:♢
|    |    |    |    |    |    |    [219:219] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [219:219] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [219:219] <Match> = ♢viewSizeVal♢
|    |    |    |    |    |    |    |    [219:219] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [219:219] <Text> = ♢sizeValue♢
|    |    |    |    |    |    |    |    [219:219] <Match> = ♢]♢
|    |    |    |    |    |    |    [219:219] <Match> = ♢]♢
|    |    |    |    |    |    [219:219] <Semicolon> = ♢;♢
|    |    |    |    |    |    [219:220] <Newline> = ♢¶♢
|    |    |    |    |    |    [220:220] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [220:220] <CConditionIf>
|    |    |    |    |    |    |    [220:220] <Match> = ♢if♢
|    |    |    |    |    |    |    [220:220] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [220:220] <Parenthesis>
|    |    |    |    |    |    |    |    [220:220] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [220:220] <Text> = ♢paperSizeVal♢
|    |    |    |    |    |    |    |    [220:220] <Match> = ♢)♢
|    |    |    |    |    |    |    [220:220] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [220:220] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [220:220] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [220:220] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [220:220] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [220:220] <Text> = ♢setPaperSize♢
|    |    |    |    |    |    |    |    [220:220] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [220:220] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [220:220] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [220:220] <Match> = ♢paperSizeVal♢
|    |    |    |    |    |    |    |    |    [220:220] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [220:220] <Text> = ♢sizeValue♢
|    |    |    |    |    |    |    |    |    [220:220] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [220:220] <Match> = ♢]♢
|    |    |    |    |    |    |    [220:220] <Semicolon> = ♢;♢
|    |    |    |    |    |    [220:221] <Newline> = ♢¶♢
|    |    |    |    |    |    [221:221] <Indenting> = ♢••••♢
|    |    |    |    |    |    [221:221] <Match> = ♢}♢
|    |    |    |    [221:221] <Whitespace> = ♢•♢
|    |    |    |    [221:234] <CConditionElse>
|    |    |    |    |    [221:221] <Match> = ♢else♢
|    |    |    |    |    [221:221] <Whitespace> = ♢•♢
|    |    |    |    |    [221:234] <Braces>
|    |    |    |    |    |    [221:221] <Match> = ♢{♢
|    |    |    |    |    |    [221:221] <Whitespace> = ♢→♢
|    |    |    |    |    |    [221:221] <CPPComment> = ♢//•No•ViewSize...♢
|    |    |    |    |    |    [221:222] <Newline> = ♢¶♢
|    |    |    |    |    |    [222:222] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [222:233] <CConditionIf>
|    |    |    |    |    |    |    [222:222] <Match> = ♢if♢
|    |    |    |    |    |    |    [222:222] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [222:222] <Parenthesis>
|    |    |    |    |    |    |    |    [222:222] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [222:222] <Text> = ♢paperSizeVal♢
|    |    |    |    |    |    |    |    [222:222] <Match> = ♢)♢
|    |    |    |    |    |    |    [222:222] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [222:233] <Braces>
|    |    |    |    |    |    |    |    [222:222] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [222:222] <Whitespace> = ♢→♢
|    |    |    |    |    |    |    |    [222:222] <CPPComment> = ♢//•See•if•PaperSize•should•be•used•as•ViewSize;•if•so,•we•also•have•some•tweaking•to•do•on•it♢
|    |    |    |    |    |    |    |    [222:223] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [223:223] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [223:223] <Text> = ♢val♢
|    |    |    |    |    |    |    |    [223:223] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [223:223] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [223:223] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [223:223] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [223:223] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [223:223] <Match> = ♢docAttrs♢
|    |    |    |    |    |    |    |    |    [223:223] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [223:223] <Text> = ♢objectForKey♢
|    |    |    |    |    |    |    |    |    [223:223] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [223:223] <Text> = ♢NSCocoaVersionDocumentAttribute♢
|    |    |    |    |    |    |    |    |    [223:223] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [223:223] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [223:224] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [224:224] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [224:230] <CConditionIf>
|    |    |    |    |    |    |    |    |    [224:224] <Match> = ♢if♢
|    |    |    |    |    |    |    |    |    [224:224] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [224:224] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [224:224] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [224:224] <Text> = ♢val♢
|    |    |    |    |    |    |    |    |    |    [224:224] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [224:224] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    |    [224:224] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    |    [224:224] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [224:224] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    [224:224] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    [224:224] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    [224:224] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    [224:224] <Match> = ♢val♢
|    |    |    |    |    |    |    |    |    |    |    |    [224:224] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [224:224] <Text> = ♢integerValue♢
|    |    |    |    |    |    |    |    |    |    |    |    [224:224] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    [224:224] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [224:224] <Text> = ♢<♢
|    |    |    |    |    |    |    |    |    |    |    [224:224] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [224:224] <Text> = ♢100♢
|    |    |    |    |    |    |    |    |    |    |    [224:224] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    [224:224] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [224:224] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [224:230] <Braces>
|    |    |    |    |    |    |    |    |    |    [224:224] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    [224:224] <Whitespace> = ♢→♢
|    |    |    |    |    |    |    |    |    |    [224:224] <CPPComment> = ♢//•Indicates•old•RTF•file;•value•described•in•AppKit/NSAttributedString.h♢
|    |    |    |    |    |    |    |    |    |    [224:225] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [225:225] <Indenting> = ♢••••••••••••••••♢
|    |    |    |    |    |    |    |    |    |    [225:225] <Text> = ♢NSSize♢
|    |    |    |    |    |    |    |    |    |    [225:225] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [225:225] <Text> = ♢size♢
|    |    |    |    |    |    |    |    |    |    [225:225] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [225:225] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    |    [225:225] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [225:225] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [225:225] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [225:225] <Match> = ♢paperSizeVal♢
|    |    |    |    |    |    |    |    |    |    |    [225:225] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [225:225] <Text> = ♢sizeValue♢
|    |    |    |    |    |    |    |    |    |    |    [225:225] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [225:225] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    [225:226] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [226:226] <Indenting> = ♢••••••••••••••••♢
|    |    |    |    |    |    |    |    |    |    [226:229] <CConditionIf>
|    |    |    |    |    |    |    |    |    |    |    [226:226] <Match> = ♢if♢
|    |    |    |    |    |    |    |    |    |    |    [226:226] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [226:226] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Text> = ♢size.width♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Text> = ♢>♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Text> = ♢0♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Text> = ♢size.height♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Text> = ♢>♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Text> = ♢0♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [226:226] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Text> = ♢hasMultiplePages♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    [226:226] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [226:229] <Braces>
|    |    |    |    |    |    |    |    |    |    |    |    [226:226] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    |    |    [226:227] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    [227:227] <Indenting> = ♢••••••••••••••••••••♢
|    |    |    |    |    |    |    |    |    |    |    |    [227:227] <Text> = ♢size.width♢
|    |    |    |    |    |    |    |    |    |    |    |    [227:227] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [227:227] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    |    |    |    [227:227] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [227:227] <Text> = ♢size.width♢
|    |    |    |    |    |    |    |    |    |    |    |    [227:227] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [227:227] <Text> = ♢-♢
|    |    |    |    |    |    |    |    |    |    |    |    [227:227] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [227:227] <Text> = ♢oldEditPaddingCompensation♢
|    |    |    |    |    |    |    |    |    |    |    |    [227:227] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    |    [227:228] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    [228:228] <Indenting> = ♢••••••••••••••••••••♢
|    |    |    |    |    |    |    |    |    |    |    |    [228:228] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    [228:228] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [228:228] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [228:228] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [228:228] <Text> = ♢setViewSize♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [228:228] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [228:228] <Text> = ♢size♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [228:228] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    |    [228:228] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    |    [228:229] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    [229:229] <Indenting> = ♢••••••••••••••••♢
|    |    |    |    |    |    |    |    |    |    |    |    [229:229] <Match> = ♢}♢
|    |    |    |    |    |    |    |    |    |    [229:230] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [230:230] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    |    |    [230:230] <Match> = ♢}♢
|    |    |    |    |    |    |    |    [230:230] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [230:232] <CConditionElse>
|    |    |    |    |    |    |    |    |    [230:230] <Match> = ♢else♢
|    |    |    |    |    |    |    |    |    [230:230] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [230:232] <Braces>
|    |    |    |    |    |    |    |    |    |    [230:230] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    [230:231] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [231:231] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [231:231] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [231:231] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [231:231] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    [231:231] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [231:231] <Text> = ♢setPaperSize♢
|    |    |    |    |    |    |    |    |    |    |    [231:231] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    [231:231] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    [231:231] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    [231:231] <Match> = ♢paperSizeVal♢
|    |    |    |    |    |    |    |    |    |    |    |    [231:231] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [231:231] <Text> = ♢sizeValue♢
|    |    |    |    |    |    |    |    |    |    |    |    [231:231] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    [231:231] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [231:231] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    [231:232] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [232:232] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    |    |    [232:232] <Match> = ♢}♢
|    |    |    |    |    |    |    |    [232:233] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [233:233] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    |    |    [233:233] <Match> = ♢}♢
|    |    |    |    |    |    [233:234] <Newline> = ♢¶♢
|    |    |    |    |    |    [234:234] <Indenting> = ♢••••♢
|    |    |    |    |    |    [234:234] <Match> = ♢}♢
|    |    |    |    [234:235] <Newline> = ♢¶♢
|    |    |    |    [235:235] <Indenting> = ♢••••♢
|    |    |    |    [235:236] <Newline> = ♢¶♢
|    |    |    |    [236:236] <Indenting> = ♢••••♢
|    |    |    |    [236:236] <ObjCMethodCall>
|    |    |    |    |    [236:236] <Match> = ♢[♢
|    |    |    |    |    [236:236] <ObjCSelf> = ♢self♢
|    |    |    |    |    [236:236] <Whitespace> = ♢•♢
|    |    |    |    |    [236:236] <Text> = ♢setHyphenationFactor♢
|    |    |    |    |    [236:236] <Colon> = ♢:♢
|    |    |    |    |    [236:236] <Parenthesis>
|    |    |    |    |    |    [236:236] <Match> = ♢(♢
|    |    |    |    |    |    [236:236] <Text> = ♢val♢
|    |    |    |    |    |    [236:236] <Whitespace> = ♢•♢
|    |    |    |    |    |    [236:236] <Text> = ♢=♢
|    |    |    |    |    |    [236:236] <Whitespace> = ♢•♢
|    |    |    |    |    |    [236:236] <ObjCMethodCall>
|    |    |    |    |    |    |    [236:236] <Match> = ♢[♢
|    |    |    |    |    |    |    [236:236] <Match> = ♢docAttrs♢
|    |    |    |    |    |    |    [236:236] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [236:236] <Text> = ♢objectForKey♢
|    |    |    |    |    |    |    [236:236] <Colon> = ♢:♢
|    |    |    |    |    |    |    [236:236] <Text> = ♢NSHyphenationFactorDocumentAttribute♢
|    |    |    |    |    |    |    [236:236] <Match> = ♢]♢
|    |    |    |    |    |    [236:236] <Match> = ♢)♢
|    |    |    |    |    [236:236] <Whitespace> = ♢•♢
|    |    |    |    |    [236:236] <QuestionMark> = ♢?♢
|    |    |    |    |    [236:236] <Whitespace> = ♢•♢
|    |    |    |    |    [236:236] <ObjCMethodCall>
|    |    |    |    |    |    [236:236] <Match> = ♢[♢
|    |    |    |    |    |    [236:236] <Match> = ♢val♢
|    |    |    |    |    |    [236:236] <Whitespace> = ♢•♢
|    |    |    |    |    |    [236:236] <Text> = ♢floatValue♢
|    |    |    |    |    |    [236:236] <Match> = ♢]♢
|    |    |    |    |    [236:236] <Whitespace> = ♢•♢
|    |    |    |    |    [236:236] <Colon> = ♢:♢
|    |    |    |    |    [236:236] <Whitespace> = ♢•♢
|    |    |    |    |    [236:236] <Text> = ♢0♢
|    |    |    |    |    [236:236] <Match> = ♢]♢
|    |    |    |    [236:236] <Semicolon> = ♢;♢
|    |    |    |    [236:237] <Newline> = ♢¶♢
|    |    |    |    [237:237] <Indenting> = ♢••••♢
|    |    |    |    [237:237] <ObjCMethodCall>
|    |    |    |    |    [237:237] <Match> = ♢[♢
|    |    |    |    |    [237:237] <ObjCSelf> = ♢self♢
|    |    |    |    |    [237:237] <Whitespace> = ♢•♢
|    |    |    |    |    [237:237] <Text> = ♢setBackgroundColor♢
|    |    |    |    |    [237:237] <Colon> = ♢:♢
|    |    |    |    |    [237:237] <Parenthesis>
|    |    |    |    |    |    [237:237] <Match> = ♢(♢
|    |    |    |    |    |    [237:237] <Text> = ♢val♢
|    |    |    |    |    |    [237:237] <Whitespace> = ♢•♢
|    |    |    |    |    |    [237:237] <Text> = ♢=♢
|    |    |    |    |    |    [237:237] <Whitespace> = ♢•♢
|    |    |    |    |    |    [237:237] <ObjCMethodCall>
|    |    |    |    |    |    |    [237:237] <Match> = ♢[♢
|    |    |    |    |    |    |    [237:237] <Match> = ♢docAttrs♢
|    |    |    |    |    |    |    [237:237] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [237:237] <Text> = ♢objectForKey♢
|    |    |    |    |    |    |    [237:237] <Colon> = ♢:♢
|    |    |    |    |    |    |    [237:237] <Text> = ♢NSBackgroundColorDocumentAttribute♢
|    |    |    |    |    |    |    [237:237] <Match> = ♢]♢
|    |    |    |    |    |    [237:237] <Match> = ♢)♢
|    |    |    |    |    [237:237] <Whitespace> = ♢•♢
|    |    |    |    |    [237:237] <QuestionMark> = ♢?♢
|    |    |    |    |    [237:237] <Whitespace> = ♢•♢
|    |    |    |    |    [237:237] <Text> = ♢val♢
|    |    |    |    |    [237:237] <Whitespace> = ♢•♢
|    |    |    |    |    [237:237] <Colon> = ♢:♢
|    |    |    |    |    [237:237] <Whitespace> = ♢•♢
|    |    |    |    |    [237:237] <ObjCMethodCall>
|    |    |    |    |    |    [237:237] <Match> = ♢[♢
|    |    |    |    |    |    [237:237] <Match> = ♢NSColor♢
|    |    |    |    |    |    [237:237] <Whitespace> = ♢•♢
|    |    |    |    |    |    [237:237] <Text> = ♢whiteColor♢
|    |    |    |    |    |    [237:237] <Match> = ♢]♢
|    |    |    |    |    [237:237] <Match> = ♢]♢
|    |    |    |    [237:237] <Semicolon> = ♢;♢
|    |    |    |    [237:238] <Newline> = ♢¶♢
|    |    |    |    [238:238] <Indenting> = ♢••••♢
|    |    |    |    [238:239] <Newline> = ♢¶♢
|    |    |    |    [239:239] <Indenting> = ♢••••♢
|    |    |    |    [239:239] <CPPComment> = ♢//•Set•the•document•properties,•generically,•going•through•key•value•coding♢
|    |    |    |    [239:240] <Newline> = ♢¶♢
|    |    |    |    [240:240] <Indenting> = ♢••••♢
|    |    |    |    [240:240] <Text> = ♢NSDictionary♢
|    |    |    |    [240:240] <Whitespace> = ♢•♢
|    |    |    |    [240:240] <Asterisk> = ♢*♢
|    |    |    |    [240:240] <Text> = ♢map♢
|    |    |    |    [240:240] <Whitespace> = ♢•♢
|    |    |    |    [240:240] <Text> = ♢=♢
|    |    |    |    [240:240] <Whitespace> = ♢•♢
|    |    |    |    [240:240] <ObjCMethodCall>
|    |    |    |    |    [240:240] <Match> = ♢[♢
|    |    |    |    |    [240:240] <ObjCSelf> = ♢self♢
|    |    |    |    |    [240:240] <Whitespace> = ♢•♢
|    |    |    |    |    [240:240] <Text> = ♢documentPropertyToAttributeNameMappings♢
|    |    |    |    |    [240:240] <Match> = ♢]♢
|    |    |    |    [240:240] <Semicolon> = ♢;♢
|    |    |    |    [240:241] <Newline> = ♢¶♢
|    |    |    |    [241:241] <Indenting> = ♢••••♢
|    |    |    |    [241:241] <CFlowFor>
|    |    |    |    |    [241:241] <Match> = ♢for♢
|    |    |    |    |    [241:241] <Whitespace> = ♢•♢
|    |    |    |    |    [241:241] <Parenthesis>
|    |    |    |    |    |    [241:241] <Match> = ♢(♢
|    |    |    |    |    |    [241:241] <Text> = ♢NSString♢
|    |    |    |    |    |    [241:241] <Whitespace> = ♢•♢
|    |    |    |    |    |    [241:241] <Asterisk> = ♢*♢
|    |    |    |    |    |    [241:241] <Text> = ♢property♢
|    |    |    |    |    |    [241:241] <Whitespace> = ♢•♢
|    |    |    |    |    |    [241:241] <Text> = ♢in♢
|    |    |    |    |    |    [241:241] <Whitespace> = ♢•♢
|    |    |    |    |    |    [241:241] <ObjCMethodCall>
|    |    |    |    |    |    |    [241:241] <Match> = ♢[♢
|    |    |    |    |    |    |    [241:241] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [241:241] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [241:241] <Text> = ♢knownDocumentProperties♢
|    |    |    |    |    |    |    [241:241] <Match> = ♢]♢
|    |    |    |    |    |    [241:241] <Match> = ♢)♢
|    |    |    |    |    [241:241] <Whitespace> = ♢•♢
|    |    |    |    |    [241:241] <ObjCMethodCall>
|    |    |    |    |    |    [241:241] <Match> = ♢[♢
|    |    |    |    |    |    [241:241] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    [241:241] <Whitespace> = ♢•♢
|    |    |    |    |    |    [241:241] <Text> = ♢setValue♢
|    |    |    |    |    |    [241:241] <Colon> = ♢:♢
|    |    |    |    |    |    [241:241] <ObjCMethodCall>
|    |    |    |    |    |    |    [241:241] <Match> = ♢[♢
|    |    |    |    |    |    |    [241:241] <Match> = ♢docAttrs♢
|    |    |    |    |    |    |    [241:241] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [241:241] <Text> = ♢objectForKey♢
|    |    |    |    |    |    |    [241:241] <Colon> = ♢:♢
|    |    |    |    |    |    |    [241:241] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [241:241] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [241:241] <Match> = ♢map♢
|    |    |    |    |    |    |    |    [241:241] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [241:241] <Text> = ♢objectForKey♢
|    |    |    |    |    |    |    |    [241:241] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [241:241] <Text> = ♢property♢
|    |    |    |    |    |    |    |    [241:241] <Match> = ♢]♢
|    |    |    |    |    |    |    [241:241] <Match> = ♢]♢
|    |    |    |    |    |    [241:241] <Whitespace> = ♢•♢
|    |    |    |    |    |    [241:241] <Text> = ♢forKey♢
|    |    |    |    |    |    [241:241] <Colon> = ♢:♢
|    |    |    |    |    |    [241:241] <Text> = ♢property♢
|    |    |    |    |    |    [241:241] <Match> = ♢]♢
|    |    |    |    |    [241:241] <Semicolon> = ♢;♢
|    |    |    |    [241:241] <Whitespace> = ♢→♢
|    |    |    |    [241:241] <CPPComment> = ♢//•OK•to•set•nil•to•clear♢
|    |    |    |    [241:242] <Newline> = ♢¶♢
|    |    |    |    [242:242] <Indenting> = ♢••••♢
|    |    |    |    [242:243] <Newline> = ♢¶♢
|    |    |    |    [243:243] <Indenting> = ♢••••♢
|    |    |    |    [243:243] <ObjCMethodCall>
|    |    |    |    |    [243:243] <Match> = ♢[♢
|    |    |    |    |    [243:243] <ObjCSelf> = ♢self♢
|    |    |    |    |    [243:243] <Whitespace> = ♢•♢
|    |    |    |    |    [243:243] <Text> = ♢setReadOnly♢
|    |    |    |    |    [243:243] <Colon> = ♢:♢
|    |    |    |    |    [243:243] <Parenthesis>
|    |    |    |    |    |    [243:243] <Match> = ♢(♢
|    |    |    |    |    |    [243:243] <Parenthesis>
|    |    |    |    |    |    |    [243:243] <Match> = ♢(♢
|    |    |    |    |    |    |    [243:243] <Text> = ♢val♢
|    |    |    |    |    |    |    [243:243] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [243:243] <Text> = ♢=♢
|    |    |    |    |    |    |    [243:243] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [243:243] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [243:243] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [243:243] <Match> = ♢docAttrs♢
|    |    |    |    |    |    |    |    [243:243] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [243:243] <Text> = ♢objectForKey♢
|    |    |    |    |    |    |    |    [243:243] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [243:243] <Text> = ♢NSReadOnlyDocumentAttribute♢
|    |    |    |    |    |    |    |    [243:243] <Match> = ♢]♢
|    |    |    |    |    |    |    [243:243] <Match> = ♢)♢
|    |    |    |    |    |    [243:243] <Whitespace> = ♢•♢
|    |    |    |    |    |    [243:243] <Ampersand> = ♢&♢
|    |    |    |    |    |    [243:243] <Ampersand> = ♢&♢
|    |    |    |    |    |    [243:243] <Whitespace> = ♢•♢
|    |    |    |    |    |    [243:243] <Parenthesis>
|    |    |    |    |    |    |    [243:243] <Match> = ♢(♢
|    |    |    |    |    |    |    [243:243] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [243:243] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [243:243] <Match> = ♢val♢
|    |    |    |    |    |    |    |    [243:243] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [243:243] <Text> = ♢integerValue♢
|    |    |    |    |    |    |    |    [243:243] <Match> = ♢]♢
|    |    |    |    |    |    |    [243:243] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [243:243] <Text> = ♢>♢
|    |    |    |    |    |    |    [243:243] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [243:243] <Text> = ♢0♢
|    |    |    |    |    |    |    [243:243] <Match> = ♢)♢
|    |    |    |    |    |    [243:243] <Match> = ♢)♢
|    |    |    |    |    [243:243] <Match> = ♢]♢
|    |    |    |    [243:243] <Semicolon> = ♢;♢
|    |    |    |    [243:244] <Newline> = ♢¶♢
|    |    |    |    [244:244] <Indenting> = ♢••••♢
|    |    |    |    [244:245] <Newline> = ♢¶♢
|    |    |    |    [245:245] <Indenting> = ♢••••♢
|    |    |    |    [245:245] <ObjCMethodCall>
|    |    |    |    |    [245:245] <Match> = ♢[♢
|    |    |    |    |    [245:245] <ObjCMethodCall>
|    |    |    |    |    |    [245:245] <Match> = ♢[♢
|    |    |    |    |    |    [245:245] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    [245:245] <Whitespace> = ♢•♢
|    |    |    |    |    |    [245:245] <Text> = ♢undoManager♢
|    |    |    |    |    |    [245:245] <Match> = ♢]♢
|    |    |    |    |    [245:245] <Whitespace> = ♢•♢
|    |    |    |    |    [245:245] <Text> = ♢enableUndoRegistration♢
|    |    |    |    |    [245:245] <Match> = ♢]♢
|    |    |    |    [245:245] <Semicolon> = ♢;♢
|    |    |    |    [245:246] <Newline> = ♢¶♢
|    |    |    |    [246:246] <Indenting> = ♢••••♢
|    |    |    |    [246:247] <Newline> = ♢¶♢
|    |    |    |    [247:247] <Indenting> = ♢••••♢
|    |    |    |    [247:247] <CFlowReturn>
|    |    |    |    |    [247:247] <Match> = ♢return♢
|    |    |    |    |    [247:247] <Whitespace> = ♢•♢
|    |    |    |    |    [247:247] <Text> = ♢YES♢
|    |    |    |    |    [247:247] <Semicolon> = ♢;♢
|    |    |    |    [247:248] <Newline> = ♢¶♢
|    |    |    |    [248:248] <Match> = ♢}♢
|    |    [248:249] <Newline> = ♢¶♢
|    |    [249:250] <Newline> = ♢¶♢
|    |    [250:285] <ObjCMethodImplementation>
|    |    |    [250:250] <Match> = ♢-♢
|    |    |    [250:250] <Whitespace> = ♢•♢
|    |    |    [250:250] <Parenthesis>
|    |    |    |    [250:250] <Match> = ♢(♢
|    |    |    |    [250:250] <Text> = ♢NSDictionary♢
|    |    |    |    [250:250] <Whitespace> = ♢•♢
|    |    |    |    [250:250] <Asterisk> = ♢*♢
|    |    |    |    [250:250] <Match> = ♢)♢
|    |    |    [250:250] <Text> = ♢defaultTextAttributes♢
|    |    |    [250:250] <Colon> = ♢:♢
|    |    |    [250:250] <Parenthesis>
|    |    |    |    [250:250] <Match> = ♢(♢
|    |    |    |    [250:250] <Text> = ♢BOOL♢
|    |    |    |    [250:250] <Match> = ♢)♢
|    |    |    [250:250] <Text> = ♢forRichText♢
|    |    |    [250:250] <Whitespace> = ♢•♢
|    |    |    [250:285] <Braces>
|    |    |    |    [250:250] <Match> = ♢{♢
|    |    |    |    [250:251] <Newline> = ♢¶♢
|    |    |    |    [251:251] <Indenting> = ♢••••♢
|    |    |    |    [251:251] <CStatic> = ♢static♢
|    |    |    |    [251:251] <Whitespace> = ♢•♢
|    |    |    |    [251:251] <Text> = ♢NSParagraphStyle♢
|    |    |    |    [251:251] <Whitespace> = ♢•♢
|    |    |    |    [251:251] <Asterisk> = ♢*♢
|    |    |    |    [251:251] <Text> = ♢defaultRichParaStyle♢
|    |    |    |    [251:251] <Whitespace> = ♢•♢
|    |    |    |    [251:251] <Text> = ♢=♢
|    |    |    |    [251:251] <Whitespace> = ♢•♢
|    |    |    |    [251:251] <ObjCNil> = ♢nil♢
|    |    |    |    [251:251] <Semicolon> = ♢;♢
|    |    |    |    [251:252] <Newline> = ♢¶♢
|    |    |    |    [252:252] <Indenting> = ♢••••♢
|    |    |    |    [252:252] <Text> = ♢NSMutableDictionary♢
|    |    |    |    [252:252] <Whitespace> = ♢•♢
|    |    |    |    [252:252] <Asterisk> = ♢*♢
|    |    |    |    [252:252] <Text> = ♢textAttributes♢
|    |    |    |    [252:252] <Whitespace> = ♢•♢
|    |    |    |    [252:252] <Text> = ♢=♢
|    |    |    |    [252:252] <Whitespace> = ♢•♢
|    |    |    |    [252:252] <ObjCMethodCall>
|    |    |    |    |    [252:252] <Match> = ♢[♢
|    |    |    |    |    [252:252] <ObjCMethodCall>
|    |    |    |    |    |    [252:252] <Match> = ♢[♢
|    |    |    |    |    |    [252:252] <ObjCMethodCall>
|    |    |    |    |    |    |    [252:252] <Match> = ♢[♢
|    |    |    |    |    |    |    [252:252] <Match> = ♢NSMutableDictionary♢
|    |    |    |    |    |    |    [252:252] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [252:252] <Text> = ♢alloc♢
|    |    |    |    |    |    |    [252:252] <Match> = ♢]♢
|    |    |    |    |    |    [252:252] <Whitespace> = ♢•♢
|    |    |    |    |    |    [252:252] <Text> = ♢initWithCapacity♢
|    |    |    |    |    |    [252:252] <Colon> = ♢:♢
|    |    |    |    |    |    [252:252] <Text> = ♢2♢
|    |    |    |    |    |    [252:252] <Match> = ♢]♢
|    |    |    |    |    [252:252] <Whitespace> = ♢•♢
|    |    |    |    |    [252:252] <Text> = ♢autorelease♢
|    |    |    |    |    [252:252] <Match> = ♢]♢
|    |    |    |    [252:252] <Semicolon> = ♢;♢
|    |    |    |    [252:253] <Newline> = ♢¶♢
|    |    |    |    [253:253] <Indenting> = ♢••••♢
|    |    |    |    [253:269] <CConditionIf>
|    |    |    |    |    [253:253] <Match> = ♢if♢
|    |    |    |    |    [253:253] <Whitespace> = ♢•♢
|    |    |    |    |    [253:253] <Parenthesis>
|    |    |    |    |    |    [253:253] <Match> = ♢(♢
|    |    |    |    |    |    [253:253] <Text> = ♢forRichText♢
|    |    |    |    |    |    [253:253] <Match> = ♢)♢
|    |    |    |    |    [253:253] <Whitespace> = ♢•♢
|    |    |    |    |    [253:269] <Braces>
|    |    |    |    |    |    [253:253] <Match> = ♢{♢
|    |    |    |    |    |    [253:254] <Newline> = ♢¶♢
|    |    |    |    |    |    [254:254] <Indenting> = ♢→♢
|    |    |    |    |    |    [254:254] <ObjCMethodCall>
|    |    |    |    |    |    |    [254:254] <Match> = ♢[♢
|    |    |    |    |    |    |    [254:254] <Match> = ♢textAttributes♢
|    |    |    |    |    |    |    [254:254] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [254:254] <Text> = ♢setObject♢
|    |    |    |    |    |    |    [254:254] <Colon> = ♢:♢
|    |    |    |    |    |    |    [254:254] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [254:254] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [254:254] <Match> = ♢NSFont♢
|    |    |    |    |    |    |    |    [254:254] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [254:254] <Text> = ♢userFontOfSize♢
|    |    |    |    |    |    |    |    [254:254] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [254:254] <Text> = ♢0.0♢
|    |    |    |    |    |    |    |    [254:254] <Match> = ♢]♢
|    |    |    |    |    |    |    [254:254] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [254:254] <Text> = ♢forKey♢
|    |    |    |    |    |    |    [254:254] <Colon> = ♢:♢
|    |    |    |    |    |    |    [254:254] <Text> = ♢NSFontAttributeName♢
|    |    |    |    |    |    |    [254:254] <Match> = ♢]♢
|    |    |    |    |    |    [254:254] <Semicolon> = ♢;♢
|    |    |    |    |    |    [254:255] <Newline> = ♢¶♢
|    |    |    |    |    |    [255:255] <Indenting> = ♢→♢
|    |    |    |    |    |    [255:267] <CConditionIf>
|    |    |    |    |    |    |    [255:255] <Match> = ♢if♢
|    |    |    |    |    |    |    [255:255] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [255:255] <Parenthesis>
|    |    |    |    |    |    |    |    [255:255] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [255:255] <Text> = ♢defaultRichParaStyle♢
|    |    |    |    |    |    |    |    [255:255] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [255:255] <Text> = ♢==♢
|    |    |    |    |    |    |    |    [255:255] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [255:255] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    |    [255:255] <Match> = ♢)♢
|    |    |    |    |    |    |    [255:255] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [255:267] <Braces>
|    |    |    |    |    |    |    |    [255:255] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [255:255] <Whitespace> = ♢→♢
|    |    |    |    |    |    |    |    [255:255] <CPPComment> = ♢//•We•do•this•once...♢
|    |    |    |    |    |    |    |    [255:256] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [256:256] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [256:256] <Text> = ♢NSInteger♢
|    |    |    |    |    |    |    |    [256:256] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [256:256] <Text> = ♢cnt♢
|    |    |    |    |    |    |    |    [256:256] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [256:257] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [257:257] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [257:257] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    [257:257] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [257:257] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [257:257] <Text> = ♢measurementUnits♢
|    |    |    |    |    |    |    |    [257:257] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [257:257] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [257:257] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [257:257] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [257:257] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [257:257] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [257:257] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [257:257] <Match> = ♢NSUserDefaults♢
|    |    |    |    |    |    |    |    |    |    [257:257] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [257:257] <Text> = ♢standardUserDefaults♢
|    |    |    |    |    |    |    |    |    |    [257:257] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [257:257] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [257:257] <Text> = ♢objectForKey♢
|    |    |    |    |    |    |    |    |    [257:257] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [257:257] <ObjCString> = ♢@"AppleMeasurementUnits"♢
|    |    |    |    |    |    |    |    |    [257:257] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [257:257] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [257:258] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [258:258] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [258:258] <Text> = ♢CGFloat♢
|    |    |    |    |    |    |    |    [258:258] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [258:258] <Text> = ♢tabInterval♢
|    |    |    |    |    |    |    |    [258:258] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [258:258] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [258:258] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [258:258] <CConditionalOperator>
|    |    |    |    |    |    |    |    |    [258:258] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [258:258] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [258:258] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [258:258] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [258:258] <ObjCString> = ♢@"Centimeters"♢
|    |    |    |    |    |    |    |    |    |    |    [258:258] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [258:258] <Text> = ♢isEqual♢
|    |    |    |    |    |    |    |    |    |    |    [258:258] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    [258:258] <Text> = ♢measurementUnits♢
|    |    |    |    |    |    |    |    |    |    |    [258:258] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [258:258] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [258:258] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [258:258] <QuestionMark> = ♢?♢
|    |    |    |    |    |    |    |    |    [258:258] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [258:258] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [258:258] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [258:258] <Text> = ♢72.0♢
|    |    |    |    |    |    |    |    |    |    [258:258] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [258:258] <Text> = ♢/♢
|    |    |    |    |    |    |    |    |    |    [258:258] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [258:258] <Text> = ♢2.54♢
|    |    |    |    |    |    |    |    |    |    [258:258] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [258:258] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [258:258] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [258:258] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [258:258] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [258:258] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [258:258] <Text> = ♢72.0♢
|    |    |    |    |    |    |    |    |    |    [258:258] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [258:258] <Text> = ♢/♢
|    |    |    |    |    |    |    |    |    |    [258:258] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [258:258] <Text> = ♢2.0♢
|    |    |    |    |    |    |    |    |    |    [258:258] <Match> = ♢)♢
|    |    |    |    |    |    |    |    [258:258] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [258:258] <Whitespace> = ♢••♢
|    |    |    |    |    |    |    |    [258:258] <CPPComment> = ♢//•Every•cm•or•half•inch♢
|    |    |    |    |    |    |    |    [258:259] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [259:259] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [259:259] <Text> = ♢NSMutableParagraphStyle♢
|    |    |    |    |    |    |    |    [259:259] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [259:259] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [259:259] <Text> = ♢paraStyle♢
|    |    |    |    |    |    |    |    [259:259] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [259:259] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [259:259] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [259:259] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [259:259] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [259:259] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [259:259] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [259:259] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [259:259] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [259:259] <Match> = ♢NSMutableParagraphStyle♢
|    |    |    |    |    |    |    |    |    |    |    [259:259] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [259:259] <Text> = ♢alloc♢
|    |    |    |    |    |    |    |    |    |    |    [259:259] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [259:259] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [259:259] <Text> = ♢init♢
|    |    |    |    |    |    |    |    |    |    [259:259] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [259:259] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [259:259] <Text> = ♢autorelease♢
|    |    |    |    |    |    |    |    |    [259:259] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [259:259] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [259:260] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [260:260] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [260:260] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [260:260] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [260:260] <Match> = ♢paraStyle♢
|    |    |    |    |    |    |    |    |    [260:260] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [260:260] <Text> = ♢setTabStops♢
|    |    |    |    |    |    |    |    |    [260:260] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [260:260] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [260:260] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [260:260] <Match> = ♢NSArray♢
|    |    |    |    |    |    |    |    |    |    [260:260] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [260:260] <Text> = ♢array♢
|    |    |    |    |    |    |    |    |    |    [260:260] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [260:260] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [260:260] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [260:260] <Whitespace> = ♢→♢
|    |    |    |    |    |    |    |    [260:260] <CPPComment> = ♢//•This•first•clears•all•tab•stops♢
|    |    |    |    |    |    |    |    [260:261] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [261:261] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [261:265] <CFlowFor>
|    |    |    |    |    |    |    |    |    [261:261] <Match> = ♢for♢
|    |    |    |    |    |    |    |    |    [261:261] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [261:261] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [261:261] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [261:261] <Text> = ♢cnt♢
|    |    |    |    |    |    |    |    |    |    [261:261] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [261:261] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    |    [261:261] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [261:261] <Text> = ♢0♢
|    |    |    |    |    |    |    |    |    |    [261:261] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    [261:261] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [261:261] <Text> = ♢cnt♢
|    |    |    |    |    |    |    |    |    |    [261:261] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [261:261] <Text> = ♢<♢
|    |    |    |    |    |    |    |    |    |    [261:261] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [261:261] <Text> = ♢12♢
|    |    |    |    |    |    |    |    |    |    [261:261] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    [261:261] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [261:261] <Text> = ♢cnt++♢
|    |    |    |    |    |    |    |    |    |    [261:261] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [261:261] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [261:265] <Braces>
|    |    |    |    |    |    |    |    |    |    [261:261] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    [261:261] <Whitespace> = ♢→♢
|    |    |    |    |    |    |    |    |    |    [261:261] <CPPComment> = ♢//•Add•12•tab•stops,•at•desired•intervals...♢
|    |    |    |    |    |    |    |    |    |    [261:262] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [262:262] <Indenting> = ♢••••••••••••••••♢
|    |    |    |    |    |    |    |    |    |    [262:262] <Text> = ♢NSTextTab♢
|    |    |    |    |    |    |    |    |    |    [262:262] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [262:262] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    |    |    [262:262] <Text> = ♢tabStop♢
|    |    |    |    |    |    |    |    |    |    [262:262] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [262:262] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    |    [262:262] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [262:262] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [262:262] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [262:262] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    [262:262] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    [262:262] <Match> = ♢NSTextTab♢
|    |    |    |    |    |    |    |    |    |    |    |    [262:262] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [262:262] <Text> = ♢alloc♢
|    |    |    |    |    |    |    |    |    |    |    |    [262:262] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    [262:262] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [262:262] <Text> = ♢initWithType♢
|    |    |    |    |    |    |    |    |    |    |    [262:262] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    [262:262] <Text> = ♢NSLeftTabStopType♢
|    |    |    |    |    |    |    |    |    |    |    [262:262] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [262:262] <Text> = ♢location♢
|    |    |    |    |    |    |    |    |    |    |    [262:262] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    [262:262] <Text> = ♢tabInterval♢
|    |    |    |    |    |    |    |    |    |    |    [262:262] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [262:262] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    |    |    |    [262:262] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [262:262] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    [262:262] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    [262:262] <Text> = ♢cnt♢
|    |    |    |    |    |    |    |    |    |    |    |    [262:262] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [262:262] <Text> = ♢+♢
|    |    |    |    |    |    |    |    |    |    |    |    [262:262] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [262:262] <Text> = ♢1♢
|    |    |    |    |    |    |    |    |    |    |    |    [262:262] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    [262:262] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [262:262] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    [262:263] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [263:263] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [263:263] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [263:263] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [263:263] <Match> = ♢paraStyle♢
|    |    |    |    |    |    |    |    |    |    |    [263:263] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [263:263] <Text> = ♢addTabStop♢
|    |    |    |    |    |    |    |    |    |    |    [263:263] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    [263:263] <Text> = ♢tabStop♢
|    |    |    |    |    |    |    |    |    |    |    [263:263] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [263:263] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    [263:264] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [264:264] <Indenting> = ♢→•→♢
|    |    |    |    |    |    |    |    |    |    [264:264] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [264:264] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [264:264] <Match> = ♢tabStop♢
|    |    |    |    |    |    |    |    |    |    |    [264:264] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [264:264] <Text> = ♢release♢
|    |    |    |    |    |    |    |    |    |    |    [264:264] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [264:264] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    [264:265] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [265:265] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    |    |    [265:265] <Match> = ♢}♢
|    |    |    |    |    |    |    |    [265:266] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [266:266] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [266:266] <Text> = ♢defaultRichParaStyle♢
|    |    |    |    |    |    |    |    [266:266] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [266:266] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [266:266] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [266:266] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [266:266] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [266:266] <Match> = ♢paraStyle♢
|    |    |    |    |    |    |    |    |    [266:266] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [266:266] <Text> = ♢copy♢
|    |    |    |    |    |    |    |    |    [266:266] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [266:266] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [266:267] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [267:267] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [267:267] <Match> = ♢}♢
|    |    |    |    |    |    [267:268] <Newline> = ♢¶♢
|    |    |    |    |    |    [268:268] <Indenting> = ♢→♢
|    |    |    |    |    |    [268:268] <ObjCMethodCall>
|    |    |    |    |    |    |    [268:268] <Match> = ♢[♢
|    |    |    |    |    |    |    [268:268] <Match> = ♢textAttributes♢
|    |    |    |    |    |    |    [268:268] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [268:268] <Text> = ♢setObject♢
|    |    |    |    |    |    |    [268:268] <Colon> = ♢:♢
|    |    |    |    |    |    |    [268:268] <Text> = ♢defaultRichParaStyle♢
|    |    |    |    |    |    |    [268:268] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [268:268] <Text> = ♢forKey♢
|    |    |    |    |    |    |    [268:268] <Colon> = ♢:♢
|    |    |    |    |    |    |    [268:268] <Text> = ♢NSParagraphStyleAttributeName♢
|    |    |    |    |    |    |    [268:268] <Match> = ♢]♢
|    |    |    |    |    |    [268:268] <Semicolon> = ♢;♢
|    |    |    |    |    |    [268:269] <Newline> = ♢¶♢
|    |    |    |    |    |    [269:269] <Indenting> = ♢••••♢
|    |    |    |    |    |    [269:269] <Match> = ♢}♢
|    |    |    |    [269:269] <Whitespace> = ♢•♢
|    |    |    |    [269:283] <CConditionElse>
|    |    |    |    |    [269:269] <Match> = ♢else♢
|    |    |    |    |    [269:269] <Whitespace> = ♢•♢
|    |    |    |    |    [269:283] <Braces>
|    |    |    |    |    |    [269:269] <Match> = ♢{♢
|    |    |    |    |    |    [269:270] <Newline> = ♢¶♢
|    |    |    |    |    |    [270:270] <Indenting> = ♢→♢
|    |    |    |    |    |    [270:270] <Text> = ♢NSFont♢
|    |    |    |    |    |    [270:270] <Whitespace> = ♢•♢
|    |    |    |    |    |    [270:270] <Asterisk> = ♢*♢
|    |    |    |    |    |    [270:270] <Text> = ♢plainFont♢
|    |    |    |    |    |    [270:270] <Whitespace> = ♢•♢
|    |    |    |    |    |    [270:270] <Text> = ♢=♢
|    |    |    |    |    |    [270:270] <Whitespace> = ♢•♢
|    |    |    |    |    |    [270:270] <ObjCMethodCall>
|    |    |    |    |    |    |    [270:270] <Match> = ♢[♢
|    |    |    |    |    |    |    [270:270] <Match> = ♢NSFont♢
|    |    |    |    |    |    |    [270:270] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [270:270] <Text> = ♢userFixedPitchFontOfSize♢
|    |    |    |    |    |    |    [270:270] <Colon> = ♢:♢
|    |    |    |    |    |    |    [270:270] <Text> = ♢0.0♢
|    |    |    |    |    |    |    [270:270] <Match> = ♢]♢
|    |    |    |    |    |    [270:270] <Semicolon> = ♢;♢
|    |    |    |    |    |    [270:271] <Newline> = ♢¶♢
|    |    |    |    |    |    [271:271] <Indenting> = ♢→♢
|    |    |    |    |    |    [271:271] <Text> = ♢NSInteger♢
|    |    |    |    |    |    [271:271] <Whitespace> = ♢•♢
|    |    |    |    |    |    [271:271] <Text> = ♢tabWidth♢
|    |    |    |    |    |    [271:271] <Whitespace> = ♢•♢
|    |    |    |    |    |    [271:271] <Text> = ♢=♢
|    |    |    |    |    |    [271:271] <Whitespace> = ♢•♢
|    |    |    |    |    |    [271:271] <ObjCMethodCall>
|    |    |    |    |    |    |    [271:271] <Match> = ♢[♢
|    |    |    |    |    |    |    [271:271] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [271:271] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [271:271] <Match> = ♢NSUserDefaults♢
|    |    |    |    |    |    |    |    [271:271] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [271:271] <Text> = ♢standardUserDefaults♢
|    |    |    |    |    |    |    |    [271:271] <Match> = ♢]♢
|    |    |    |    |    |    |    [271:271] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [271:271] <Text> = ♢integerForKey♢
|    |    |    |    |    |    |    [271:271] <Colon> = ♢:♢
|    |    |    |    |    |    |    [271:271] <Text> = ♢TabWidth♢
|    |    |    |    |    |    |    [271:271] <Match> = ♢]♢
|    |    |    |    |    |    [271:271] <Semicolon> = ♢;♢
|    |    |    |    |    |    [271:272] <Newline> = ♢¶♢
|    |    |    |    |    |    [272:272] <Indenting> = ♢→♢
|    |    |    |    |    |    [272:272] <Text> = ♢CGFloat♢
|    |    |    |    |    |    [272:272] <Whitespace> = ♢•♢
|    |    |    |    |    |    [272:272] <Text> = ♢charWidth♢
|    |    |    |    |    |    [272:272] <Whitespace> = ♢•♢
|    |    |    |    |    |    [272:272] <Text> = ♢=♢
|    |    |    |    |    |    [272:272] <Whitespace> = ♢•♢
|    |    |    |    |    |    [272:272] <ObjCMethodCall>
|    |    |    |    |    |    |    [272:272] <Match> = ♢[♢
|    |    |    |    |    |    |    [272:272] <ObjCString> = ♢@"•"♢
|    |    |    |    |    |    |    [272:272] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [272:272] <Text> = ♢sizeWithAttributes♢
|    |    |    |    |    |    |    [272:272] <Colon> = ♢:♢
|    |    |    |    |    |    |    [272:272] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [272:272] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [272:272] <Match> = ♢NSDictionary♢
|    |    |    |    |    |    |    |    [272:272] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [272:272] <Text> = ♢dictionaryWithObject♢
|    |    |    |    |    |    |    |    [272:272] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [272:272] <Text> = ♢plainFont♢
|    |    |    |    |    |    |    |    [272:272] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [272:272] <Text> = ♢forKey♢
|    |    |    |    |    |    |    |    [272:272] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [272:272] <Text> = ♢NSFontAttributeName♢
|    |    |    |    |    |    |    |    [272:272] <Match> = ♢]♢
|    |    |    |    |    |    |    [272:272] <Match> = ♢]♢
|    |    |    |    |    |    [272:272] <Text> = ♢.width♢
|    |    |    |    |    |    [272:272] <Semicolon> = ♢;♢
|    |    |    |    |    |    [272:273] <Newline> = ♢¶♢
|    |    |    |    |    |    [273:273] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [273:273] <CConditionIf>
|    |    |    |    |    |    |    [273:273] <Match> = ♢if♢
|    |    |    |    |    |    |    [273:273] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [273:273] <Parenthesis>
|    |    |    |    |    |    |    |    [273:273] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [273:273] <Text> = ♢charWidth♢
|    |    |    |    |    |    |    |    [273:273] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [273:273] <Text> = ♢==♢
|    |    |    |    |    |    |    |    [273:273] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [273:273] <Text> = ♢0♢
|    |    |    |    |    |    |    |    [273:273] <Match> = ♢)♢
|    |    |    |    |    |    |    [273:273] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [273:273] <Text> = ♢charWidth♢
|    |    |    |    |    |    |    [273:273] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [273:273] <Text> = ♢=♢
|    |    |    |    |    |    |    [273:273] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [273:273] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [273:273] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [273:273] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [273:273] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [273:273] <Match> = ♢plainFont♢
|    |    |    |    |    |    |    |    |    [273:273] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [273:273] <Text> = ♢screenFontWithRenderingMode♢
|    |    |    |    |    |    |    |    |    [273:273] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [273:273] <Text> = ♢NSFontDefaultRenderingMode♢
|    |    |    |    |    |    |    |    |    [273:273] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [273:273] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [273:273] <Text> = ♢maximumAdvancement♢
|    |    |    |    |    |    |    |    [273:273] <Match> = ♢]♢
|    |    |    |    |    |    |    [273:273] <Text> = ♢.width♢
|    |    |    |    |    |    |    [273:273] <Semicolon> = ♢;♢
|    |    |    |    |    |    [273:274] <Newline> = ♢¶♢
|    |    |    |    |    |    [274:274] <Indenting> = ♢→♢
|    |    |    |    |    |    [274:275] <Newline> = ♢¶♢
|    |    |    |    |    |    [275:275] <Indenting> = ♢→♢
|    |    |    |    |    |    [275:275] <CPPComment> = ♢//•Now•use•a•default•paragraph•style,•but•with•the•tab•width•adjusted♢
|    |    |    |    |    |    [275:276] <Newline> = ♢¶♢
|    |    |    |    |    |    [276:276] <Indenting> = ♢→♢
|    |    |    |    |    |    [276:276] <Text> = ♢NSMutableParagraphStyle♢
|    |    |    |    |    |    [276:276] <Whitespace> = ♢•♢
|    |    |    |    |    |    [276:276] <Asterisk> = ♢*♢
|    |    |    |    |    |    [276:276] <Text> = ♢mStyle♢
|    |    |    |    |    |    [276:276] <Whitespace> = ♢•♢
|    |    |    |    |    |    [276:276] <Text> = ♢=♢
|    |    |    |    |    |    [276:276] <Whitespace> = ♢•♢
|    |    |    |    |    |    [276:276] <ObjCMethodCall>
|    |    |    |    |    |    |    [276:276] <Match> = ♢[♢
|    |    |    |    |    |    |    [276:276] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [276:276] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [276:276] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [276:276] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [276:276] <Match> = ♢NSParagraphStyle♢
|    |    |    |    |    |    |    |    |    [276:276] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [276:276] <Text> = ♢defaultParagraphStyle♢
|    |    |    |    |    |    |    |    |    [276:276] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [276:276] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [276:276] <Text> = ♢mutableCopy♢
|    |    |    |    |    |    |    |    [276:276] <Match> = ♢]♢
|    |    |    |    |    |    |    [276:276] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [276:276] <Text> = ♢autorelease♢
|    |    |    |    |    |    |    [276:276] <Match> = ♢]♢
|    |    |    |    |    |    [276:276] <Semicolon> = ♢;♢
|    |    |    |    |    |    [276:277] <Newline> = ♢¶♢
|    |    |    |    |    |    [277:277] <Indenting> = ♢→♢
|    |    |    |    |    |    [277:277] <ObjCMethodCall>
|    |    |    |    |    |    |    [277:277] <Match> = ♢[♢
|    |    |    |    |    |    |    [277:277] <Match> = ♢mStyle♢
|    |    |    |    |    |    |    [277:277] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [277:277] <Text> = ♢setTabStops♢
|    |    |    |    |    |    |    [277:277] <Colon> = ♢:♢
|    |    |    |    |    |    |    [277:277] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [277:277] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [277:277] <Match> = ♢NSArray♢
|    |    |    |    |    |    |    |    [277:277] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [277:277] <Text> = ♢array♢
|    |    |    |    |    |    |    |    [277:277] <Match> = ♢]♢
|    |    |    |    |    |    |    [277:277] <Match> = ♢]♢
|    |    |    |    |    |    [277:277] <Semicolon> = ♢;♢
|    |    |    |    |    |    [277:278] <Newline> = ♢¶♢
|    |    |    |    |    |    [278:278] <Indenting> = ♢→♢
|    |    |    |    |    |    [278:278] <ObjCMethodCall>
|    |    |    |    |    |    |    [278:278] <Match> = ♢[♢
|    |    |    |    |    |    |    [278:278] <Match> = ♢mStyle♢
|    |    |    |    |    |    |    [278:278] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [278:278] <Text> = ♢setDefaultTabInterval♢
|    |    |    |    |    |    |    [278:278] <Colon> = ♢:♢
|    |    |    |    |    |    |    [278:278] <Parenthesis>
|    |    |    |    |    |    |    |    [278:278] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [278:278] <Text> = ♢charWidth♢
|    |    |    |    |    |    |    |    [278:278] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [278:278] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [278:278] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [278:278] <Text> = ♢tabWidth♢
|    |    |    |    |    |    |    |    [278:278] <Match> = ♢)♢
|    |    |    |    |    |    |    [278:278] <Match> = ♢]♢
|    |    |    |    |    |    [278:278] <Semicolon> = ♢;♢
|    |    |    |    |    |    [278:279] <Newline> = ♢¶♢
|    |    |    |    |    |    [279:279] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [279:279] <ObjCMethodCall>
|    |    |    |    |    |    |    [279:279] <Match> = ♢[♢
|    |    |    |    |    |    |    [279:279] <Match> = ♢textAttributes♢
|    |    |    |    |    |    |    [279:279] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [279:279] <Text> = ♢setObject♢
|    |    |    |    |    |    |    [279:279] <Colon> = ♢:♢
|    |    |    |    |    |    |    [279:279] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [279:279] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [279:279] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [279:279] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [279:279] <Match> = ♢mStyle♢
|    |    |    |    |    |    |    |    |    [279:279] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [279:279] <Text> = ♢copy♢
|    |    |    |    |    |    |    |    |    [279:279] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [279:279] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [279:279] <Text> = ♢autorelease♢
|    |    |    |    |    |    |    |    [279:279] <Match> = ♢]♢
|    |    |    |    |    |    |    [279:279] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [279:279] <Text> = ♢forKey♢
|    |    |    |    |    |    |    [279:279] <Colon> = ♢:♢
|    |    |    |    |    |    |    [279:279] <Text> = ♢NSParagraphStyleAttributeName♢
|    |    |    |    |    |    |    [279:279] <Match> = ♢]♢
|    |    |    |    |    |    [279:279] <Semicolon> = ♢;♢
|    |    |    |    |    |    [279:280] <Newline> = ♢¶♢
|    |    |    |    |    |    [280:280] <Indenting> = ♢→♢
|    |    |    |    |    |    [280:281] <Newline> = ♢¶♢
|    |    |    |    |    |    [281:281] <Indenting> = ♢→♢
|    |    |    |    |    |    [281:281] <CPPComment> = ♢//•Also•set•the•font♢
|    |    |    |    |    |    [281:282] <Newline> = ♢¶♢
|    |    |    |    |    |    [282:282] <Indenting> = ♢→♢
|    |    |    |    |    |    [282:282] <ObjCMethodCall>
|    |    |    |    |    |    |    [282:282] <Match> = ♢[♢
|    |    |    |    |    |    |    [282:282] <Match> = ♢textAttributes♢
|    |    |    |    |    |    |    [282:282] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [282:282] <Text> = ♢setObject♢
|    |    |    |    |    |    |    [282:282] <Colon> = ♢:♢
|    |    |    |    |    |    |    [282:282] <Text> = ♢plainFont♢
|    |    |    |    |    |    |    [282:282] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [282:282] <Text> = ♢forKey♢
|    |    |    |    |    |    |    [282:282] <Colon> = ♢:♢
|    |    |    |    |    |    |    [282:282] <Text> = ♢NSFontAttributeName♢
|    |    |    |    |    |    |    [282:282] <Match> = ♢]♢
|    |    |    |    |    |    [282:282] <Semicolon> = ♢;♢
|    |    |    |    |    |    [282:283] <Newline> = ♢¶♢
|    |    |    |    |    |    [283:283] <Indenting> = ♢••••♢
|    |    |    |    |    |    [283:283] <Match> = ♢}♢
|    |    |    |    [283:284] <Newline> = ♢¶♢
|    |    |    |    [284:284] <Indenting> = ♢••••♢
|    |    |    |    [284:284] <CFlowReturn>
|    |    |    |    |    [284:284] <Match> = ♢return♢
|    |    |    |    |    [284:284] <Whitespace> = ♢•♢
|    |    |    |    |    [284:284] <Text> = ♢textAttributes♢
|    |    |    |    |    [284:284] <Semicolon> = ♢;♢
|    |    |    |    [284:285] <Newline> = ♢¶♢
|    |    |    |    [285:285] <Match> = ♢}♢
|    |    [285:286] <Newline> = ♢¶♢
|    |    [286:287] <Newline> = ♢¶♢
|    |    [287:302] <ObjCMethodImplementation>
|    |    |    [287:287] <Match> = ♢-♢
|    |    |    [287:287] <Whitespace> = ♢•♢
|    |    |    [287:287] <Parenthesis>
|    |    |    |    [287:287] <Match> = ♢(♢
|    |    |    |    [287:287] <CVoid> = ♢void♢
|    |    |    |    [287:287] <Match> = ♢)♢
|    |    |    [287:287] <Text> = ♢applyDefaultTextAttributes♢
|    |    |    [287:287] <Colon> = ♢:♢
|    |    |    [287:287] <Parenthesis>
|    |    |    |    [287:287] <Match> = ♢(♢
|    |    |    |    [287:287] <Text> = ♢BOOL♢
|    |    |    |    [287:287] <Match> = ♢)♢
|    |    |    [287:287] <Text> = ♢forRichText♢
|    |    |    [287:287] <Whitespace> = ♢•♢
|    |    |    [287:302] <Braces>
|    |    |    |    [287:287] <Match> = ♢{♢
|    |    |    |    [287:288] <Newline> = ♢¶♢
|    |    |    |    [288:288] <Indenting> = ♢••••♢
|    |    |    |    [288:288] <Text> = ♢NSDictionary♢
|    |    |    |    [288:288] <Whitespace> = ♢•♢
|    |    |    |    [288:288] <Asterisk> = ♢*♢
|    |    |    |    [288:288] <Text> = ♢textAttributes♢
|    |    |    |    [288:288] <Whitespace> = ♢•♢
|    |    |    |    [288:288] <Text> = ♢=♢
|    |    |    |    [288:288] <Whitespace> = ♢•♢
|    |    |    |    [288:288] <ObjCMethodCall>
|    |    |    |    |    [288:288] <Match> = ♢[♢
|    |    |    |    |    [288:288] <ObjCSelf> = ♢self♢
|    |    |    |    |    [288:288] <Whitespace> = ♢•♢
|    |    |    |    |    [288:288] <Text> = ♢defaultTextAttributes♢
|    |    |    |    |    [288:288] <Colon> = ♢:♢
|    |    |    |    |    [288:288] <Text> = ♢forRichText♢
|    |    |    |    |    [288:288] <Match> = ♢]♢
|    |    |    |    [288:288] <Semicolon> = ♢;♢
|    |    |    |    [288:289] <Newline> = ♢¶♢
|    |    |    |    [289:289] <Indenting> = ♢••••♢
|    |    |    |    [289:289] <Text> = ♢NSTextStorage♢
|    |    |    |    [289:289] <Whitespace> = ♢•♢
|    |    |    |    [289:289] <Asterisk> = ♢*♢
|    |    |    |    [289:289] <Text> = ♢text♢
|    |    |    |    [289:289] <Whitespace> = ♢•♢
|    |    |    |    [289:289] <Text> = ♢=♢
|    |    |    |    [289:289] <Whitespace> = ♢•♢
|    |    |    |    [289:289] <ObjCMethodCall>
|    |    |    |    |    [289:289] <Match> = ♢[♢
|    |    |    |    |    [289:289] <ObjCSelf> = ♢self♢
|    |    |    |    |    [289:289] <Whitespace> = ♢•♢
|    |    |    |    |    [289:289] <Text> = ♢textStorage♢
|    |    |    |    |    [289:289] <Match> = ♢]♢
|    |    |    |    [289:289] <Semicolon> = ♢;♢
|    |    |    |    [289:290] <Newline> = ♢¶♢
|    |    |    |    [290:290] <Indenting> = ♢••••♢
|    |    |    |    [290:290] <CPPComment> = ♢//•We•now•preserve•base•writing•direction•even•for•plain•text,•using•the•10.6-introduced•attribute•enumeration•API♢
|    |    |    |    [290:291] <Newline> = ♢¶♢
|    |    |    |    [291:291] <Indenting> = ♢••••♢
|    |    |    |    [291:301] <ObjCMethodCall>
|    |    |    |    |    [291:291] <Match> = ♢[♢
|    |    |    |    |    [291:291] <Match> = ♢text♢
|    |    |    |    |    [291:291] <Whitespace> = ♢•♢
|    |    |    |    |    [291:291] <Text> = ♢enumerateAttribute♢
|    |    |    |    |    [291:291] <Colon> = ♢:♢
|    |    |    |    |    [291:291] <Text> = ♢NSParagraphStyleAttributeName♢
|    |    |    |    |    [291:291] <Whitespace> = ♢•♢
|    |    |    |    |    [291:291] <Text> = ♢inRange♢
|    |    |    |    |    [291:291] <Colon> = ♢:♢
|    |    |    |    |    [291:291] <CFunctionCall>
|    |    |    |    |    |    [291:291] <Match> = ♢NSMakeRange♢
|    |    |    |    |    |    [291:291] <Parenthesis>
|    |    |    |    |    |    |    [291:291] <Match> = ♢(♢
|    |    |    |    |    |    |    [291:291] <Text> = ♢0,♢
|    |    |    |    |    |    |    [291:291] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [291:291] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [291:291] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [291:291] <Match> = ♢text♢
|    |    |    |    |    |    |    |    [291:291] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [291:291] <Text> = ♢length♢
|    |    |    |    |    |    |    |    [291:291] <Match> = ♢]♢
|    |    |    |    |    |    |    [291:291] <Match> = ♢)♢
|    |    |    |    |    [291:291] <Whitespace> = ♢•♢
|    |    |    |    |    [291:291] <Text> = ♢options♢
|    |    |    |    |    [291:291] <Colon> = ♢:♢
|    |    |    |    |    [291:291] <Text> = ♢0♢
|    |    |    |    |    [291:291] <Whitespace> = ♢•♢
|    |    |    |    |    [291:291] <Text> = ♢usingBlock♢
|    |    |    |    |    [291:291] <Colon> = ♢:♢
|    |    |    |    |    [291:291] <Caret> = ♢^♢
|    |    |    |    |    [291:291] <Parenthesis>
|    |    |    |    |    |    [291:291] <Match> = ♢(♢
|    |    |    |    |    |    [291:291] <Text> = ♢id♢
|    |    |    |    |    |    [291:291] <Whitespace> = ♢•♢
|    |    |    |    |    |    [291:291] <Text> = ♢paragraphStyle,♢
|    |    |    |    |    |    [291:291] <Whitespace> = ♢•♢
|    |    |    |    |    |    [291:291] <Text> = ♢NSRange♢
|    |    |    |    |    |    [291:291] <Whitespace> = ♢•♢
|    |    |    |    |    |    [291:291] <Text> = ♢paragraphStyleRange,♢
|    |    |    |    |    |    [291:291] <Whitespace> = ♢•♢
|    |    |    |    |    |    [291:291] <Text> = ♢BOOL♢
|    |    |    |    |    |    [291:291] <Whitespace> = ♢•♢
|    |    |    |    |    |    [291:291] <Asterisk> = ♢*♢
|    |    |    |    |    |    [291:291] <Text> = ♢stop♢
|    |    |    |    |    |    [291:291] <Match> = ♢)♢
|    |    |    |    |    [291:301] <Braces>
|    |    |    |    |    |    [291:291] <Match> = ♢{♢
|    |    |    |    |    |    [291:292] <Newline> = ♢¶♢
|    |    |    |    |    |    [292:292] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [292:292] <Text> = ♢NSWritingDirection♢
|    |    |    |    |    |    [292:292] <Whitespace> = ♢•♢
|    |    |    |    |    |    [292:292] <Text> = ♢writingDirection♢
|    |    |    |    |    |    [292:292] <Whitespace> = ♢•♢
|    |    |    |    |    |    [292:292] <Text> = ♢=♢
|    |    |    |    |    |    [292:292] <Whitespace> = ♢•♢
|    |    |    |    |    |    [292:292] <Text> = ♢paragraphStyle♢
|    |    |    |    |    |    [292:292] <Whitespace> = ♢•♢
|    |    |    |    |    |    [292:292] <QuestionMark> = ♢?♢
|    |    |    |    |    |    [292:292] <Whitespace> = ♢•♢
|    |    |    |    |    |    [292:292] <Brackets>
|    |    |    |    |    |    |    [292:292] <Match> = ♢[♢
|    |    |    |    |    |    |    [292:292] <Parenthesis>
|    |    |    |    |    |    |    |    [292:292] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [292:292] <Text> = ♢NSParagraphStyle♢
|    |    |    |    |    |    |    |    [292:292] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [292:292] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [292:292] <Match> = ♢)♢
|    |    |    |    |    |    |    [292:292] <Text> = ♢paragraphStyle♢
|    |    |    |    |    |    |    [292:292] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [292:292] <Text> = ♢baseWritingDirection♢
|    |    |    |    |    |    |    [292:292] <Match> = ♢]♢
|    |    |    |    |    |    [292:292] <Whitespace> = ♢•♢
|    |    |    |    |    |    [292:292] <Colon> = ♢:♢
|    |    |    |    |    |    [292:292] <Whitespace> = ♢•♢
|    |    |    |    |    |    [292:292] <Text> = ♢NSWritingDirectionNatural♢
|    |    |    |    |    |    [292:292] <Semicolon> = ♢;♢
|    |    |    |    |    |    [292:293] <Newline> = ♢¶♢
|    |    |    |    |    |    [293:293] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [293:293] <CPPComment> = ♢//•We•also•preserve•NSWritingDirectionAttributeName•(new•in•10.6)♢
|    |    |    |    |    |    [293:294] <Newline> = ♢¶♢
|    |    |    |    |    |    [294:294] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [294:299] <ObjCMethodCall>
|    |    |    |    |    |    |    [294:294] <Match> = ♢[♢
|    |    |    |    |    |    |    [294:294] <Match> = ♢text♢
|    |    |    |    |    |    |    [294:294] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [294:294] <Text> = ♢enumerateAttribute♢
|    |    |    |    |    |    |    [294:294] <Colon> = ♢:♢
|    |    |    |    |    |    |    [294:294] <Text> = ♢NSWritingDirectionAttributeName♢
|    |    |    |    |    |    |    [294:294] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [294:294] <Text> = ♢inRange♢
|    |    |    |    |    |    |    [294:294] <Colon> = ♢:♢
|    |    |    |    |    |    |    [294:294] <Text> = ♢paragraphStyleRange♢
|    |    |    |    |    |    |    [294:294] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [294:294] <Text> = ♢options♢
|    |    |    |    |    |    |    [294:294] <Colon> = ♢:♢
|    |    |    |    |    |    |    [294:294] <Text> = ♢0♢
|    |    |    |    |    |    |    [294:294] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [294:294] <Text> = ♢usingBlock♢
|    |    |    |    |    |    |    [294:294] <Colon> = ♢:♢
|    |    |    |    |    |    |    [294:294] <Caret> = ♢^♢
|    |    |    |    |    |    |    [294:294] <Parenthesis>
|    |    |    |    |    |    |    |    [294:294] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [294:294] <Text> = ♢id♢
|    |    |    |    |    |    |    |    [294:294] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [294:294] <Text> = ♢value,♢
|    |    |    |    |    |    |    |    [294:294] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [294:294] <Text> = ♢NSRange♢
|    |    |    |    |    |    |    |    [294:294] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [294:294] <Text> = ♢attributeRange,♢
|    |    |    |    |    |    |    |    [294:294] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [294:294] <Text> = ♢BOOL♢
|    |    |    |    |    |    |    |    [294:294] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [294:294] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [294:294] <Text> = ♢stop♢
|    |    |    |    |    |    |    |    [294:294] <Match> = ♢)♢
|    |    |    |    |    |    |    [294:299] <Braces>
|    |    |    |    |    |    |    |    [294:294] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [294:295] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [295:295] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [295:295] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [295:295] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [295:295] <Match> = ♢value♢
|    |    |    |    |    |    |    |    |    [295:295] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [295:295] <Text> = ♢retain♢
|    |    |    |    |    |    |    |    |    [295:295] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [295:295] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [295:296] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [296:296] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [296:296] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [296:296] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [296:296] <Match> = ♢text♢
|    |    |    |    |    |    |    |    |    [296:296] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [296:296] <Text> = ♢setAttributes♢
|    |    |    |    |    |    |    |    |    [296:296] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [296:296] <Text> = ♢textAttributes♢
|    |    |    |    |    |    |    |    |    [296:296] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [296:296] <Text> = ♢range♢
|    |    |    |    |    |    |    |    |    [296:296] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [296:296] <Text> = ♢attributeRange♢
|    |    |    |    |    |    |    |    |    [296:296] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [296:296] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [296:297] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [297:297] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [297:297] <CConditionIf>
|    |    |    |    |    |    |    |    |    [297:297] <Match> = ♢if♢
|    |    |    |    |    |    |    |    |    [297:297] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [297:297] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [297:297] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [297:297] <Text> = ♢value♢
|    |    |    |    |    |    |    |    |    |    [297:297] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [297:297] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [297:297] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [297:297] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [297:297] <Match> = ♢text♢
|    |    |    |    |    |    |    |    |    |    [297:297] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [297:297] <Text> = ♢addAttribute♢
|    |    |    |    |    |    |    |    |    |    [297:297] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [297:297] <Text> = ♢NSWritingDirectionAttributeName♢
|    |    |    |    |    |    |    |    |    |    [297:297] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [297:297] <Text> = ♢value♢
|    |    |    |    |    |    |    |    |    |    [297:297] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [297:297] <Text> = ♢value♢
|    |    |    |    |    |    |    |    |    |    [297:297] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [297:297] <Text> = ♢range♢
|    |    |    |    |    |    |    |    |    |    [297:297] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [297:297] <Text> = ♢attributeRange♢
|    |    |    |    |    |    |    |    |    |    [297:297] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [297:297] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [297:298] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [298:298] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [298:298] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [298:298] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [298:298] <Match> = ♢value♢
|    |    |    |    |    |    |    |    |    [298:298] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [298:298] <Text> = ♢release♢
|    |    |    |    |    |    |    |    |    [298:298] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [298:298] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [298:299] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [299:299] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    |    |    [299:299] <Match> = ♢}♢
|    |    |    |    |    |    |    [299:299] <Match> = ♢]♢
|    |    |    |    |    |    [299:299] <Semicolon> = ♢;♢
|    |    |    |    |    |    [299:300] <Newline> = ♢¶♢
|    |    |    |    |    |    [300:300] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [300:300] <CConditionIf>
|    |    |    |    |    |    |    [300:300] <Match> = ♢if♢
|    |    |    |    |    |    |    [300:300] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [300:300] <Parenthesis>
|    |    |    |    |    |    |    |    [300:300] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [300:300] <Text> = ♢writingDirection♢
|    |    |    |    |    |    |    |    [300:300] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [300:300] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    [300:300] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [300:300] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [300:300] <Text> = ♢NSWritingDirectionNatural♢
|    |    |    |    |    |    |    |    [300:300] <Match> = ♢)♢
|    |    |    |    |    |    |    [300:300] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [300:300] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [300:300] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [300:300] <Match> = ♢text♢
|    |    |    |    |    |    |    |    [300:300] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [300:300] <Text> = ♢setBaseWritingDirection♢
|    |    |    |    |    |    |    |    [300:300] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [300:300] <Text> = ♢writingDirection♢
|    |    |    |    |    |    |    |    [300:300] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [300:300] <Text> = ♢range♢
|    |    |    |    |    |    |    |    [300:300] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [300:300] <Text> = ♢paragraphStyleRange♢
|    |    |    |    |    |    |    |    [300:300] <Match> = ♢]♢
|    |    |    |    |    |    |    [300:300] <Semicolon> = ♢;♢
|    |    |    |    |    |    [300:301] <Newline> = ♢¶♢
|    |    |    |    |    |    [301:301] <Indenting> = ♢••••♢
|    |    |    |    |    |    [301:301] <Match> = ♢}♢
|    |    |    |    |    [301:301] <Match> = ♢]♢
|    |    |    |    [301:301] <Semicolon> = ♢;♢
|    |    |    |    [301:302] <Newline> = ♢¶♢
|    |    |    |    [302:302] <Match> = ♢}♢
|    |    [302:303] <Newline> = ♢¶♢
|    |    [303:304] <Newline> = ♢¶♢
|    |    [304:305] <Newline> = ♢¶♢
|    |    [305:306] <CComment> = ♢/*•This•method•will•return•a•suggested•encoding•for•the•document.•In•Leopard,•unless•the•user•has•specified•a•favorite•encoding•for•saving•that•applies•to•the•document,•we•use•UTF-8.¶*/♢
|    |    [306:307] <Newline> = ♢¶♢
|    |    [307:318] <ObjCMethodImplementation>
|    |    |    [307:307] <Match> = ♢-♢
|    |    |    [307:307] <Whitespace> = ♢•♢
|    |    |    [307:307] <Parenthesis>
|    |    |    |    [307:307] <Match> = ♢(♢
|    |    |    |    [307:307] <Text> = ♢NSStringEncoding♢
|    |    |    |    [307:307] <Match> = ♢)♢
|    |    |    [307:307] <Text> = ♢suggestedDocumentEncoding♢
|    |    |    [307:307] <Whitespace> = ♢•♢
|    |    |    [307:318] <Braces>
|    |    |    |    [307:307] <Match> = ♢{♢
|    |    |    |    [307:308] <Newline> = ♢¶♢
|    |    |    |    [308:308] <Indenting> = ♢••••♢
|    |    |    |    [308:308] <Text> = ♢NSUInteger♢
|    |    |    |    [308:308] <Whitespace> = ♢•♢
|    |    |    |    [308:308] <Text> = ♢enc♢
|    |    |    |    [308:308] <Whitespace> = ♢•♢
|    |    |    |    [308:308] <Text> = ♢=♢
|    |    |    |    [308:308] <Whitespace> = ♢•♢
|    |    |    |    [308:308] <Text> = ♢NoStringEncoding♢
|    |    |    |    [308:308] <Semicolon> = ♢;♢
|    |    |    |    [308:309] <Newline> = ♢¶♢
|    |    |    |    [309:309] <Indenting> = ♢••••♢
|    |    |    |    [309:309] <Text> = ♢NSNumber♢
|    |    |    |    [309:309] <Whitespace> = ♢•♢
|    |    |    |    [309:309] <Asterisk> = ♢*♢
|    |    |    |    [309:309] <Text> = ♢val♢
|    |    |    |    [309:309] <Whitespace> = ♢•♢
|    |    |    |    [309:309] <Text> = ♢=♢
|    |    |    |    [309:309] <Whitespace> = ♢•♢
|    |    |    |    [309:309] <ObjCMethodCall>
|    |    |    |    |    [309:309] <Match> = ♢[♢
|    |    |    |    |    [309:309] <ObjCMethodCall>
|    |    |    |    |    |    [309:309] <Match> = ♢[♢
|    |    |    |    |    |    [309:309] <Match> = ♢NSUserDefaults♢
|    |    |    |    |    |    [309:309] <Whitespace> = ♢•♢
|    |    |    |    |    |    [309:309] <Text> = ♢standardUserDefaults♢
|    |    |    |    |    |    [309:309] <Match> = ♢]♢
|    |    |    |    |    [309:309] <Whitespace> = ♢•♢
|    |    |    |    |    [309:309] <Text> = ♢objectForKey♢
|    |    |    |    |    [309:309] <Colon> = ♢:♢
|    |    |    |    |    [309:309] <Text> = ♢PlainTextEncodingForWrite♢
|    |    |    |    |    [309:309] <Match> = ♢]♢
|    |    |    |    [309:309] <Semicolon> = ♢;♢
|    |    |    |    [309:310] <Newline> = ♢¶♢
|    |    |    |    [310:310] <Indenting> = ♢••••♢
|    |    |    |    [310:315] <CConditionIf>
|    |    |    |    |    [310:310] <Match> = ♢if♢
|    |    |    |    |    [310:310] <Whitespace> = ♢•♢
|    |    |    |    |    [310:310] <Parenthesis>
|    |    |    |    |    |    [310:310] <Match> = ♢(♢
|    |    |    |    |    |    [310:310] <Text> = ♢val♢
|    |    |    |    |    |    [310:310] <Match> = ♢)♢
|    |    |    |    |    [310:310] <Whitespace> = ♢•♢
|    |    |    |    |    [310:315] <Braces>
|    |    |    |    |    |    [310:310] <Match> = ♢{♢
|    |    |    |    |    |    [310:311] <Newline> = ♢¶♢
|    |    |    |    |    |    [311:311] <Indenting> = ♢→♢
|    |    |    |    |    |    [311:311] <Text> = ♢NSStringEncoding♢
|    |    |    |    |    |    [311:311] <Whitespace> = ♢•♢
|    |    |    |    |    |    [311:311] <Text> = ♢chosenEncoding♢
|    |    |    |    |    |    [311:311] <Whitespace> = ♢•♢
|    |    |    |    |    |    [311:311] <Text> = ♢=♢
|    |    |    |    |    |    [311:311] <Whitespace> = ♢•♢
|    |    |    |    |    |    [311:311] <ObjCMethodCall>
|    |    |    |    |    |    |    [311:311] <Match> = ♢[♢
|    |    |    |    |    |    |    [311:311] <Match> = ♢val♢
|    |    |    |    |    |    |    [311:311] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [311:311] <Text> = ♢unsignedIntegerValue♢
|    |    |    |    |    |    |    [311:311] <Match> = ♢]♢
|    |    |    |    |    |    [311:311] <Semicolon> = ♢;♢
|    |    |    |    |    |    [311:312] <Newline> = ♢¶♢
|    |    |    |    |    |    [312:312] <Indenting> = ♢→♢
|    |    |    |    |    |    [312:314] <CConditionIf>
|    |    |    |    |    |    |    [312:312] <Match> = ♢if♢
|    |    |    |    |    |    |    [312:312] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [312:312] <Parenthesis>
|    |    |    |    |    |    |    |    [312:312] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [312:312] <Parenthesis>
|    |    |    |    |    |    |    |    |    [312:312] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    [312:312] <Text> = ♢chosenEncoding♢
|    |    |    |    |    |    |    |    |    [312:312] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [312:312] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    |    [312:312] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    [312:312] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [312:312] <Text> = ♢NoStringEncoding♢
|    |    |    |    |    |    |    |    |    [312:312] <Match> = ♢)♢
|    |    |    |    |    |    |    |    [312:312] <Whitespace> = ♢••♢
|    |    |    |    |    |    |    |    [312:312] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    [312:312] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    [312:312] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [312:312] <Parenthesis>
|    |    |    |    |    |    |    |    |    [312:312] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    [312:312] <Text> = ♢chosenEncoding♢
|    |    |    |    |    |    |    |    |    [312:312] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [312:312] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    |    [312:312] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    [312:312] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [312:312] <Text> = ♢NSUnicodeStringEncoding♢
|    |    |    |    |    |    |    |    |    [312:312] <Match> = ♢)♢
|    |    |    |    |    |    |    |    [312:312] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [312:312] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    [312:312] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    [312:312] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [312:312] <Parenthesis>
|    |    |    |    |    |    |    |    |    [312:312] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    [312:312] <Text> = ♢chosenEncoding♢
|    |    |    |    |    |    |    |    |    [312:312] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [312:312] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    |    [312:312] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    [312:312] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [312:312] <Text> = ♢NSUTF8StringEncoding♢
|    |    |    |    |    |    |    |    |    [312:312] <Match> = ♢)♢
|    |    |    |    |    |    |    |    [312:312] <Match> = ♢)♢
|    |    |    |    |    |    |    [312:312] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [312:314] <Braces>
|    |    |    |    |    |    |    |    [312:312] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [312:313] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [313:313] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [313:313] <CConditionIf>
|    |    |    |    |    |    |    |    |    [313:313] <Match> = ♢if♢
|    |    |    |    |    |    |    |    |    [313:313] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [313:313] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [313:313] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [313:313] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [313:313] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [313:313] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    [313:313] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    [313:313] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    [313:313] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [313:313] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [313:313] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [313:313] <Text> = ♢textStorage♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [313:313] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    |    [313:313] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [313:313] <Text> = ♢string♢
|    |    |    |    |    |    |    |    |    |    |    |    [313:313] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    [313:313] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [313:313] <Text> = ♢canBeConvertedToEncoding♢
|    |    |    |    |    |    |    |    |    |    |    [313:313] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    [313:313] <Text> = ♢chosenEncoding♢
|    |    |    |    |    |    |    |    |    |    |    [313:313] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [313:313] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [313:313] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [313:313] <Text> = ♢enc♢
|    |    |    |    |    |    |    |    |    [313:313] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [313:313] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    [313:313] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [313:313] <Text> = ♢chosenEncoding♢
|    |    |    |    |    |    |    |    |    [313:313] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [313:314] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [314:314] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [314:314] <Match> = ♢}♢
|    |    |    |    |    |    [314:315] <Newline> = ♢¶♢
|    |    |    |    |    |    [315:315] <Indenting> = ♢••••♢
|    |    |    |    |    |    [315:315] <Match> = ♢}♢
|    |    |    |    [315:316] <Newline> = ♢¶♢
|    |    |    |    [316:316] <Indenting> = ♢••••♢
|    |    |    |    [316:316] <CConditionIf>
|    |    |    |    |    [316:316] <Match> = ♢if♢
|    |    |    |    |    [316:316] <Whitespace> = ♢•♢
|    |    |    |    |    [316:316] <Parenthesis>
|    |    |    |    |    |    [316:316] <Match> = ♢(♢
|    |    |    |    |    |    [316:316] <Text> = ♢enc♢
|    |    |    |    |    |    [316:316] <Whitespace> = ♢•♢
|    |    |    |    |    |    [316:316] <Text> = ♢==♢
|    |    |    |    |    |    [316:316] <Whitespace> = ♢•♢
|    |    |    |    |    |    [316:316] <Text> = ♢NoStringEncoding♢
|    |    |    |    |    |    [316:316] <Match> = ♢)♢
|    |    |    |    |    [316:316] <Whitespace> = ♢•♢
|    |    |    |    |    [316:316] <Text> = ♢enc♢
|    |    |    |    |    [316:316] <Whitespace> = ♢•♢
|    |    |    |    |    [316:316] <Text> = ♢=♢
|    |    |    |    |    [316:316] <Whitespace> = ♢•♢
|    |    |    |    |    [316:316] <Text> = ♢NSUTF8StringEncoding♢
|    |    |    |    |    [316:316] <Semicolon> = ♢;♢
|    |    |    |    [316:316] <Whitespace> = ♢→♢
|    |    |    |    [316:316] <CPPComment> = ♢//•Default•to•UTF-8♢
|    |    |    |    [316:317] <Newline> = ♢¶♢
|    |    |    |    [317:317] <Indenting> = ♢••••♢
|    |    |    |    [317:317] <CFlowReturn>
|    |    |    |    |    [317:317] <Match> = ♢return♢
|    |    |    |    |    [317:317] <Whitespace> = ♢•♢
|    |    |    |    |    [317:317] <Text> = ♢enc♢
|    |    |    |    |    [317:317] <Semicolon> = ♢;♢
|    |    |    |    [317:318] <Newline> = ♢¶♢
|    |    |    |    [318:318] <Match> = ♢}♢
|    |    [318:319] <Newline> = ♢¶♢
|    |    [319:320] <Newline> = ♢¶♢
|    |    [320:321] <CComment> = ♢/*•Returns•an•object•that•represents•the•document•to•be•written•to•file.•¶*/♢
|    |    [321:322] <Newline> = ♢¶♢
|    |    [322:409] <ObjCMethodImplementation>
|    |    |    [322:322] <Match> = ♢-♢
|    |    |    [322:322] <Whitespace> = ♢•♢
|    |    |    [322:322] <Parenthesis>
|    |    |    |    [322:322] <Match> = ♢(♢
|    |    |    |    [322:322] <Text> = ♢id♢
|    |    |    |    [322:322] <Match> = ♢)♢
|    |    |    [322:322] <Text> = ♢fileWrapperOfType♢
|    |    |    [322:322] <Colon> = ♢:♢
|    |    |    [322:322] <Parenthesis>
|    |    |    |    [322:322] <Match> = ♢(♢
|    |    |    |    [322:322] <Text> = ♢NSString♢
|    |    |    |    [322:322] <Whitespace> = ♢•♢
|    |    |    |    [322:322] <Asterisk> = ♢*♢
|    |    |    |    [322:322] <Match> = ♢)♢
|    |    |    [322:322] <Text> = ♢typeName♢
|    |    |    [322:322] <Whitespace> = ♢•♢
|    |    |    [322:322] <Text> = ♢error♢
|    |    |    [322:322] <Colon> = ♢:♢
|    |    |    [322:322] <Parenthesis>
|    |    |    |    [322:322] <Match> = ♢(♢
|    |    |    |    [322:322] <Text> = ♢NSError♢
|    |    |    |    [322:322] <Whitespace> = ♢•♢
|    |    |    |    [322:322] <Asterisk> = ♢*♢
|    |    |    |    [322:322] <Asterisk> = ♢*♢
|    |    |    |    [322:322] <Match> = ♢)♢
|    |    |    [322:322] <Text> = ♢outError♢
|    |    |    [322:322] <Whitespace> = ♢•♢
|    |    |    [322:409] <Braces>
|    |    |    |    [322:322] <Match> = ♢{♢
|    |    |    |    [322:323] <Newline> = ♢¶♢
|    |    |    |    [323:323] <Indenting> = ♢••••♢
|    |    |    |    [323:323] <Text> = ♢NSTextStorage♢
|    |    |    |    [323:323] <Whitespace> = ♢•♢
|    |    |    |    [323:323] <Asterisk> = ♢*♢
|    |    |    |    [323:323] <Text> = ♢text♢
|    |    |    |    [323:323] <Whitespace> = ♢•♢
|    |    |    |    [323:323] <Text> = ♢=♢
|    |    |    |    [323:323] <Whitespace> = ♢•♢
|    |    |    |    [323:323] <ObjCMethodCall>
|    |    |    |    |    [323:323] <Match> = ♢[♢
|    |    |    |    |    [323:323] <ObjCSelf> = ♢self♢
|    |    |    |    |    [323:323] <Whitespace> = ♢•♢
|    |    |    |    |    [323:323] <Text> = ♢textStorage♢
|    |    |    |    |    [323:323] <Match> = ♢]♢
|    |    |    |    [323:323] <Semicolon> = ♢;♢
|    |    |    |    [323:324] <Newline> = ♢¶♢
|    |    |    |    [324:324] <Indenting> = ♢••••♢
|    |    |    |    [324:324] <Text> = ♢NSRange♢
|    |    |    |    [324:324] <Whitespace> = ♢•♢
|    |    |    |    [324:324] <Text> = ♢range♢
|    |    |    |    [324:324] <Whitespace> = ♢•♢
|    |    |    |    [324:324] <Text> = ♢=♢
|    |    |    |    [324:324] <Whitespace> = ♢•♢
|    |    |    |    [324:324] <CFunctionCall>
|    |    |    |    |    [324:324] <Match> = ♢NSMakeRange♢
|    |    |    |    |    [324:324] <Parenthesis>
|    |    |    |    |    |    [324:324] <Match> = ♢(♢
|    |    |    |    |    |    [324:324] <Text> = ♢0,♢
|    |    |    |    |    |    [324:324] <Whitespace> = ♢•♢
|    |    |    |    |    |    [324:324] <ObjCMethodCall>
|    |    |    |    |    |    |    [324:324] <Match> = ♢[♢
|    |    |    |    |    |    |    [324:324] <Match> = ♢text♢
|    |    |    |    |    |    |    [324:324] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [324:324] <Text> = ♢length♢
|    |    |    |    |    |    |    [324:324] <Match> = ♢]♢
|    |    |    |    |    |    [324:324] <Match> = ♢)♢
|    |    |    |    [324:324] <Semicolon> = ♢;♢
|    |    |    |    [324:325] <Newline> = ♢¶♢
|    |    |    |    [325:326] <Newline> = ♢¶♢
|    |    |    |    [326:326] <Indenting> = ♢••••♢
|    |    |    |    [326:326] <Text> = ♢NSMutableDictionary♢
|    |    |    |    [326:326] <Whitespace> = ♢•♢
|    |    |    |    [326:326] <Asterisk> = ♢*♢
|    |    |    |    [326:326] <Text> = ♢dict♢
|    |    |    |    [326:326] <Whitespace> = ♢•♢
|    |    |    |    [326:326] <Text> = ♢=♢
|    |    |    |    [326:326] <Whitespace> = ♢•♢
|    |    |    |    [326:335] <ObjCMethodCall>
|    |    |    |    |    [326:326] <Match> = ♢[♢
|    |    |    |    |    [326:326] <Match> = ♢NSMutableDictionary♢
|    |    |    |    |    [326:326] <Whitespace> = ♢•♢
|    |    |    |    |    [326:326] <Text> = ♢dictionaryWithObjectsAndKeys♢
|    |    |    |    |    [326:326] <Colon> = ♢:♢
|    |    |    |    |    [326:327] <Newline> = ♢¶♢
|    |    |    |    |    [327:327] <Indenting> = ♢→♢
|    |    |    |    |    [327:327] <ObjCMethodCall>
|    |    |    |    |    |    [327:327] <Match> = ♢[♢
|    |    |    |    |    |    [327:327] <Match> = ♢NSValue♢
|    |    |    |    |    |    [327:327] <Whitespace> = ♢•♢
|    |    |    |    |    |    [327:327] <Text> = ♢valueWithSize♢
|    |    |    |    |    |    [327:327] <Colon> = ♢:♢
|    |    |    |    |    |    [327:327] <ObjCMethodCall>
|    |    |    |    |    |    |    [327:327] <Match> = ♢[♢
|    |    |    |    |    |    |    [327:327] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [327:327] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [327:327] <Text> = ♢paperSize♢
|    |    |    |    |    |    |    [327:327] <Match> = ♢]♢
|    |    |    |    |    |    [327:327] <Match> = ♢]♢
|    |    |    |    |    [327:327] <Text> = ♢,♢
|    |    |    |    |    [327:327] <Whitespace> = ♢•♢
|    |    |    |    |    [327:327] <Text> = ♢NSPaperSizeDocumentAttribute,♢
|    |    |    |    |    [327:327] <Whitespace> = ♢•♢
|    |    |    |    |    [327:328] <Newline> = ♢¶♢
|    |    |    |    |    [328:328] <Indenting> = ♢→♢
|    |    |    |    |    [328:328] <ObjCMethodCall>
|    |    |    |    |    |    [328:328] <Match> = ♢[♢
|    |    |    |    |    |    [328:328] <Match> = ♢NSNumber♢
|    |    |    |    |    |    [328:328] <Whitespace> = ♢•♢
|    |    |    |    |    |    [328:328] <Text> = ♢numberWithInteger♢
|    |    |    |    |    |    [328:328] <Colon> = ♢:♢
|    |    |    |    |    |    [328:328] <ObjCMethodCall>
|    |    |    |    |    |    |    [328:328] <Match> = ♢[♢
|    |    |    |    |    |    |    [328:328] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [328:328] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [328:328] <Text> = ♢isReadOnly♢
|    |    |    |    |    |    |    [328:328] <Match> = ♢]♢
|    |    |    |    |    |    [328:328] <Whitespace> = ♢•♢
|    |    |    |    |    |    [328:328] <QuestionMark> = ♢?♢
|    |    |    |    |    |    [328:328] <Whitespace> = ♢•♢
|    |    |    |    |    |    [328:328] <Text> = ♢1♢
|    |    |    |    |    |    [328:328] <Whitespace> = ♢•♢
|    |    |    |    |    |    [328:328] <Colon> = ♢:♢
|    |    |    |    |    |    [328:328] <Whitespace> = ♢•♢
|    |    |    |    |    |    [328:328] <Text> = ♢0♢
|    |    |    |    |    |    [328:328] <Match> = ♢]♢
|    |    |    |    |    [328:328] <Text> = ♢,♢
|    |    |    |    |    [328:328] <Whitespace> = ♢•♢
|    |    |    |    |    [328:328] <Text> = ♢NSReadOnlyDocumentAttribute,♢
|    |    |    |    |    [328:328] <Whitespace> = ♢•♢
|    |    |    |    |    [328:329] <Newline> = ♢¶♢
|    |    |    |    |    [329:329] <Indenting> = ♢→♢
|    |    |    |    |    [329:329] <ObjCMethodCall>
|    |    |    |    |    |    [329:329] <Match> = ♢[♢
|    |    |    |    |    |    [329:329] <Match> = ♢NSNumber♢
|    |    |    |    |    |    [329:329] <Whitespace> = ♢•♢
|    |    |    |    |    |    [329:329] <Text> = ♢numberWithFloat♢
|    |    |    |    |    |    [329:329] <Colon> = ♢:♢
|    |    |    |    |    |    [329:329] <ObjCMethodCall>
|    |    |    |    |    |    |    [329:329] <Match> = ♢[♢
|    |    |    |    |    |    |    [329:329] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [329:329] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [329:329] <Text> = ♢hyphenationFactor♢
|    |    |    |    |    |    |    [329:329] <Match> = ♢]♢
|    |    |    |    |    |    [329:329] <Match> = ♢]♢
|    |    |    |    |    [329:329] <Text> = ♢,♢
|    |    |    |    |    [329:329] <Whitespace> = ♢•♢
|    |    |    |    |    [329:329] <Text> = ♢NSHyphenationFactorDocumentAttribute,♢
|    |    |    |    |    [329:329] <Whitespace> = ♢•♢
|    |    |    |    |    [329:330] <Newline> = ♢¶♢
|    |    |    |    |    [330:330] <Indenting> = ♢→♢
|    |    |    |    |    [330:330] <ObjCMethodCall>
|    |    |    |    |    |    [330:330] <Match> = ♢[♢
|    |    |    |    |    |    [330:330] <Match> = ♢NSNumber♢
|    |    |    |    |    |    [330:330] <Whitespace> = ♢•♢
|    |    |    |    |    |    [330:330] <Text> = ♢numberWithDouble♢
|    |    |    |    |    |    [330:330] <Colon> = ♢:♢
|    |    |    |    |    |    [330:330] <ObjCMethodCall>
|    |    |    |    |    |    |    [330:330] <Match> = ♢[♢
|    |    |    |    |    |    |    [330:330] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [330:330] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [330:330] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [330:330] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [330:330] <Text> = ♢printInfo♢
|    |    |    |    |    |    |    |    [330:330] <Match> = ♢]♢
|    |    |    |    |    |    |    [330:330] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [330:330] <Text> = ♢leftMargin♢
|    |    |    |    |    |    |    [330:330] <Match> = ♢]♢
|    |    |    |    |    |    [330:330] <Match> = ♢]♢
|    |    |    |    |    [330:330] <Text> = ♢,♢
|    |    |    |    |    [330:330] <Whitespace> = ♢•♢
|    |    |    |    |    [330:330] <Text> = ♢NSLeftMarginDocumentAttribute,♢
|    |    |    |    |    [330:330] <Whitespace> = ♢•♢
|    |    |    |    |    [330:331] <Newline> = ♢¶♢
|    |    |    |    |    [331:331] <Indenting> = ♢→♢
|    |    |    |    |    [331:331] <ObjCMethodCall>
|    |    |    |    |    |    [331:331] <Match> = ♢[♢
|    |    |    |    |    |    [331:331] <Match> = ♢NSNumber♢
|    |    |    |    |    |    [331:331] <Whitespace> = ♢•♢
|    |    |    |    |    |    [331:331] <Text> = ♢numberWithDouble♢
|    |    |    |    |    |    [331:331] <Colon> = ♢:♢
|    |    |    |    |    |    [331:331] <ObjCMethodCall>
|    |    |    |    |    |    |    [331:331] <Match> = ♢[♢
|    |    |    |    |    |    |    [331:331] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [331:331] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [331:331] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [331:331] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [331:331] <Text> = ♢printInfo♢
|    |    |    |    |    |    |    |    [331:331] <Match> = ♢]♢
|    |    |    |    |    |    |    [331:331] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [331:331] <Text> = ♢rightMargin♢
|    |    |    |    |    |    |    [331:331] <Match> = ♢]♢
|    |    |    |    |    |    [331:331] <Match> = ♢]♢
|    |    |    |    |    [331:331] <Text> = ♢,♢
|    |    |    |    |    [331:331] <Whitespace> = ♢•♢
|    |    |    |    |    [331:331] <Text> = ♢NSRightMarginDocumentAttribute,♢
|    |    |    |    |    [331:331] <Whitespace> = ♢•♢
|    |    |    |    |    [331:332] <Newline> = ♢¶♢
|    |    |    |    |    [332:332] <Indenting> = ♢→♢
|    |    |    |    |    [332:332] <ObjCMethodCall>
|    |    |    |    |    |    [332:332] <Match> = ♢[♢
|    |    |    |    |    |    [332:332] <Match> = ♢NSNumber♢
|    |    |    |    |    |    [332:332] <Whitespace> = ♢•♢
|    |    |    |    |    |    [332:332] <Text> = ♢numberWithDouble♢
|    |    |    |    |    |    [332:332] <Colon> = ♢:♢
|    |    |    |    |    |    [332:332] <ObjCMethodCall>
|    |    |    |    |    |    |    [332:332] <Match> = ♢[♢
|    |    |    |    |    |    |    [332:332] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [332:332] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [332:332] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [332:332] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [332:332] <Text> = ♢printInfo♢
|    |    |    |    |    |    |    |    [332:332] <Match> = ♢]♢
|    |    |    |    |    |    |    [332:332] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [332:332] <Text> = ♢bottomMargin♢
|    |    |    |    |    |    |    [332:332] <Match> = ♢]♢
|    |    |    |    |    |    [332:332] <Match> = ♢]♢
|    |    |    |    |    [332:332] <Text> = ♢,♢
|    |    |    |    |    [332:332] <Whitespace> = ♢•♢
|    |    |    |    |    [332:332] <Text> = ♢NSBottomMarginDocumentAttribute,♢
|    |    |    |    |    [332:332] <Whitespace> = ♢•♢
|    |    |    |    |    [332:333] <Newline> = ♢¶♢
|    |    |    |    |    [333:333] <Indenting> = ♢→♢
|    |    |    |    |    [333:333] <ObjCMethodCall>
|    |    |    |    |    |    [333:333] <Match> = ♢[♢
|    |    |    |    |    |    [333:333] <Match> = ♢NSNumber♢
|    |    |    |    |    |    [333:333] <Whitespace> = ♢•♢
|    |    |    |    |    |    [333:333] <Text> = ♢numberWithDouble♢
|    |    |    |    |    |    [333:333] <Colon> = ♢:♢
|    |    |    |    |    |    [333:333] <ObjCMethodCall>
|    |    |    |    |    |    |    [333:333] <Match> = ♢[♢
|    |    |    |    |    |    |    [333:333] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [333:333] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [333:333] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [333:333] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [333:333] <Text> = ♢printInfo♢
|    |    |    |    |    |    |    |    [333:333] <Match> = ♢]♢
|    |    |    |    |    |    |    [333:333] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [333:333] <Text> = ♢topMargin♢
|    |    |    |    |    |    |    [333:333] <Match> = ♢]♢
|    |    |    |    |    |    [333:333] <Match> = ♢]♢
|    |    |    |    |    [333:333] <Text> = ♢,♢
|    |    |    |    |    [333:333] <Whitespace> = ♢•♢
|    |    |    |    |    [333:333] <Text> = ♢NSTopMarginDocumentAttribute,♢
|    |    |    |    |    [333:333] <Whitespace> = ♢•♢
|    |    |    |    |    [333:334] <Newline> = ♢¶♢
|    |    |    |    |    [334:334] <Indenting> = ♢→♢
|    |    |    |    |    [334:334] <ObjCMethodCall>
|    |    |    |    |    |    [334:334] <Match> = ♢[♢
|    |    |    |    |    |    [334:334] <Match> = ♢NSNumber♢
|    |    |    |    |    |    [334:334] <Whitespace> = ♢•♢
|    |    |    |    |    |    [334:334] <Text> = ♢numberWithInteger♢
|    |    |    |    |    |    [334:334] <Colon> = ♢:♢
|    |    |    |    |    |    [334:334] <ObjCMethodCall>
|    |    |    |    |    |    |    [334:334] <Match> = ♢[♢
|    |    |    |    |    |    |    [334:334] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [334:334] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [334:334] <Text> = ♢hasMultiplePages♢
|    |    |    |    |    |    |    [334:334] <Match> = ♢]♢
|    |    |    |    |    |    [334:334] <Whitespace> = ♢•♢
|    |    |    |    |    |    [334:334] <QuestionMark> = ♢?♢
|    |    |    |    |    |    [334:334] <Whitespace> = ♢•♢
|    |    |    |    |    |    [334:334] <Text> = ♢1♢
|    |    |    |    |    |    [334:334] <Whitespace> = ♢•♢
|    |    |    |    |    |    [334:334] <Colon> = ♢:♢
|    |    |    |    |    |    [334:334] <Whitespace> = ♢•♢
|    |    |    |    |    |    [334:334] <Text> = ♢0♢
|    |    |    |    |    |    [334:334] <Match> = ♢]♢
|    |    |    |    |    [334:334] <Text> = ♢,♢
|    |    |    |    |    [334:334] <Whitespace> = ♢•♢
|    |    |    |    |    [334:334] <Text> = ♢NSViewModeDocumentAttribute,♢
|    |    |    |    |    [334:335] <Newline> = ♢¶♢
|    |    |    |    |    [335:335] <Indenting> = ♢→♢
|    |    |    |    |    [335:335] <ObjCNil> = ♢nil♢
|    |    |    |    |    [335:335] <Match> = ♢]♢
|    |    |    |    [335:335] <Semicolon> = ♢;♢
|    |    |    |    [335:336] <Newline> = ♢¶♢
|    |    |    |    [336:336] <Indenting> = ♢••••♢
|    |    |    |    [336:336] <Text> = ♢NSString♢
|    |    |    |    [336:336] <Whitespace> = ♢•♢
|    |    |    |    [336:336] <Asterisk> = ♢*♢
|    |    |    |    [336:336] <Text> = ♢docType♢
|    |    |    |    [336:336] <Whitespace> = ♢•♢
|    |    |    |    [336:336] <Text> = ♢=♢
|    |    |    |    [336:336] <Whitespace> = ♢•♢
|    |    |    |    [336:336] <ObjCNil> = ♢nil♢
|    |    |    |    [336:336] <Semicolon> = ♢;♢
|    |    |    |    [336:337] <Newline> = ♢¶♢
|    |    |    |    [337:337] <Indenting> = ♢••••♢
|    |    |    |    [337:337] <Text> = ♢id♢
|    |    |    |    [337:337] <Whitespace> = ♢•♢
|    |    |    |    [337:337] <Text> = ♢val♢
|    |    |    |    [337:337] <Whitespace> = ♢•♢
|    |    |    |    [337:337] <Text> = ♢=♢
|    |    |    |    [337:337] <Whitespace> = ♢•♢
|    |    |    |    [337:337] <ObjCNil> = ♢nil♢
|    |    |    |    [337:337] <Semicolon> = ♢;♢
|    |    |    |    [337:337] <Whitespace> = ♢•♢
|    |    |    |    [337:337] <CPPComment> = ♢//•temporary•values♢
|    |    |    |    [337:338] <Newline> = ♢¶♢
|    |    |    |    [338:338] <Indenting> = ♢••••♢
|    |    |    |    [338:339] <Newline> = ♢¶♢
|    |    |    |    [339:339] <Indenting> = ♢••••♢
|    |    |    |    [339:339] <Text> = ♢NSSize♢
|    |    |    |    [339:339] <Whitespace> = ♢•♢
|    |    |    |    [339:339] <Text> = ♢size♢
|    |    |    |    [339:339] <Whitespace> = ♢•♢
|    |    |    |    [339:339] <Text> = ♢=♢
|    |    |    |    [339:339] <Whitespace> = ♢•♢
|    |    |    |    [339:339] <ObjCMethodCall>
|    |    |    |    |    [339:339] <Match> = ♢[♢
|    |    |    |    |    [339:339] <ObjCSelf> = ♢self♢
|    |    |    |    |    [339:339] <Whitespace> = ♢•♢
|    |    |    |    |    [339:339] <Text> = ♢viewSize♢
|    |    |    |    |    [339:339] <Match> = ♢]♢
|    |    |    |    [339:339] <Semicolon> = ♢;♢
|    |    |    |    [339:340] <Newline> = ♢¶♢
|    |    |    |    [340:340] <Indenting> = ♢••••♢
|    |    |    |    [340:342] <CConditionIf>
|    |    |    |    |    [340:340] <Match> = ♢if♢
|    |    |    |    |    [340:340] <Whitespace> = ♢•♢
|    |    |    |    |    [340:340] <Parenthesis>
|    |    |    |    |    |    [340:340] <Match> = ♢(♢
|    |    |    |    |    |    [340:340] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    [340:340] <CFunctionCall>
|    |    |    |    |    |    |    [340:340] <Match> = ♢NSEqualSizes♢
|    |    |    |    |    |    |    [340:340] <Parenthesis>
|    |    |    |    |    |    |    |    [340:340] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [340:340] <Text> = ♢size,♢
|    |    |    |    |    |    |    |    [340:340] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [340:340] <Text> = ♢NSZeroSize♢
|    |    |    |    |    |    |    |    [340:340] <Match> = ♢)♢
|    |    |    |    |    |    [340:340] <Match> = ♢)♢
|    |    |    |    |    [340:340] <Whitespace> = ♢•♢
|    |    |    |    |    [340:342] <Braces>
|    |    |    |    |    |    [340:340] <Match> = ♢{♢
|    |    |    |    |    |    [340:341] <Newline> = ♢¶♢
|    |    |    |    |    |    [341:341] <Indenting> = ♢→♢
|    |    |    |    |    |    [341:341] <ObjCMethodCall>
|    |    |    |    |    |    |    [341:341] <Match> = ♢[♢
|    |    |    |    |    |    |    [341:341] <Match> = ♢dict♢
|    |    |    |    |    |    |    [341:341] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [341:341] <Text> = ♢setObject♢
|    |    |    |    |    |    |    [341:341] <Colon> = ♢:♢
|    |    |    |    |    |    |    [341:341] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [341:341] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [341:341] <Match> = ♢NSValue♢
|    |    |    |    |    |    |    |    [341:341] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [341:341] <Text> = ♢valueWithSize♢
|    |    |    |    |    |    |    |    [341:341] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [341:341] <Text> = ♢size♢
|    |    |    |    |    |    |    |    [341:341] <Match> = ♢]♢
|    |    |    |    |    |    |    [341:341] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [341:341] <Text> = ♢forKey♢
|    |    |    |    |    |    |    [341:341] <Colon> = ♢:♢
|    |    |    |    |    |    |    [341:341] <Text> = ♢NSViewSizeDocumentAttribute♢
|    |    |    |    |    |    |    [341:341] <Match> = ♢]♢
|    |    |    |    |    |    [341:341] <Semicolon> = ♢;♢
|    |    |    |    |    |    [341:342] <Newline> = ♢¶♢
|    |    |    |    |    |    [342:342] <Indenting> = ♢••••♢
|    |    |    |    |    |    [342:342] <Match> = ♢}♢
|    |    |    |    [342:343] <Newline> = ♢¶♢
|    |    |    |    [343:343] <Indenting> = ♢••••♢
|    |    |    |    [343:344] <Newline> = ♢¶♢
|    |    |    |    [344:344] <Indenting> = ♢••••♢
|    |    |    |    [344:344] <CPPComment> = ♢//•TextEdit•knows•how•to•save•all•these•types,•including•their•super-types.•It•does•not•know•how•to•save•any•of•their•potential•subtypes.•Hence,•the•conformance•check•is•the•reverse•of•the•usual•pattern.♢
|    |    |    |    [344:345] <Newline> = ♢¶♢
|    |    |    |    [345:345] <Indenting> = ♢••••♢
|    |    |    |    [345:345] <Text> = ♢NSWorkspace♢
|    |    |    |    [345:345] <Whitespace> = ♢•♢
|    |    |    |    [345:345] <Asterisk> = ♢*♢
|    |    |    |    [345:345] <Text> = ♢workspace♢
|    |    |    |    [345:345] <Whitespace> = ♢•♢
|    |    |    |    [345:345] <Text> = ♢=♢
|    |    |    |    [345:345] <Whitespace> = ♢•♢
|    |    |    |    [345:345] <ObjCMethodCall>
|    |    |    |    |    [345:345] <Match> = ♢[♢
|    |    |    |    |    [345:345] <Match> = ♢NSWorkspace♢
|    |    |    |    |    [345:345] <Whitespace> = ♢•♢
|    |    |    |    |    [345:345] <Text> = ♢sharedWorkspace♢
|    |    |    |    |    [345:345] <Match> = ♢]♢
|    |    |    |    [345:345] <Semicolon> = ♢;♢
|    |    |    |    [345:346] <Newline> = ♢¶♢
|    |    |    |    [346:346] <Indenting> = ♢••••♢
|    |    |    |    [346:346] <CConditionIf>
|    |    |    |    |    [346:346] <Match> = ♢if♢
|    |    |    |    |    [346:346] <Whitespace> = ♢•♢
|    |    |    |    |    [346:346] <Parenthesis>
|    |    |    |    |    |    [346:346] <Match> = ♢(♢
|    |    |    |    |    |    [346:346] <ObjCMethodCall>
|    |    |    |    |    |    |    [346:346] <Match> = ♢[♢
|    |    |    |    |    |    |    [346:346] <Match> = ♢workspace♢
|    |    |    |    |    |    |    [346:346] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [346:346] <Text> = ♢type♢
|    |    |    |    |    |    |    [346:346] <Colon> = ♢:♢
|    |    |    |    |    |    |    [346:346] <Parenthesis>
|    |    |    |    |    |    |    |    [346:346] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [346:346] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    [346:346] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [346:346] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [346:346] <Match> = ♢)♢
|    |    |    |    |    |    |    [346:346] <Text> = ♢kUTTypeRTF♢
|    |    |    |    |    |    |    [346:346] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [346:346] <Text> = ♢conformsToType♢
|    |    |    |    |    |    |    [346:346] <Colon> = ♢:♢
|    |    |    |    |    |    |    [346:346] <Text> = ♢typeName♢
|    |    |    |    |    |    |    [346:346] <Match> = ♢]♢
|    |    |    |    |    |    [346:346] <Match> = ♢)♢
|    |    |    |    |    [346:346] <Whitespace> = ♢•♢
|    |    |    |    |    [346:346] <Text> = ♢docType♢
|    |    |    |    |    [346:346] <Whitespace> = ♢•♢
|    |    |    |    |    [346:346] <Text> = ♢=♢
|    |    |    |    |    [346:346] <Whitespace> = ♢•♢
|    |    |    |    |    [346:346] <Text> = ♢NSRTFTextDocumentType♢
|    |    |    |    |    [346:346] <Semicolon> = ♢;♢
|    |    |    |    [346:347] <Newline> = ♢¶♢
|    |    |    |    [347:347] <Indenting> = ♢••••♢
|    |    |    |    [347:347] <CConditionElseIf>
|    |    |    |    |    [347:347] <Match> = ♢else•if♢
|    |    |    |    |    [347:347] <Whitespace> = ♢•♢
|    |    |    |    |    [347:347] <Parenthesis>
|    |    |    |    |    |    [347:347] <Match> = ♢(♢
|    |    |    |    |    |    [347:347] <ObjCMethodCall>
|    |    |    |    |    |    |    [347:347] <Match> = ♢[♢
|    |    |    |    |    |    |    [347:347] <Match> = ♢workspace♢
|    |    |    |    |    |    |    [347:347] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [347:347] <Text> = ♢type♢
|    |    |    |    |    |    |    [347:347] <Colon> = ♢:♢
|    |    |    |    |    |    |    [347:347] <Parenthesis>
|    |    |    |    |    |    |    |    [347:347] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [347:347] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    [347:347] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [347:347] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [347:347] <Match> = ♢)♢
|    |    |    |    |    |    |    [347:347] <Text> = ♢kUTTypeRTFD♢
|    |    |    |    |    |    |    [347:347] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [347:347] <Text> = ♢conformsToType♢
|    |    |    |    |    |    |    [347:347] <Colon> = ♢:♢
|    |    |    |    |    |    |    [347:347] <Text> = ♢typeName♢
|    |    |    |    |    |    |    [347:347] <Match> = ♢]♢
|    |    |    |    |    |    [347:347] <Match> = ♢)♢
|    |    |    |    |    [347:347] <Whitespace> = ♢•♢
|    |    |    |    |    [347:347] <Text> = ♢docType♢
|    |    |    |    |    [347:347] <Whitespace> = ♢•♢
|    |    |    |    |    [347:347] <Text> = ♢=♢
|    |    |    |    |    [347:347] <Whitespace> = ♢•♢
|    |    |    |    |    [347:347] <Text> = ♢NSRTFDTextDocumentType♢
|    |    |    |    |    [347:347] <Semicolon> = ♢;♢
|    |    |    |    [347:348] <Newline> = ♢¶♢
|    |    |    |    [348:348] <Indenting> = ♢••••♢
|    |    |    |    [348:348] <CConditionElseIf>
|    |    |    |    |    [348:348] <Match> = ♢else•if♢
|    |    |    |    |    [348:348] <Whitespace> = ♢•♢
|    |    |    |    |    [348:348] <Parenthesis>
|    |    |    |    |    |    [348:348] <Match> = ♢(♢
|    |    |    |    |    |    [348:348] <ObjCMethodCall>
|    |    |    |    |    |    |    [348:348] <Match> = ♢[♢
|    |    |    |    |    |    |    [348:348] <Match> = ♢workspace♢
|    |    |    |    |    |    |    [348:348] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [348:348] <Text> = ♢type♢
|    |    |    |    |    |    |    [348:348] <Colon> = ♢:♢
|    |    |    |    |    |    |    [348:348] <Parenthesis>
|    |    |    |    |    |    |    |    [348:348] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [348:348] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    [348:348] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [348:348] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [348:348] <Match> = ♢)♢
|    |    |    |    |    |    |    [348:348] <Text> = ♢kUTTypePlainText♢
|    |    |    |    |    |    |    [348:348] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [348:348] <Text> = ♢conformsToType♢
|    |    |    |    |    |    |    [348:348] <Colon> = ♢:♢
|    |    |    |    |    |    |    [348:348] <Text> = ♢typeName♢
|    |    |    |    |    |    |    [348:348] <Match> = ♢]♢
|    |    |    |    |    |    [348:348] <Match> = ♢)♢
|    |    |    |    |    [348:348] <Whitespace> = ♢•♢
|    |    |    |    |    [348:348] <Text> = ♢docType♢
|    |    |    |    |    [348:348] <Whitespace> = ♢•♢
|    |    |    |    |    [348:348] <Text> = ♢=♢
|    |    |    |    |    [348:348] <Whitespace> = ♢•♢
|    |    |    |    |    [348:348] <Text> = ♢NSPlainTextDocumentType♢
|    |    |    |    |    [348:348] <Semicolon> = ♢;♢
|    |    |    |    [348:349] <Newline> = ♢¶♢
|    |    |    |    [349:349] <Indenting> = ♢••••♢
|    |    |    |    [349:349] <CConditionElseIf>
|    |    |    |    |    [349:349] <Match> = ♢else•if♢
|    |    |    |    |    [349:349] <Whitespace> = ♢•♢
|    |    |    |    |    [349:349] <Parenthesis>
|    |    |    |    |    |    [349:349] <Match> = ♢(♢
|    |    |    |    |    |    [349:349] <ObjCMethodCall>
|    |    |    |    |    |    |    [349:349] <Match> = ♢[♢
|    |    |    |    |    |    |    [349:349] <Match> = ♢workspace♢
|    |    |    |    |    |    |    [349:349] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [349:349] <Text> = ♢type♢
|    |    |    |    |    |    |    [349:349] <Colon> = ♢:♢
|    |    |    |    |    |    |    [349:349] <Text> = ♢SimpleTextType♢
|    |    |    |    |    |    |    [349:349] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [349:349] <Text> = ♢conformsToType♢
|    |    |    |    |    |    |    [349:349] <Colon> = ♢:♢
|    |    |    |    |    |    |    [349:349] <Text> = ♢typeName♢
|    |    |    |    |    |    |    [349:349] <Match> = ♢]♢
|    |    |    |    |    |    [349:349] <Match> = ♢)♢
|    |    |    |    |    [349:349] <Whitespace> = ♢•♢
|    |    |    |    |    [349:349] <Text> = ♢docType♢
|    |    |    |    |    [349:349] <Whitespace> = ♢•♢
|    |    |    |    |    [349:349] <Text> = ♢=♢
|    |    |    |    |    [349:349] <Whitespace> = ♢•♢
|    |    |    |    |    [349:349] <Text> = ♢NSMacSimpleTextDocumentType♢
|    |    |    |    |    [349:349] <Semicolon> = ♢;♢
|    |    |    |    [349:350] <Newline> = ♢¶♢
|    |    |    |    [350:350] <Indenting> = ♢••••♢
|    |    |    |    [350:350] <CConditionElseIf>
|    |    |    |    |    [350:350] <Match> = ♢else•if♢
|    |    |    |    |    [350:350] <Whitespace> = ♢•♢
|    |    |    |    |    [350:350] <Parenthesis>
|    |    |    |    |    |    [350:350] <Match> = ♢(♢
|    |    |    |    |    |    [350:350] <ObjCMethodCall>
|    |    |    |    |    |    |    [350:350] <Match> = ♢[♢
|    |    |    |    |    |    |    [350:350] <Match> = ♢workspace♢
|    |    |    |    |    |    |    [350:350] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [350:350] <Text> = ♢type♢
|    |    |    |    |    |    |    [350:350] <Colon> = ♢:♢
|    |    |    |    |    |    |    [350:350] <Text> = ♢Word97Type♢
|    |    |    |    |    |    |    [350:350] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [350:350] <Text> = ♢conformsToType♢
|    |    |    |    |    |    |    [350:350] <Colon> = ♢:♢
|    |    |    |    |    |    |    [350:350] <Text> = ♢typeName♢
|    |    |    |    |    |    |    [350:350] <Match> = ♢]♢
|    |    |    |    |    |    [350:350] <Match> = ♢)♢
|    |    |    |    |    [350:350] <Whitespace> = ♢•♢
|    |    |    |    |    [350:350] <Text> = ♢docType♢
|    |    |    |    |    [350:350] <Whitespace> = ♢•♢
|    |    |    |    |    [350:350] <Text> = ♢=♢
|    |    |    |    |    [350:350] <Whitespace> = ♢•♢
|    |    |    |    |    [350:350] <Text> = ♢NSDocFormatTextDocumentType♢
|    |    |    |    |    [350:350] <Semicolon> = ♢;♢
|    |    |    |    [350:351] <Newline> = ♢¶♢
|    |    |    |    [351:351] <Indenting> = ♢••••♢
|    |    |    |    [351:351] <CConditionElseIf>
|    |    |    |    |    [351:351] <Match> = ♢else•if♢
|    |    |    |    |    [351:351] <Whitespace> = ♢•♢
|    |    |    |    |    [351:351] <Parenthesis>
|    |    |    |    |    |    [351:351] <Match> = ♢(♢
|    |    |    |    |    |    [351:351] <ObjCMethodCall>
|    |    |    |    |    |    |    [351:351] <Match> = ♢[♢
|    |    |    |    |    |    |    [351:351] <Match> = ♢workspace♢
|    |    |    |    |    |    |    [351:351] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [351:351] <Text> = ♢type♢
|    |    |    |    |    |    |    [351:351] <Colon> = ♢:♢
|    |    |    |    |    |    |    [351:351] <Text> = ♢Word2007Type♢
|    |    |    |    |    |    |    [351:351] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [351:351] <Text> = ♢conformsToType♢
|    |    |    |    |    |    |    [351:351] <Colon> = ♢:♢
|    |    |    |    |    |    |    [351:351] <Text> = ♢typeName♢
|    |    |    |    |    |    |    [351:351] <Match> = ♢]♢
|    |    |    |    |    |    [351:351] <Match> = ♢)♢
|    |    |    |    |    [351:351] <Whitespace> = ♢•♢
|    |    |    |    |    [351:351] <Text> = ♢docType♢
|    |    |    |    |    [351:351] <Whitespace> = ♢•♢
|    |    |    |    |    [351:351] <Text> = ♢=♢
|    |    |    |    |    [351:351] <Whitespace> = ♢•♢
|    |    |    |    |    [351:351] <Text> = ♢NSOfficeOpenXMLTextDocumentType♢
|    |    |    |    |    [351:351] <Semicolon> = ♢;♢
|    |    |    |    [351:352] <Newline> = ♢¶♢
|    |    |    |    [352:352] <Indenting> = ♢••••♢
|    |    |    |    [352:352] <CConditionElseIf>
|    |    |    |    |    [352:352] <Match> = ♢else•if♢
|    |    |    |    |    [352:352] <Whitespace> = ♢•♢
|    |    |    |    |    [352:352] <Parenthesis>
|    |    |    |    |    |    [352:352] <Match> = ♢(♢
|    |    |    |    |    |    [352:352] <ObjCMethodCall>
|    |    |    |    |    |    |    [352:352] <Match> = ♢[♢
|    |    |    |    |    |    |    [352:352] <Match> = ♢workspace♢
|    |    |    |    |    |    |    [352:352] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [352:352] <Text> = ♢type♢
|    |    |    |    |    |    |    [352:352] <Colon> = ♢:♢
|    |    |    |    |    |    |    [352:352] <Text> = ♢Word2003XMLType♢
|    |    |    |    |    |    |    [352:352] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [352:352] <Text> = ♢conformsToType♢
|    |    |    |    |    |    |    [352:352] <Colon> = ♢:♢
|    |    |    |    |    |    |    [352:352] <Text> = ♢typeName♢
|    |    |    |    |    |    |    [352:352] <Match> = ♢]♢
|    |    |    |    |    |    [352:352] <Match> = ♢)♢
|    |    |    |    |    [352:352] <Whitespace> = ♢•♢
|    |    |    |    |    [352:352] <Text> = ♢docType♢
|    |    |    |    |    [352:352] <Whitespace> = ♢•♢
|    |    |    |    |    [352:352] <Text> = ♢=♢
|    |    |    |    |    [352:352] <Whitespace> = ♢•♢
|    |    |    |    |    [352:352] <Text> = ♢NSWordMLTextDocumentType♢
|    |    |    |    |    [352:352] <Semicolon> = ♢;♢
|    |    |    |    [352:353] <Newline> = ♢¶♢
|    |    |    |    [353:353] <Indenting> = ♢••••♢
|    |    |    |    [353:353] <CConditionElseIf>
|    |    |    |    |    [353:353] <Match> = ♢else•if♢
|    |    |    |    |    [353:353] <Whitespace> = ♢•♢
|    |    |    |    |    [353:353] <Parenthesis>
|    |    |    |    |    |    [353:353] <Match> = ♢(♢
|    |    |    |    |    |    [353:353] <ObjCMethodCall>
|    |    |    |    |    |    |    [353:353] <Match> = ♢[♢
|    |    |    |    |    |    |    [353:353] <Match> = ♢workspace♢
|    |    |    |    |    |    |    [353:353] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [353:353] <Text> = ♢type♢
|    |    |    |    |    |    |    [353:353] <Colon> = ♢:♢
|    |    |    |    |    |    |    [353:353] <Text> = ♢OpenDocumentTextType♢
|    |    |    |    |    |    |    [353:353] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [353:353] <Text> = ♢conformsToType♢
|    |    |    |    |    |    |    [353:353] <Colon> = ♢:♢
|    |    |    |    |    |    |    [353:353] <Text> = ♢typeName♢
|    |    |    |    |    |    |    [353:353] <Match> = ♢]♢
|    |    |    |    |    |    [353:353] <Match> = ♢)♢
|    |    |    |    |    [353:353] <Whitespace> = ♢•♢
|    |    |    |    |    [353:353] <Text> = ♢docType♢
|    |    |    |    |    [353:353] <Whitespace> = ♢•♢
|    |    |    |    |    [353:353] <Text> = ♢=♢
|    |    |    |    |    [353:353] <Whitespace> = ♢•♢
|    |    |    |    |    [353:353] <Text> = ♢NSOpenDocumentTextDocumentType♢
|    |    |    |    |    [353:353] <Semicolon> = ♢;♢
|    |    |    |    [353:354] <Newline> = ♢¶♢
|    |    |    |    [354:354] <Indenting> = ♢••••♢
|    |    |    |    [354:354] <CConditionElseIf>
|    |    |    |    |    [354:354] <Match> = ♢else•if♢
|    |    |    |    |    [354:354] <Whitespace> = ♢•♢
|    |    |    |    |    [354:354] <Parenthesis>
|    |    |    |    |    |    [354:354] <Match> = ♢(♢
|    |    |    |    |    |    [354:354] <ObjCMethodCall>
|    |    |    |    |    |    |    [354:354] <Match> = ♢[♢
|    |    |    |    |    |    |    [354:354] <Match> = ♢workspace♢
|    |    |    |    |    |    |    [354:354] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [354:354] <Text> = ♢type♢
|    |    |    |    |    |    |    [354:354] <Colon> = ♢:♢
|    |    |    |    |    |    |    [354:354] <Parenthesis>
|    |    |    |    |    |    |    |    [354:354] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [354:354] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    [354:354] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [354:354] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [354:354] <Match> = ♢)♢
|    |    |    |    |    |    |    [354:354] <Text> = ♢kUTTypeHTML♢
|    |    |    |    |    |    |    [354:354] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [354:354] <Text> = ♢conformsToType♢
|    |    |    |    |    |    |    [354:354] <Colon> = ♢:♢
|    |    |    |    |    |    |    [354:354] <Text> = ♢typeName♢
|    |    |    |    |    |    |    [354:354] <Match> = ♢]♢
|    |    |    |    |    |    [354:354] <Match> = ♢)♢
|    |    |    |    |    [354:354] <Whitespace> = ♢•♢
|    |    |    |    |    [354:354] <Text> = ♢docType♢
|    |    |    |    |    [354:354] <Whitespace> = ♢•♢
|    |    |    |    |    [354:354] <Text> = ♢=♢
|    |    |    |    |    [354:354] <Whitespace> = ♢•♢
|    |    |    |    |    [354:354] <Text> = ♢NSHTMLTextDocumentType♢
|    |    |    |    |    [354:354] <Semicolon> = ♢;♢
|    |    |    |    [354:355] <Newline> = ♢¶♢
|    |    |    |    [355:355] <Indenting> = ♢••••♢
|    |    |    |    [355:355] <CConditionElseIf>
|    |    |    |    |    [355:355] <Match> = ♢else•if♢
|    |    |    |    |    [355:355] <Whitespace> = ♢•♢
|    |    |    |    |    [355:355] <Parenthesis>
|    |    |    |    |    |    [355:355] <Match> = ♢(♢
|    |    |    |    |    |    [355:355] <ObjCMethodCall>
|    |    |    |    |    |    |    [355:355] <Match> = ♢[♢
|    |    |    |    |    |    |    [355:355] <Match> = ♢workspace♢
|    |    |    |    |    |    |    [355:355] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [355:355] <Text> = ♢type♢
|    |    |    |    |    |    |    [355:355] <Colon> = ♢:♢
|    |    |    |    |    |    |    [355:355] <Parenthesis>
|    |    |    |    |    |    |    |    [355:355] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [355:355] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    [355:355] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [355:355] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [355:355] <Match> = ♢)♢
|    |    |    |    |    |    |    [355:355] <Text> = ♢kUTTypeWebArchive♢
|    |    |    |    |    |    |    [355:355] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [355:355] <Text> = ♢conformsToType♢
|    |    |    |    |    |    |    [355:355] <Colon> = ♢:♢
|    |    |    |    |    |    |    [355:355] <Text> = ♢typeName♢
|    |    |    |    |    |    |    [355:355] <Match> = ♢]♢
|    |    |    |    |    |    [355:355] <Match> = ♢)♢
|    |    |    |    |    [355:355] <Whitespace> = ♢•♢
|    |    |    |    |    [355:355] <Text> = ♢docType♢
|    |    |    |    |    [355:355] <Whitespace> = ♢•♢
|    |    |    |    |    [355:355] <Text> = ♢=♢
|    |    |    |    |    [355:355] <Whitespace> = ♢•♢
|    |    |    |    |    [355:355] <Text> = ♢NSWebArchiveTextDocumentType♢
|    |    |    |    |    [355:355] <Semicolon> = ♢;♢
|    |    |    |    [355:356] <Newline> = ♢¶♢
|    |    |    |    [356:356] <Indenting> = ♢••••♢
|    |    |    |    [356:356] <CConditionElse>
|    |    |    |    |    [356:356] <Match> = ♢else♢
|    |    |    |    |    [356:356] <Whitespace> = ♢•♢
|    |    |    |    |    [356:356] <ObjCMethodCall>
|    |    |    |    |    |    [356:356] <Match> = ♢[♢
|    |    |    |    |    |    [356:356] <Match> = ♢NSException♢
|    |    |    |    |    |    [356:356] <Whitespace> = ♢•♢
|    |    |    |    |    |    [356:356] <Text> = ♢raise♢
|    |    |    |    |    |    [356:356] <Colon> = ♢:♢
|    |    |    |    |    |    [356:356] <Text> = ♢NSInvalidArgumentException♢
|    |    |    |    |    |    [356:356] <Whitespace> = ♢•♢
|    |    |    |    |    |    [356:356] <Text> = ♢format♢
|    |    |    |    |    |    [356:356] <Colon> = ♢:♢
|    |    |    |    |    |    [356:356] <ObjCString> = ♢@"%@•is•not•a•recognized•document•type."♢
|    |    |    |    |    |    [356:356] <Text> = ♢,♢
|    |    |    |    |    |    [356:356] <Whitespace> = ♢•♢
|    |    |    |    |    |    [356:356] <Text> = ♢typeName♢
|    |    |    |    |    |    [356:356] <Match> = ♢]♢
|    |    |    |    |    [356:356] <Semicolon> = ♢;♢
|    |    |    |    [356:357] <Newline> = ♢¶♢
|    |    |    |    [357:357] <Indenting> = ♢••••♢
|    |    |    |    [357:358] <Newline> = ♢¶♢
|    |    |    |    [358:358] <Indenting> = ♢••••♢
|    |    |    |    [358:358] <CConditionIf>
|    |    |    |    |    [358:358] <Match> = ♢if♢
|    |    |    |    |    [358:358] <Whitespace> = ♢•♢
|    |    |    |    |    [358:358] <Parenthesis>
|    |    |    |    |    |    [358:358] <Match> = ♢(♢
|    |    |    |    |    |    [358:358] <Text> = ♢docType♢
|    |    |    |    |    |    [358:358] <Match> = ♢)♢
|    |    |    |    |    [358:358] <Whitespace> = ♢•♢
|    |    |    |    |    [358:358] <ObjCMethodCall>
|    |    |    |    |    |    [358:358] <Match> = ♢[♢
|    |    |    |    |    |    [358:358] <Match> = ♢dict♢
|    |    |    |    |    |    [358:358] <Whitespace> = ♢•♢
|    |    |    |    |    |    [358:358] <Text> = ♢setObject♢
|    |    |    |    |    |    [358:358] <Colon> = ♢:♢
|    |    |    |    |    |    [358:358] <Text> = ♢docType♢
|    |    |    |    |    |    [358:358] <Whitespace> = ♢•♢
|    |    |    |    |    |    [358:358] <Text> = ♢forKey♢
|    |    |    |    |    |    [358:358] <Colon> = ♢:♢
|    |    |    |    |    |    [358:358] <Text> = ♢NSDocumentTypeDocumentAttribute♢
|    |    |    |    |    |    [358:358] <Match> = ♢]♢
|    |    |    |    |    [358:358] <Semicolon> = ♢;♢
|    |    |    |    [358:359] <Newline> = ♢¶♢
|    |    |    |    [359:359] <Indenting> = ♢••••♢
|    |    |    |    [359:359] <CConditionIf>
|    |    |    |    |    [359:359] <Match> = ♢if♢
|    |    |    |    |    [359:359] <Whitespace> = ♢•♢
|    |    |    |    |    [359:359] <Parenthesis>
|    |    |    |    |    |    [359:359] <Match> = ♢(♢
|    |    |    |    |    |    [359:359] <ObjCMethodCall>
|    |    |    |    |    |    |    [359:359] <Match> = ♢[♢
|    |    |    |    |    |    |    [359:359] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [359:359] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [359:359] <Text> = ♢hasMultiplePages♢
|    |    |    |    |    |    |    [359:359] <Match> = ♢]♢
|    |    |    |    |    |    [359:359] <Whitespace> = ♢•♢
|    |    |    |    |    |    [359:359] <Ampersand> = ♢&♢
|    |    |    |    |    |    [359:359] <Ampersand> = ♢&♢
|    |    |    |    |    |    [359:359] <Whitespace> = ♢•♢
|    |    |    |    |    |    [359:359] <Parenthesis>
|    |    |    |    |    |    |    [359:359] <Match> = ♢(♢
|    |    |    |    |    |    |    [359:359] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [359:359] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [359:359] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [359:359] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [359:359] <Text> = ♢scaleFactor♢
|    |    |    |    |    |    |    |    [359:359] <Match> = ♢]♢
|    |    |    |    |    |    |    [359:359] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [359:359] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    [359:359] <Text> = ♢=♢
|    |    |    |    |    |    |    [359:359] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [359:359] <Text> = ♢1.0♢
|    |    |    |    |    |    |    [359:359] <Match> = ♢)♢
|    |    |    |    |    |    [359:359] <Match> = ♢)♢
|    |    |    |    |    [359:359] <Whitespace> = ♢•♢
|    |    |    |    |    [359:359] <ObjCMethodCall>
|    |    |    |    |    |    [359:359] <Match> = ♢[♢
|    |    |    |    |    |    [359:359] <Match> = ♢dict♢
|    |    |    |    |    |    [359:359] <Whitespace> = ♢•♢
|    |    |    |    |    |    [359:359] <Text> = ♢setObject♢
|    |    |    |    |    |    [359:359] <Colon> = ♢:♢
|    |    |    |    |    |    [359:359] <ObjCMethodCall>
|    |    |    |    |    |    |    [359:359] <Match> = ♢[♢
|    |    |    |    |    |    |    [359:359] <Match> = ♢NSNumber♢
|    |    |    |    |    |    |    [359:359] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [359:359] <Text> = ♢numberWithDouble♢
|    |    |    |    |    |    |    [359:359] <Colon> = ♢:♢
|    |    |    |    |    |    |    [359:359] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [359:359] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [359:359] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [359:359] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [359:359] <Text> = ♢scaleFactor♢
|    |    |    |    |    |    |    |    [359:359] <Match> = ♢]♢
|    |    |    |    |    |    |    [359:359] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [359:359] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    [359:359] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [359:359] <Text> = ♢100.0♢
|    |    |    |    |    |    |    [359:359] <Match> = ♢]♢
|    |    |    |    |    |    [359:359] <Whitespace> = ♢•♢
|    |    |    |    |    |    [359:359] <Text> = ♢forKey♢
|    |    |    |    |    |    [359:359] <Colon> = ♢:♢
|    |    |    |    |    |    [359:359] <Text> = ♢NSViewZoomDocumentAttribute♢
|    |    |    |    |    |    [359:359] <Match> = ♢]♢
|    |    |    |    |    [359:359] <Semicolon> = ♢;♢
|    |    |    |    [359:360] <Newline> = ♢¶♢
|    |    |    |    [360:360] <Indenting> = ♢••••♢
|    |    |    |    [360:360] <CConditionIf>
|    |    |    |    |    [360:360] <Match> = ♢if♢
|    |    |    |    |    [360:360] <Whitespace> = ♢•♢
|    |    |    |    |    [360:360] <Parenthesis>
|    |    |    |    |    |    [360:360] <Match> = ♢(♢
|    |    |    |    |    |    [360:360] <Text> = ♢val♢
|    |    |    |    |    |    [360:360] <Whitespace> = ♢•♢
|    |    |    |    |    |    [360:360] <Text> = ♢=♢
|    |    |    |    |    |    [360:360] <Whitespace> = ♢•♢
|    |    |    |    |    |    [360:360] <ObjCMethodCall>
|    |    |    |    |    |    |    [360:360] <Match> = ♢[♢
|    |    |    |    |    |    |    [360:360] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [360:360] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [360:360] <Text> = ♢backgroundColor♢
|    |    |    |    |    |    |    [360:360] <Match> = ♢]♢
|    |    |    |    |    |    [360:360] <Match> = ♢)♢
|    |    |    |    |    [360:360] <Whitespace> = ♢•♢
|    |    |    |    |    [360:360] <ObjCMethodCall>
|    |    |    |    |    |    [360:360] <Match> = ♢[♢
|    |    |    |    |    |    [360:360] <Match> = ♢dict♢
|    |    |    |    |    |    [360:360] <Whitespace> = ♢•♢
|    |    |    |    |    |    [360:360] <Text> = ♢setObject♢
|    |    |    |    |    |    [360:360] <Colon> = ♢:♢
|    |    |    |    |    |    [360:360] <Text> = ♢val♢
|    |    |    |    |    |    [360:360] <Whitespace> = ♢•♢
|    |    |    |    |    |    [360:360] <Text> = ♢forKey♢
|    |    |    |    |    |    [360:360] <Colon> = ♢:♢
|    |    |    |    |    |    [360:360] <Text> = ♢NSBackgroundColorDocumentAttribute♢
|    |    |    |    |    |    [360:360] <Match> = ♢]♢
|    |    |    |    |    [360:360] <Semicolon> = ♢;♢
|    |    |    |    [360:361] <Newline> = ♢¶♢
|    |    |    |    [361:361] <Indenting> = ♢••••♢
|    |    |    |    [361:362] <Newline> = ♢¶♢
|    |    |    |    [362:362] <Indenting> = ♢••••♢
|    |    |    |    [362:371] <CConditionIf>
|    |    |    |    |    [362:362] <Match> = ♢if♢
|    |    |    |    |    [362:362] <Whitespace> = ♢•♢
|    |    |    |    |    [362:362] <Parenthesis>
|    |    |    |    |    |    [362:362] <Match> = ♢(♢
|    |    |    |    |    |    [362:362] <Text> = ♢docType♢
|    |    |    |    |    |    [362:362] <Whitespace> = ♢•♢
|    |    |    |    |    |    [362:362] <Text> = ♢==♢
|    |    |    |    |    |    [362:362] <Whitespace> = ♢•♢
|    |    |    |    |    |    [362:362] <Text> = ♢NSPlainTextDocumentType♢
|    |    |    |    |    |    [362:362] <Match> = ♢)♢
|    |    |    |    |    [362:362] <Whitespace> = ♢•♢
|    |    |    |    |    [362:371] <Braces>
|    |    |    |    |    |    [362:362] <Match> = ♢{♢
|    |    |    |    |    |    [362:363] <Newline> = ♢¶♢
|    |    |    |    |    |    [363:363] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [363:363] <Text> = ♢NSStringEncoding♢
|    |    |    |    |    |    [363:363] <Whitespace> = ♢•♢
|    |    |    |    |    |    [363:363] <Text> = ♢enc♢
|    |    |    |    |    |    [363:363] <Whitespace> = ♢•♢
|    |    |    |    |    |    [363:363] <Text> = ♢=♢
|    |    |    |    |    |    [363:363] <Whitespace> = ♢•♢
|    |    |    |    |    |    [363:363] <ObjCMethodCall>
|    |    |    |    |    |    |    [363:363] <Match> = ♢[♢
|    |    |    |    |    |    |    [363:363] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [363:363] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [363:363] <Text> = ♢encodingForSaving♢
|    |    |    |    |    |    |    [363:363] <Match> = ♢]♢
|    |    |    |    |    |    [363:363] <Semicolon> = ♢;♢
|    |    |    |    |    |    [363:364] <Newline> = ♢¶♢
|    |    |    |    |    |    [364:365] <Newline> = ♢¶♢
|    |    |    |    |    |    [365:365] <Indenting> = ♢→♢
|    |    |    |    |    |    [365:365] <CPPComment> = ♢//•check•here•in•case•this•didn't•go•through•save•panel•(i.e.•scripting)♢
|    |    |    |    |    |    [365:366] <Newline> = ♢¶♢
|    |    |    |    |    |    [366:366] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [366:369] <CConditionIf>
|    |    |    |    |    |    |    [366:366] <Match> = ♢if♢
|    |    |    |    |    |    |    [366:366] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [366:366] <Parenthesis>
|    |    |    |    |    |    |    |    [366:366] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [366:366] <Text> = ♢enc♢
|    |    |    |    |    |    |    |    [366:366] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [366:366] <Text> = ♢==♢
|    |    |    |    |    |    |    |    [366:366] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [366:366] <Text> = ♢NoStringEncoding♢
|    |    |    |    |    |    |    |    [366:366] <Match> = ♢)♢
|    |    |    |    |    |    |    [366:366] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [366:369] <Braces>
|    |    |    |    |    |    |    |    [366:366] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [366:367] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [367:367] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [367:367] <Text> = ♢enc♢
|    |    |    |    |    |    |    |    [367:367] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [367:367] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [367:367] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [367:367] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [367:367] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [367:367] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    [367:367] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [367:367] <Text> = ♢encoding♢
|    |    |    |    |    |    |    |    |    [367:367] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [367:367] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [367:368] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [368:368] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [368:368] <CConditionIf>
|    |    |    |    |    |    |    |    |    [368:368] <Match> = ♢if♢
|    |    |    |    |    |    |    |    |    [368:368] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [368:368] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [368:368] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [368:368] <Text> = ♢enc♢
|    |    |    |    |    |    |    |    |    |    [368:368] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [368:368] <Text> = ♢==♢
|    |    |    |    |    |    |    |    |    |    [368:368] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [368:368] <Text> = ♢NoStringEncoding♢
|    |    |    |    |    |    |    |    |    |    [368:368] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [368:368] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [368:368] <Text> = ♢enc♢
|    |    |    |    |    |    |    |    |    [368:368] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [368:368] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    [368:368] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [368:368] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [368:368] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [368:368] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    [368:368] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [368:368] <Text> = ♢suggestedDocumentEncoding♢
|    |    |    |    |    |    |    |    |    |    [368:368] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [368:368] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [368:369] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [369:369] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [369:369] <Match> = ♢}♢
|    |    |    |    |    |    [369:370] <Newline> = ♢¶♢
|    |    |    |    |    |    [370:370] <Indenting> = ♢→♢
|    |    |    |    |    |    [370:370] <ObjCMethodCall>
|    |    |    |    |    |    |    [370:370] <Match> = ♢[♢
|    |    |    |    |    |    |    [370:370] <Match> = ♢dict♢
|    |    |    |    |    |    |    [370:370] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [370:370] <Text> = ♢setObject♢
|    |    |    |    |    |    |    [370:370] <Colon> = ♢:♢
|    |    |    |    |    |    |    [370:370] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [370:370] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [370:370] <Match> = ♢NSNumber♢
|    |    |    |    |    |    |    |    [370:370] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [370:370] <Text> = ♢numberWithUnsignedInteger♢
|    |    |    |    |    |    |    |    [370:370] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [370:370] <Text> = ♢enc♢
|    |    |    |    |    |    |    |    [370:370] <Match> = ♢]♢
|    |    |    |    |    |    |    [370:370] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [370:370] <Text> = ♢forKey♢
|    |    |    |    |    |    |    [370:370] <Colon> = ♢:♢
|    |    |    |    |    |    |    [370:370] <Text> = ♢NSCharacterEncodingDocumentAttribute♢
|    |    |    |    |    |    |    [370:370] <Match> = ♢]♢
|    |    |    |    |    |    [370:370] <Semicolon> = ♢;♢
|    |    |    |    |    |    [370:371] <Newline> = ♢¶♢
|    |    |    |    |    |    [371:371] <Indenting> = ♢••••♢
|    |    |    |    |    |    [371:371] <Match> = ♢}♢
|    |    |    |    [371:371] <Whitespace> = ♢•♢
|    |    |    |    [371:389] <CConditionElseIf>
|    |    |    |    |    [371:371] <Match> = ♢else•if♢
|    |    |    |    |    [371:371] <Whitespace> = ♢•♢
|    |    |    |    |    [371:371] <Parenthesis>
|    |    |    |    |    |    [371:371] <Match> = ♢(♢
|    |    |    |    |    |    [371:371] <Text> = ♢docType♢
|    |    |    |    |    |    [371:371] <Whitespace> = ♢•♢
|    |    |    |    |    |    [371:371] <Text> = ♢==♢
|    |    |    |    |    |    [371:371] <Whitespace> = ♢•♢
|    |    |    |    |    |    [371:371] <Text> = ♢NSHTMLTextDocumentType♢
|    |    |    |    |    |    [371:371] <Whitespace> = ♢•♢
|    |    |    |    |    |    [371:371] <Text> = ♢||♢
|    |    |    |    |    |    [371:371] <Whitespace> = ♢•♢
|    |    |    |    |    |    [371:371] <Text> = ♢docType♢
|    |    |    |    |    |    [371:371] <Whitespace> = ♢•♢
|    |    |    |    |    |    [371:371] <Text> = ♢==♢
|    |    |    |    |    |    [371:371] <Whitespace> = ♢•♢
|    |    |    |    |    |    [371:371] <Text> = ♢NSWebArchiveTextDocumentType♢
|    |    |    |    |    |    [371:371] <Match> = ♢)♢
|    |    |    |    |    [371:371] <Whitespace> = ♢•♢
|    |    |    |    |    [371:389] <Braces>
|    |    |    |    |    |    [371:371] <Match> = ♢{♢
|    |    |    |    |    |    [371:372] <Newline> = ♢¶♢
|    |    |    |    |    |    [372:372] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [372:372] <Text> = ♢NSUserDefaults♢
|    |    |    |    |    |    [372:372] <Whitespace> = ♢•♢
|    |    |    |    |    |    [372:372] <Asterisk> = ♢*♢
|    |    |    |    |    |    [372:372] <Text> = ♢defaults♢
|    |    |    |    |    |    [372:372] <Whitespace> = ♢•♢
|    |    |    |    |    |    [372:372] <Text> = ♢=♢
|    |    |    |    |    |    [372:372] <Whitespace> = ♢•♢
|    |    |    |    |    |    [372:372] <ObjCMethodCall>
|    |    |    |    |    |    |    [372:372] <Match> = ♢[♢
|    |    |    |    |    |    |    [372:372] <Match> = ♢NSUserDefaults♢
|    |    |    |    |    |    |    [372:372] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [372:372] <Text> = ♢standardUserDefaults♢
|    |    |    |    |    |    |    [372:372] <Match> = ♢]♢
|    |    |    |    |    |    [372:372] <Semicolon> = ♢;♢
|    |    |    |    |    |    [372:373] <Newline> = ♢¶♢
|    |    |    |    |    |    [373:373] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [373:374] <Newline> = ♢¶♢
|    |    |    |    |    |    [374:374] <Indenting> = ♢→♢
|    |    |    |    |    |    [374:374] <Text> = ♢NSMutableArray♢
|    |    |    |    |    |    [374:374] <Whitespace> = ♢•♢
|    |    |    |    |    |    [374:374] <Asterisk> = ♢*♢
|    |    |    |    |    |    [374:374] <Text> = ♢excludedElements♢
|    |    |    |    |    |    [374:374] <Whitespace> = ♢•♢
|    |    |    |    |    |    [374:374] <Text> = ♢=♢
|    |    |    |    |    |    [374:374] <Whitespace> = ♢•♢
|    |    |    |    |    |    [374:374] <ObjCMethodCall>
|    |    |    |    |    |    |    [374:374] <Match> = ♢[♢
|    |    |    |    |    |    |    [374:374] <Match> = ♢NSMutableArray♢
|    |    |    |    |    |    |    [374:374] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [374:374] <Text> = ♢array♢
|    |    |    |    |    |    |    [374:374] <Match> = ♢]♢
|    |    |    |    |    |    [374:374] <Semicolon> = ♢;♢
|    |    |    |    |    |    [374:375] <Newline> = ♢¶♢
|    |    |    |    |    |    [375:375] <Indenting> = ♢→♢
|    |    |    |    |    |    [375:375] <CConditionIf>
|    |    |    |    |    |    |    [375:375] <Match> = ♢if♢
|    |    |    |    |    |    |    [375:375] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [375:375] <Parenthesis>
|    |    |    |    |    |    |    |    [375:375] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [375:375] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    [375:375] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [375:375] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [375:375] <Match> = ♢defaults♢
|    |    |    |    |    |    |    |    |    [375:375] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [375:375] <Text> = ♢boolForKey♢
|    |    |    |    |    |    |    |    |    [375:375] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [375:375] <Text> = ♢UseXHTMLDocType♢
|    |    |    |    |    |    |    |    |    [375:375] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [375:375] <Match> = ♢)♢
|    |    |    |    |    |    |    [375:375] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [375:375] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [375:375] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [375:375] <Match> = ♢excludedElements♢
|    |    |    |    |    |    |    |    [375:375] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [375:375] <Text> = ♢addObject♢
|    |    |    |    |    |    |    |    [375:375] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [375:375] <ObjCString> = ♢@"XML"♢
|    |    |    |    |    |    |    |    [375:375] <Match> = ♢]♢
|    |    |    |    |    |    |    [375:375] <Semicolon> = ♢;♢
|    |    |    |    |    |    [375:376] <Newline> = ♢¶♢
|    |    |    |    |    |    [376:376] <Indenting> = ♢→♢
|    |    |    |    |    |    [376:376] <CConditionIf>
|    |    |    |    |    |    |    [376:376] <Match> = ♢if♢
|    |    |    |    |    |    |    [376:376] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [376:376] <Parenthesis>
|    |    |    |    |    |    |    |    [376:376] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [376:376] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    [376:376] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [376:376] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [376:376] <Match> = ♢defaults♢
|    |    |    |    |    |    |    |    |    [376:376] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [376:376] <Text> = ♢boolForKey♢
|    |    |    |    |    |    |    |    |    [376:376] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [376:376] <Text> = ♢UseTransitionalDocType♢
|    |    |    |    |    |    |    |    |    [376:376] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [376:376] <Match> = ♢)♢
|    |    |    |    |    |    |    [376:376] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [376:376] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [376:376] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [376:376] <Match> = ♢excludedElements♢
|    |    |    |    |    |    |    |    [376:376] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [376:376] <Text> = ♢addObjectsFromArray♢
|    |    |    |    |    |    |    |    [376:376] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [376:376] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [376:376] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [376:376] <Match> = ♢NSArray♢
|    |    |    |    |    |    |    |    |    [376:376] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [376:376] <Text> = ♢arrayWithObjects♢
|    |    |    |    |    |    |    |    |    [376:376] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [376:376] <ObjCString> = ♢@"APPLET"♢
|    |    |    |    |    |    |    |    |    [376:376] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    [376:376] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [376:376] <ObjCString> = ♢@"BASEFONT"♢
|    |    |    |    |    |    |    |    |    [376:376] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    [376:376] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [376:376] <ObjCString> = ♢@"CENTER"♢
|    |    |    |    |    |    |    |    |    [376:376] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    [376:376] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [376:376] <ObjCString> = ♢@"DIR"♢
|    |    |    |    |    |    |    |    |    [376:376] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    [376:376] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [376:376] <ObjCString> = ♢@"FONT"♢
|    |    |    |    |    |    |    |    |    [376:376] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    [376:376] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [376:376] <ObjCString> = ♢@"ISINDEX"♢
|    |    |    |    |    |    |    |    |    [376:376] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    [376:376] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [376:376] <ObjCString> = ♢@"MENU"♢
|    |    |    |    |    |    |    |    |    [376:376] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    [376:376] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [376:376] <ObjCString> = ♢@"S"♢
|    |    |    |    |    |    |    |    |    [376:376] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    [376:376] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [376:376] <ObjCString> = ♢@"STRIKE"♢
|    |    |    |    |    |    |    |    |    [376:376] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    [376:376] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [376:376] <ObjCString> = ♢@"U"♢
|    |    |    |    |    |    |    |    |    [376:376] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    [376:376] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [376:376] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    |    |    [376:376] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [376:376] <Match> = ♢]♢
|    |    |    |    |    |    |    [376:376] <Semicolon> = ♢;♢
|    |    |    |    |    |    [376:377] <Newline> = ♢¶♢
|    |    |    |    |    |    [377:377] <Indenting> = ♢→♢
|    |    |    |    |    |    [377:380] <CConditionIf>
|    |    |    |    |    |    |    [377:377] <Match> = ♢if♢
|    |    |    |    |    |    |    [377:377] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [377:377] <Parenthesis>
|    |    |    |    |    |    |    |    [377:377] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [377:377] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    [377:377] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [377:377] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [377:377] <Match> = ♢defaults♢
|    |    |    |    |    |    |    |    |    [377:377] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [377:377] <Text> = ♢boolForKey♢
|    |    |    |    |    |    |    |    |    [377:377] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [377:377] <Text> = ♢UseEmbeddedCSS♢
|    |    |    |    |    |    |    |    |    [377:377] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [377:377] <Match> = ♢)♢
|    |    |    |    |    |    |    [377:377] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [377:380] <Braces>
|    |    |    |    |    |    |    |    [377:377] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [377:378] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [378:378] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [378:378] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [378:378] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [378:378] <Match> = ♢excludedElements♢
|    |    |    |    |    |    |    |    |    [378:378] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [378:378] <Text> = ♢addObject♢
|    |    |    |    |    |    |    |    |    [378:378] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [378:378] <ObjCString> = ♢@"STYLE"♢
|    |    |    |    |    |    |    |    |    [378:378] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [378:378] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [378:379] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [379:379] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [379:379] <CConditionIf>
|    |    |    |    |    |    |    |    |    [379:379] <Match> = ♢if♢
|    |    |    |    |    |    |    |    |    [379:379] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [379:379] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [379:379] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [379:379] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    |    |    [379:379] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [379:379] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [379:379] <Match> = ♢defaults♢
|    |    |    |    |    |    |    |    |    |    |    [379:379] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [379:379] <Text> = ♢boolForKey♢
|    |    |    |    |    |    |    |    |    |    |    [379:379] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    [379:379] <Text> = ♢UseInlineCSS♢
|    |    |    |    |    |    |    |    |    |    |    [379:379] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [379:379] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [379:379] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [379:379] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [379:379] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [379:379] <Match> = ♢excludedElements♢
|    |    |    |    |    |    |    |    |    |    [379:379] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [379:379] <Text> = ♢addObject♢
|    |    |    |    |    |    |    |    |    |    [379:379] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [379:379] <ObjCString> = ♢@"SPAN"♢
|    |    |    |    |    |    |    |    |    |    [379:379] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [379:379] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [379:380] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [380:380] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [380:380] <Match> = ♢}♢
|    |    |    |    |    |    [380:381] <Newline> = ♢¶♢
|    |    |    |    |    |    [381:381] <Indenting> = ♢→♢
|    |    |    |    |    |    [381:385] <CConditionIf>
|    |    |    |    |    |    |    [381:381] <Match> = ♢if♢
|    |    |    |    |    |    |    [381:381] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [381:381] <Parenthesis>
|    |    |    |    |    |    |    |    [381:381] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [381:381] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    [381:381] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [381:381] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [381:381] <Match> = ♢defaults♢
|    |    |    |    |    |    |    |    |    [381:381] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [381:381] <Text> = ♢boolForKey♢
|    |    |    |    |    |    |    |    |    [381:381] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [381:381] <Text> = ♢PreserveWhitespace♢
|    |    |    |    |    |    |    |    |    [381:381] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [381:381] <Match> = ♢)♢
|    |    |    |    |    |    |    [381:381] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [381:385] <Braces>
|    |    |    |    |    |    |    |    [381:381] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [381:382] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [382:382] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [382:382] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [382:382] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [382:382] <Match> = ♢excludedElements♢
|    |    |    |    |    |    |    |    |    [382:382] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [382:382] <Text> = ♢addObject♢
|    |    |    |    |    |    |    |    |    [382:382] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [382:382] <ObjCString> = ♢@"Apple-converted-space"♢
|    |    |    |    |    |    |    |    |    [382:382] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [382:382] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [382:383] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [383:383] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [383:383] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [383:383] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [383:383] <Match> = ♢excludedElements♢
|    |    |    |    |    |    |    |    |    [383:383] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [383:383] <Text> = ♢addObject♢
|    |    |    |    |    |    |    |    |    [383:383] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [383:383] <ObjCString> = ♢@"Apple-converted-tab"♢
|    |    |    |    |    |    |    |    |    [383:383] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [383:383] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [383:384] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [384:384] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [384:384] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [384:384] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [384:384] <Match> = ♢excludedElements♢
|    |    |    |    |    |    |    |    |    [384:384] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [384:384] <Text> = ♢addObject♢
|    |    |    |    |    |    |    |    |    [384:384] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [384:384] <ObjCString> = ♢@"Apple-interchange-newline"♢
|    |    |    |    |    |    |    |    |    [384:384] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [384:384] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [384:385] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [385:385] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [385:385] <Match> = ♢}♢
|    |    |    |    |    |    [385:386] <Newline> = ♢¶♢
|    |    |    |    |    |    [386:386] <Indenting> = ♢→♢
|    |    |    |    |    |    [386:386] <ObjCMethodCall>
|    |    |    |    |    |    |    [386:386] <Match> = ♢[♢
|    |    |    |    |    |    |    [386:386] <Match> = ♢dict♢
|    |    |    |    |    |    |    [386:386] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [386:386] <Text> = ♢setObject♢
|    |    |    |    |    |    |    [386:386] <Colon> = ♢:♢
|    |    |    |    |    |    |    [386:386] <Text> = ♢excludedElements♢
|    |    |    |    |    |    |    [386:386] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [386:386] <Text> = ♢forKey♢
|    |    |    |    |    |    |    [386:386] <Colon> = ♢:♢
|    |    |    |    |    |    |    [386:386] <Text> = ♢NSExcludedElementsDocumentAttribute♢
|    |    |    |    |    |    |    [386:386] <Match> = ♢]♢
|    |    |    |    |    |    [386:386] <Semicolon> = ♢;♢
|    |    |    |    |    |    [386:387] <Newline> = ♢¶♢
|    |    |    |    |    |    [387:387] <Indenting> = ♢→♢
|    |    |    |    |    |    [387:387] <ObjCMethodCall>
|    |    |    |    |    |    |    [387:387] <Match> = ♢[♢
|    |    |    |    |    |    |    [387:387] <Match> = ♢dict♢
|    |    |    |    |    |    |    [387:387] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [387:387] <Text> = ♢setObject♢
|    |    |    |    |    |    |    [387:387] <Colon> = ♢:♢
|    |    |    |    |    |    |    [387:387] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [387:387] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [387:387] <Match> = ♢defaults♢
|    |    |    |    |    |    |    |    [387:387] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [387:387] <Text> = ♢objectForKey♢
|    |    |    |    |    |    |    |    [387:387] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [387:387] <Text> = ♢HTMLEncoding♢
|    |    |    |    |    |    |    |    [387:387] <Match> = ♢]♢
|    |    |    |    |    |    |    [387:387] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [387:387] <Text> = ♢forKey♢
|    |    |    |    |    |    |    [387:387] <Colon> = ♢:♢
|    |    |    |    |    |    |    [387:387] <Text> = ♢NSCharacterEncodingDocumentAttribute♢
|    |    |    |    |    |    |    [387:387] <Match> = ♢]♢
|    |    |    |    |    |    [387:387] <Semicolon> = ♢;♢
|    |    |    |    |    |    [387:388] <Newline> = ♢¶♢
|    |    |    |    |    |    [388:388] <Indenting> = ♢→♢
|    |    |    |    |    |    [388:388] <ObjCMethodCall>
|    |    |    |    |    |    |    [388:388] <Match> = ♢[♢
|    |    |    |    |    |    |    [388:388] <Match> = ♢dict♢
|    |    |    |    |    |    |    [388:388] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [388:388] <Text> = ♢setObject♢
|    |    |    |    |    |    |    [388:388] <Colon> = ♢:♢
|    |    |    |    |    |    |    [388:388] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [388:388] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [388:388] <Match> = ♢NSNumber♢
|    |    |    |    |    |    |    |    [388:388] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [388:388] <Text> = ♢numberWithInteger♢
|    |    |    |    |    |    |    |    [388:388] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [388:388] <Text> = ♢2♢
|    |    |    |    |    |    |    |    [388:388] <Match> = ♢]♢
|    |    |    |    |    |    |    [388:388] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [388:388] <Text> = ♢forKey♢
|    |    |    |    |    |    |    [388:388] <Colon> = ♢:♢
|    |    |    |    |    |    |    [388:388] <Text> = ♢NSPrefixSpacesDocumentAttribute♢
|    |    |    |    |    |    |    [388:388] <Match> = ♢]♢
|    |    |    |    |    |    [388:388] <Semicolon> = ♢;♢
|    |    |    |    |    |    [388:389] <Newline> = ♢¶♢
|    |    |    |    |    |    [389:389] <Indenting> = ♢••••♢
|    |    |    |    |    |    [389:389] <Match> = ♢}♢
|    |    |    |    [389:390] <Newline> = ♢¶♢
|    |    |    |    [390:390] <Indenting> = ♢••••♢
|    |    |    |    [390:391] <Newline> = ♢¶♢
|    |    |    |    [391:391] <Indenting> = ♢••••♢
|    |    |    |    [391:391] <CPPComment> = ♢//•Set•the•document•properties,•generically,•going•through•key•value•coding♢
|    |    |    |    [391:392] <Newline> = ♢¶♢
|    |    |    |    [392:392] <Indenting> = ♢••••♢
|    |    |    |    [392:395] <CFlowFor>
|    |    |    |    |    [392:392] <Match> = ♢for♢
|    |    |    |    |    [392:392] <Whitespace> = ♢•♢
|    |    |    |    |    [392:392] <Parenthesis>
|    |    |    |    |    |    [392:392] <Match> = ♢(♢
|    |    |    |    |    |    [392:392] <Text> = ♢NSString♢
|    |    |    |    |    |    [392:392] <Whitespace> = ♢•♢
|    |    |    |    |    |    [392:392] <Asterisk> = ♢*♢
|    |    |    |    |    |    [392:392] <Text> = ♢property♢
|    |    |    |    |    |    [392:392] <Whitespace> = ♢•♢
|    |    |    |    |    |    [392:392] <Text> = ♢in♢
|    |    |    |    |    |    [392:392] <Whitespace> = ♢•♢
|    |    |    |    |    |    [392:392] <ObjCMethodCall>
|    |    |    |    |    |    |    [392:392] <Match> = ♢[♢
|    |    |    |    |    |    |    [392:392] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [392:392] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [392:392] <Text> = ♢knownDocumentProperties♢
|    |    |    |    |    |    |    [392:392] <Match> = ♢]♢
|    |    |    |    |    |    [392:392] <Match> = ♢)♢
|    |    |    |    |    [392:392] <Whitespace> = ♢•♢
|    |    |    |    |    [392:395] <Braces>
|    |    |    |    |    |    [392:392] <Match> = ♢{♢
|    |    |    |    |    |    [392:393] <Newline> = ♢¶♢
|    |    |    |    |    |    [393:393] <Indenting> = ♢→♢
|    |    |    |    |    |    [393:393] <Text> = ♢id♢
|    |    |    |    |    |    [393:393] <Whitespace> = ♢•♢
|    |    |    |    |    |    [393:393] <Text> = ♢value♢
|    |    |    |    |    |    [393:393] <Whitespace> = ♢•♢
|    |    |    |    |    |    [393:393] <Text> = ♢=♢
|    |    |    |    |    |    [393:393] <Whitespace> = ♢•♢
|    |    |    |    |    |    [393:393] <ObjCMethodCall>
|    |    |    |    |    |    |    [393:393] <Match> = ♢[♢
|    |    |    |    |    |    |    [393:393] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [393:393] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [393:393] <Text> = ♢valueForKey♢
|    |    |    |    |    |    |    [393:393] <Colon> = ♢:♢
|    |    |    |    |    |    |    [393:393] <Text> = ♢property♢
|    |    |    |    |    |    |    [393:393] <Match> = ♢]♢
|    |    |    |    |    |    [393:393] <Semicolon> = ♢;♢
|    |    |    |    |    |    [393:394] <Newline> = ♢¶♢
|    |    |    |    |    |    [394:394] <Indenting> = ♢→♢
|    |    |    |    |    |    [394:394] <CConditionIf>
|    |    |    |    |    |    |    [394:394] <Match> = ♢if♢
|    |    |    |    |    |    |    [394:394] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [394:394] <Parenthesis>
|    |    |    |    |    |    |    |    [394:394] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [394:394] <Text> = ♢value♢
|    |    |    |    |    |    |    |    [394:394] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [394:394] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    [394:394] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    [394:394] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [394:394] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    [394:394] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [394:394] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [394:394] <Match> = ♢value♢
|    |    |    |    |    |    |    |    |    [394:394] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [394:394] <Text> = ♢isEqual♢
|    |    |    |    |    |    |    |    |    [394:394] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [394:394] <ObjCString> = ♢@""♢
|    |    |    |    |    |    |    |    |    [394:394] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [394:394] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [394:394] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    [394:394] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    [394:394] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [394:394] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    [394:394] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [394:394] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [394:394] <Match> = ♢value♢
|    |    |    |    |    |    |    |    |    [394:394] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [394:394] <Text> = ♢isEqual♢
|    |    |    |    |    |    |    |    |    [394:394] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [394:394] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [394:394] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [394:394] <Match> = ♢NSArray♢
|    |    |    |    |    |    |    |    |    |    [394:394] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [394:394] <Text> = ♢array♢
|    |    |    |    |    |    |    |    |    |    [394:394] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [394:394] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [394:394] <Match> = ♢)♢
|    |    |    |    |    |    |    [394:394] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [394:394] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [394:394] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [394:394] <Match> = ♢dict♢
|    |    |    |    |    |    |    |    [394:394] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [394:394] <Text> = ♢setObject♢
|    |    |    |    |    |    |    |    [394:394] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [394:394] <Text> = ♢value♢
|    |    |    |    |    |    |    |    [394:394] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [394:394] <Text> = ♢forKey♢
|    |    |    |    |    |    |    |    [394:394] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [394:394] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [394:394] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [394:394] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [394:394] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [394:394] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    [394:394] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [394:394] <Text> = ♢documentPropertyToAttributeNameMappings♢
|    |    |    |    |    |    |    |    |    |    [394:394] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [394:394] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [394:394] <Text> = ♢objectForKey♢
|    |    |    |    |    |    |    |    |    [394:394] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [394:394] <Text> = ♢property♢
|    |    |    |    |    |    |    |    |    [394:394] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [394:394] <Match> = ♢]♢
|    |    |    |    |    |    |    [394:394] <Semicolon> = ♢;♢
|    |    |    |    |    |    [394:395] <Newline> = ♢¶♢
|    |    |    |    |    |    [395:395] <Indenting> = ♢••••♢
|    |    |    |    |    |    [395:395] <Match> = ♢}♢
|    |    |    |    [395:396] <Newline> = ♢¶♢
|    |    |    |    [396:396] <Indenting> = ♢••••♢
|    |    |    |    [396:397] <Newline> = ♢¶♢
|    |    |    |    [397:397] <Indenting> = ♢••••♢
|    |    |    |    [397:397] <Text> = ♢NSFileWrapper♢
|    |    |    |    [397:397] <Whitespace> = ♢•♢
|    |    |    |    [397:397] <Asterisk> = ♢*♢
|    |    |    |    [397:397] <Text> = ♢result♢
|    |    |    |    [397:397] <Whitespace> = ♢•♢
|    |    |    |    [397:397] <Text> = ♢=♢
|    |    |    |    [397:397] <Whitespace> = ♢•♢
|    |    |    |    [397:397] <ObjCNil> = ♢nil♢
|    |    |    |    [397:397] <Semicolon> = ♢;♢
|    |    |    |    [397:398] <Newline> = ♢¶♢
|    |    |    |    [398:398] <Indenting> = ♢••••♢
|    |    |    |    [398:400] <CConditionIf>
|    |    |    |    |    [398:398] <Match> = ♢if♢
|    |    |    |    |    [398:398] <Whitespace> = ♢•♢
|    |    |    |    |    [398:398] <Parenthesis>
|    |    |    |    |    |    [398:398] <Match> = ♢(♢
|    |    |    |    |    |    [398:398] <Text> = ♢docType♢
|    |    |    |    |    |    [398:398] <Whitespace> = ♢•♢
|    |    |    |    |    |    [398:398] <Text> = ♢==♢
|    |    |    |    |    |    [398:398] <Whitespace> = ♢•♢
|    |    |    |    |    |    [398:398] <Text> = ♢NSRTFDTextDocumentType♢
|    |    |    |    |    |    [398:398] <Whitespace> = ♢•♢
|    |    |    |    |    |    [398:398] <Text> = ♢||♢
|    |    |    |    |    |    [398:398] <Whitespace> = ♢•♢
|    |    |    |    |    |    [398:398] <Parenthesis>
|    |    |    |    |    |    |    [398:398] <Match> = ♢(♢
|    |    |    |    |    |    |    [398:398] <Text> = ♢docType♢
|    |    |    |    |    |    |    [398:398] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [398:398] <Text> = ♢==♢
|    |    |    |    |    |    |    [398:398] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [398:398] <Text> = ♢NSPlainTextDocumentType♢
|    |    |    |    |    |    |    [398:398] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [398:398] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    [398:398] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    [398:398] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [398:398] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    [398:398] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [398:398] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [398:398] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [398:398] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [398:398] <Text> = ♢isOpenedIgnoringRichText♢
|    |    |    |    |    |    |    |    [398:398] <Match> = ♢]♢
|    |    |    |    |    |    |    [398:398] <Match> = ♢)♢
|    |    |    |    |    |    [398:398] <Match> = ♢)♢
|    |    |    |    |    [398:398] <Whitespace> = ♢•♢
|    |    |    |    |    [398:400] <Braces>
|    |    |    |    |    |    [398:398] <Match> = ♢{♢
|    |    |    |    |    |    [398:398] <Whitespace> = ♢→♢
|    |    |    |    |    |    [398:398] <CPPComment> = ♢//•We•obtain•a•file•wrapper•from•the•text•storage•for•RTFD•(to•produce•a•directory),•or•for•true•plain-text•documents•(to•write•out•encoding•in•extended•attributes)♢
|    |    |    |    |    |    [398:399] <Newline> = ♢¶♢
|    |    |    |    |    |    [399:399] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [399:399] <Text> = ♢result♢
|    |    |    |    |    |    [399:399] <Whitespace> = ♢•♢
|    |    |    |    |    |    [399:399] <Text> = ♢=♢
|    |    |    |    |    |    [399:399] <Whitespace> = ♢•♢
|    |    |    |    |    |    [399:399] <ObjCMethodCall>
|    |    |    |    |    |    |    [399:399] <Match> = ♢[♢
|    |    |    |    |    |    |    [399:399] <Match> = ♢text♢
|    |    |    |    |    |    |    [399:399] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [399:399] <Text> = ♢fileWrapperFromRange♢
|    |    |    |    |    |    |    [399:399] <Colon> = ♢:♢
|    |    |    |    |    |    |    [399:399] <Text> = ♢range♢
|    |    |    |    |    |    |    [399:399] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [399:399] <Text> = ♢documentAttributes♢
|    |    |    |    |    |    |    [399:399] <Colon> = ♢:♢
|    |    |    |    |    |    |    [399:399] <Text> = ♢dict♢
|    |    |    |    |    |    |    [399:399] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [399:399] <Text> = ♢error♢
|    |    |    |    |    |    |    [399:399] <Colon> = ♢:♢
|    |    |    |    |    |    |    [399:399] <Text> = ♢outError♢
|    |    |    |    |    |    |    [399:399] <Match> = ♢]♢
|    |    |    |    |    |    [399:399] <Semicolon> = ♢;♢
|    |    |    |    |    |    [399:399] <Whitespace> = ♢•♢
|    |    |    |    |    |    [399:399] <CPPComment> = ♢//•returns•NSFileWrapper♢
|    |    |    |    |    |    [399:400] <Newline> = ♢¶♢
|    |    |    |    |    |    [400:400] <Indenting> = ♢••••♢
|    |    |    |    |    |    [400:400] <Match> = ♢}♢
|    |    |    |    [400:400] <Whitespace> = ♢•♢
|    |    |    |    [400:406] <CConditionElse>
|    |    |    |    |    [400:400] <Match> = ♢else♢
|    |    |    |    |    [400:400] <Whitespace> = ♢•♢
|    |    |    |    |    [400:406] <Braces>
|    |    |    |    |    |    [400:400] <Match> = ♢{♢
|    |    |    |    |    |    [400:401] <Newline> = ♢¶♢
|    |    |    |    |    |    [401:401] <Indenting> = ♢••••→♢
|    |    |    |    |    |    [401:401] <Text> = ♢NSData♢
|    |    |    |    |    |    [401:401] <Whitespace> = ♢•♢
|    |    |    |    |    |    [401:401] <Asterisk> = ♢*♢
|    |    |    |    |    |    [401:401] <Text> = ♢data♢
|    |    |    |    |    |    [401:401] <Whitespace> = ♢•♢
|    |    |    |    |    |    [401:401] <Text> = ♢=♢
|    |    |    |    |    |    [401:401] <Whitespace> = ♢•♢
|    |    |    |    |    |    [401:401] <ObjCMethodCall>
|    |    |    |    |    |    |    [401:401] <Match> = ♢[♢
|    |    |    |    |    |    |    [401:401] <Match> = ♢text♢
|    |    |    |    |    |    |    [401:401] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [401:401] <Text> = ♢dataFromRange♢
|    |    |    |    |    |    |    [401:401] <Colon> = ♢:♢
|    |    |    |    |    |    |    [401:401] <Text> = ♢range♢
|    |    |    |    |    |    |    [401:401] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [401:401] <Text> = ♢documentAttributes♢
|    |    |    |    |    |    |    [401:401] <Colon> = ♢:♢
|    |    |    |    |    |    |    [401:401] <Text> = ♢dict♢
|    |    |    |    |    |    |    [401:401] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [401:401] <Text> = ♢error♢
|    |    |    |    |    |    |    [401:401] <Colon> = ♢:♢
|    |    |    |    |    |    |    [401:401] <Text> = ♢outError♢
|    |    |    |    |    |    |    [401:401] <Match> = ♢]♢
|    |    |    |    |    |    [401:401] <Semicolon> = ♢;♢
|    |    |    |    |    |    [401:401] <Whitespace> = ♢•♢
|    |    |    |    |    |    [401:401] <CPPComment> = ♢//•returns•NSData♢
|    |    |    |    |    |    [401:402] <Newline> = ♢¶♢
|    |    |    |    |    |    [402:402] <Indenting> = ♢→♢
|    |    |    |    |    |    [402:405] <CConditionIf>
|    |    |    |    |    |    |    [402:402] <Match> = ♢if♢
|    |    |    |    |    |    |    [402:402] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [402:402] <Parenthesis>
|    |    |    |    |    |    |    |    [402:402] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [402:402] <Text> = ♢data♢
|    |    |    |    |    |    |    |    [402:402] <Match> = ♢)♢
|    |    |    |    |    |    |    [402:402] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [402:405] <Braces>
|    |    |    |    |    |    |    |    [402:402] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [402:403] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [403:403] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [403:403] <Text> = ♢result♢
|    |    |    |    |    |    |    |    [403:403] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [403:403] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [403:403] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [403:403] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [403:403] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [403:403] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [403:403] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [403:403] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [403:403] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [403:403] <Match> = ♢NSFileWrapper♢
|    |    |    |    |    |    |    |    |    |    |    [403:403] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [403:403] <Text> = ♢alloc♢
|    |    |    |    |    |    |    |    |    |    |    [403:403] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [403:403] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [403:403] <Text> = ♢initRegularFileWithContents♢
|    |    |    |    |    |    |    |    |    |    [403:403] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [403:403] <Text> = ♢data♢
|    |    |    |    |    |    |    |    |    |    [403:403] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [403:403] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [403:403] <Text> = ♢autorelease♢
|    |    |    |    |    |    |    |    |    [403:403] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [403:403] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [403:404] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [404:404] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [404:404] <CConditionIf>
|    |    |    |    |    |    |    |    |    [404:404] <Match> = ♢if♢
|    |    |    |    |    |    |    |    |    [404:404] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [404:404] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [404:404] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [404:404] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    |    |    [404:404] <Text> = ♢result♢
|    |    |    |    |    |    |    |    |    |    [404:404] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [404:404] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    |    [404:404] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    |    [404:404] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [404:404] <Text> = ♢outError♢
|    |    |    |    |    |    |    |    |    |    [404:404] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [404:404] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [404:404] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    |    [404:404] <Text> = ♢outError♢
|    |    |    |    |    |    |    |    |    [404:404] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [404:404] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    [404:404] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [404:404] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [404:404] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [404:404] <Match> = ♢NSError♢
|    |    |    |    |    |    |    |    |    |    [404:404] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [404:404] <Text> = ♢errorWithDomain♢
|    |    |    |    |    |    |    |    |    |    [404:404] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [404:404] <Text> = ♢NSCocoaErrorDomain♢
|    |    |    |    |    |    |    |    |    |    [404:404] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [404:404] <Text> = ♢code♢
|    |    |    |    |    |    |    |    |    |    [404:404] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [404:404] <Text> = ♢NSFileWriteUnknownError♢
|    |    |    |    |    |    |    |    |    |    [404:404] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [404:404] <Text> = ♢userInfo♢
|    |    |    |    |    |    |    |    |    |    [404:404] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [404:404] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    |    |    |    [404:404] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [404:404] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [404:404] <Whitespace> = ♢••••♢
|    |    |    |    |    |    |    |    [404:404] <CPPComment> = ♢//•Unlikely,•but•just•in•case•we•should•generate•an•NSError•for•this•case♢
|    |    |    |    |    |    |    |    [404:405] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [405:405] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    |    |    [405:405] <Match> = ♢}♢
|    |    |    |    |    |    [405:406] <Newline> = ♢¶♢
|    |    |    |    |    |    [406:406] <Indenting> = ♢••••♢
|    |    |    |    |    |    [406:406] <Match> = ♢}♢
|    |    |    |    [406:407] <Newline> = ♢¶♢
|    |    |    |    [407:407] <Indenting> = ♢••••♢
|    |    |    |    [407:408] <Newline> = ♢¶♢
|    |    |    |    [408:408] <Indenting> = ♢••••♢
|    |    |    |    [408:408] <CFlowReturn>
|    |    |    |    |    [408:408] <Match> = ♢return♢
|    |    |    |    |    [408:408] <Whitespace> = ♢•♢
|    |    |    |    |    [408:408] <Text> = ♢result♢
|    |    |    |    |    [408:408] <Semicolon> = ♢;♢
|    |    |    |    [408:409] <Newline> = ♢¶♢
|    |    |    |    [409:409] <Match> = ♢}♢
|    |    [409:410] <Newline> = ♢¶♢
|    |    [410:411] <Newline> = ♢¶♢
|    |    [411:412] <CComment> = ♢/*•Clear•the•delegates•of•the•text•views•and•window,•then•release•all•resources•and•go•away...¶*/♢
|    |    [412:413] <Newline> = ♢¶♢
|    |    [413:429] <ObjCMethodImplementation>
|    |    |    [413:413] <Match> = ♢-♢
|    |    |    [413:413] <Whitespace> = ♢•♢
|    |    |    [413:413] <Parenthesis>
|    |    |    |    [413:413] <Match> = ♢(♢
|    |    |    |    [413:413] <CVoid> = ♢void♢
|    |    |    |    [413:413] <Match> = ♢)♢
|    |    |    [413:413] <Text> = ♢dealloc♢
|    |    |    [413:413] <Whitespace> = ♢•♢
|    |    |    [413:429] <Braces>
|    |    |    |    [413:413] <Match> = ♢{♢
|    |    |    |    [413:414] <Newline> = ♢¶♢
|    |    |    |    [414:414] <Indenting> = ♢••••♢
|    |    |    |    [414:414] <ObjCMethodCall>
|    |    |    |    |    [414:414] <Match> = ♢[♢
|    |    |    |    |    [414:414] <Match> = ♢textStorage♢
|    |    |    |    |    [414:414] <Whitespace> = ♢•♢
|    |    |    |    |    [414:414] <Text> = ♢release♢
|    |    |    |    |    [414:414] <Match> = ♢]♢
|    |    |    |    [414:414] <Semicolon> = ♢;♢
|    |    |    |    [414:415] <Newline> = ♢¶♢
|    |    |    |    [415:415] <Indenting> = ♢••••♢
|    |    |    |    [415:415] <ObjCMethodCall>
|    |    |    |    |    [415:415] <Match> = ♢[♢
|    |    |    |    |    [415:415] <Match> = ♢backgroundColor♢
|    |    |    |    |    [415:415] <Whitespace> = ♢•♢
|    |    |    |    |    [415:415] <Text> = ♢release♢
|    |    |    |    |    [415:415] <Match> = ♢]♢
|    |    |    |    [415:415] <Semicolon> = ♢;♢
|    |    |    |    [415:416] <Newline> = ♢¶♢
|    |    |    |    [416:416] <Indenting> = ♢••••♢
|    |    |    |    [416:417] <Newline> = ♢¶♢
|    |    |    |    [417:417] <Indenting> = ♢••••♢
|    |    |    |    [417:417] <ObjCMethodCall>
|    |    |    |    |    [417:417] <Match> = ♢[♢
|    |    |    |    |    [417:417] <Match> = ♢author♢
|    |    |    |    |    [417:417] <Whitespace> = ♢•♢
|    |    |    |    |    [417:417] <Text> = ♢release♢
|    |    |    |    |    [417:417] <Match> = ♢]♢
|    |    |    |    [417:417] <Semicolon> = ♢;♢
|    |    |    |    [417:418] <Newline> = ♢¶♢
|    |    |    |    [418:418] <Indenting> = ♢••••♢
|    |    |    |    [418:418] <ObjCMethodCall>
|    |    |    |    |    [418:418] <Match> = ♢[♢
|    |    |    |    |    [418:418] <Match> = ♢comment♢
|    |    |    |    |    [418:418] <Whitespace> = ♢•♢
|    |    |    |    |    [418:418] <Text> = ♢release♢
|    |    |    |    |    [418:418] <Match> = ♢]♢
|    |    |    |    [418:418] <Semicolon> = ♢;♢
|    |    |    |    [418:419] <Newline> = ♢¶♢
|    |    |    |    [419:419] <Indenting> = ♢••••♢
|    |    |    |    [419:419] <ObjCMethodCall>
|    |    |    |    |    [419:419] <Match> = ♢[♢
|    |    |    |    |    [419:419] <Match> = ♢subject♢
|    |    |    |    |    [419:419] <Whitespace> = ♢•♢
|    |    |    |    |    [419:419] <Text> = ♢release♢
|    |    |    |    |    [419:419] <Match> = ♢]♢
|    |    |    |    [419:419] <Semicolon> = ♢;♢
|    |    |    |    [419:420] <Newline> = ♢¶♢
|    |    |    |    [420:420] <Indenting> = ♢••••♢
|    |    |    |    [420:420] <ObjCMethodCall>
|    |    |    |    |    [420:420] <Match> = ♢[♢
|    |    |    |    |    [420:420] <Match> = ♢title♢
|    |    |    |    |    [420:420] <Whitespace> = ♢•♢
|    |    |    |    |    [420:420] <Text> = ♢release♢
|    |    |    |    |    [420:420] <Match> = ♢]♢
|    |    |    |    [420:420] <Semicolon> = ♢;♢
|    |    |    |    [420:421] <Newline> = ♢¶♢
|    |    |    |    [421:421] <Indenting> = ♢••••♢
|    |    |    |    [421:421] <ObjCMethodCall>
|    |    |    |    |    [421:421] <Match> = ♢[♢
|    |    |    |    |    [421:421] <Match> = ♢keywords♢
|    |    |    |    |    [421:421] <Whitespace> = ♢•♢
|    |    |    |    |    [421:421] <Text> = ♢release♢
|    |    |    |    |    [421:421] <Match> = ♢]♢
|    |    |    |    [421:421] <Semicolon> = ♢;♢
|    |    |    |    [421:422] <Newline> = ♢¶♢
|    |    |    |    [422:422] <Indenting> = ♢••••♢
|    |    |    |    [422:422] <ObjCMethodCall>
|    |    |    |    |    [422:422] <Match> = ♢[♢
|    |    |    |    |    [422:422] <Match> = ♢copyright♢
|    |    |    |    |    [422:422] <Whitespace> = ♢•♢
|    |    |    |    |    [422:422] <Text> = ♢release♢
|    |    |    |    |    [422:422] <Match> = ♢]♢
|    |    |    |    [422:422] <Semicolon> = ♢;♢
|    |    |    |    [422:423] <Newline> = ♢¶♢
|    |    |    |    [423:423] <Indenting> = ♢••••♢
|    |    |    |    [423:424] <Newline> = ♢¶♢
|    |    |    |    [424:424] <Indenting> = ♢••••♢
|    |    |    |    [424:424] <ObjCMethodCall>
|    |    |    |    |    [424:424] <Match> = ♢[♢
|    |    |    |    |    [424:424] <Match> = ♢defaultDestination♢
|    |    |    |    |    [424:424] <Whitespace> = ♢•♢
|    |    |    |    |    [424:424] <Text> = ♢release♢
|    |    |    |    |    [424:424] <Match> = ♢]♢
|    |    |    |    [424:424] <Semicolon> = ♢;♢
|    |    |    |    [424:425] <Newline> = ♢¶♢
|    |    |    |    [425:426] <Newline> = ♢¶♢
|    |    |    |    [426:426] <Indenting> = ♢••••♢
|    |    |    |    [426:426] <CConditionIf>
|    |    |    |    |    [426:426] <Match> = ♢if♢
|    |    |    |    |    [426:426] <Whitespace> = ♢•♢
|    |    |    |    |    [426:426] <Parenthesis>
|    |    |    |    |    |    [426:426] <Match> = ♢(♢
|    |    |    |    |    |    [426:426] <Text> = ♢uniqueZone♢
|    |    |    |    |    |    [426:426] <Match> = ♢)♢
|    |    |    |    |    [426:426] <Whitespace> = ♢•♢
|    |    |    |    |    [426:426] <CFunctionCall>
|    |    |    |    |    |    [426:426] <Match> = ♢NSRecycleZone♢
|    |    |    |    |    |    [426:426] <Parenthesis>
|    |    |    |    |    |    |    [426:426] <Match> = ♢(♢
|    |    |    |    |    |    |    [426:426] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [426:426] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [426:426] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [426:426] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [426:426] <Text> = ♢zone♢
|    |    |    |    |    |    |    |    [426:426] <Match> = ♢]♢
|    |    |    |    |    |    |    [426:426] <Match> = ♢)♢
|    |    |    |    |    [426:426] <Semicolon> = ♢;♢
|    |    |    |    [426:427] <Newline> = ♢¶♢
|    |    |    |    [427:428] <Newline> = ♢¶♢
|    |    |    |    [428:428] <Indenting> = ♢••••♢
|    |    |    |    [428:428] <ObjCMethodCall>
|    |    |    |    |    [428:428] <Match> = ♢[♢
|    |    |    |    |    [428:428] <ObjCSuper> = ♢super♢
|    |    |    |    |    [428:428] <Whitespace> = ♢•♢
|    |    |    |    |    [428:428] <Text> = ♢dealloc♢
|    |    |    |    |    [428:428] <Match> = ♢]♢
|    |    |    |    [428:428] <Semicolon> = ♢;♢
|    |    |    |    [428:429] <Newline> = ♢¶♢
|    |    |    |    [429:429] <Match> = ♢}♢
|    |    [429:430] <Newline> = ♢¶♢
|    |    [430:431] <Newline> = ♢¶♢
|    |    [431:433] <ObjCMethodImplementation>
|    |    |    [431:431] <Match> = ♢-♢
|    |    |    [431:431] <Whitespace> = ♢•♢
|    |    |    [431:431] <Parenthesis>
|    |    |    |    [431:431] <Match> = ♢(♢
|    |    |    |    [431:431] <Text> = ♢CGFloat♢
|    |    |    |    [431:431] <Match> = ♢)♢
|    |    |    [431:431] <Text> = ♢scaleFactor♢
|    |    |    [431:431] <Whitespace> = ♢•♢
|    |    |    [431:433] <Braces>
|    |    |    |    [431:431] <Match> = ♢{♢
|    |    |    |    [431:432] <Newline> = ♢¶♢
|    |    |    |    [432:432] <Indenting> = ♢••••♢
|    |    |    |    [432:432] <CFlowReturn>
|    |    |    |    |    [432:432] <Match> = ♢return♢
|    |    |    |    |    [432:432] <Whitespace> = ♢•♢
|    |    |    |    |    [432:432] <Text> = ♢scaleFactor♢
|    |    |    |    |    [432:432] <Semicolon> = ♢;♢
|    |    |    |    [432:433] <Newline> = ♢¶♢
|    |    |    |    [433:433] <Match> = ♢}♢
|    |    [433:434] <Newline> = ♢¶♢
|    |    [434:435] <Newline> = ♢¶♢
|    |    [435:437] <ObjCMethodImplementation>
|    |    |    [435:435] <Match> = ♢-♢
|    |    |    [435:435] <Whitespace> = ♢•♢
|    |    |    [435:435] <Parenthesis>
|    |    |    |    [435:435] <Match> = ♢(♢
|    |    |    |    [435:435] <CVoid> = ♢void♢
|    |    |    |    [435:435] <Match> = ♢)♢
|    |    |    [435:435] <Text> = ♢setScaleFactor♢
|    |    |    [435:435] <Colon> = ♢:♢
|    |    |    [435:435] <Parenthesis>
|    |    |    |    [435:435] <Match> = ♢(♢
|    |    |    |    [435:435] <Text> = ♢CGFloat♢
|    |    |    |    [435:435] <Match> = ♢)♢
|    |    |    [435:435] <Text> = ♢newScaleFactor♢
|    |    |    [435:435] <Whitespace> = ♢•♢
|    |    |    [435:437] <Braces>
|    |    |    |    [435:435] <Match> = ♢{♢
|    |    |    |    [435:436] <Newline> = ♢¶♢
|    |    |    |    [436:436] <Indenting> = ♢••••♢
|    |    |    |    [436:436] <Text> = ♢scaleFactor♢
|    |    |    |    [436:436] <Whitespace> = ♢•♢
|    |    |    |    [436:436] <Text> = ♢=♢
|    |    |    |    [436:436] <Whitespace> = ♢•♢
|    |    |    |    [436:436] <Text> = ♢newScaleFactor♢
|    |    |    |    [436:436] <Semicolon> = ♢;♢
|    |    |    |    [436:437] <Newline> = ♢¶♢
|    |    |    |    [437:437] <Match> = ♢}♢
|    |    [437:438] <Newline> = ♢¶♢
|    |    [438:439] <Newline> = ♢¶♢
|    |    [439:441] <ObjCMethodImplementation>
|    |    |    [439:439] <Match> = ♢-♢
|    |    |    [439:439] <Whitespace> = ♢•♢
|    |    |    [439:439] <Parenthesis>
|    |    |    |    [439:439] <Match> = ♢(♢
|    |    |    |    [439:439] <Text> = ♢NSSize♢
|    |    |    |    [439:439] <Match> = ♢)♢
|    |    |    [439:439] <Text> = ♢viewSize♢
|    |    |    [439:439] <Whitespace> = ♢•♢
|    |    |    [439:441] <Braces>
|    |    |    |    [439:439] <Match> = ♢{♢
|    |    |    |    [439:440] <Newline> = ♢¶♢
|    |    |    |    [440:440] <Indenting> = ♢••••♢
|    |    |    |    [440:440] <CFlowReturn>
|    |    |    |    |    [440:440] <Match> = ♢return♢
|    |    |    |    |    [440:440] <Whitespace> = ♢•♢
|    |    |    |    |    [440:440] <Text> = ♢viewSize♢
|    |    |    |    |    [440:440] <Semicolon> = ♢;♢
|    |    |    |    [440:441] <Newline> = ♢¶♢
|    |    |    |    [441:441] <Match> = ♢}♢
|    |    [441:442] <Newline> = ♢¶♢
|    |    [442:443] <Newline> = ♢¶♢
|    |    [443:445] <ObjCMethodImplementation>
|    |    |    [443:443] <Match> = ♢-♢
|    |    |    [443:443] <Whitespace> = ♢•♢
|    |    |    [443:443] <Parenthesis>
|    |    |    |    [443:443] <Match> = ♢(♢
|    |    |    |    [443:443] <CVoid> = ♢void♢
|    |    |    |    [443:443] <Match> = ♢)♢
|    |    |    [443:443] <Text> = ♢setViewSize♢
|    |    |    [443:443] <Colon> = ♢:♢
|    |    |    [443:443] <Parenthesis>
|    |    |    |    [443:443] <Match> = ♢(♢
|    |    |    |    [443:443] <Text> = ♢NSSize♢
|    |    |    |    [443:443] <Match> = ♢)♢
|    |    |    [443:443] <Text> = ♢size♢
|    |    |    [443:443] <Whitespace> = ♢•♢
|    |    |    [443:445] <Braces>
|    |    |    |    [443:443] <Match> = ♢{♢
|    |    |    |    [443:444] <Newline> = ♢¶♢
|    |    |    |    [444:444] <Indenting> = ♢••••♢
|    |    |    |    [444:444] <Text> = ♢viewSize♢
|    |    |    |    [444:444] <Whitespace> = ♢•♢
|    |    |    |    [444:444] <Text> = ♢=♢
|    |    |    |    [444:444] <Whitespace> = ♢•♢
|    |    |    |    [444:444] <Text> = ♢size♢
|    |    |    |    [444:444] <Semicolon> = ♢;♢
|    |    |    |    [444:445] <Newline> = ♢¶♢
|    |    |    |    [445:445] <Match> = ♢}♢
|    |    [445:446] <Newline> = ♢¶♢
|    |    [446:447] <Newline> = ♢¶♢
|    |    [447:449] <ObjCMethodImplementation>
|    |    |    [447:447] <Match> = ♢-♢
|    |    |    [447:447] <Whitespace> = ♢•♢
|    |    |    [447:447] <Parenthesis>
|    |    |    |    [447:447] <Match> = ♢(♢
|    |    |    |    [447:447] <CVoid> = ♢void♢
|    |    |    |    [447:447] <Match> = ♢)♢
|    |    |    [447:447] <Text> = ♢setReadOnly♢
|    |    |    [447:447] <Colon> = ♢:♢
|    |    |    [447:447] <Parenthesis>
|    |    |    |    [447:447] <Match> = ♢(♢
|    |    |    |    [447:447] <Text> = ♢BOOL♢
|    |    |    |    [447:447] <Match> = ♢)♢
|    |    |    [447:447] <Text> = ♢flag♢
|    |    |    [447:447] <Whitespace> = ♢•♢
|    |    |    [447:449] <Braces>
|    |    |    |    [447:447] <Match> = ♢{♢
|    |    |    |    [447:448] <Newline> = ♢¶♢
|    |    |    |    [448:448] <Indenting> = ♢••••♢
|    |    |    |    [448:448] <Text> = ♢isReadOnly♢
|    |    |    |    [448:448] <Whitespace> = ♢•♢
|    |    |    |    [448:448] <Text> = ♢=♢
|    |    |    |    [448:448] <Whitespace> = ♢•♢
|    |    |    |    [448:448] <Text> = ♢flag♢
|    |    |    |    [448:448] <Semicolon> = ♢;♢
|    |    |    |    [448:449] <Newline> = ♢¶♢
|    |    |    |    [449:449] <Match> = ♢}♢
|    |    [449:450] <Newline> = ♢¶♢
|    |    [450:451] <Newline> = ♢¶♢
|    |    [451:453] <ObjCMethodImplementation>
|    |    |    [451:451] <Match> = ♢-♢
|    |    |    [451:451] <Whitespace> = ♢•♢
|    |    |    [451:451] <Parenthesis>
|    |    |    |    [451:451] <Match> = ♢(♢
|    |    |    |    [451:451] <Text> = ♢BOOL♢
|    |    |    |    [451:451] <Match> = ♢)♢
|    |    |    [451:451] <Text> = ♢isReadOnly♢
|    |    |    [451:451] <Whitespace> = ♢•♢
|    |    |    [451:453] <Braces>
|    |    |    |    [451:451] <Match> = ♢{♢
|    |    |    |    [451:452] <Newline> = ♢¶♢
|    |    |    |    [452:452] <Indenting> = ♢••••♢
|    |    |    |    [452:452] <CFlowReturn>
|    |    |    |    |    [452:452] <Match> = ♢return♢
|    |    |    |    |    [452:452] <Whitespace> = ♢•♢
|    |    |    |    |    [452:452] <Text> = ♢isReadOnly♢
|    |    |    |    |    [452:452] <Semicolon> = ♢;♢
|    |    |    |    [452:453] <Newline> = ♢¶♢
|    |    |    |    [453:453] <Match> = ♢}♢
|    |    [453:454] <Newline> = ♢¶♢
|    |    [454:455] <Newline> = ♢¶♢
|    |    [455:459] <ObjCMethodImplementation>
|    |    |    [455:455] <Match> = ♢-♢
|    |    |    [455:455] <Whitespace> = ♢•♢
|    |    |    [455:455] <Parenthesis>
|    |    |    |    [455:455] <Match> = ♢(♢
|    |    |    |    [455:455] <CVoid> = ♢void♢
|    |    |    |    [455:455] <Match> = ♢)♢
|    |    |    [455:455] <Text> = ♢setBackgroundColor♢
|    |    |    [455:455] <Colon> = ♢:♢
|    |    |    [455:455] <Parenthesis>
|    |    |    |    [455:455] <Match> = ♢(♢
|    |    |    |    [455:455] <Text> = ♢NSColor♢
|    |    |    |    [455:455] <Whitespace> = ♢•♢
|    |    |    |    [455:455] <Asterisk> = ♢*♢
|    |    |    |    [455:455] <Match> = ♢)♢
|    |    |    [455:455] <Text> = ♢color♢
|    |    |    [455:455] <Whitespace> = ♢•♢
|    |    |    [455:459] <Braces>
|    |    |    |    [455:455] <Match> = ♢{♢
|    |    |    |    [455:456] <Newline> = ♢¶♢
|    |    |    |    [456:456] <Indenting> = ♢••••♢
|    |    |    |    [456:456] <Text> = ♢id♢
|    |    |    |    [456:456] <Whitespace> = ♢•♢
|    |    |    |    [456:456] <Text> = ♢oldCol♢
|    |    |    |    [456:456] <Whitespace> = ♢•♢
|    |    |    |    [456:456] <Text> = ♢=♢
|    |    |    |    [456:456] <Whitespace> = ♢•♢
|    |    |    |    [456:456] <Text> = ♢backgroundColor♢
|    |    |    |    [456:456] <Semicolon> = ♢;♢
|    |    |    |    [456:457] <Newline> = ♢¶♢
|    |    |    |    [457:457] <Indenting> = ♢••••♢
|    |    |    |    [457:457] <Text> = ♢backgroundColor♢
|    |    |    |    [457:457] <Whitespace> = ♢•♢
|    |    |    |    [457:457] <Text> = ♢=♢
|    |    |    |    [457:457] <Whitespace> = ♢•♢
|    |    |    |    [457:457] <ObjCMethodCall>
|    |    |    |    |    [457:457] <Match> = ♢[♢
|    |    |    |    |    [457:457] <Match> = ♢color♢
|    |    |    |    |    [457:457] <Whitespace> = ♢•♢
|    |    |    |    |    [457:457] <Text> = ♢copy♢
|    |    |    |    |    [457:457] <Match> = ♢]♢
|    |    |    |    [457:457] <Semicolon> = ♢;♢
|    |    |    |    [457:458] <Newline> = ♢¶♢
|    |    |    |    [458:458] <Indenting> = ♢••••♢
|    |    |    |    [458:458] <ObjCMethodCall>
|    |    |    |    |    [458:458] <Match> = ♢[♢
|    |    |    |    |    [458:458] <Match> = ♢oldCol♢
|    |    |    |    |    [458:458] <Whitespace> = ♢•♢
|    |    |    |    |    [458:458] <Text> = ♢release♢
|    |    |    |    |    [458:458] <Match> = ♢]♢
|    |    |    |    [458:458] <Semicolon> = ♢;♢
|    |    |    |    [458:459] <Newline> = ♢¶♢
|    |    |    |    [459:459] <Match> = ♢}♢
|    |    [459:460] <Newline> = ♢¶♢
|    |    [460:461] <Newline> = ♢¶♢
|    |    [461:463] <ObjCMethodImplementation>
|    |    |    [461:461] <Match> = ♢-♢
|    |    |    [461:461] <Whitespace> = ♢•♢
|    |    |    [461:461] <Parenthesis>
|    |    |    |    [461:461] <Match> = ♢(♢
|    |    |    |    [461:461] <Text> = ♢NSColor♢
|    |    |    |    [461:461] <Whitespace> = ♢•♢
|    |    |    |    [461:461] <Asterisk> = ♢*♢
|    |    |    |    [461:461] <Match> = ♢)♢
|    |    |    [461:461] <Text> = ♢backgroundColor♢
|    |    |    [461:461] <Whitespace> = ♢•♢
|    |    |    [461:463] <Braces>
|    |    |    |    [461:461] <Match> = ♢{♢
|    |    |    |    [461:462] <Newline> = ♢¶♢
|    |    |    |    [462:462] <Indenting> = ♢••••♢
|    |    |    |    [462:462] <CFlowReturn>
|    |    |    |    |    [462:462] <Match> = ♢return♢
|    |    |    |    |    [462:462] <Whitespace> = ♢•♢
|    |    |    |    |    [462:462] <Text> = ♢backgroundColor♢
|    |    |    |    |    [462:462] <Semicolon> = ♢;♢
|    |    |    |    [462:463] <Newline> = ♢¶♢
|    |    |    |    [463:463] <Match> = ♢}♢
|    |    [463:464] <Newline> = ♢¶♢
|    |    [464:465] <Newline> = ♢¶♢
|    |    [465:467] <ObjCMethodImplementation>
|    |    |    [465:465] <Match> = ♢-♢
|    |    |    [465:465] <Whitespace> = ♢•♢
|    |    |    [465:465] <Parenthesis>
|    |    |    |    [465:465] <Match> = ♢(♢
|    |    |    |    [465:465] <Text> = ♢NSTextStorage♢
|    |    |    |    [465:465] <Whitespace> = ♢•♢
|    |    |    |    [465:465] <Asterisk> = ♢*♢
|    |    |    |    [465:465] <Match> = ♢)♢
|    |    |    [465:465] <Text> = ♢textStorage♢
|    |    |    [465:465] <Whitespace> = ♢•♢
|    |    |    [465:467] <Braces>
|    |    |    |    [465:465] <Match> = ♢{♢
|    |    |    |    [465:466] <Newline> = ♢¶♢
|    |    |    |    [466:466] <Indenting> = ♢••••♢
|    |    |    |    [466:466] <CFlowReturn>
|    |    |    |    |    [466:466] <Match> = ♢return♢
|    |    |    |    |    [466:466] <Whitespace> = ♢•♢
|    |    |    |    |    [466:466] <Text> = ♢textStorage♢
|    |    |    |    |    [466:466] <Semicolon> = ♢;♢
|    |    |    |    [466:467] <Newline> = ♢¶♢
|    |    |    |    [467:467] <Match> = ♢}♢
|    |    [467:468] <Newline> = ♢¶♢
|    |    [468:469] <Newline> = ♢¶♢
|    |    [469:471] <ObjCMethodImplementation>
|    |    |    [469:469] <Match> = ♢-♢
|    |    |    [469:469] <Whitespace> = ♢•♢
|    |    |    [469:469] <Parenthesis>
|    |    |    |    [469:469] <Match> = ♢(♢
|    |    |    |    [469:469] <Text> = ♢NSSize♢
|    |    |    |    [469:469] <Match> = ♢)♢
|    |    |    [469:469] <Text> = ♢paperSize♢
|    |    |    [469:469] <Whitespace> = ♢•♢
|    |    |    [469:471] <Braces>
|    |    |    |    [469:469] <Match> = ♢{♢
|    |    |    |    [469:470] <Newline> = ♢¶♢
|    |    |    |    [470:470] <Indenting> = ♢••••♢
|    |    |    |    [470:470] <CFlowReturn>
|    |    |    |    |    [470:470] <Match> = ♢return♢
|    |    |    |    |    [470:470] <Whitespace> = ♢•♢
|    |    |    |    |    [470:470] <ObjCMethodCall>
|    |    |    |    |    |    [470:470] <Match> = ♢[♢
|    |    |    |    |    |    [470:470] <ObjCMethodCall>
|    |    |    |    |    |    |    [470:470] <Match> = ♢[♢
|    |    |    |    |    |    |    [470:470] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [470:470] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [470:470] <Text> = ♢printInfo♢
|    |    |    |    |    |    |    [470:470] <Match> = ♢]♢
|    |    |    |    |    |    [470:470] <Whitespace> = ♢•♢
|    |    |    |    |    |    [470:470] <Text> = ♢paperSize♢
|    |    |    |    |    |    [470:470] <Match> = ♢]♢
|    |    |    |    |    [470:470] <Semicolon> = ♢;♢
|    |    |    |    [470:471] <Newline> = ♢¶♢
|    |    |    |    [471:471] <Match> = ♢}♢
|    |    [471:472] <Newline> = ♢¶♢
|    |    [472:473] <Newline> = ♢¶♢
|    |    [473:481] <ObjCMethodImplementation>
|    |    |    [473:473] <Match> = ♢-♢
|    |    |    [473:473] <Whitespace> = ♢•♢
|    |    |    [473:473] <Parenthesis>
|    |    |    |    [473:473] <Match> = ♢(♢
|    |    |    |    [473:473] <CVoid> = ♢void♢
|    |    |    |    [473:473] <Match> = ♢)♢
|    |    |    [473:473] <Text> = ♢setPaperSize♢
|    |    |    [473:473] <Colon> = ♢:♢
|    |    |    [473:473] <Parenthesis>
|    |    |    |    [473:473] <Match> = ♢(♢
|    |    |    |    [473:473] <Text> = ♢NSSize♢
|    |    |    |    [473:473] <Match> = ♢)♢
|    |    |    [473:473] <Text> = ♢size♢
|    |    |    [473:473] <Whitespace> = ♢•♢
|    |    |    [473:481] <Braces>
|    |    |    |    [473:473] <Match> = ♢{♢
|    |    |    |    [473:474] <Newline> = ♢¶♢
|    |    |    |    [474:474] <Indenting> = ♢••••♢
|    |    |    |    [474:474] <Text> = ♢NSPrintInfo♢
|    |    |    |    [474:474] <Whitespace> = ♢•♢
|    |    |    |    [474:474] <Asterisk> = ♢*♢
|    |    |    |    [474:474] <Text> = ♢oldPrintInfo♢
|    |    |    |    [474:474] <Whitespace> = ♢•♢
|    |    |    |    [474:474] <Text> = ♢=♢
|    |    |    |    [474:474] <Whitespace> = ♢•♢
|    |    |    |    [474:474] <ObjCMethodCall>
|    |    |    |    |    [474:474] <Match> = ♢[♢
|    |    |    |    |    [474:474] <ObjCSelf> = ♢self♢
|    |    |    |    |    [474:474] <Whitespace> = ♢•♢
|    |    |    |    |    [474:474] <Text> = ♢printInfo♢
|    |    |    |    |    [474:474] <Match> = ♢]♢
|    |    |    |    [474:474] <Semicolon> = ♢;♢
|    |    |    |    [474:475] <Newline> = ♢¶♢
|    |    |    |    [475:475] <Indenting> = ♢••••♢
|    |    |    |    [475:480] <CConditionIf>
|    |    |    |    |    [475:475] <Match> = ♢if♢
|    |    |    |    |    [475:475] <Whitespace> = ♢•♢
|    |    |    |    |    [475:475] <Parenthesis>
|    |    |    |    |    |    [475:475] <Match> = ♢(♢
|    |    |    |    |    |    [475:475] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    [475:475] <CFunctionCall>
|    |    |    |    |    |    |    [475:475] <Match> = ♢NSEqualSizes♢
|    |    |    |    |    |    |    [475:475] <Parenthesis>
|    |    |    |    |    |    |    |    [475:475] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [475:475] <Text> = ♢size,♢
|    |    |    |    |    |    |    |    [475:475] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [475:475] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [475:475] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [475:475] <Match> = ♢oldPrintInfo♢
|    |    |    |    |    |    |    |    |    [475:475] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [475:475] <Text> = ♢paperSize♢
|    |    |    |    |    |    |    |    |    [475:475] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [475:475] <Match> = ♢)♢
|    |    |    |    |    |    [475:475] <Match> = ♢)♢
|    |    |    |    |    [475:475] <Whitespace> = ♢•♢
|    |    |    |    |    [475:480] <Braces>
|    |    |    |    |    |    [475:475] <Match> = ♢{♢
|    |    |    |    |    |    [475:476] <Newline> = ♢¶♢
|    |    |    |    |    |    [476:476] <Indenting> = ♢→♢
|    |    |    |    |    |    [476:476] <Text> = ♢NSPrintInfo♢
|    |    |    |    |    |    [476:476] <Whitespace> = ♢•♢
|    |    |    |    |    |    [476:476] <Asterisk> = ♢*♢
|    |    |    |    |    |    [476:476] <Text> = ♢newPrintInfo♢
|    |    |    |    |    |    [476:476] <Whitespace> = ♢•♢
|    |    |    |    |    |    [476:476] <Text> = ♢=♢
|    |    |    |    |    |    [476:476] <Whitespace> = ♢•♢
|    |    |    |    |    |    [476:476] <ObjCMethodCall>
|    |    |    |    |    |    |    [476:476] <Match> = ♢[♢
|    |    |    |    |    |    |    [476:476] <Match> = ♢oldPrintInfo♢
|    |    |    |    |    |    |    [476:476] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [476:476] <Text> = ♢copy♢
|    |    |    |    |    |    |    [476:476] <Match> = ♢]♢
|    |    |    |    |    |    [476:476] <Semicolon> = ♢;♢
|    |    |    |    |    |    [476:477] <Newline> = ♢¶♢
|    |    |    |    |    |    [477:477] <Indenting> = ♢→♢
|    |    |    |    |    |    [477:477] <ObjCMethodCall>
|    |    |    |    |    |    |    [477:477] <Match> = ♢[♢
|    |    |    |    |    |    |    [477:477] <Match> = ♢newPrintInfo♢
|    |    |    |    |    |    |    [477:477] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [477:477] <Text> = ♢setPaperSize♢
|    |    |    |    |    |    |    [477:477] <Colon> = ♢:♢
|    |    |    |    |    |    |    [477:477] <Text> = ♢size♢
|    |    |    |    |    |    |    [477:477] <Match> = ♢]♢
|    |    |    |    |    |    [477:477] <Semicolon> = ♢;♢
|    |    |    |    |    |    [477:478] <Newline> = ♢¶♢
|    |    |    |    |    |    [478:478] <Indenting> = ♢→♢
|    |    |    |    |    |    [478:478] <ObjCMethodCall>
|    |    |    |    |    |    |    [478:478] <Match> = ♢[♢
|    |    |    |    |    |    |    [478:478] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [478:478] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [478:478] <Text> = ♢setPrintInfo♢
|    |    |    |    |    |    |    [478:478] <Colon> = ♢:♢
|    |    |    |    |    |    |    [478:478] <Text> = ♢newPrintInfo♢
|    |    |    |    |    |    |    [478:478] <Match> = ♢]♢
|    |    |    |    |    |    [478:478] <Semicolon> = ♢;♢
|    |    |    |    |    |    [478:479] <Newline> = ♢¶♢
|    |    |    |    |    |    [479:479] <Indenting> = ♢→♢
|    |    |    |    |    |    [479:479] <ObjCMethodCall>
|    |    |    |    |    |    |    [479:479] <Match> = ♢[♢
|    |    |    |    |    |    |    [479:479] <Match> = ♢newPrintInfo♢
|    |    |    |    |    |    |    [479:479] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [479:479] <Text> = ♢release♢
|    |    |    |    |    |    |    [479:479] <Match> = ♢]♢
|    |    |    |    |    |    [479:479] <Semicolon> = ♢;♢
|    |    |    |    |    |    [479:480] <Newline> = ♢¶♢
|    |    |    |    |    |    [480:480] <Indenting> = ♢••••♢
|    |    |    |    |    |    [480:480] <Match> = ♢}♢
|    |    |    |    [480:481] <Newline> = ♢¶♢
|    |    |    |    [481:481] <Match> = ♢}♢
|    |    [481:482] <Newline> = ♢¶♢
|    |    [482:483] <Newline> = ♢¶♢
|    |    [483:484] <CComment> = ♢/*•Hyphenation•related•methods.¶*/♢
|    |    [484:485] <Newline> = ♢¶♢
|    |    [485:487] <ObjCMethodImplementation>
|    |    |    [485:485] <Match> = ♢-♢
|    |    |    [485:485] <Whitespace> = ♢•♢
|    |    |    [485:485] <Parenthesis>
|    |    |    |    [485:485] <Match> = ♢(♢
|    |    |    |    [485:485] <CVoid> = ♢void♢
|    |    |    |    [485:485] <Match> = ♢)♢
|    |    |    [485:485] <Text> = ♢setHyphenationFactor♢
|    |    |    [485:485] <Colon> = ♢:♢
|    |    |    [485:485] <Parenthesis>
|    |    |    |    [485:485] <Match> = ♢(♢
|    |    |    |    [485:485] <CFloat> = ♢float♢
|    |    |    |    [485:485] <Match> = ♢)♢
|    |    |    [485:485] <Text> = ♢factor♢
|    |    |    [485:485] <Whitespace> = ♢•♢
|    |    |    [485:487] <Braces>
|    |    |    |    [485:485] <Match> = ♢{♢
|    |    |    |    [485:486] <Newline> = ♢¶♢
|    |    |    |    [486:486] <Indenting> = ♢••••♢
|    |    |    |    [486:486] <Text> = ♢hyphenationFactor♢
|    |    |    |    [486:486] <Whitespace> = ♢•♢
|    |    |    |    [486:486] <Text> = ♢=♢
|    |    |    |    [486:486] <Whitespace> = ♢•♢
|    |    |    |    [486:486] <Text> = ♢factor♢
|    |    |    |    [486:486] <Semicolon> = ♢;♢
|    |    |    |    [486:487] <Newline> = ♢¶♢
|    |    |    |    [487:487] <Match> = ♢}♢
|    |    [487:488] <Newline> = ♢¶♢
|    |    [488:489] <Newline> = ♢¶♢
|    |    [489:491] <ObjCMethodImplementation>
|    |    |    [489:489] <Match> = ♢-♢
|    |    |    [489:489] <Whitespace> = ♢•♢
|    |    |    [489:489] <Parenthesis>
|    |    |    |    [489:489] <Match> = ♢(♢
|    |    |    |    [489:489] <CFloat> = ♢float♢
|    |    |    |    [489:489] <Match> = ♢)♢
|    |    |    [489:489] <Text> = ♢hyphenationFactor♢
|    |    |    [489:489] <Whitespace> = ♢•♢
|    |    |    [489:491] <Braces>
|    |    |    |    [489:489] <Match> = ♢{♢
|    |    |    |    [489:490] <Newline> = ♢¶♢
|    |    |    |    [490:490] <Indenting> = ♢••••♢
|    |    |    |    [490:490] <CFlowReturn>
|    |    |    |    |    [490:490] <Match> = ♢return♢
|    |    |    |    |    [490:490] <Whitespace> = ♢•♢
|    |    |    |    |    [490:490] <Text> = ♢hyphenationFactor♢
|    |    |    |    |    [490:490] <Semicolon> = ♢;♢
|    |    |    |    [490:491] <Newline> = ♢¶♢
|    |    |    |    [491:491] <Match> = ♢}♢
|    |    [491:492] <Newline> = ♢¶♢
|    |    [492:493] <Newline> = ♢¶♢
|    |    [493:494] <CComment> = ♢/*•Encoding...¶*/♢
|    |    [494:495] <Newline> = ♢¶♢
|    |    [495:497] <ObjCMethodImplementation>
|    |    |    [495:495] <Match> = ♢-♢
|    |    |    [495:495] <Whitespace> = ♢•♢
|    |    |    [495:495] <Parenthesis>
|    |    |    |    [495:495] <Match> = ♢(♢
|    |    |    |    [495:495] <Text> = ♢NSUInteger♢
|    |    |    |    [495:495] <Match> = ♢)♢
|    |    |    [495:495] <Text> = ♢encoding♢
|    |    |    [495:495] <Whitespace> = ♢•♢
|    |    |    [495:497] <Braces>
|    |    |    |    [495:495] <Match> = ♢{♢
|    |    |    |    [495:496] <Newline> = ♢¶♢
|    |    |    |    [496:496] <Indenting> = ♢••••♢
|    |    |    |    [496:496] <CFlowReturn>
|    |    |    |    |    [496:496] <Match> = ♢return♢
|    |    |    |    |    [496:496] <Whitespace> = ♢•♢
|    |    |    |    |    [496:496] <Text> = ♢documentEncoding♢
|    |    |    |    |    [496:496] <Semicolon> = ♢;♢
|    |    |    |    [496:497] <Newline> = ♢¶♢
|    |    |    |    [497:497] <Match> = ♢}♢
|    |    [497:498] <Newline> = ♢¶♢
|    |    [498:499] <Newline> = ♢¶♢
|    |    [499:501] <ObjCMethodImplementation>
|    |    |    [499:499] <Match> = ♢-♢
|    |    |    [499:499] <Whitespace> = ♢•♢
|    |    |    [499:499] <Parenthesis>
|    |    |    |    [499:499] <Match> = ♢(♢
|    |    |    |    [499:499] <CVoid> = ♢void♢
|    |    |    |    [499:499] <Match> = ♢)♢
|    |    |    [499:499] <Text> = ♢setEncoding♢
|    |    |    [499:499] <Colon> = ♢:♢
|    |    |    [499:499] <Parenthesis>
|    |    |    |    [499:499] <Match> = ♢(♢
|    |    |    |    [499:499] <Text> = ♢NSUInteger♢
|    |    |    |    [499:499] <Match> = ♢)♢
|    |    |    [499:499] <Text> = ♢encoding♢
|    |    |    [499:499] <Whitespace> = ♢•♢
|    |    |    [499:501] <Braces>
|    |    |    |    [499:499] <Match> = ♢{♢
|    |    |    |    [499:500] <Newline> = ♢¶♢
|    |    |    |    [500:500] <Indenting> = ♢••••♢
|    |    |    |    [500:500] <Text> = ♢documentEncoding♢
|    |    |    |    [500:500] <Whitespace> = ♢•♢
|    |    |    |    [500:500] <Text> = ♢=♢
|    |    |    |    [500:500] <Whitespace> = ♢•♢
|    |    |    |    [500:500] <Text> = ♢encoding♢
|    |    |    |    [500:500] <Semicolon> = ♢;♢
|    |    |    |    [500:501] <Newline> = ♢¶♢
|    |    |    |    [501:501] <Match> = ♢}♢
|    |    [501:502] <Newline> = ♢¶♢
|    |    [502:503] <Newline> = ♢¶♢
|    |    [503:504] <CComment> = ♢/*•This•is•the•encoding•used•for•saving;•valid•only•during•a•save•operation¶*/♢
|    |    [504:505] <Newline> = ♢¶♢
|    |    [505:507] <ObjCMethodImplementation>
|    |    |    [505:505] <Match> = ♢-♢
|    |    |    [505:505] <Whitespace> = ♢•♢
|    |    |    [505:505] <Parenthesis>
|    |    |    |    [505:505] <Match> = ♢(♢
|    |    |    |    [505:505] <Text> = ♢NSUInteger♢
|    |    |    |    [505:505] <Match> = ♢)♢
|    |    |    [505:505] <Text> = ♢encodingForSaving♢
|    |    |    [505:505] <Whitespace> = ♢•♢
|    |    |    [505:507] <Braces>
|    |    |    |    [505:505] <Match> = ♢{♢
|    |    |    |    [505:506] <Newline> = ♢¶♢
|    |    |    |    [506:506] <Indenting> = ♢••••♢
|    |    |    |    [506:506] <CFlowReturn>
|    |    |    |    |    [506:506] <Match> = ♢return♢
|    |    |    |    |    [506:506] <Whitespace> = ♢•♢
|    |    |    |    |    [506:506] <Text> = ♢documentEncodingForSaving♢
|    |    |    |    |    [506:506] <Semicolon> = ♢;♢
|    |    |    |    [506:507] <Newline> = ♢¶♢
|    |    |    |    [507:507] <Match> = ♢}♢
|    |    [507:508] <Newline> = ♢¶♢
|    |    [508:509] <Newline> = ♢¶♢
|    |    [509:511] <ObjCMethodImplementation>
|    |    |    [509:509] <Match> = ♢-♢
|    |    |    [509:509] <Whitespace> = ♢•♢
|    |    |    [509:509] <Parenthesis>
|    |    |    |    [509:509] <Match> = ♢(♢
|    |    |    |    [509:509] <CVoid> = ♢void♢
|    |    |    |    [509:509] <Match> = ♢)♢
|    |    |    [509:509] <Text> = ♢setEncodingForSaving♢
|    |    |    [509:509] <Colon> = ♢:♢
|    |    |    [509:509] <Parenthesis>
|    |    |    |    [509:509] <Match> = ♢(♢
|    |    |    |    [509:509] <Text> = ♢NSUInteger♢
|    |    |    |    [509:509] <Match> = ♢)♢
|    |    |    [509:509] <Text> = ♢encoding♢
|    |    |    [509:509] <Whitespace> = ♢•♢
|    |    |    [509:511] <Braces>
|    |    |    |    [509:509] <Match> = ♢{♢
|    |    |    |    [509:510] <Newline> = ♢¶♢
|    |    |    |    [510:510] <Indenting> = ♢••••♢
|    |    |    |    [510:510] <Text> = ♢documentEncodingForSaving♢
|    |    |    |    [510:510] <Whitespace> = ♢•♢
|    |    |    |    [510:510] <Text> = ♢=♢
|    |    |    |    [510:510] <Whitespace> = ♢•♢
|    |    |    |    [510:510] <Text> = ♢encoding♢
|    |    |    |    [510:510] <Semicolon> = ♢;♢
|    |    |    |    [510:511] <Newline> = ♢¶♢
|    |    |    |    [511:511] <Match> = ♢}♢
|    |    [511:512] <Newline> = ♢¶♢
|    |    [512:513] <Newline> = ♢¶♢
|    |    [513:514] <Newline> = ♢¶♢
|    |    [514:516] <ObjCMethodImplementation>
|    |    |    [514:514] <Match> = ♢-♢
|    |    |    [514:514] <Whitespace> = ♢•♢
|    |    |    [514:514] <Parenthesis>
|    |    |    |    [514:514] <Match> = ♢(♢
|    |    |    |    [514:514] <Text> = ♢BOOL♢
|    |    |    |    [514:514] <Match> = ♢)♢
|    |    |    [514:514] <Text> = ♢isConverted♢
|    |    |    [514:514] <Whitespace> = ♢•♢
|    |    |    [514:516] <Braces>
|    |    |    |    [514:514] <Match> = ♢{♢
|    |    |    |    [514:515] <Newline> = ♢¶♢
|    |    |    |    [515:515] <Indenting> = ♢••••♢
|    |    |    |    [515:515] <CFlowReturn>
|    |    |    |    |    [515:515] <Match> = ♢return♢
|    |    |    |    |    [515:515] <Whitespace> = ♢•♢
|    |    |    |    |    [515:515] <Text> = ♢convertedDocument♢
|    |    |    |    |    [515:515] <Semicolon> = ♢;♢
|    |    |    |    [515:516] <Newline> = ♢¶♢
|    |    |    |    [516:516] <Match> = ♢}♢
|    |    [516:517] <Newline> = ♢¶♢
|    |    [517:518] <Newline> = ♢¶♢
|    |    [518:520] <ObjCMethodImplementation>
|    |    |    [518:518] <Match> = ♢-♢
|    |    |    [518:518] <Whitespace> = ♢•♢
|    |    |    [518:518] <Parenthesis>
|    |    |    |    [518:518] <Match> = ♢(♢
|    |    |    |    [518:518] <CVoid> = ♢void♢
|    |    |    |    [518:518] <Match> = ♢)♢
|    |    |    [518:518] <Text> = ♢setConverted♢
|    |    |    [518:518] <Colon> = ♢:♢
|    |    |    [518:518] <Parenthesis>
|    |    |    |    [518:518] <Match> = ♢(♢
|    |    |    |    [518:518] <Text> = ♢BOOL♢
|    |    |    |    [518:518] <Match> = ♢)♢
|    |    |    [518:518] <Text> = ♢flag♢
|    |    |    [518:518] <Whitespace> = ♢•♢
|    |    |    [518:520] <Braces>
|    |    |    |    [518:518] <Match> = ♢{♢
|    |    |    |    [518:519] <Newline> = ♢¶♢
|    |    |    |    [519:519] <Indenting> = ♢••••♢
|    |    |    |    [519:519] <Text> = ♢convertedDocument♢
|    |    |    |    [519:519] <Whitespace> = ♢•♢
|    |    |    |    [519:519] <Text> = ♢=♢
|    |    |    |    [519:519] <Whitespace> = ♢•♢
|    |    |    |    [519:519] <Text> = ♢flag♢
|    |    |    |    [519:519] <Semicolon> = ♢;♢
|    |    |    |    [519:520] <Newline> = ♢¶♢
|    |    |    |    [520:520] <Match> = ♢}♢
|    |    [520:521] <Newline> = ♢¶♢
|    |    [521:522] <Newline> = ♢¶♢
|    |    [522:524] <ObjCMethodImplementation>
|    |    |    [522:522] <Match> = ♢-♢
|    |    |    [522:522] <Whitespace> = ♢•♢
|    |    |    [522:522] <Parenthesis>
|    |    |    |    [522:522] <Match> = ♢(♢
|    |    |    |    [522:522] <Text> = ♢BOOL♢
|    |    |    |    [522:522] <Match> = ♢)♢
|    |    |    [522:522] <Text> = ♢isLossy♢
|    |    |    [522:522] <Whitespace> = ♢•♢
|    |    |    [522:524] <Braces>
|    |    |    |    [522:522] <Match> = ♢{♢
|    |    |    |    [522:523] <Newline> = ♢¶♢
|    |    |    |    [523:523] <Indenting> = ♢••••♢
|    |    |    |    [523:523] <CFlowReturn>
|    |    |    |    |    [523:523] <Match> = ♢return♢
|    |    |    |    |    [523:523] <Whitespace> = ♢•♢
|    |    |    |    |    [523:523] <Text> = ♢lossyDocument♢
|    |    |    |    |    [523:523] <Semicolon> = ♢;♢
|    |    |    |    [523:524] <Newline> = ♢¶♢
|    |    |    |    [524:524] <Match> = ♢}♢
|    |    [524:525] <Newline> = ♢¶♢
|    |    [525:526] <Newline> = ♢¶♢
|    |    [526:528] <ObjCMethodImplementation>
|    |    |    [526:526] <Match> = ♢-♢
|    |    |    [526:526] <Whitespace> = ♢•♢
|    |    |    [526:526] <Parenthesis>
|    |    |    |    [526:526] <Match> = ♢(♢
|    |    |    |    [526:526] <CVoid> = ♢void♢
|    |    |    |    [526:526] <Match> = ♢)♢
|    |    |    [526:526] <Text> = ♢setLossy♢
|    |    |    [526:526] <Colon> = ♢:♢
|    |    |    [526:526] <Parenthesis>
|    |    |    |    [526:526] <Match> = ♢(♢
|    |    |    |    [526:526] <Text> = ♢BOOL♢
|    |    |    |    [526:526] <Match> = ♢)♢
|    |    |    [526:526] <Text> = ♢flag♢
|    |    |    [526:526] <Whitespace> = ♢•♢
|    |    |    [526:528] <Braces>
|    |    |    |    [526:526] <Match> = ♢{♢
|    |    |    |    [526:527] <Newline> = ♢¶♢
|    |    |    |    [527:527] <Indenting> = ♢••••♢
|    |    |    |    [527:527] <Text> = ♢lossyDocument♢
|    |    |    |    [527:527] <Whitespace> = ♢•♢
|    |    |    |    [527:527] <Text> = ♢=♢
|    |    |    |    [527:527] <Whitespace> = ♢•♢
|    |    |    |    [527:527] <Text> = ♢flag♢
|    |    |    |    [527:527] <Semicolon> = ♢;♢
|    |    |    |    [527:528] <Newline> = ♢¶♢
|    |    |    |    [528:528] <Match> = ♢}♢
|    |    [528:529] <Newline> = ♢¶♢
|    |    [529:530] <Newline> = ♢¶♢
|    |    [530:532] <ObjCMethodImplementation>
|    |    |    [530:530] <Match> = ♢-♢
|    |    |    [530:530] <Whitespace> = ♢•♢
|    |    |    [530:530] <Parenthesis>
|    |    |    |    [530:530] <Match> = ♢(♢
|    |    |    |    [530:530] <Text> = ♢BOOL♢
|    |    |    |    [530:530] <Match> = ♢)♢
|    |    |    [530:530] <Text> = ♢isOpenedIgnoringRichText♢
|    |    |    [530:530] <Whitespace> = ♢•♢
|    |    |    [530:532] <Braces>
|    |    |    |    [530:530] <Match> = ♢{♢
|    |    |    |    [530:531] <Newline> = ♢¶♢
|    |    |    |    [531:531] <Indenting> = ♢••••♢
|    |    |    |    [531:531] <CFlowReturn>
|    |    |    |    |    [531:531] <Match> = ♢return♢
|    |    |    |    |    [531:531] <Whitespace> = ♢•♢
|    |    |    |    |    [531:531] <Text> = ♢openedIgnoringRichText♢
|    |    |    |    |    [531:531] <Semicolon> = ♢;♢
|    |    |    |    [531:532] <Newline> = ♢¶♢
|    |    |    |    [532:532] <Match> = ♢}♢
|    |    [532:533] <Newline> = ♢¶♢
|    |    [533:534] <Newline> = ♢¶♢
|    |    [534:536] <ObjCMethodImplementation>
|    |    |    [534:534] <Match> = ♢-♢
|    |    |    [534:534] <Whitespace> = ♢•♢
|    |    |    [534:534] <Parenthesis>
|    |    |    |    [534:534] <Match> = ♢(♢
|    |    |    |    [534:534] <CVoid> = ♢void♢
|    |    |    |    [534:534] <Match> = ♢)♢
|    |    |    [534:534] <Text> = ♢setOpenedIgnoringRichText♢
|    |    |    [534:534] <Colon> = ♢:♢
|    |    |    [534:534] <Parenthesis>
|    |    |    |    [534:534] <Match> = ♢(♢
|    |    |    |    [534:534] <Text> = ♢BOOL♢
|    |    |    |    [534:534] <Match> = ♢)♢
|    |    |    [534:534] <Text> = ♢flag♢
|    |    |    [534:534] <Whitespace> = ♢•♢
|    |    |    [534:536] <Braces>
|    |    |    |    [534:534] <Match> = ♢{♢
|    |    |    |    [534:535] <Newline> = ♢¶♢
|    |    |    |    [535:535] <Indenting> = ♢••••♢
|    |    |    |    [535:535] <Text> = ♢openedIgnoringRichText♢
|    |    |    |    [535:535] <Whitespace> = ♢•♢
|    |    |    |    [535:535] <Text> = ♢=♢
|    |    |    |    [535:535] <Whitespace> = ♢•♢
|    |    |    |    [535:535] <Text> = ♢flag♢
|    |    |    |    [535:535] <Semicolon> = ♢;♢
|    |    |    |    [535:536] <Newline> = ♢¶♢
|    |    |    |    [536:536] <Match> = ♢}♢
|    |    [536:537] <Newline> = ♢¶♢
|    |    [537:538] <Newline> = ♢¶♢
|    |    [538:539] <CComment> = ♢/*•A•transient•document•is•an•untitled•document•that•was•opened•automatically.•If•a•real•document•is•opened•before•the•transient•document•is•edited,•the•real•document•should•replace•the•transient.•If•a•transient•document•is•edited,•it•ceases•to•be•transient.•¶*/♢
|    |    [539:540] <Newline> = ♢¶♢
|    |    [540:542] <ObjCMethodImplementation>
|    |    |    [540:540] <Match> = ♢-♢
|    |    |    [540:540] <Whitespace> = ♢•♢
|    |    |    [540:540] <Parenthesis>
|    |    |    |    [540:540] <Match> = ♢(♢
|    |    |    |    [540:540] <Text> = ♢BOOL♢
|    |    |    |    [540:540] <Match> = ♢)♢
|    |    |    [540:540] <Text> = ♢isTransient♢
|    |    |    [540:540] <Whitespace> = ♢•♢
|    |    |    [540:542] <Braces>
|    |    |    |    [540:540] <Match> = ♢{♢
|    |    |    |    [540:541] <Newline> = ♢¶♢
|    |    |    |    [541:541] <Indenting> = ♢••••♢
|    |    |    |    [541:541] <CFlowReturn>
|    |    |    |    |    [541:541] <Match> = ♢return♢
|    |    |    |    |    [541:541] <Whitespace> = ♢•♢
|    |    |    |    |    [541:541] <Text> = ♢transient♢
|    |    |    |    |    [541:541] <Semicolon> = ♢;♢
|    |    |    |    [541:542] <Newline> = ♢¶♢
|    |    |    |    [542:542] <Match> = ♢}♢
|    |    [542:543] <Newline> = ♢¶♢
|    |    [543:544] <Newline> = ♢¶♢
|    |    [544:546] <ObjCMethodImplementation>
|    |    |    [544:544] <Match> = ♢-♢
|    |    |    [544:544] <Whitespace> = ♢•♢
|    |    |    [544:544] <Parenthesis>
|    |    |    |    [544:544] <Match> = ♢(♢
|    |    |    |    [544:544] <CVoid> = ♢void♢
|    |    |    |    [544:544] <Match> = ♢)♢
|    |    |    [544:544] <Text> = ♢setTransient♢
|    |    |    [544:544] <Colon> = ♢:♢
|    |    |    [544:544] <Parenthesis>
|    |    |    |    [544:544] <Match> = ♢(♢
|    |    |    |    [544:544] <Text> = ♢BOOL♢
|    |    |    |    [544:544] <Match> = ♢)♢
|    |    |    [544:544] <Text> = ♢flag♢
|    |    |    [544:544] <Whitespace> = ♢•♢
|    |    |    [544:546] <Braces>
|    |    |    |    [544:544] <Match> = ♢{♢
|    |    |    |    [544:545] <Newline> = ♢¶♢
|    |    |    |    [545:545] <Indenting> = ♢••••♢
|    |    |    |    [545:545] <Text> = ♢transient♢
|    |    |    |    [545:545] <Whitespace> = ♢•♢
|    |    |    |    [545:545] <Text> = ♢=♢
|    |    |    |    [545:545] <Whitespace> = ♢•♢
|    |    |    |    [545:545] <Text> = ♢flag♢
|    |    |    |    [545:545] <Semicolon> = ♢;♢
|    |    |    |    [545:546] <Newline> = ♢¶♢
|    |    |    |    [546:546] <Match> = ♢}♢
|    |    [546:547] <Newline> = ♢¶♢
|    |    [547:548] <Newline> = ♢¶♢
|    |    [548:549] <CComment> = ♢/*•We•can't•replace•transient•document•that•have•sheets•on•them.¶*/♢
|    |    [549:550] <Newline> = ♢¶♢
|    |    [550:554] <ObjCMethodImplementation>
|    |    |    [550:550] <Match> = ♢-♢
|    |    |    [550:550] <Whitespace> = ♢•♢
|    |    |    [550:550] <Parenthesis>
|    |    |    |    [550:550] <Match> = ♢(♢
|    |    |    |    [550:550] <Text> = ♢BOOL♢
|    |    |    |    [550:550] <Match> = ♢)♢
|    |    |    [550:550] <Text> = ♢isTransientAndCanBeReplaced♢
|    |    |    [550:550] <Whitespace> = ♢•♢
|    |    |    [550:554] <Braces>
|    |    |    |    [550:550] <Match> = ♢{♢
|    |    |    |    [550:551] <Newline> = ♢¶♢
|    |    |    |    [551:551] <Indenting> = ♢••••♢
|    |    |    |    [551:551] <CConditionIf>
|    |    |    |    |    [551:551] <Match> = ♢if♢
|    |    |    |    |    [551:551] <Whitespace> = ♢•♢
|    |    |    |    |    [551:551] <Parenthesis>
|    |    |    |    |    |    [551:551] <Match> = ♢(♢
|    |    |    |    |    |    [551:551] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    [551:551] <ObjCMethodCall>
|    |    |    |    |    |    |    [551:551] <Match> = ♢[♢
|    |    |    |    |    |    |    [551:551] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [551:551] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [551:551] <Text> = ♢isTransient♢
|    |    |    |    |    |    |    [551:551] <Match> = ♢]♢
|    |    |    |    |    |    [551:551] <Match> = ♢)♢
|    |    |    |    |    [551:551] <Whitespace> = ♢•♢
|    |    |    |    |    [551:551] <CFlowReturn>
|    |    |    |    |    |    [551:551] <Match> = ♢return♢
|    |    |    |    |    |    [551:551] <Whitespace> = ♢•♢
|    |    |    |    |    |    [551:551] <Text> = ♢NO♢
|    |    |    |    |    |    [551:551] <Semicolon> = ♢;♢
|    |    |    |    [551:552] <Newline> = ♢¶♢
|    |    |    |    [552:552] <Indenting> = ♢••••♢
|    |    |    |    [552:552] <CFlowFor>
|    |    |    |    |    [552:552] <Match> = ♢for♢
|    |    |    |    |    [552:552] <Whitespace> = ♢•♢
|    |    |    |    |    [552:552] <Parenthesis>
|    |    |    |    |    |    [552:552] <Match> = ♢(♢
|    |    |    |    |    |    [552:552] <Text> = ♢NSWindowController♢
|    |    |    |    |    |    [552:552] <Whitespace> = ♢•♢
|    |    |    |    |    |    [552:552] <Asterisk> = ♢*♢
|    |    |    |    |    |    [552:552] <Text> = ♢controller♢
|    |    |    |    |    |    [552:552] <Whitespace> = ♢•♢
|    |    |    |    |    |    [552:552] <Text> = ♢in♢
|    |    |    |    |    |    [552:552] <Whitespace> = ♢•♢
|    |    |    |    |    |    [552:552] <ObjCMethodCall>
|    |    |    |    |    |    |    [552:552] <Match> = ♢[♢
|    |    |    |    |    |    |    [552:552] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [552:552] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [552:552] <Text> = ♢windowControllers♢
|    |    |    |    |    |    |    [552:552] <Match> = ♢]♢
|    |    |    |    |    |    [552:552] <Match> = ♢)♢
|    |    |    |    |    [552:552] <Whitespace> = ♢•♢
|    |    |    |    |    [552:552] <CConditionIf>
|    |    |    |    |    |    [552:552] <Match> = ♢if♢
|    |    |    |    |    |    [552:552] <Whitespace> = ♢•♢
|    |    |    |    |    |    [552:552] <Parenthesis>
|    |    |    |    |    |    |    [552:552] <Match> = ♢(♢
|    |    |    |    |    |    |    [552:552] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [552:552] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [552:552] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [552:552] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [552:552] <Match> = ♢controller♢
|    |    |    |    |    |    |    |    |    [552:552] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [552:552] <Text> = ♢window♢
|    |    |    |    |    |    |    |    |    [552:552] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [552:552] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [552:552] <Text> = ♢attachedSheet♢
|    |    |    |    |    |    |    |    [552:552] <Match> = ♢]♢
|    |    |    |    |    |    |    [552:552] <Match> = ♢)♢
|    |    |    |    |    |    [552:552] <Whitespace> = ♢•♢
|    |    |    |    |    |    [552:552] <CFlowReturn>
|    |    |    |    |    |    |    [552:552] <Match> = ♢return♢
|    |    |    |    |    |    |    [552:552] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [552:552] <Text> = ♢NO♢
|    |    |    |    |    |    |    [552:552] <Semicolon> = ♢;♢
|    |    |    |    [552:553] <Newline> = ♢¶♢
|    |    |    |    [553:553] <Indenting> = ♢••••♢
|    |    |    |    [553:553] <CFlowReturn>
|    |    |    |    |    [553:553] <Match> = ♢return♢
|    |    |    |    |    [553:553] <Whitespace> = ♢•♢
|    |    |    |    |    [553:553] <Text> = ♢YES♢
|    |    |    |    |    [553:553] <Semicolon> = ♢;♢
|    |    |    |    [553:554] <Newline> = ♢¶♢
|    |    |    |    [554:554] <Match> = ♢}♢
|    |    [554:555] <Newline> = ♢¶♢
|    |    [555:556] <Newline> = ♢¶♢
|    |    [556:557] <Newline> = ♢¶♢
|    |    [557:558] <CComment> = ♢/*•The•rich•text•status•is•dependent•on•the•document•type,•and•vice•versa.•Making•a•plain•document•rich,•will•-setFileType:•to•RTF.•¶*/♢
|    |    [558:559] <Newline> = ♢¶♢
|    |    [559:568] <ObjCMethodImplementation>
|    |    |    [559:559] <Match> = ♢-♢
|    |    |    [559:559] <Whitespace> = ♢•♢
|    |    |    [559:559] <Parenthesis>
|    |    |    |    [559:559] <Match> = ♢(♢
|    |    |    |    [559:559] <CVoid> = ♢void♢
|    |    |    |    [559:559] <Match> = ♢)♢
|    |    |    [559:559] <Text> = ♢setRichText♢
|    |    |    [559:559] <Colon> = ♢:♢
|    |    |    [559:559] <Parenthesis>
|    |    |    |    [559:559] <Match> = ♢(♢
|    |    |    |    [559:559] <Text> = ♢BOOL♢
|    |    |    |    [559:559] <Match> = ♢)♢
|    |    |    [559:559] <Text> = ♢flag♢
|    |    |    [559:559] <Whitespace> = ♢•♢
|    |    |    [559:568] <Braces>
|    |    |    |    [559:559] <Match> = ♢{♢
|    |    |    |    [559:560] <Newline> = ♢¶♢
|    |    |    |    [560:560] <Indenting> = ♢••••♢
|    |    |    |    [560:567] <CConditionIf>
|    |    |    |    |    [560:560] <Match> = ♢if♢
|    |    |    |    |    [560:560] <Whitespace> = ♢•♢
|    |    |    |    |    [560:560] <Parenthesis>
|    |    |    |    |    |    [560:560] <Match> = ♢(♢
|    |    |    |    |    |    [560:560] <Text> = ♢flag♢
|    |    |    |    |    |    [560:560] <Whitespace> = ♢•♢
|    |    |    |    |    |    [560:560] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    [560:560] <Text> = ♢=♢
|    |    |    |    |    |    [560:560] <Whitespace> = ♢•♢
|    |    |    |    |    |    [560:560] <ObjCMethodCall>
|    |    |    |    |    |    |    [560:560] <Match> = ♢[♢
|    |    |    |    |    |    |    [560:560] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [560:560] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [560:560] <Text> = ♢isRichText♢
|    |    |    |    |    |    |    [560:560] <Match> = ♢]♢
|    |    |    |    |    |    [560:560] <Match> = ♢)♢
|    |    |    |    |    [560:560] <Whitespace> = ♢•♢
|    |    |    |    |    [560:567] <Braces>
|    |    |    |    |    |    [560:560] <Match> = ♢{♢
|    |    |    |    |    |    [560:561] <Newline> = ♢¶♢
|    |    |    |    |    |    [561:561] <Indenting> = ♢→♢
|    |    |    |    |    |    [561:561] <ObjCMethodCall>
|    |    |    |    |    |    |    [561:561] <Match> = ♢[♢
|    |    |    |    |    |    |    [561:561] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [561:561] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [561:561] <Text> = ♢setFileType♢
|    |    |    |    |    |    |    [561:561] <Colon> = ♢:♢
|    |    |    |    |    |    |    [561:561] <Parenthesis>
|    |    |    |    |    |    |    |    [561:561] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [561:561] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    [561:561] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [561:561] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [561:561] <Match> = ♢)♢
|    |    |    |    |    |    |    [561:561] <Parenthesis>
|    |    |    |    |    |    |    |    [561:561] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [561:561] <CConditionalOperator>
|    |    |    |    |    |    |    |    |    [561:561] <Text> = ♢flag♢
|    |    |    |    |    |    |    |    |    [561:561] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [561:561] <QuestionMark> = ♢?♢
|    |    |    |    |    |    |    |    |    [561:561] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [561:561] <Text> = ♢kUTTypeRTF♢
|    |    |    |    |    |    |    |    |    [561:561] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [561:561] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [561:561] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [561:561] <Text> = ♢kUTTypePlainText♢
|    |    |    |    |    |    |    |    [561:561] <Match> = ♢)♢
|    |    |    |    |    |    |    [561:561] <Match> = ♢]♢
|    |    |    |    |    |    [561:561] <Semicolon> = ♢;♢
|    |    |    |    |    |    [561:562] <Newline> = ♢¶♢
|    |    |    |    |    |    [562:562] <Indenting> = ♢→♢
|    |    |    |    |    |    [562:564] <CConditionIf>
|    |    |    |    |    |    |    [562:562] <Match> = ♢if♢
|    |    |    |    |    |    |    [562:562] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [562:562] <Parenthesis>
|    |    |    |    |    |    |    |    [562:562] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [562:562] <Text> = ♢flag♢
|    |    |    |    |    |    |    |    [562:562] <Match> = ♢)♢
|    |    |    |    |    |    |    [562:562] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [562:564] <Braces>
|    |    |    |    |    |    |    |    [562:562] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [562:563] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [563:563] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [563:563] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [563:563] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [563:563] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    [563:563] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [563:563] <Text> = ♢setDocumentPropertiesToDefaults♢
|    |    |    |    |    |    |    |    |    [563:563] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [563:563] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [563:564] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [564:564] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [564:564] <Match> = ♢}♢
|    |    |    |    |    |    [564:564] <Whitespace> = ♢•♢
|    |    |    |    |    |    [564:566] <CConditionElse>
|    |    |    |    |    |    |    [564:564] <Match> = ♢else♢
|    |    |    |    |    |    |    [564:564] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [564:566] <Braces>
|    |    |    |    |    |    |    |    [564:564] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [564:565] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [565:565] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [565:565] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [565:565] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [565:565] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    [565:565] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [565:565] <Text> = ♢clearDocumentProperties♢
|    |    |    |    |    |    |    |    |    [565:565] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [565:565] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [565:566] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [566:566] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [566:566] <Match> = ♢}♢
|    |    |    |    |    |    [566:567] <Newline> = ♢¶♢
|    |    |    |    |    |    [567:567] <Indenting> = ♢••••♢
|    |    |    |    |    |    [567:567] <Match> = ♢}♢
|    |    |    |    [567:568] <Newline> = ♢¶♢
|    |    |    |    [568:568] <Match> = ♢}♢
|    |    [568:569] <Newline> = ♢¶♢
|    |    [569:570] <Newline> = ♢¶♢
|    |    [570:572] <ObjCMethodImplementation>
|    |    |    [570:570] <Match> = ♢-♢
|    |    |    [570:570] <Whitespace> = ♢•♢
|    |    |    [570:570] <Parenthesis>
|    |    |    |    [570:570] <Match> = ♢(♢
|    |    |    |    [570:570] <Text> = ♢BOOL♢
|    |    |    |    [570:570] <Match> = ♢)♢
|    |    |    [570:570] <Text> = ♢isRichText♢
|    |    |    [570:570] <Whitespace> = ♢•♢
|    |    |    [570:572] <Braces>
|    |    |    |    [570:570] <Match> = ♢{♢
|    |    |    |    [570:571] <Newline> = ♢¶♢
|    |    |    |    [571:571] <Indenting> = ♢••••♢
|    |    |    |    [571:571] <CFlowReturn>
|    |    |    |    |    [571:571] <Match> = ♢return♢
|    |    |    |    |    [571:571] <Whitespace> = ♢•♢
|    |    |    |    |    [571:571] <ExclamationMark> = ♢!♢
|    |    |    |    |    [571:571] <ObjCMethodCall>
|    |    |    |    |    |    [571:571] <Match> = ♢[♢
|    |    |    |    |    |    [571:571] <ObjCMethodCall>
|    |    |    |    |    |    |    [571:571] <Match> = ♢[♢
|    |    |    |    |    |    |    [571:571] <Match> = ♢NSWorkspace♢
|    |    |    |    |    |    |    [571:571] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [571:571] <Text> = ♢sharedWorkspace♢
|    |    |    |    |    |    |    [571:571] <Match> = ♢]♢
|    |    |    |    |    |    [571:571] <Whitespace> = ♢•♢
|    |    |    |    |    |    [571:571] <Text> = ♢type♢
|    |    |    |    |    |    [571:571] <Colon> = ♢:♢
|    |    |    |    |    |    [571:571] <ObjCMethodCall>
|    |    |    |    |    |    |    [571:571] <Match> = ♢[♢
|    |    |    |    |    |    |    [571:571] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [571:571] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [571:571] <Text> = ♢fileType♢
|    |    |    |    |    |    |    [571:571] <Match> = ♢]♢
|    |    |    |    |    |    [571:571] <Whitespace> = ♢•♢
|    |    |    |    |    |    [571:571] <Text> = ♢conformsToType♢
|    |    |    |    |    |    [571:571] <Colon> = ♢:♢
|    |    |    |    |    |    [571:571] <Parenthesis>
|    |    |    |    |    |    |    [571:571] <Match> = ♢(♢
|    |    |    |    |    |    |    [571:571] <Text> = ♢NSString♢
|    |    |    |    |    |    |    [571:571] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [571:571] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    [571:571] <Match> = ♢)♢
|    |    |    |    |    |    [571:571] <Text> = ♢kUTTypePlainText♢
|    |    |    |    |    |    [571:571] <Match> = ♢]♢
|    |    |    |    |    [571:571] <Semicolon> = ♢;♢
|    |    |    |    [571:572] <Newline> = ♢¶♢
|    |    |    |    [572:572] <Match> = ♢}♢
|    |    [572:573] <Newline> = ♢¶♢
|    |    [573:574] <Newline> = ♢¶♢
|    |    [574:575] <Newline> = ♢¶♢
|    |    [575:575] <CComment> = ♢/*•Document•properties•management•*/♢
|    |    [575:576] <Newline> = ♢¶♢
|    |    [576:577] <Newline> = ♢¶♢
|    |    [577:578] <CComment> = ♢/*•Table•mapping•document•property•keys•"company",•etc,•to•text•system•document•attribute•keys•(NSCompanyDocumentAttribute,•etc)¶*/♢
|    |    [578:579] <Newline> = ♢¶♢
|    |    [579:590] <ObjCMethodImplementation>
|    |    |    [579:579] <Match> = ♢-♢
|    |    |    [579:579] <Whitespace> = ♢•♢
|    |    |    [579:579] <Parenthesis>
|    |    |    |    [579:579] <Match> = ♢(♢
|    |    |    |    [579:579] <Text> = ♢NSDictionary♢
|    |    |    |    [579:579] <Whitespace> = ♢•♢
|    |    |    |    [579:579] <Asterisk> = ♢*♢
|    |    |    |    [579:579] <Match> = ♢)♢
|    |    |    [579:579] <Text> = ♢documentPropertyToAttributeNameMappings♢
|    |    |    [579:579] <Whitespace> = ♢•♢
|    |    |    [579:590] <Braces>
|    |    |    |    [579:579] <Match> = ♢{♢
|    |    |    |    [579:580] <Newline> = ♢¶♢
|    |    |    |    [580:580] <Indenting> = ♢••••♢
|    |    |    |    [580:580] <CStatic> = ♢static♢
|    |    |    |    [580:580] <Whitespace> = ♢•♢
|    |    |    |    [580:580] <Text> = ♢NSDictionary♢
|    |    |    |    [580:580] <Whitespace> = ♢•♢
|    |    |    |    [580:580] <Asterisk> = ♢*♢
|    |    |    |    [580:580] <Text> = ♢dict♢
|    |    |    |    [580:580] <Whitespace> = ♢•♢
|    |    |    |    [580:580] <Text> = ♢=♢
|    |    |    |    [580:580] <Whitespace> = ♢•♢
|    |    |    |    [580:580] <ObjCNil> = ♢nil♢
|    |    |    |    [580:580] <Semicolon> = ♢;♢
|    |    |    |    [580:581] <Newline> = ♢¶♢
|    |    |    |    [581:581] <Indenting> = ♢••••♢
|    |    |    |    [581:588] <CConditionIf>
|    |    |    |    |    [581:581] <Match> = ♢if♢
|    |    |    |    |    [581:581] <Whitespace> = ♢•♢
|    |    |    |    |    [581:581] <Parenthesis>
|    |    |    |    |    |    [581:581] <Match> = ♢(♢
|    |    |    |    |    |    [581:581] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    [581:581] <Text> = ♢dict♢
|    |    |    |    |    |    [581:581] <Match> = ♢)♢
|    |    |    |    |    [581:581] <Whitespace> = ♢•♢
|    |    |    |    |    [581:581] <Text> = ♢dict♢
|    |    |    |    |    [581:581] <Whitespace> = ♢•♢
|    |    |    |    |    [581:581] <Text> = ♢=♢
|    |    |    |    |    [581:581] <Whitespace> = ♢•♢
|    |    |    |    |    [581:588] <ObjCMethodCall>
|    |    |    |    |    |    [581:581] <Match> = ♢[♢
|    |    |    |    |    |    [581:581] <ObjCMethodCall>
|    |    |    |    |    |    |    [581:581] <Match> = ♢[♢
|    |    |    |    |    |    |    [581:581] <Match> = ♢NSDictionary♢
|    |    |    |    |    |    |    [581:581] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [581:581] <Text> = ♢alloc♢
|    |    |    |    |    |    |    [581:581] <Match> = ♢]♢
|    |    |    |    |    |    [581:581] <Whitespace> = ♢•♢
|    |    |    |    |    |    [581:581] <Text> = ♢initWithObjectsAndKeys♢
|    |    |    |    |    |    [581:581] <Colon> = ♢:♢
|    |    |    |    |    |    [581:582] <Newline> = ♢¶♢
|    |    |    |    |    |    [582:582] <Indenting> = ♢→♢
|    |    |    |    |    |    [582:582] <Text> = ♢NSCompanyDocumentAttribute,♢
|    |    |    |    |    |    [582:582] <Whitespace> = ♢•♢
|    |    |    |    |    |    [582:582] <ObjCString> = ♢@"company"♢
|    |    |    |    |    |    [582:582] <Text> = ♢,♢
|    |    |    |    |    |    [582:582] <Whitespace> = ♢•♢
|    |    |    |    |    |    [582:583] <Newline> = ♢¶♢
|    |    |    |    |    |    [583:583] <Indenting> = ♢→♢
|    |    |    |    |    |    [583:583] <Text> = ♢NSAuthorDocumentAttribute,♢
|    |    |    |    |    |    [583:583] <Whitespace> = ♢•♢
|    |    |    |    |    |    [583:583] <ObjCString> = ♢@"author"♢
|    |    |    |    |    |    [583:583] <Text> = ♢,♢
|    |    |    |    |    |    [583:583] <Whitespace> = ♢•♢
|    |    |    |    |    |    [583:584] <Newline> = ♢¶♢
|    |    |    |    |    |    [584:584] <Indenting> = ♢→♢
|    |    |    |    |    |    [584:584] <Text> = ♢NSKeywordsDocumentAttribute,♢
|    |    |    |    |    |    [584:584] <Whitespace> = ♢•♢
|    |    |    |    |    |    [584:584] <ObjCString> = ♢@"keywords"♢
|    |    |    |    |    |    [584:584] <Text> = ♢,♢
|    |    |    |    |    |    [584:584] <Whitespace> = ♢•♢
|    |    |    |    |    |    [584:585] <Newline> = ♢¶♢
|    |    |    |    |    |    [585:585] <Indenting> = ♢••→♢
|    |    |    |    |    |    [585:585] <Text> = ♢NSCopyrightDocumentAttribute,♢
|    |    |    |    |    |    [585:585] <Whitespace> = ♢•♢
|    |    |    |    |    |    [585:585] <ObjCString> = ♢@"copyright"♢
|    |    |    |    |    |    [585:585] <Text> = ♢,♢
|    |    |    |    |    |    [585:585] <Whitespace> = ♢•♢
|    |    |    |    |    |    [585:586] <Newline> = ♢¶♢
|    |    |    |    |    |    [586:586] <Indenting> = ♢→♢
|    |    |    |    |    |    [586:586] <Text> = ♢NSTitleDocumentAttribute,♢
|    |    |    |    |    |    [586:586] <Whitespace> = ♢•♢
|    |    |    |    |    |    [586:586] <ObjCString> = ♢@"title"♢
|    |    |    |    |    |    [586:586] <Text> = ♢,♢
|    |    |    |    |    |    [586:586] <Whitespace> = ♢•♢
|    |    |    |    |    |    [586:587] <Newline> = ♢¶♢
|    |    |    |    |    |    [587:587] <Indenting> = ♢→♢
|    |    |    |    |    |    [587:587] <Text> = ♢NSSubjectDocumentAttribute,♢
|    |    |    |    |    |    [587:587] <Whitespace> = ♢•♢
|    |    |    |    |    |    [587:587] <ObjCString> = ♢@"subject"♢
|    |    |    |    |    |    [587:587] <Text> = ♢,♢
|    |    |    |    |    |    [587:587] <Whitespace> = ♢•♢
|    |    |    |    |    |    [587:588] <Newline> = ♢¶♢
|    |    |    |    |    |    [588:588] <Indenting> = ♢→♢
|    |    |    |    |    |    [588:588] <Text> = ♢NSCommentDocumentAttribute,♢
|    |    |    |    |    |    [588:588] <Whitespace> = ♢•♢
|    |    |    |    |    |    [588:588] <ObjCString> = ♢@"comment"♢
|    |    |    |    |    |    [588:588] <Text> = ♢,♢
|    |    |    |    |    |    [588:588] <Whitespace> = ♢•♢
|    |    |    |    |    |    [588:588] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    [588:588] <Match> = ♢]♢
|    |    |    |    |    [588:588] <Semicolon> = ♢;♢
|    |    |    |    [588:589] <Newline> = ♢¶♢
|    |    |    |    [589:589] <Indenting> = ♢••••♢
|    |    |    |    [589:589] <CFlowReturn>
|    |    |    |    |    [589:589] <Match> = ♢return♢
|    |    |    |    |    [589:589] <Whitespace> = ♢•♢
|    |    |    |    |    [589:589] <Text> = ♢dict♢
|    |    |    |    |    [589:589] <Semicolon> = ♢;♢
|    |    |    |    [589:590] <Newline> = ♢¶♢
|    |    |    |    [590:590] <Match> = ♢}♢
|    |    [590:591] <Newline> = ♢¶♢
|    |    [591:592] <Newline> = ♢¶♢
|    |    [592:594] <ObjCMethodImplementation>
|    |    |    [592:592] <Match> = ♢-♢
|    |    |    [592:592] <Whitespace> = ♢•♢
|    |    |    [592:592] <Parenthesis>
|    |    |    |    [592:592] <Match> = ♢(♢
|    |    |    |    [592:592] <Text> = ♢NSArray♢
|    |    |    |    [592:592] <Whitespace> = ♢•♢
|    |    |    |    [592:592] <Asterisk> = ♢*♢
|    |    |    |    [592:592] <Match> = ♢)♢
|    |    |    [592:592] <Text> = ♢knownDocumentProperties♢
|    |    |    [592:592] <Whitespace> = ♢•♢
|    |    |    [592:594] <Braces>
|    |    |    |    [592:592] <Match> = ♢{♢
|    |    |    |    [592:593] <Newline> = ♢¶♢
|    |    |    |    [593:593] <Indenting> = ♢••••♢
|    |    |    |    [593:593] <CFlowReturn>
|    |    |    |    |    [593:593] <Match> = ♢return♢
|    |    |    |    |    [593:593] <Whitespace> = ♢•♢
|    |    |    |    |    [593:593] <ObjCMethodCall>
|    |    |    |    |    |    [593:593] <Match> = ♢[♢
|    |    |    |    |    |    [593:593] <ObjCMethodCall>
|    |    |    |    |    |    |    [593:593] <Match> = ♢[♢
|    |    |    |    |    |    |    [593:593] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [593:593] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [593:593] <Text> = ♢documentPropertyToAttributeNameMappings♢
|    |    |    |    |    |    |    [593:593] <Match> = ♢]♢
|    |    |    |    |    |    [593:593] <Whitespace> = ♢•♢
|    |    |    |    |    |    [593:593] <Text> = ♢allKeys♢
|    |    |    |    |    |    [593:593] <Match> = ♢]♢
|    |    |    |    |    [593:593] <Semicolon> = ♢;♢
|    |    |    |    [593:594] <Newline> = ♢¶♢
|    |    |    |    [594:594] <Match> = ♢}♢
|    |    [594:595] <Newline> = ♢¶♢
|    |    [595:596] <Newline> = ♢¶♢
|    |    [596:597] <CComment> = ♢/*•If•there•are•document•properties•and•they•are•not•the•same•as•the•defaults•established•in•preferences,•return•YES¶*/♢
|    |    [597:598] <Newline> = ♢¶♢
|    |    [598:604] <ObjCMethodImplementation>
|    |    |    [598:598] <Match> = ♢-♢
|    |    |    [598:598] <Whitespace> = ♢•♢
|    |    |    [598:598] <Parenthesis>
|    |    |    |    [598:598] <Match> = ♢(♢
|    |    |    |    [598:598] <Text> = ♢BOOL♢
|    |    |    |    [598:598] <Match> = ♢)♢
|    |    |    [598:598] <Text> = ♢hasDocumentProperties♢
|    |    |    [598:598] <Whitespace> = ♢•♢
|    |    |    [598:604] <Braces>
|    |    |    |    [598:598] <Match> = ♢{♢
|    |    |    |    [598:599] <Newline> = ♢¶♢
|    |    |    |    [599:599] <Indenting> = ♢••••♢
|    |    |    |    [599:602] <CFlowFor>
|    |    |    |    |    [599:599] <Match> = ♢for♢
|    |    |    |    |    [599:599] <Whitespace> = ♢•♢
|    |    |    |    |    [599:599] <Parenthesis>
|    |    |    |    |    |    [599:599] <Match> = ♢(♢
|    |    |    |    |    |    [599:599] <Text> = ♢NSString♢
|    |    |    |    |    |    [599:599] <Whitespace> = ♢•♢
|    |    |    |    |    |    [599:599] <Asterisk> = ♢*♢
|    |    |    |    |    |    [599:599] <Text> = ♢key♢
|    |    |    |    |    |    [599:599] <Whitespace> = ♢•♢
|    |    |    |    |    |    [599:599] <Text> = ♢in♢
|    |    |    |    |    |    [599:599] <Whitespace> = ♢•♢
|    |    |    |    |    |    [599:599] <ObjCMethodCall>
|    |    |    |    |    |    |    [599:599] <Match> = ♢[♢
|    |    |    |    |    |    |    [599:599] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [599:599] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [599:599] <Text> = ♢knownDocumentProperties♢
|    |    |    |    |    |    |    [599:599] <Match> = ♢]♢
|    |    |    |    |    |    [599:599] <Match> = ♢)♢
|    |    |    |    |    [599:599] <Whitespace> = ♢•♢
|    |    |    |    |    [599:602] <Braces>
|    |    |    |    |    |    [599:599] <Match> = ♢{♢
|    |    |    |    |    |    [599:600] <Newline> = ♢¶♢
|    |    |    |    |    |    [600:600] <Indenting> = ♢→♢
|    |    |    |    |    |    [600:600] <Text> = ♢id♢
|    |    |    |    |    |    [600:600] <Whitespace> = ♢•♢
|    |    |    |    |    |    [600:600] <Text> = ♢value♢
|    |    |    |    |    |    [600:600] <Whitespace> = ♢•♢
|    |    |    |    |    |    [600:600] <Text> = ♢=♢
|    |    |    |    |    |    [600:600] <Whitespace> = ♢•♢
|    |    |    |    |    |    [600:600] <ObjCMethodCall>
|    |    |    |    |    |    |    [600:600] <Match> = ♢[♢
|    |    |    |    |    |    |    [600:600] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [600:600] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [600:600] <Text> = ♢valueForKey♢
|    |    |    |    |    |    |    [600:600] <Colon> = ♢:♢
|    |    |    |    |    |    |    [600:600] <Text> = ♢key♢
|    |    |    |    |    |    |    [600:600] <Match> = ♢]♢
|    |    |    |    |    |    [600:600] <Semicolon> = ♢;♢
|    |    |    |    |    |    [600:601] <Newline> = ♢¶♢
|    |    |    |    |    |    [601:601] <Indenting> = ♢→♢
|    |    |    |    |    |    [601:601] <CConditionIf>
|    |    |    |    |    |    |    [601:601] <Match> = ♢if♢
|    |    |    |    |    |    |    [601:601] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [601:601] <Parenthesis>
|    |    |    |    |    |    |    |    [601:601] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [601:601] <Text> = ♢value♢
|    |    |    |    |    |    |    |    [601:601] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [601:601] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    [601:601] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    [601:601] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [601:601] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    [601:601] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [601:601] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [601:601] <Match> = ♢value♢
|    |    |    |    |    |    |    |    |    [601:601] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [601:601] <Text> = ♢isEqual♢
|    |    |    |    |    |    |    |    |    [601:601] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [601:601] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [601:601] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [601:601] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [601:601] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [601:601] <Match> = ♢NSUserDefaults♢
|    |    |    |    |    |    |    |    |    |    |    [601:601] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [601:601] <Text> = ♢standardUserDefaults♢
|    |    |    |    |    |    |    |    |    |    |    [601:601] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [601:601] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [601:601] <Text> = ♢objectForKey♢
|    |    |    |    |    |    |    |    |    |    [601:601] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [601:601] <Text> = ♢key♢
|    |    |    |    |    |    |    |    |    |    [601:601] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [601:601] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [601:601] <Match> = ♢)♢
|    |    |    |    |    |    |    [601:601] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [601:601] <CFlowReturn>
|    |    |    |    |    |    |    |    [601:601] <Match> = ♢return♢
|    |    |    |    |    |    |    |    [601:601] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [601:601] <Text> = ♢YES♢
|    |    |    |    |    |    |    |    [601:601] <Semicolon> = ♢;♢
|    |    |    |    |    |    [601:602] <Newline> = ♢¶♢
|    |    |    |    |    |    [602:602] <Indenting> = ♢••••♢
|    |    |    |    |    |    [602:602] <Match> = ♢}♢
|    |    |    |    [602:603] <Newline> = ♢¶♢
|    |    |    |    [603:603] <Indenting> = ♢••••♢
|    |    |    |    [603:603] <CFlowReturn>
|    |    |    |    |    [603:603] <Match> = ♢return♢
|    |    |    |    |    [603:603] <Whitespace> = ♢•♢
|    |    |    |    |    [603:603] <Text> = ♢NO♢
|    |    |    |    |    [603:603] <Semicolon> = ♢;♢
|    |    |    |    [603:604] <Newline> = ♢¶♢
|    |    |    |    [604:604] <Match> = ♢}♢
|    |    [604:605] <Newline> = ♢¶♢
|    |    [605:606] <Newline> = ♢¶♢
|    |    [606:607] <CComment> = ♢/*•This•actually•clears•all•properties•(rather•than•setting•them•to•default•values•established•in•preferences)¶*/♢
|    |    [607:608] <Newline> = ♢¶♢
|    |    [608:610] <ObjCMethodImplementation>
|    |    |    [608:608] <Match> = ♢-♢
|    |    |    [608:608] <Whitespace> = ♢•♢
|    |    |    [608:608] <Parenthesis>
|    |    |    |    [608:608] <Match> = ♢(♢
|    |    |    |    [608:608] <CVoid> = ♢void♢
|    |    |    |    [608:608] <Match> = ♢)♢
|    |    |    [608:608] <Text> = ♢clearDocumentProperties♢
|    |    |    [608:608] <Whitespace> = ♢•♢
|    |    |    [608:610] <Braces>
|    |    |    |    [608:608] <Match> = ♢{♢
|    |    |    |    [608:609] <Newline> = ♢¶♢
|    |    |    |    [609:609] <Indenting> = ♢••••♢
|    |    |    |    [609:609] <CFlowFor>
|    |    |    |    |    [609:609] <Match> = ♢for♢
|    |    |    |    |    [609:609] <Whitespace> = ♢•♢
|    |    |    |    |    [609:609] <Parenthesis>
|    |    |    |    |    |    [609:609] <Match> = ♢(♢
|    |    |    |    |    |    [609:609] <Text> = ♢NSString♢
|    |    |    |    |    |    [609:609] <Whitespace> = ♢•♢
|    |    |    |    |    |    [609:609] <Asterisk> = ♢*♢
|    |    |    |    |    |    [609:609] <Text> = ♢key♢
|    |    |    |    |    |    [609:609] <Whitespace> = ♢•♢
|    |    |    |    |    |    [609:609] <Text> = ♢in♢
|    |    |    |    |    |    [609:609] <Whitespace> = ♢•♢
|    |    |    |    |    |    [609:609] <ObjCMethodCall>
|    |    |    |    |    |    |    [609:609] <Match> = ♢[♢
|    |    |    |    |    |    |    [609:609] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [609:609] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [609:609] <Text> = ♢knownDocumentProperties♢
|    |    |    |    |    |    |    [609:609] <Match> = ♢]♢
|    |    |    |    |    |    [609:609] <Match> = ♢)♢
|    |    |    |    |    [609:609] <Whitespace> = ♢•♢
|    |    |    |    |    [609:609] <ObjCMethodCall>
|    |    |    |    |    |    [609:609] <Match> = ♢[♢
|    |    |    |    |    |    [609:609] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    [609:609] <Whitespace> = ♢•♢
|    |    |    |    |    |    [609:609] <Text> = ♢setValue♢
|    |    |    |    |    |    [609:609] <Colon> = ♢:♢
|    |    |    |    |    |    [609:609] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    [609:609] <Whitespace> = ♢•♢
|    |    |    |    |    |    [609:609] <Text> = ♢forKey♢
|    |    |    |    |    |    [609:609] <Colon> = ♢:♢
|    |    |    |    |    |    [609:609] <Text> = ♢key♢
|    |    |    |    |    |    [609:609] <Match> = ♢]♢
|    |    |    |    |    [609:609] <Semicolon> = ♢;♢
|    |    |    |    [609:610] <Newline> = ♢¶♢
|    |    |    |    [610:610] <Match> = ♢}♢
|    |    [610:611] <Newline> = ♢¶♢
|    |    [611:612] <Newline> = ♢¶♢
|    |    [612:613] <CComment> = ♢/*•This•sets•document•properties•to•values•established•in•defaults¶*/♢
|    |    [613:614] <Newline> = ♢¶♢
|    |    [614:616] <ObjCMethodImplementation>
|    |    |    [614:614] <Match> = ♢-♢
|    |    |    [614:614] <Whitespace> = ♢•♢
|    |    |    [614:614] <Parenthesis>
|    |    |    |    [614:614] <Match> = ♢(♢
|    |    |    |    [614:614] <CVoid> = ♢void♢
|    |    |    |    [614:614] <Match> = ♢)♢
|    |    |    [614:614] <Text> = ♢setDocumentPropertiesToDefaults♢
|    |    |    [614:614] <Whitespace> = ♢•♢
|    |    |    [614:616] <Braces>
|    |    |    |    [614:614] <Match> = ♢{♢
|    |    |    |    [614:615] <Newline> = ♢¶♢
|    |    |    |    [615:615] <Indenting> = ♢••••♢
|    |    |    |    [615:615] <CFlowFor>
|    |    |    |    |    [615:615] <Match> = ♢for♢
|    |    |    |    |    [615:615] <Whitespace> = ♢•♢
|    |    |    |    |    [615:615] <Parenthesis>
|    |    |    |    |    |    [615:615] <Match> = ♢(♢
|    |    |    |    |    |    [615:615] <Text> = ♢NSString♢
|    |    |    |    |    |    [615:615] <Whitespace> = ♢•♢
|    |    |    |    |    |    [615:615] <Asterisk> = ♢*♢
|    |    |    |    |    |    [615:615] <Text> = ♢key♢
|    |    |    |    |    |    [615:615] <Whitespace> = ♢•♢
|    |    |    |    |    |    [615:615] <Text> = ♢in♢
|    |    |    |    |    |    [615:615] <Whitespace> = ♢•♢
|    |    |    |    |    |    [615:615] <ObjCMethodCall>
|    |    |    |    |    |    |    [615:615] <Match> = ♢[♢
|    |    |    |    |    |    |    [615:615] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [615:615] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [615:615] <Text> = ♢knownDocumentProperties♢
|    |    |    |    |    |    |    [615:615] <Match> = ♢]♢
|    |    |    |    |    |    [615:615] <Match> = ♢)♢
|    |    |    |    |    [615:615] <Whitespace> = ♢•♢
|    |    |    |    |    [615:615] <ObjCMethodCall>
|    |    |    |    |    |    [615:615] <Match> = ♢[♢
|    |    |    |    |    |    [615:615] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    [615:615] <Whitespace> = ♢•♢
|    |    |    |    |    |    [615:615] <Text> = ♢setValue♢
|    |    |    |    |    |    [615:615] <Colon> = ♢:♢
|    |    |    |    |    |    [615:615] <ObjCMethodCall>
|    |    |    |    |    |    |    [615:615] <Match> = ♢[♢
|    |    |    |    |    |    |    [615:615] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [615:615] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [615:615] <Match> = ♢NSUserDefaults♢
|    |    |    |    |    |    |    |    [615:615] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [615:615] <Text> = ♢standardUserDefaults♢
|    |    |    |    |    |    |    |    [615:615] <Match> = ♢]♢
|    |    |    |    |    |    |    [615:615] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [615:615] <Text> = ♢objectForKey♢
|    |    |    |    |    |    |    [615:615] <Colon> = ♢:♢
|    |    |    |    |    |    |    [615:615] <Text> = ♢key♢
|    |    |    |    |    |    |    [615:615] <Match> = ♢]♢
|    |    |    |    |    |    [615:615] <Whitespace> = ♢•♢
|    |    |    |    |    |    [615:615] <Text> = ♢forKey♢
|    |    |    |    |    |    [615:615] <Colon> = ♢:♢
|    |    |    |    |    |    [615:615] <Text> = ♢key♢
|    |    |    |    |    |    [615:615] <Match> = ♢]♢
|    |    |    |    |    [615:615] <Semicolon> = ♢;♢
|    |    |    |    [615:616] <Newline> = ♢¶♢
|    |    |    |    [616:616] <Match> = ♢}♢
|    |    [616:617] <Newline> = ♢¶♢
|    |    [617:618] <Newline> = ♢¶♢
|    |    [618:619] <CComment> = ♢/*•We•implement•a•setValue:forDocumentProperty:•to•work•around•NSUndoManager•bug•where•prepareWithInvocationTarget:•fails•to•freeze-dry•invocations•with•"known"•methods•such•as•setValue:forKey:.••¶*/♢
|    |    [619:620] <Newline> = ♢¶♢
|    |    [620:627] <ObjCMethodImplementation>
|    |    |    [620:620] <Match> = ♢-♢
|    |    |    [620:620] <Whitespace> = ♢•♢
|    |    |    [620:620] <Parenthesis>
|    |    |    |    [620:620] <Match> = ♢(♢
|    |    |    |    [620:620] <CVoid> = ♢void♢
|    |    |    |    [620:620] <Match> = ♢)♢
|    |    |    [620:620] <Text> = ♢setValue♢
|    |    |    [620:620] <Colon> = ♢:♢
|    |    |    [620:620] <Parenthesis>
|    |    |    |    [620:620] <Match> = ♢(♢
|    |    |    |    [620:620] <Text> = ♢id♢
|    |    |    |    [620:620] <Match> = ♢)♢
|    |    |    [620:620] <Text> = ♢value♢
|    |    |    [620:620] <Whitespace> = ♢•♢
|    |    |    [620:620] <Text> = ♢forDocumentProperty♢
|    |    |    [620:620] <Colon> = ♢:♢
|    |    |    [620:620] <Parenthesis>
|    |    |    |    [620:620] <Match> = ♢(♢
|    |    |    |    [620:620] <Text> = ♢NSString♢
|    |    |    |    [620:620] <Whitespace> = ♢•♢
|    |    |    |    [620:620] <Asterisk> = ♢*♢
|    |    |    |    [620:620] <Match> = ♢)♢
|    |    |    [620:620] <Text> = ♢property♢
|    |    |    [620:620] <Whitespace> = ♢•♢
|    |    |    [620:627] <Braces>
|    |    |    |    [620:620] <Match> = ♢{♢
|    |    |    |    [620:621] <Newline> = ♢¶♢
|    |    |    |    [621:621] <Indenting> = ♢••••♢
|    |    |    |    [621:621] <Text> = ♢id♢
|    |    |    |    [621:621] <Whitespace> = ♢•♢
|    |    |    |    [621:621] <Text> = ♢oldValue♢
|    |    |    |    [621:621] <Whitespace> = ♢•♢
|    |    |    |    [621:621] <Text> = ♢=♢
|    |    |    |    [621:621] <Whitespace> = ♢•♢
|    |    |    |    [621:621] <ObjCMethodCall>
|    |    |    |    |    [621:621] <Match> = ♢[♢
|    |    |    |    |    [621:621] <ObjCSelf> = ♢self♢
|    |    |    |    |    [621:621] <Whitespace> = ♢•♢
|    |    |    |    |    [621:621] <Text> = ♢valueForKey♢
|    |    |    |    |    [621:621] <Colon> = ♢:♢
|    |    |    |    |    [621:621] <Text> = ♢property♢
|    |    |    |    |    [621:621] <Match> = ♢]♢
|    |    |    |    [621:621] <Semicolon> = ♢;♢
|    |    |    |    [621:622] <Newline> = ♢¶♢
|    |    |    |    [622:622] <Indenting> = ♢••••♢
|    |    |    |    [622:622] <ObjCMethodCall>
|    |    |    |    |    [622:622] <Match> = ♢[♢
|    |    |    |    |    [622:622] <ObjCMethodCall>
|    |    |    |    |    |    [622:622] <Match> = ♢[♢
|    |    |    |    |    |    [622:622] <ObjCMethodCall>
|    |    |    |    |    |    |    [622:622] <Match> = ♢[♢
|    |    |    |    |    |    |    [622:622] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [622:622] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [622:622] <Text> = ♢undoManager♢
|    |    |    |    |    |    |    [622:622] <Match> = ♢]♢
|    |    |    |    |    |    [622:622] <Whitespace> = ♢•♢
|    |    |    |    |    |    [622:622] <Text> = ♢prepareWithInvocationTarget♢
|    |    |    |    |    |    [622:622] <Colon> = ♢:♢
|    |    |    |    |    |    [622:622] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    [622:622] <Match> = ♢]♢
|    |    |    |    |    [622:622] <Whitespace> = ♢•♢
|    |    |    |    |    [622:622] <Text> = ♢setValue♢
|    |    |    |    |    [622:622] <Colon> = ♢:♢
|    |    |    |    |    [622:622] <Text> = ♢oldValue♢
|    |    |    |    |    [622:622] <Whitespace> = ♢•♢
|    |    |    |    |    [622:622] <Text> = ♢forDocumentProperty♢
|    |    |    |    |    [622:622] <Colon> = ♢:♢
|    |    |    |    |    [622:622] <Text> = ♢property♢
|    |    |    |    |    [622:622] <Match> = ♢]♢
|    |    |    |    [622:622] <Semicolon> = ♢;♢
|    |    |    |    [622:623] <Newline> = ♢¶♢
|    |    |    |    [623:623] <Indenting> = ♢••••♢
|    |    |    |    [623:623] <ObjCMethodCall>
|    |    |    |    |    [623:623] <Match> = ♢[♢
|    |    |    |    |    [623:623] <ObjCMethodCall>
|    |    |    |    |    |    [623:623] <Match> = ♢[♢
|    |    |    |    |    |    [623:623] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    [623:623] <Whitespace> = ♢•♢
|    |    |    |    |    |    [623:623] <Text> = ♢undoManager♢
|    |    |    |    |    |    [623:623] <Match> = ♢]♢
|    |    |    |    |    [623:623] <Whitespace> = ♢•♢
|    |    |    |    |    [623:623] <Text> = ♢setActionName♢
|    |    |    |    |    [623:623] <Colon> = ♢:♢
|    |    |    |    |    [623:623] <CFunctionCall>
|    |    |    |    |    |    [623:623] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    [623:623] <Parenthesis>
|    |    |    |    |    |    |    [623:623] <Match> = ♢(♢
|    |    |    |    |    |    |    [623:623] <Text> = ♢property,♢
|    |    |    |    |    |    |    [623:623] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [623:623] <CStringDoubleQuote> = ♢""♢
|    |    |    |    |    |    |    [623:623] <Match> = ♢)♢
|    |    |    |    |    [623:623] <Match> = ♢]♢
|    |    |    |    [623:623] <Semicolon> = ♢;♢
|    |    |    |    [623:623] <Whitespace> = ♢→♢
|    |    |    |    [623:623] <CPPComment> = ♢//•Potential•strings•for•action•names•are•listed•below•(for•genstrings•to•pick•up)♢
|    |    |    |    [623:624] <Newline> = ♢¶♢
|    |    |    |    [624:625] <Newline> = ♢¶♢
|    |    |    |    [625:625] <Indenting> = ♢••••♢
|    |    |    |    [625:625] <CPPComment> = ♢//•Call•the•regular•KVC•mechanism•to•get•the•value•to•be•properly•set♢
|    |    |    |    [625:626] <Newline> = ♢¶♢
|    |    |    |    [626:626] <Indenting> = ♢••••♢
|    |    |    |    [626:626] <ObjCMethodCall>
|    |    |    |    |    [626:626] <Match> = ♢[♢
|    |    |    |    |    [626:626] <ObjCSuper> = ♢super♢
|    |    |    |    |    [626:626] <Whitespace> = ♢•♢
|    |    |    |    |    [626:626] <Text> = ♢setValue♢
|    |    |    |    |    [626:626] <Colon> = ♢:♢
|    |    |    |    |    [626:626] <Text> = ♢value♢
|    |    |    |    |    [626:626] <Whitespace> = ♢•♢
|    |    |    |    |    [626:626] <Text> = ♢forKey♢
|    |    |    |    |    [626:626] <Colon> = ♢:♢
|    |    |    |    |    [626:626] <Text> = ♢property♢
|    |    |    |    |    [626:626] <Match> = ♢]♢
|    |    |    |    [626:626] <Semicolon> = ♢;♢
|    |    |    |    [626:627] <Newline> = ♢¶♢
|    |    |    |    [627:627] <Match> = ♢}♢
|    |    [627:628] <Newline> = ♢¶♢
|    |    [628:629] <Newline> = ♢¶♢
|    |    [629:635] <ObjCMethodImplementation>
|    |    |    [629:629] <Match> = ♢-♢
|    |    |    [629:629] <Whitespace> = ♢•♢
|    |    |    [629:629] <Parenthesis>
|    |    |    |    [629:629] <Match> = ♢(♢
|    |    |    |    [629:629] <CVoid> = ♢void♢
|    |    |    |    [629:629] <Match> = ♢)♢
|    |    |    [629:629] <Text> = ♢setValue♢
|    |    |    [629:629] <Colon> = ♢:♢
|    |    |    [629:629] <Parenthesis>
|    |    |    |    [629:629] <Match> = ♢(♢
|    |    |    |    [629:629] <Text> = ♢id♢
|    |    |    |    [629:629] <Match> = ♢)♢
|    |    |    [629:629] <Text> = ♢value♢
|    |    |    [629:629] <Whitespace> = ♢•♢
|    |    |    [629:629] <Text> = ♢forKey♢
|    |    |    [629:629] <Colon> = ♢:♢
|    |    |    [629:629] <Parenthesis>
|    |    |    |    [629:629] <Match> = ♢(♢
|    |    |    |    [629:629] <Text> = ♢NSString♢
|    |    |    |    [629:629] <Whitespace> = ♢•♢
|    |    |    |    [629:629] <Asterisk> = ♢*♢
|    |    |    |    [629:629] <Match> = ♢)♢
|    |    |    [629:629] <Text> = ♢key♢
|    |    |    [629:629] <Whitespace> = ♢•♢
|    |    |    [629:635] <Braces>
|    |    |    |    [629:629] <Match> = ♢{♢
|    |    |    |    [629:630] <Newline> = ♢¶♢
|    |    |    |    [630:630] <Indenting> = ♢••••♢
|    |    |    |    [630:632] <CConditionIf>
|    |    |    |    |    [630:630] <Match> = ♢if♢
|    |    |    |    |    [630:630] <Whitespace> = ♢•♢
|    |    |    |    |    [630:630] <Parenthesis>
|    |    |    |    |    |    [630:630] <Match> = ♢(♢
|    |    |    |    |    |    [630:630] <ObjCMethodCall>
|    |    |    |    |    |    |    [630:630] <Match> = ♢[♢
|    |    |    |    |    |    |    [630:630] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [630:630] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [630:630] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [630:630] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [630:630] <Text> = ♢knownDocumentProperties♢
|    |    |    |    |    |    |    |    [630:630] <Match> = ♢]♢
|    |    |    |    |    |    |    [630:630] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [630:630] <Text> = ♢containsObject♢
|    |    |    |    |    |    |    [630:630] <Colon> = ♢:♢
|    |    |    |    |    |    |    [630:630] <Text> = ♢key♢
|    |    |    |    |    |    |    [630:630] <Match> = ♢]♢
|    |    |    |    |    |    [630:630] <Match> = ♢)♢
|    |    |    |    |    [630:630] <Whitespace> = ♢•♢
|    |    |    |    |    [630:632] <Braces>
|    |    |    |    |    |    [630:630] <Match> = ♢{♢
|    |    |    |    |    |    [630:630] <Whitespace> = ♢•♢
|    |    |    |    |    |    [630:631] <Newline> = ♢¶♢
|    |    |    |    |    |    [631:631] <Indenting> = ♢→♢
|    |    |    |    |    |    [631:631] <ObjCMethodCall>
|    |    |    |    |    |    |    [631:631] <Match> = ♢[♢
|    |    |    |    |    |    |    [631:631] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [631:631] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [631:631] <Text> = ♢setValue♢
|    |    |    |    |    |    |    [631:631] <Colon> = ♢:♢
|    |    |    |    |    |    |    [631:631] <Text> = ♢value♢
|    |    |    |    |    |    |    [631:631] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [631:631] <Text> = ♢forDocumentProperty♢
|    |    |    |    |    |    |    [631:631] <Colon> = ♢:♢
|    |    |    |    |    |    |    [631:631] <Text> = ♢key♢
|    |    |    |    |    |    |    [631:631] <Match> = ♢]♢
|    |    |    |    |    |    [631:631] <Semicolon> = ♢;♢
|    |    |    |    |    |    [631:631] <Whitespace> = ♢→♢
|    |    |    |    |    |    [631:631] <CPPComment> = ♢//•We•take•a•side-trip•to•this•method•to•register•for•undo♢
|    |    |    |    |    |    [631:632] <Newline> = ♢¶♢
|    |    |    |    |    |    [632:632] <Indenting> = ♢••••♢
|    |    |    |    |    |    [632:632] <Match> = ♢}♢
|    |    |    |    [632:632] <Whitespace> = ♢•♢
|    |    |    |    [632:634] <CConditionElse>
|    |    |    |    |    [632:632] <Match> = ♢else♢
|    |    |    |    |    [632:632] <Whitespace> = ♢•♢
|    |    |    |    |    [632:634] <Braces>
|    |    |    |    |    |    [632:632] <Match> = ♢{♢
|    |    |    |    |    |    [632:633] <Newline> = ♢¶♢
|    |    |    |    |    |    [633:633] <Indenting> = ♢→♢
|    |    |    |    |    |    [633:633] <ObjCMethodCall>
|    |    |    |    |    |    |    [633:633] <Match> = ♢[♢
|    |    |    |    |    |    |    [633:633] <ObjCSuper> = ♢super♢
|    |    |    |    |    |    |    [633:633] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [633:633] <Text> = ♢setValue♢
|    |    |    |    |    |    |    [633:633] <Colon> = ♢:♢
|    |    |    |    |    |    |    [633:633] <Text> = ♢value♢
|    |    |    |    |    |    |    [633:633] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [633:633] <Text> = ♢forKey♢
|    |    |    |    |    |    |    [633:633] <Colon> = ♢:♢
|    |    |    |    |    |    |    [633:633] <Text> = ♢key♢
|    |    |    |    |    |    |    [633:633] <Match> = ♢]♢
|    |    |    |    |    |    [633:633] <Semicolon> = ♢;♢
|    |    |    |    |    |    [633:633] <Whitespace> = ♢••♢
|    |    |    |    |    |    [633:633] <CPPComment> = ♢//•In•case•some•other•KVC•call•is•sent•to•Document,•we•treat•it•normally♢
|    |    |    |    |    |    [633:634] <Newline> = ♢¶♢
|    |    |    |    |    |    [634:634] <Indenting> = ♢••••♢
|    |    |    |    |    |    [634:634] <Match> = ♢}♢
|    |    |    |    [634:635] <Newline> = ♢¶♢
|    |    |    |    [635:635] <Match> = ♢}♢
|    |    [635:636] <Newline> = ♢¶♢
|    |    [636:637] <Newline> = ♢¶♢
|    |    [637:645] <CComment> = ♢/*•For•genstrings:¶••••NSLocalizedStringWithDefaultValue(@"author",•@"",•@"",•@"Change•Author",•@"Undo•menu•change•string,•without•the•'Undo'");¶••••NSLocalizedStringWithDefaultValue(@"copyright",•@"",•@"",•@"Change•Copyright",•@"Undo•menu•change•string,•without•the•'Undo'");¶••••NSLocalizedStringWithDefaultValue(@"subject",•@"",•@"",•@"Change•Subject",•@"Undo•menu•change•string,•without•the•'Undo'");¶••••NSLocalizedStringWithDefaultValue(@"title",•@"",•@"",•@"Change•Title",•@"Undo•menu•change•string,•without•the•'Undo'");¶••••NSLocalizedStringWithDefaultValue(@"company",•@"",•@"",•@"Change•Company",•@"Undo•menu•change•string,•without•the•'Undo'");¶••••NSLocalizedStringWithDefaultValue(@"comment",•@"",•@"",•@"Change•Comment",•@"Undo•menu•change•string,•without•the•'Undo'");¶••••NSLocalizedStringWithDefaultValue(@"keywords",•@"",•@"",•@"Change•Keywords",•@"Undo•menu•change•string,•without•the•'Undo'");¶*/♢
|    |    [645:646] <Newline> = ♢¶♢
|    |    [646:647] <Newline> = ♢¶♢
|    |    [647:648] <Newline> = ♢¶♢
|    |    [648:649] <Newline> = ♢¶♢
|    |    [649:675] <ObjCMethodImplementation>
|    |    |    [649:649] <Match> = ♢-♢
|    |    |    [649:649] <Whitespace> = ♢•♢
|    |    |    [649:649] <Parenthesis>
|    |    |    |    [649:649] <Match> = ♢(♢
|    |    |    |    [649:649] <Text> = ♢NSPrintOperation♢
|    |    |    |    [649:649] <Whitespace> = ♢•♢
|    |    |    |    [649:649] <Asterisk> = ♢*♢
|    |    |    |    [649:649] <Match> = ♢)♢
|    |    |    [649:649] <Text> = ♢printOperationWithSettings♢
|    |    |    [649:649] <Colon> = ♢:♢
|    |    |    [649:649] <Parenthesis>
|    |    |    |    [649:649] <Match> = ♢(♢
|    |    |    |    [649:649] <Text> = ♢NSDictionary♢
|    |    |    |    [649:649] <Whitespace> = ♢•♢
|    |    |    |    [649:649] <Asterisk> = ♢*♢
|    |    |    |    [649:649] <Match> = ♢)♢
|    |    |    [649:649] <Text> = ♢printSettings♢
|    |    |    [649:649] <Whitespace> = ♢•♢
|    |    |    [649:649] <Text> = ♢error♢
|    |    |    [649:649] <Colon> = ♢:♢
|    |    |    [649:649] <Parenthesis>
|    |    |    |    [649:649] <Match> = ♢(♢
|    |    |    |    [649:649] <Text> = ♢NSError♢
|    |    |    |    [649:649] <Whitespace> = ♢•♢
|    |    |    |    [649:649] <Asterisk> = ♢*♢
|    |    |    |    [649:649] <Asterisk> = ♢*♢
|    |    |    |    [649:649] <Match> = ♢)♢
|    |    |    [649:649] <Text> = ♢outError♢
|    |    |    [649:649] <Whitespace> = ♢•♢
|    |    |    [649:675] <Braces>
|    |    |    |    [649:649] <Match> = ♢{♢
|    |    |    |    [649:650] <Newline> = ♢¶♢
|    |    |    |    [650:650] <Indenting> = ♢••••♢
|    |    |    |    [650:650] <Text> = ♢NSPrintInfo♢
|    |    |    |    [650:650] <Whitespace> = ♢•♢
|    |    |    |    [650:650] <Asterisk> = ♢*♢
|    |    |    |    [650:650] <Text> = ♢tempPrintInfo♢
|    |    |    |    [650:650] <Whitespace> = ♢•♢
|    |    |    |    [650:650] <Text> = ♢=♢
|    |    |    |    [650:650] <Whitespace> = ♢•♢
|    |    |    |    [650:650] <ObjCMethodCall>
|    |    |    |    |    [650:650] <Match> = ♢[♢
|    |    |    |    |    [650:650] <ObjCSelf> = ♢self♢
|    |    |    |    |    [650:650] <Whitespace> = ♢•♢
|    |    |    |    |    [650:650] <Text> = ♢printInfo♢
|    |    |    |    |    [650:650] <Match> = ♢]♢
|    |    |    |    [650:650] <Semicolon> = ♢;♢
|    |    |    |    [650:651] <Newline> = ♢¶♢
|    |    |    |    [651:651] <Indenting> = ♢••••♢
|    |    |    |    [651:651] <Text> = ♢BOOL♢
|    |    |    |    [651:651] <Whitespace> = ♢•♢
|    |    |    |    [651:651] <Text> = ♢numberPages♢
|    |    |    |    [651:651] <Whitespace> = ♢•♢
|    |    |    |    [651:651] <Text> = ♢=♢
|    |    |    |    [651:651] <Whitespace> = ♢•♢
|    |    |    |    [651:651] <ObjCMethodCall>
|    |    |    |    |    [651:651] <Match> = ♢[♢
|    |    |    |    |    [651:651] <ObjCMethodCall>
|    |    |    |    |    |    [651:651] <Match> = ♢[♢
|    |    |    |    |    |    [651:651] <Match> = ♢NSUserDefaults♢
|    |    |    |    |    |    [651:651] <Whitespace> = ♢•♢
|    |    |    |    |    |    [651:651] <Text> = ♢standardUserDefaults♢
|    |    |    |    |    |    [651:651] <Match> = ♢]♢
|    |    |    |    |    [651:651] <Whitespace> = ♢•♢
|    |    |    |    |    [651:651] <Text> = ♢boolForKey♢
|    |    |    |    |    [651:651] <Colon> = ♢:♢
|    |    |    |    |    [651:651] <Text> = ♢NumberPagesWhenPrinting♢
|    |    |    |    |    [651:651] <Match> = ♢]♢
|    |    |    |    [651:651] <Semicolon> = ♢;♢
|    |    |    |    [651:652] <Newline> = ♢¶♢
|    |    |    |    [652:652] <Indenting> = ♢••••♢
|    |    |    |    [652:658] <CConditionIf>
|    |    |    |    |    [652:652] <Match> = ♢if♢
|    |    |    |    |    [652:652] <Whitespace> = ♢•♢
|    |    |    |    |    [652:652] <Parenthesis>
|    |    |    |    |    |    [652:652] <Match> = ♢(♢
|    |    |    |    |    |    [652:652] <ObjCMethodCall>
|    |    |    |    |    |    |    [652:652] <Match> = ♢[♢
|    |    |    |    |    |    |    [652:652] <Match> = ♢printSettings♢
|    |    |    |    |    |    |    [652:652] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [652:652] <Text> = ♢count♢
|    |    |    |    |    |    |    [652:652] <Match> = ♢]♢
|    |    |    |    |    |    [652:652] <Whitespace> = ♢•♢
|    |    |    |    |    |    [652:652] <Text> = ♢||♢
|    |    |    |    |    |    [652:652] <Whitespace> = ♢•♢
|    |    |    |    |    |    [652:652] <Text> = ♢numberPages♢
|    |    |    |    |    |    [652:652] <Match> = ♢)♢
|    |    |    |    |    [652:652] <Whitespace> = ♢•♢
|    |    |    |    |    [652:658] <Braces>
|    |    |    |    |    |    [652:652] <Match> = ♢{♢
|    |    |    |    |    |    [652:653] <Newline> = ♢¶♢
|    |    |    |    |    |    [653:653] <Indenting> = ♢→♢
|    |    |    |    |    |    [653:653] <Text> = ♢tempPrintInfo♢
|    |    |    |    |    |    [653:653] <Whitespace> = ♢•♢
|    |    |    |    |    |    [653:653] <Text> = ♢=♢
|    |    |    |    |    |    [653:653] <Whitespace> = ♢•♢
|    |    |    |    |    |    [653:653] <ObjCMethodCall>
|    |    |    |    |    |    |    [653:653] <Match> = ♢[♢
|    |    |    |    |    |    |    [653:653] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [653:653] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [653:653] <Match> = ♢tempPrintInfo♢
|    |    |    |    |    |    |    |    [653:653] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [653:653] <Text> = ♢copy♢
|    |    |    |    |    |    |    |    [653:653] <Match> = ♢]♢
|    |    |    |    |    |    |    [653:653] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [653:653] <Text> = ♢autorelease♢
|    |    |    |    |    |    |    [653:653] <Match> = ♢]♢
|    |    |    |    |    |    [653:653] <Semicolon> = ♢;♢
|    |    |    |    |    |    [653:654] <Newline> = ♢¶♢
|    |    |    |    |    |    [654:654] <Indenting> = ♢→♢
|    |    |    |    |    |    [654:654] <ObjCMethodCall>
|    |    |    |    |    |    |    [654:654] <Match> = ♢[♢
|    |    |    |    |    |    |    [654:654] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [654:654] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [654:654] <Match> = ♢tempPrintInfo♢
|    |    |    |    |    |    |    |    [654:654] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [654:654] <Text> = ♢dictionary♢
|    |    |    |    |    |    |    |    [654:654] <Match> = ♢]♢
|    |    |    |    |    |    |    [654:654] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [654:654] <Text> = ♢addEntriesFromDictionary♢
|    |    |    |    |    |    |    [654:654] <Colon> = ♢:♢
|    |    |    |    |    |    |    [654:654] <Text> = ♢printSettings♢
|    |    |    |    |    |    |    [654:654] <Match> = ♢]♢
|    |    |    |    |    |    [654:654] <Semicolon> = ♢;♢
|    |    |    |    |    |    [654:655] <Newline> = ♢¶♢
|    |    |    |    |    |    [655:655] <Indenting> = ♢→♢
|    |    |    |    |    |    [655:657] <CConditionIf>
|    |    |    |    |    |    |    [655:655] <Match> = ♢if♢
|    |    |    |    |    |    |    [655:655] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [655:655] <Parenthesis>
|    |    |    |    |    |    |    |    [655:655] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [655:655] <Text> = ♢numberPages♢
|    |    |    |    |    |    |    |    [655:655] <Match> = ♢)♢
|    |    |    |    |    |    |    [655:655] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [655:657] <Braces>
|    |    |    |    |    |    |    |    [655:655] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [655:656] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [656:656] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [656:656] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [656:656] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [656:656] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [656:656] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [656:656] <Match> = ♢tempPrintInfo♢
|    |    |    |    |    |    |    |    |    |    [656:656] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [656:656] <Text> = ♢dictionary♢
|    |    |    |    |    |    |    |    |    |    [656:656] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [656:656] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [656:656] <Text> = ♢setValue♢
|    |    |    |    |    |    |    |    |    [656:656] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [656:656] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [656:656] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [656:656] <Match> = ♢NSNumber♢
|    |    |    |    |    |    |    |    |    |    [656:656] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [656:656] <Text> = ♢numberWithBool♢
|    |    |    |    |    |    |    |    |    |    [656:656] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [656:656] <Text> = ♢YES♢
|    |    |    |    |    |    |    |    |    |    [656:656] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [656:656] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [656:656] <Text> = ♢forKey♢
|    |    |    |    |    |    |    |    |    [656:656] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [656:656] <Text> = ♢NSPrintHeaderAndFooter♢
|    |    |    |    |    |    |    |    |    [656:656] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [656:656] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [656:657] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [657:657] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [657:657] <Match> = ♢}♢
|    |    |    |    |    |    [657:658] <Newline> = ♢¶♢
|    |    |    |    |    |    [658:658] <Indenting> = ♢••••♢
|    |    |    |    |    |    [658:658] <Match> = ♢}♢
|    |    |    |    [658:659] <Newline> = ♢¶♢
|    |    |    |    [659:659] <Indenting> = ♢••••♢
|    |    |    |    [659:661] <CConditionIf>
|    |    |    |    |    [659:659] <Match> = ♢if♢
|    |    |    |    |    [659:659] <Whitespace> = ♢•♢
|    |    |    |    |    [659:659] <Parenthesis>
|    |    |    |    |    |    [659:659] <Match> = ♢(♢
|    |    |    |    |    |    [659:659] <ObjCMethodCall>
|    |    |    |    |    |    |    [659:659] <Match> = ♢[♢
|    |    |    |    |    |    |    [659:659] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [659:659] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [659:659] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [659:659] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [659:659] <Text> = ♢windowControllers♢
|    |    |    |    |    |    |    |    [659:659] <Match> = ♢]♢
|    |    |    |    |    |    |    [659:659] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [659:659] <Text> = ♢count♢
|    |    |    |    |    |    |    [659:659] <Match> = ♢]♢
|    |    |    |    |    |    [659:659] <Whitespace> = ♢•♢
|    |    |    |    |    |    [659:659] <Text> = ♢==♢
|    |    |    |    |    |    [659:659] <Whitespace> = ♢•♢
|    |    |    |    |    |    [659:659] <Text> = ♢0♢
|    |    |    |    |    |    [659:659] <Match> = ♢)♢
|    |    |    |    |    [659:659] <Whitespace> = ♢•♢
|    |    |    |    |    [659:661] <Braces>
|    |    |    |    |    |    [659:659] <Match> = ♢{♢
|    |    |    |    |    |    [659:660] <Newline> = ♢¶♢
|    |    |    |    |    |    [660:660] <Indenting> = ♢→♢
|    |    |    |    |    |    [660:660] <ObjCMethodCall>
|    |    |    |    |    |    |    [660:660] <Match> = ♢[♢
|    |    |    |    |    |    |    [660:660] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [660:660] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [660:660] <Text> = ♢makeWindowControllers♢
|    |    |    |    |    |    |    [660:660] <Match> = ♢]♢
|    |    |    |    |    |    [660:660] <Semicolon> = ♢;♢
|    |    |    |    |    |    [660:661] <Newline> = ♢¶♢
|    |    |    |    |    |    [661:661] <Indenting> = ♢••••♢
|    |    |    |    |    |    [661:661] <Match> = ♢}♢
|    |    |    |    [661:662] <Newline> = ♢¶♢
|    |    |    |    [662:662] <Indenting> = ♢••••♢
|    |    |    |    [662:663] <Newline> = ♢¶♢
|    |    |    |    [663:663] <Indenting> = ♢••••♢
|    |    |    |    [663:663] <Text> = ♢NSPrintOperation♢
|    |    |    |    [663:663] <Whitespace> = ♢•♢
|    |    |    |    [663:663] <Asterisk> = ♢*♢
|    |    |    |    [663:663] <Text> = ♢op♢
|    |    |    |    [663:663] <Whitespace> = ♢•♢
|    |    |    |    [663:663] <Text> = ♢=♢
|    |    |    |    [663:663] <Whitespace> = ♢•♢
|    |    |    |    [663:663] <ObjCMethodCall>
|    |    |    |    |    [663:663] <Match> = ♢[♢
|    |    |    |    |    [663:663] <Match> = ♢NSPrintOperation♢
|    |    |    |    |    [663:663] <Whitespace> = ♢•♢
|    |    |    |    |    [663:663] <Text> = ♢printOperationWithView♢
|    |    |    |    |    [663:663] <Colon> = ♢:♢
|    |    |    |    |    [663:663] <ObjCMethodCall>
|    |    |    |    |    |    [663:663] <Match> = ♢[♢
|    |    |    |    |    |    [663:663] <ObjCMethodCall>
|    |    |    |    |    |    |    [663:663] <Match> = ♢[♢
|    |    |    |    |    |    |    [663:663] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [663:663] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [663:663] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [663:663] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [663:663] <Text> = ♢windowControllers♢
|    |    |    |    |    |    |    |    [663:663] <Match> = ♢]♢
|    |    |    |    |    |    |    [663:663] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [663:663] <Text> = ♢objectAtIndex♢
|    |    |    |    |    |    |    [663:663] <Colon> = ♢:♢
|    |    |    |    |    |    |    [663:663] <Text> = ♢0♢
|    |    |    |    |    |    |    [663:663] <Match> = ♢]♢
|    |    |    |    |    |    [663:663] <Whitespace> = ♢•♢
|    |    |    |    |    |    [663:663] <Text> = ♢documentView♢
|    |    |    |    |    |    [663:663] <Match> = ♢]♢
|    |    |    |    |    [663:663] <Whitespace> = ♢•♢
|    |    |    |    |    [663:663] <Text> = ♢printInfo♢
|    |    |    |    |    [663:663] <Colon> = ♢:♢
|    |    |    |    |    [663:663] <Text> = ♢tempPrintInfo♢
|    |    |    |    |    [663:663] <Match> = ♢]♢
|    |    |    |    [663:663] <Semicolon> = ♢;♢
|    |    |    |    [663:664] <Newline> = ♢¶♢
|    |    |    |    [664:664] <Indenting> = ♢••••♢
|    |    |    |    [664:664] <ObjCMethodCall>
|    |    |    |    |    [664:664] <Match> = ♢[♢
|    |    |    |    |    [664:664] <Match> = ♢op♢
|    |    |    |    |    [664:664] <Whitespace> = ♢•♢
|    |    |    |    |    [664:664] <Text> = ♢setShowsPrintPanel♢
|    |    |    |    |    [664:664] <Colon> = ♢:♢
|    |    |    |    |    [664:664] <Text> = ♢YES♢
|    |    |    |    |    [664:664] <Match> = ♢]♢
|    |    |    |    [664:664] <Semicolon> = ♢;♢
|    |    |    |    [664:665] <Newline> = ♢¶♢
|    |    |    |    [665:665] <Indenting> = ♢••••♢
|    |    |    |    [665:665] <ObjCMethodCall>
|    |    |    |    |    [665:665] <Match> = ♢[♢
|    |    |    |    |    [665:665] <Match> = ♢op♢
|    |    |    |    |    [665:665] <Whitespace> = ♢•♢
|    |    |    |    |    [665:665] <Text> = ♢setShowsProgressPanel♢
|    |    |    |    |    [665:665] <Colon> = ♢:♢
|    |    |    |    |    [665:665] <Text> = ♢YES♢
|    |    |    |    |    [665:665] <Match> = ♢]♢
|    |    |    |    [665:665] <Semicolon> = ♢;♢
|    |    |    |    [665:666] <Newline> = ♢¶♢
|    |    |    |    [666:666] <Indenting> = ♢••••♢
|    |    |    |    [666:667] <Newline> = ♢¶♢
|    |    |    |    [667:667] <Indenting> = ♢••••♢
|    |    |    |    [667:667] <ObjCMethodCall>
|    |    |    |    |    [667:667] <Match> = ♢[♢
|    |    |    |    |    [667:667] <ObjCMethodCall>
|    |    |    |    |    |    [667:667] <Match> = ♢[♢
|    |    |    |    |    |    [667:667] <ObjCMethodCall>
|    |    |    |    |    |    |    [667:667] <Match> = ♢[♢
|    |    |    |    |    |    |    [667:667] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [667:667] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [667:667] <Text> = ♢windowControllers♢
|    |    |    |    |    |    |    [667:667] <Match> = ♢]♢
|    |    |    |    |    |    [667:667] <Whitespace> = ♢•♢
|    |    |    |    |    |    [667:667] <Text> = ♢objectAtIndex♢
|    |    |    |    |    |    [667:667] <Colon> = ♢:♢
|    |    |    |    |    |    [667:667] <Text> = ♢0♢
|    |    |    |    |    |    [667:667] <Match> = ♢]♢
|    |    |    |    |    [667:667] <Whitespace> = ♢•♢
|    |    |    |    |    [667:667] <Text> = ♢doForegroundLayoutToCharacterIndex♢
|    |    |    |    |    [667:667] <Colon> = ♢:♢
|    |    |    |    |    [667:667] <Text> = ♢NSIntegerMax♢
|    |    |    |    |    [667:667] <Match> = ♢]♢
|    |    |    |    [667:667] <Semicolon> = ♢;♢
|    |    |    |    [667:667] <Whitespace> = ♢→♢
|    |    |    |    [667:667] <CPPComment> = ♢//•Make•sure•the•whole•document•is•laid•out•before•printing♢
|    |    |    |    [667:668] <Newline> = ♢¶♢
|    |    |    |    [668:668] <Indenting> = ♢••••♢
|    |    |    |    [668:669] <Newline> = ♢¶♢
|    |    |    |    [669:669] <Indenting> = ♢••••♢
|    |    |    |    [669:669] <Text> = ♢NSPrintPanel♢
|    |    |    |    [669:669] <Whitespace> = ♢•♢
|    |    |    |    [669:669] <Asterisk> = ♢*♢
|    |    |    |    [669:669] <Text> = ♢printPanel♢
|    |    |    |    [669:669] <Whitespace> = ♢•♢
|    |    |    |    [669:669] <Text> = ♢=♢
|    |    |    |    [669:669] <Whitespace> = ♢•♢
|    |    |    |    [669:669] <ObjCMethodCall>
|    |    |    |    |    [669:669] <Match> = ♢[♢
|    |    |    |    |    [669:669] <Match> = ♢op♢
|    |    |    |    |    [669:669] <Whitespace> = ♢•♢
|    |    |    |    |    [669:669] <Text> = ♢printPanel♢
|    |    |    |    |    [669:669] <Match> = ♢]♢
|    |    |    |    [669:669] <Semicolon> = ♢;♢
|    |    |    |    [669:670] <Newline> = ♢¶♢
|    |    |    |    [670:670] <Indenting> = ♢••••♢
|    |    |    |    [670:670] <ObjCMethodCall>
|    |    |    |    |    [670:670] <Match> = ♢[♢
|    |    |    |    |    [670:670] <Match> = ♢printPanel♢
|    |    |    |    |    [670:670] <Whitespace> = ♢•♢
|    |    |    |    |    [670:670] <Text> = ♢addAccessoryController♢
|    |    |    |    |    [670:670] <Colon> = ♢:♢
|    |    |    |    |    [670:670] <ObjCMethodCall>
|    |    |    |    |    |    [670:670] <Match> = ♢[♢
|    |    |    |    |    |    [670:670] <ObjCMethodCall>
|    |    |    |    |    |    |    [670:670] <Match> = ♢[♢
|    |    |    |    |    |    |    [670:670] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [670:670] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [670:670] <Match> = ♢PrintPanelAccessoryController♢
|    |    |    |    |    |    |    |    [670:670] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [670:670] <Text> = ♢alloc♢
|    |    |    |    |    |    |    |    [670:670] <Match> = ♢]♢
|    |    |    |    |    |    |    [670:670] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [670:670] <Text> = ♢init♢
|    |    |    |    |    |    |    [670:670] <Match> = ♢]♢
|    |    |    |    |    |    [670:670] <Whitespace> = ♢•♢
|    |    |    |    |    |    [670:670] <Text> = ♢autorelease♢
|    |    |    |    |    |    [670:670] <Match> = ♢]♢
|    |    |    |    |    [670:670] <Match> = ♢]♢
|    |    |    |    [670:670] <Semicolon> = ♢;♢
|    |    |    |    [670:671] <Newline> = ♢¶♢
|    |    |    |    [671:671] <Indenting> = ♢••••♢
|    |    |    |    [671:671] <CPPComment> = ♢//•We•allow•changing•print•parameters•if•not•in•"Wrap•to•Page"•mode,•where•the•page•setup•settings•are•used♢
|    |    |    |    [671:672] <Newline> = ♢¶♢
|    |    |    |    [672:672] <Indenting> = ♢••••♢
|    |    |    |    [672:672] <CConditionIf>
|    |    |    |    |    [672:672] <Match> = ♢if♢
|    |    |    |    |    [672:672] <Whitespace> = ♢•♢
|    |    |    |    |    [672:672] <Parenthesis>
|    |    |    |    |    |    [672:672] <Match> = ♢(♢
|    |    |    |    |    |    [672:672] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    [672:672] <ObjCMethodCall>
|    |    |    |    |    |    |    [672:672] <Match> = ♢[♢
|    |    |    |    |    |    |    [672:672] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [672:672] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [672:672] <Text> = ♢hasMultiplePages♢
|    |    |    |    |    |    |    [672:672] <Match> = ♢]♢
|    |    |    |    |    |    [672:672] <Match> = ♢)♢
|    |    |    |    |    [672:672] <Whitespace> = ♢•♢
|    |    |    |    |    [672:672] <ObjCMethodCall>
|    |    |    |    |    |    [672:672] <Match> = ♢[♢
|    |    |    |    |    |    [672:672] <Match> = ♢printPanel♢
|    |    |    |    |    |    [672:672] <Whitespace> = ♢•♢
|    |    |    |    |    |    [672:672] <Text> = ♢setOptions♢
|    |    |    |    |    |    [672:672] <Colon> = ♢:♢
|    |    |    |    |    |    [672:672] <ObjCMethodCall>
|    |    |    |    |    |    |    [672:672] <Match> = ♢[♢
|    |    |    |    |    |    |    [672:672] <Match> = ♢printPanel♢
|    |    |    |    |    |    |    [672:672] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [672:672] <Text> = ♢options♢
|    |    |    |    |    |    |    [672:672] <Match> = ♢]♢
|    |    |    |    |    |    [672:672] <Whitespace> = ♢•♢
|    |    |    |    |    |    [672:672] <Text> = ♢|♢
|    |    |    |    |    |    [672:672] <Whitespace> = ♢•♢
|    |    |    |    |    |    [672:672] <Text> = ♢NSPrintPanelShowsPaperSize♢
|    |    |    |    |    |    [672:672] <Whitespace> = ♢•♢
|    |    |    |    |    |    [672:672] <Text> = ♢|♢
|    |    |    |    |    |    [672:672] <Whitespace> = ♢•♢
|    |    |    |    |    |    [672:672] <Text> = ♢NSPrintPanelShowsOrientation♢
|    |    |    |    |    |    [672:672] <Match> = ♢]♢
|    |    |    |    |    [672:672] <Semicolon> = ♢;♢
|    |    |    |    [672:673] <Newline> = ♢¶♢
|    |    |    |    [673:673] <Indenting> = ♢••••••••♢
|    |    |    |    [673:674] <Newline> = ♢¶♢
|    |    |    |    [674:674] <Indenting> = ♢••••♢
|    |    |    |    [674:674] <CFlowReturn>
|    |    |    |    |    [674:674] <Match> = ♢return♢
|    |    |    |    |    [674:674] <Whitespace> = ♢•♢
|    |    |    |    |    [674:674] <Text> = ♢op♢
|    |    |    |    |    [674:674] <Semicolon> = ♢;♢
|    |    |    |    [674:675] <Newline> = ♢¶♢
|    |    |    |    [675:675] <Match> = ♢}♢
|    |    [675:676] <Newline> = ♢¶♢
|    |    [676:677] <Newline> = ♢¶♢
|    |    [677:690] <ObjCMethodImplementation>
|    |    |    [677:677] <Match> = ♢-♢
|    |    |    [677:677] <Whitespace> = ♢•♢
|    |    |    [677:677] <Parenthesis>
|    |    |    |    [677:677] <Match> = ♢(♢
|    |    |    |    [677:677] <Text> = ♢NSPrintInfo♢
|    |    |    |    [677:677] <Whitespace> = ♢•♢
|    |    |    |    [677:677] <Asterisk> = ♢*♢
|    |    |    |    [677:677] <Match> = ♢)♢
|    |    |    [677:677] <Text> = ♢printInfo♢
|    |    |    [677:677] <Whitespace> = ♢•♢
|    |    |    [677:690] <Braces>
|    |    |    |    [677:677] <Match> = ♢{♢
|    |    |    |    [677:678] <Newline> = ♢¶♢
|    |    |    |    [678:678] <Indenting> = ♢••••♢
|    |    |    |    [678:678] <Text> = ♢NSPrintInfo♢
|    |    |    |    [678:678] <Whitespace> = ♢•♢
|    |    |    |    [678:678] <Asterisk> = ♢*♢
|    |    |    |    [678:678] <Text> = ♢printInfo♢
|    |    |    |    [678:678] <Whitespace> = ♢•♢
|    |    |    |    [678:678] <Text> = ♢=♢
|    |    |    |    [678:678] <Whitespace> = ♢•♢
|    |    |    |    [678:678] <ObjCMethodCall>
|    |    |    |    |    [678:678] <Match> = ♢[♢
|    |    |    |    |    [678:678] <ObjCSuper> = ♢super♢
|    |    |    |    |    [678:678] <Whitespace> = ♢•♢
|    |    |    |    |    [678:678] <Text> = ♢printInfo♢
|    |    |    |    |    [678:678] <Match> = ♢]♢
|    |    |    |    [678:678] <Semicolon> = ♢;♢
|    |    |    |    [678:679] <Newline> = ♢¶♢
|    |    |    |    [679:679] <Indenting> = ♢••••♢
|    |    |    |    [679:688] <CConditionIf>
|    |    |    |    |    [679:679] <Match> = ♢if♢
|    |    |    |    |    [679:679] <Whitespace> = ♢•♢
|    |    |    |    |    [679:679] <Parenthesis>
|    |    |    |    |    |    [679:679] <Match> = ♢(♢
|    |    |    |    |    |    [679:679] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    [679:679] <Text> = ♢setUpPrintInfoDefaults♢
|    |    |    |    |    |    [679:679] <Match> = ♢)♢
|    |    |    |    |    [679:679] <Whitespace> = ♢•♢
|    |    |    |    |    [679:688] <Braces>
|    |    |    |    |    |    [679:679] <Match> = ♢{♢
|    |    |    |    |    |    [679:680] <Newline> = ♢¶♢
|    |    |    |    |    |    [680:680] <Indenting> = ♢→♢
|    |    |    |    |    |    [680:680] <Text> = ♢setUpPrintInfoDefaults♢
|    |    |    |    |    |    [680:680] <Whitespace> = ♢•♢
|    |    |    |    |    |    [680:680] <Text> = ♢=♢
|    |    |    |    |    |    [680:680] <Whitespace> = ♢•♢
|    |    |    |    |    |    [680:680] <Text> = ♢YES♢
|    |    |    |    |    |    [680:680] <Semicolon> = ♢;♢
|    |    |    |    |    |    [680:681] <Newline> = ♢¶♢
|    |    |    |    |    |    [681:681] <Indenting> = ♢→♢
|    |    |    |    |    |    [681:681] <ObjCMethodCall>
|    |    |    |    |    |    |    [681:681] <Match> = ♢[♢
|    |    |    |    |    |    |    [681:681] <Match> = ♢printInfo♢
|    |    |    |    |    |    |    [681:681] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [681:681] <Text> = ♢setHorizontalPagination♢
|    |    |    |    |    |    |    [681:681] <Colon> = ♢:♢
|    |    |    |    |    |    |    [681:681] <Text> = ♢NSFitPagination♢
|    |    |    |    |    |    |    [681:681] <Match> = ♢]♢
|    |    |    |    |    |    [681:681] <Semicolon> = ♢;♢
|    |    |    |    |    |    [681:682] <Newline> = ♢¶♢
|    |    |    |    |    |    [682:682] <Indenting> = ♢→♢
|    |    |    |    |    |    [682:682] <ObjCMethodCall>
|    |    |    |    |    |    |    [682:682] <Match> = ♢[♢
|    |    |    |    |    |    |    [682:682] <Match> = ♢printInfo♢
|    |    |    |    |    |    |    [682:682] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [682:682] <Text> = ♢setHorizontallyCentered♢
|    |    |    |    |    |    |    [682:682] <Colon> = ♢:♢
|    |    |    |    |    |    |    [682:682] <Text> = ♢NO♢
|    |    |    |    |    |    |    [682:682] <Match> = ♢]♢
|    |    |    |    |    |    [682:682] <Semicolon> = ♢;♢
|    |    |    |    |    |    [682:683] <Newline> = ♢¶♢
|    |    |    |    |    |    [683:683] <Indenting> = ♢→♢
|    |    |    |    |    |    [683:683] <ObjCMethodCall>
|    |    |    |    |    |    |    [683:683] <Match> = ♢[♢
|    |    |    |    |    |    |    [683:683] <Match> = ♢printInfo♢
|    |    |    |    |    |    |    [683:683] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [683:683] <Text> = ♢setVerticallyCentered♢
|    |    |    |    |    |    |    [683:683] <Colon> = ♢:♢
|    |    |    |    |    |    |    [683:683] <Text> = ♢NO♢
|    |    |    |    |    |    |    [683:683] <Match> = ♢]♢
|    |    |    |    |    |    [683:683] <Semicolon> = ♢;♢
|    |    |    |    |    |    [683:684] <Newline> = ♢¶♢
|    |    |    |    |    |    [684:684] <Indenting> = ♢→♢
|    |    |    |    |    |    [684:684] <ObjCMethodCall>
|    |    |    |    |    |    |    [684:684] <Match> = ♢[♢
|    |    |    |    |    |    |    [684:684] <Match> = ♢printInfo♢
|    |    |    |    |    |    |    [684:684] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [684:684] <Text> = ♢setLeftMargin♢
|    |    |    |    |    |    |    [684:684] <Colon> = ♢:♢
|    |    |    |    |    |    |    [684:684] <Text> = ♢72.0♢
|    |    |    |    |    |    |    [684:684] <Match> = ♢]♢
|    |    |    |    |    |    [684:684] <Semicolon> = ♢;♢
|    |    |    |    |    |    [684:685] <Newline> = ♢¶♢
|    |    |    |    |    |    [685:685] <Indenting> = ♢→♢
|    |    |    |    |    |    [685:685] <ObjCMethodCall>
|    |    |    |    |    |    |    [685:685] <Match> = ♢[♢
|    |    |    |    |    |    |    [685:685] <Match> = ♢printInfo♢
|    |    |    |    |    |    |    [685:685] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [685:685] <Text> = ♢setRightMargin♢
|    |    |    |    |    |    |    [685:685] <Colon> = ♢:♢
|    |    |    |    |    |    |    [685:685] <Text> = ♢72.0♢
|    |    |    |    |    |    |    [685:685] <Match> = ♢]♢
|    |    |    |    |    |    [685:685] <Semicolon> = ♢;♢
|    |    |    |    |    |    [685:686] <Newline> = ♢¶♢
|    |    |    |    |    |    [686:686] <Indenting> = ♢→♢
|    |    |    |    |    |    [686:686] <ObjCMethodCall>
|    |    |    |    |    |    |    [686:686] <Match> = ♢[♢
|    |    |    |    |    |    |    [686:686] <Match> = ♢printInfo♢
|    |    |    |    |    |    |    [686:686] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [686:686] <Text> = ♢setTopMargin♢
|    |    |    |    |    |    |    [686:686] <Colon> = ♢:♢
|    |    |    |    |    |    |    [686:686] <Text> = ♢72.0♢
|    |    |    |    |    |    |    [686:686] <Match> = ♢]♢
|    |    |    |    |    |    [686:686] <Semicolon> = ♢;♢
|    |    |    |    |    |    [686:687] <Newline> = ♢¶♢
|    |    |    |    |    |    [687:687] <Indenting> = ♢→♢
|    |    |    |    |    |    [687:687] <ObjCMethodCall>
|    |    |    |    |    |    |    [687:687] <Match> = ♢[♢
|    |    |    |    |    |    |    [687:687] <Match> = ♢printInfo♢
|    |    |    |    |    |    |    [687:687] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [687:687] <Text> = ♢setBottomMargin♢
|    |    |    |    |    |    |    [687:687] <Colon> = ♢:♢
|    |    |    |    |    |    |    [687:687] <Text> = ♢72.0♢
|    |    |    |    |    |    |    [687:687] <Match> = ♢]♢
|    |    |    |    |    |    [687:687] <Semicolon> = ♢;♢
|    |    |    |    |    |    [687:688] <Newline> = ♢¶♢
|    |    |    |    |    |    [688:688] <Indenting> = ♢••••♢
|    |    |    |    |    |    [688:688] <Match> = ♢}♢
|    |    |    |    [688:689] <Newline> = ♢¶♢
|    |    |    |    [689:689] <Indenting> = ♢••••♢
|    |    |    |    [689:689] <CFlowReturn>
|    |    |    |    |    [689:689] <Match> = ♢return♢
|    |    |    |    |    [689:689] <Whitespace> = ♢•♢
|    |    |    |    |    [689:689] <Text> = ♢printInfo♢
|    |    |    |    |    [689:689] <Semicolon> = ♢;♢
|    |    |    |    [689:690] <Newline> = ♢¶♢
|    |    |    |    [690:690] <Match> = ♢}♢
|    |    [690:691] <Newline> = ♢¶♢
|    |    [691:692] <Newline> = ♢¶♢
|    |    [692:693] <CComment> = ♢/*•Toggles•read-only•state•of•the•document¶*/♢
|    |    [693:694] <Newline> = ♢¶♢
|    |    [694:700] <ObjCMethodImplementation>
|    |    |    [694:694] <Match> = ♢-♢
|    |    |    [694:694] <Whitespace> = ♢•♢
|    |    |    [694:694] <Parenthesis>
|    |    |    |    [694:694] <Match> = ♢(♢
|    |    |    |    [694:694] <Text> = ♢IBAction♢
|    |    |    |    [694:694] <Match> = ♢)♢
|    |    |    [694:694] <Text> = ♢toggleReadOnly♢
|    |    |    [694:694] <Colon> = ♢:♢
|    |    |    [694:694] <Parenthesis>
|    |    |    |    [694:694] <Match> = ♢(♢
|    |    |    |    [694:694] <Text> = ♢id♢
|    |    |    |    [694:694] <Match> = ♢)♢
|    |    |    [694:694] <Text> = ♢sender♢
|    |    |    [694:694] <Whitespace> = ♢•♢
|    |    |    [694:700] <Braces>
|    |    |    |    [694:694] <Match> = ♢{♢
|    |    |    |    [694:695] <Newline> = ♢¶♢
|    |    |    |    [695:695] <Indenting> = ♢••••♢
|    |    |    |    [695:695] <ObjCMethodCall>
|    |    |    |    |    [695:695] <Match> = ♢[♢
|    |    |    |    |    [695:695] <ObjCMethodCall>
|    |    |    |    |    |    [695:695] <Match> = ♢[♢
|    |    |    |    |    |    [695:695] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    [695:695] <Whitespace> = ♢•♢
|    |    |    |    |    |    [695:695] <Text> = ♢undoManager♢
|    |    |    |    |    |    [695:695] <Match> = ♢]♢
|    |    |    |    |    [695:695] <Whitespace> = ♢•♢
|    |    |    |    |    [695:695] <Text> = ♢registerUndoWithTarget♢
|    |    |    |    |    [695:695] <Colon> = ♢:♢
|    |    |    |    |    [695:695] <ObjCSelf> = ♢self♢
|    |    |    |    |    [695:695] <Whitespace> = ♢•♢
|    |    |    |    |    [695:695] <Text> = ♢selector♢
|    |    |    |    |    [695:695] <Colon> = ♢:♢
|    |    |    |    |    [695:695] <ObjCSelector>
|    |    |    |    |    |    [695:695] <Match> = ♢@selector♢
|    |    |    |    |    |    [695:695] <Parenthesis>
|    |    |    |    |    |    |    [695:695] <Match> = ♢(♢
|    |    |    |    |    |    |    [695:695] <Text> = ♢toggleReadOnly♢
|    |    |    |    |    |    |    [695:695] <Colon> = ♢:♢
|    |    |    |    |    |    |    [695:695] <Match> = ♢)♢
|    |    |    |    |    [695:695] <Whitespace> = ♢•♢
|    |    |    |    |    [695:695] <Text> = ♢object♢
|    |    |    |    |    [695:695] <Colon> = ♢:♢
|    |    |    |    |    [695:695] <ObjCNil> = ♢nil♢
|    |    |    |    |    [695:695] <Match> = ♢]♢
|    |    |    |    [695:695] <Semicolon> = ♢;♢
|    |    |    |    [695:696] <Newline> = ♢¶♢
|    |    |    |    [696:696] <Indenting> = ♢••••♢
|    |    |    |    [696:698] <ObjCMethodCall>
|    |    |    |    |    [696:696] <Match> = ♢[♢
|    |    |    |    |    [696:696] <ObjCMethodCall>
|    |    |    |    |    |    [696:696] <Match> = ♢[♢
|    |    |    |    |    |    [696:696] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    [696:696] <Whitespace> = ♢•♢
|    |    |    |    |    |    [696:696] <Text> = ♢undoManager♢
|    |    |    |    |    |    [696:696] <Match> = ♢]♢
|    |    |    |    |    [696:696] <Whitespace> = ♢•♢
|    |    |    |    |    [696:696] <Text> = ♢setActionName♢
|    |    |    |    |    [696:696] <Colon> = ♢:♢
|    |    |    |    |    [696:696] <ObjCMethodCall>
|    |    |    |    |    |    [696:696] <Match> = ♢[♢
|    |    |    |    |    |    [696:696] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    [696:696] <Whitespace> = ♢•♢
|    |    |    |    |    |    [696:696] <Text> = ♢isReadOnly♢
|    |    |    |    |    |    [696:696] <Match> = ♢]♢
|    |    |    |    |    [696:696] <Whitespace> = ♢•♢
|    |    |    |    |    [696:696] <QuestionMark> = ♢?♢
|    |    |    |    |    [696:697] <Newline> = ♢¶♢
|    |    |    |    |    [697:697] <Indenting> = ♢••••••••♢
|    |    |    |    |    [697:697] <CFunctionCall>
|    |    |    |    |    |    [697:697] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    [697:697] <Parenthesis>
|    |    |    |    |    |    |    [697:697] <Match> = ♢(♢
|    |    |    |    |    |    |    [697:697] <ObjCString> = ♢@"Allow•Editing"♢
|    |    |    |    |    |    |    [697:697] <Text> = ♢,♢
|    |    |    |    |    |    |    [697:697] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [697:697] <ObjCString> = ♢@"Menu•item•to•make•the•current•document•editable•(not•read-only)"♢
|    |    |    |    |    |    |    [697:697] <Match> = ♢)♢
|    |    |    |    |    [697:697] <Whitespace> = ♢•♢
|    |    |    |    |    [697:697] <Colon> = ♢:♢
|    |    |    |    |    [697:698] <Newline> = ♢¶♢
|    |    |    |    |    [698:698] <Indenting> = ♢••••••••♢
|    |    |    |    |    [698:698] <CFunctionCall>
|    |    |    |    |    |    [698:698] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    [698:698] <Parenthesis>
|    |    |    |    |    |    |    [698:698] <Match> = ♢(♢
|    |    |    |    |    |    |    [698:698] <ObjCString> = ♢@"Prevent•Editing"♢
|    |    |    |    |    |    |    [698:698] <Text> = ♢,♢
|    |    |    |    |    |    |    [698:698] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [698:698] <ObjCString> = ♢@"Menu•item•to•make•the•current•document•read-only"♢
|    |    |    |    |    |    |    [698:698] <Match> = ♢)♢
|    |    |    |    |    [698:698] <Match> = ♢]♢
|    |    |    |    [698:698] <Semicolon> = ♢;♢
|    |    |    |    [698:699] <Newline> = ♢¶♢
|    |    |    |    [699:699] <Indenting> = ♢••••♢
|    |    |    |    [699:699] <ObjCMethodCall>
|    |    |    |    |    [699:699] <Match> = ♢[♢
|    |    |    |    |    [699:699] <ObjCSelf> = ♢self♢
|    |    |    |    |    [699:699] <Whitespace> = ♢•♢
|    |    |    |    |    [699:699] <Text> = ♢setReadOnly♢
|    |    |    |    |    [699:699] <Colon> = ♢:♢
|    |    |    |    |    [699:699] <ExclamationMark> = ♢!♢
|    |    |    |    |    [699:699] <ObjCMethodCall>
|    |    |    |    |    |    [699:699] <Match> = ♢[♢
|    |    |    |    |    |    [699:699] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    [699:699] <Whitespace> = ♢•♢
|    |    |    |    |    |    [699:699] <Text> = ♢isReadOnly♢
|    |    |    |    |    |    [699:699] <Match> = ♢]♢
|    |    |    |    |    [699:699] <Match> = ♢]♢
|    |    |    |    [699:699] <Semicolon> = ♢;♢
|    |    |    |    [699:700] <Newline> = ♢¶♢
|    |    |    |    [700:700] <Match> = ♢}♢
|    |    [700:701] <Newline> = ♢¶♢
|    |    [701:702] <Newline> = ♢¶♢
|    |    [702:713] <ObjCMethodImplementation>
|    |    |    [702:702] <Match> = ♢-♢
|    |    |    [702:702] <Whitespace> = ♢•♢
|    |    |    [702:702] <Parenthesis>
|    |    |    |    [702:702] <Match> = ♢(♢
|    |    |    |    [702:702] <Text> = ♢BOOL♢
|    |    |    |    [702:702] <Match> = ♢)♢
|    |    |    [702:702] <Text> = ♢toggleRichWillLoseInformation♢
|    |    |    [702:702] <Whitespace> = ♢•♢
|    |    |    [702:713] <Braces>
|    |    |    |    [702:702] <Match> = ♢{♢
|    |    |    |    [702:703] <Newline> = ♢¶♢
|    |    |    |    [703:703] <Indenting> = ♢••••♢
|    |    |    |    [703:703] <Text> = ♢NSInteger♢
|    |    |    |    [703:703] <Whitespace> = ♢•♢
|    |    |    |    [703:703] <Text> = ♢length♢
|    |    |    |    [703:703] <Whitespace> = ♢•♢
|    |    |    |    [703:703] <Text> = ♢=♢
|    |    |    |    [703:703] <Whitespace> = ♢•♢
|    |    |    |    [703:703] <ObjCMethodCall>
|    |    |    |    |    [703:703] <Match> = ♢[♢
|    |    |    |    |    [703:703] <Match> = ♢textStorage♢
|    |    |    |    |    [703:703] <Whitespace> = ♢•♢
|    |    |    |    |    [703:703] <Text> = ♢length♢
|    |    |    |    |    [703:703] <Match> = ♢]♢
|    |    |    |    [703:703] <Semicolon> = ♢;♢
|    |    |    |    [703:704] <Newline> = ♢¶♢
|    |    |    |    [704:704] <Indenting> = ♢••••♢
|    |    |    |    [704:704] <Text> = ♢NSRange♢
|    |    |    |    [704:704] <Whitespace> = ♢•♢
|    |    |    |    [704:704] <Text> = ♢range♢
|    |    |    |    [704:704] <Semicolon> = ♢;♢
|    |    |    |    [704:705] <Newline> = ♢¶♢
|    |    |    |    [705:705] <Indenting> = ♢••••♢
|    |    |    |    [705:705] <Text> = ♢NSDictionary♢
|    |    |    |    [705:705] <Whitespace> = ♢•♢
|    |    |    |    [705:705] <Asterisk> = ♢*♢
|    |    |    |    [705:705] <Text> = ♢attrs♢
|    |    |    |    [705:705] <Semicolon> = ♢;♢
|    |    |    |    [705:706] <Newline> = ♢¶♢
|    |    |    |    [706:706] <Indenting> = ♢••••♢
|    |    |    |    [706:712] <CFlowReturn>
|    |    |    |    |    [706:706] <Match> = ♢return♢
|    |    |    |    |    [706:706] <Whitespace> = ♢•♢
|    |    |    |    |    [706:712] <Parenthesis>
|    |    |    |    |    |    [706:706] <Match> = ♢(♢
|    |    |    |    |    |    [706:706] <Whitespace> = ♢•♢
|    |    |    |    |    |    [706:706] <ObjCMethodCall>
|    |    |    |    |    |    |    [706:706] <Match> = ♢[♢
|    |    |    |    |    |    |    [706:706] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [706:706] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [706:706] <Text> = ♢isRichText♢
|    |    |    |    |    |    |    [706:706] <Match> = ♢]♢
|    |    |    |    |    |    [706:706] <Whitespace> = ♢•♢
|    |    |    |    |    |    [706:706] <CPPComment> = ♢//•Only•rich•->•plain•can•lose•information.♢
|    |    |    |    |    |    [706:707] <Newline> = ♢¶♢
|    |    |    |    |    |    [707:707] <Indenting> = ♢→•••••♢
|    |    |    |    |    |    [707:707] <Ampersand> = ♢&♢
|    |    |    |    |    |    [707:707] <Ampersand> = ♢&♢
|    |    |    |    |    |    [707:707] <Whitespace> = ♢•♢
|    |    |    |    |    |    [707:711] <Parenthesis>
|    |    |    |    |    |    |    [707:707] <Match> = ♢(♢
|    |    |    |    |    |    |    [707:707] <Parenthesis>
|    |    |    |    |    |    |    |    [707:707] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [707:707] <Text> = ♢length♢
|    |    |    |    |    |    |    |    [707:707] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [707:707] <Text> = ♢>♢
|    |    |    |    |    |    |    |    [707:707] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [707:707] <Text> = ♢0♢
|    |    |    |    |    |    |    |    [707:707] <Match> = ♢)♢
|    |    |    |    |    |    |    [707:707] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [707:707] <CPPComment> = ♢//•If•the•document•contains•characters•and...♢
|    |    |    |    |    |    |    [707:708] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [708:708] <Indenting> = ♢→→•♢
|    |    |    |    |    |    |    [708:708] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    [708:708] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    [708:708] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [708:708] <Parenthesis>
|    |    |    |    |    |    |    |    [708:708] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [708:708] <Text> = ♢attrs♢
|    |    |    |    |    |    |    |    [708:708] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [708:708] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [708:708] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [708:708] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [708:708] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [708:708] <Match> = ♢textStorage♢
|    |    |    |    |    |    |    |    |    [708:708] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [708:708] <Text> = ♢attributesAtIndex♢
|    |    |    |    |    |    |    |    |    [708:708] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [708:708] <Text> = ♢0♢
|    |    |    |    |    |    |    |    |    [708:708] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [708:708] <Text> = ♢effectiveRange♢
|    |    |    |    |    |    |    |    |    [708:708] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [708:708] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    [708:708] <Text> = ♢range♢
|    |    |    |    |    |    |    |    |    [708:708] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [708:708] <Match> = ♢)♢
|    |    |    |    |    |    |    [708:708] <Whitespace> = ♢••♢
|    |    |    |    |    |    |    [708:708] <CPPComment> = ♢//•...they•have•attributes...♢
|    |    |    |    |    |    |    [708:709] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [709:709] <Indenting> = ♢→→•♢
|    |    |    |    |    |    |    [709:709] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    [709:709] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    [709:709] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [709:710] <Parenthesis>
|    |    |    |    |    |    |    |    [709:709] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [709:709] <Parenthesis>
|    |    |    |    |    |    |    |    |    [709:709] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    [709:709] <Text> = ♢range.length♢
|    |    |    |    |    |    |    |    |    [709:709] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [709:709] <Text> = ♢<♢
|    |    |    |    |    |    |    |    |    [709:709] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [709:709] <Text> = ♢length♢
|    |    |    |    |    |    |    |    |    [709:709] <Match> = ♢)♢
|    |    |    |    |    |    |    |    [709:709] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [709:709] <CPPComment> = ♢//•...which•either•are•not•the•same•for•the•whole•document...♢
|    |    |    |    |    |    |    |    [709:710] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [710:710] <Indenting> = ♢→→•••••♢
|    |    |    |    |    |    |    |    [710:710] <Text> = ♢||♢
|    |    |    |    |    |    |    |    [710:710] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [710:710] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    [710:710] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [710:710] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [710:710] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [710:710] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [710:710] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    [710:710] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [710:710] <Text> = ♢defaultTextAttributes♢
|    |    |    |    |    |    |    |    |    |    [710:710] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [710:710] <Text> = ♢YES♢
|    |    |    |    |    |    |    |    |    |    [710:710] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [710:710] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [710:710] <Text> = ♢isEqual♢
|    |    |    |    |    |    |    |    |    [710:710] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [710:710] <Text> = ♢attrs♢
|    |    |    |    |    |    |    |    |    [710:710] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [710:710] <Match> = ♢)♢
|    |    |    |    |    |    |    [710:710] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [710:710] <CPPComment> = ♢//•...or•differ•from•the•default,•then...♢
|    |    |    |    |    |    |    [710:711] <Newline> = ♢¶♢
|    |    |    |    |    |    |    [711:711] <Indenting> = ♢→→•♢
|    |    |    |    |    |    |    [711:711] <Match> = ♢)♢
|    |    |    |    |    |    [711:711] <Whitespace> = ♢•♢
|    |    |    |    |    |    [711:711] <CPPComment> = ♢//•...we•will•lose•styling•information.♢
|    |    |    |    |    |    [711:712] <Newline> = ♢¶♢
|    |    |    |    |    |    [712:712] <Indenting> = ♢→•••••♢
|    |    |    |    |    |    [712:712] <Text> = ♢||♢
|    |    |    |    |    |    [712:712] <Whitespace> = ♢•♢
|    |    |    |    |    |    [712:712] <ObjCMethodCall>
|    |    |    |    |    |    |    [712:712] <Match> = ♢[♢
|    |    |    |    |    |    |    [712:712] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [712:712] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [712:712] <Text> = ♢hasDocumentProperties♢
|    |    |    |    |    |    |    [712:712] <Match> = ♢]♢
|    |    |    |    |    |    [712:712] <Match> = ♢)♢
|    |    |    |    |    [712:712] <Semicolon> = ♢;♢
|    |    |    |    [712:712] <Whitespace> = ♢•♢
|    |    |    |    [712:712] <CPPComment> = ♢//•We•will•also•lose•information•if•the•document•has•properties.♢
|    |    |    |    [712:713] <Newline> = ♢¶♢
|    |    |    |    [713:713] <Match> = ♢}♢
|    |    [713:714] <Newline> = ♢¶♢
|    |    [714:715] <Newline> = ♢¶♢
|    |    [715:717] <ObjCMethodImplementation>
|    |    |    [715:715] <Match> = ♢-♢
|    |    |    [715:715] <Whitespace> = ♢•♢
|    |    |    [715:715] <Parenthesis>
|    |    |    |    [715:715] <Match> = ♢(♢
|    |    |    |    [715:715] <Text> = ♢BOOL♢
|    |    |    |    [715:715] <Match> = ♢)♢
|    |    |    [715:715] <Text> = ♢hasMultiplePages♢
|    |    |    [715:715] <Whitespace> = ♢•♢
|    |    |    [715:717] <Braces>
|    |    |    |    [715:715] <Match> = ♢{♢
|    |    |    |    [715:716] <Newline> = ♢¶♢
|    |    |    |    [716:716] <Indenting> = ♢••••♢
|    |    |    |    [716:716] <CFlowReturn>
|    |    |    |    |    [716:716] <Match> = ♢return♢
|    |    |    |    |    [716:716] <Whitespace> = ♢•♢
|    |    |    |    |    [716:716] <Text> = ♢hasMultiplePages♢
|    |    |    |    |    [716:716] <Semicolon> = ♢;♢
|    |    |    |    [716:717] <Newline> = ♢¶♢
|    |    |    |    [717:717] <Match> = ♢}♢
|    |    [717:718] <Newline> = ♢¶♢
|    |    [718:719] <Newline> = ♢¶♢
|    |    [719:721] <ObjCMethodImplementation>
|    |    |    [719:719] <Match> = ♢-♢
|    |    |    [719:719] <Whitespace> = ♢•♢
|    |    |    [719:719] <Parenthesis>
|    |    |    |    [719:719] <Match> = ♢(♢
|    |    |    |    [719:719] <CVoid> = ♢void♢
|    |    |    |    [719:719] <Match> = ♢)♢
|    |    |    [719:719] <Text> = ♢setHasMultiplePages♢
|    |    |    [719:719] <Colon> = ♢:♢
|    |    |    [719:719] <Parenthesis>
|    |    |    |    [719:719] <Match> = ♢(♢
|    |    |    |    [719:719] <Text> = ♢BOOL♢
|    |    |    |    [719:719] <Match> = ♢)♢
|    |    |    [719:719] <Text> = ♢flag♢
|    |    |    [719:719] <Whitespace> = ♢•♢
|    |    |    [719:721] <Braces>
|    |    |    |    [719:719] <Match> = ♢{♢
|    |    |    |    [719:720] <Newline> = ♢¶♢
|    |    |    |    [720:720] <Indenting> = ♢••••♢
|    |    |    |    [720:720] <Text> = ♢hasMultiplePages♢
|    |    |    |    [720:720] <Whitespace> = ♢•♢
|    |    |    |    [720:720] <Text> = ♢=♢
|    |    |    |    [720:720] <Whitespace> = ♢•♢
|    |    |    |    [720:720] <Text> = ♢flag♢
|    |    |    |    [720:720] <Semicolon> = ♢;♢
|    |    |    |    [720:721] <Newline> = ♢¶♢
|    |    |    |    [721:721] <Match> = ♢}♢
|    |    [721:722] <Newline> = ♢¶♢
|    |    [722:723] <Newline> = ♢¶♢
|    |    [723:725] <ObjCMethodImplementation>
|    |    |    [723:723] <Match> = ♢-♢
|    |    |    [723:723] <Whitespace> = ♢•♢
|    |    |    [723:723] <Parenthesis>
|    |    |    |    [723:723] <Match> = ♢(♢
|    |    |    |    [723:723] <Text> = ♢IBAction♢
|    |    |    |    [723:723] <Match> = ♢)♢
|    |    |    [723:723] <Text> = ♢togglePageBreaks♢
|    |    |    [723:723] <Colon> = ♢:♢
|    |    |    [723:723] <Parenthesis>
|    |    |    |    [723:723] <Match> = ♢(♢
|    |    |    |    [723:723] <Text> = ♢id♢
|    |    |    |    [723:723] <Match> = ♢)♢
|    |    |    [723:723] <Text> = ♢sender♢
|    |    |    [723:723] <Whitespace> = ♢•♢
|    |    |    [723:725] <Braces>
|    |    |    |    [723:723] <Match> = ♢{♢
|    |    |    |    [723:724] <Newline> = ♢¶♢
|    |    |    |    [724:724] <Indenting> = ♢••••♢
|    |    |    |    [724:724] <ObjCMethodCall>
|    |    |    |    |    [724:724] <Match> = ♢[♢
|    |    |    |    |    [724:724] <ObjCSelf> = ♢self♢
|    |    |    |    |    [724:724] <Whitespace> = ♢•♢
|    |    |    |    |    [724:724] <Text> = ♢setHasMultiplePages♢
|    |    |    |    |    [724:724] <Colon> = ♢:♢
|    |    |    |    |    [724:724] <ExclamationMark> = ♢!♢
|    |    |    |    |    [724:724] <ObjCMethodCall>
|    |    |    |    |    |    [724:724] <Match> = ♢[♢
|    |    |    |    |    |    [724:724] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    [724:724] <Whitespace> = ♢•♢
|    |    |    |    |    |    [724:724] <Text> = ♢hasMultiplePages♢
|    |    |    |    |    |    [724:724] <Match> = ♢]♢
|    |    |    |    |    [724:724] <Match> = ♢]♢
|    |    |    |    [724:724] <Semicolon> = ♢;♢
|    |    |    |    [724:725] <Newline> = ♢¶♢
|    |    |    |    [725:725] <Match> = ♢}♢
|    |    [725:726] <Newline> = ♢¶♢
|    |    [726:727] <Newline> = ♢¶♢
|    |    [727:731] <ObjCMethodImplementation>
|    |    |    [727:727] <Match> = ♢-♢
|    |    |    [727:727] <Whitespace> = ♢•♢
|    |    |    [727:727] <Parenthesis>
|    |    |    |    [727:727] <Match> = ♢(♢
|    |    |    |    [727:727] <CVoid> = ♢void♢
|    |    |    |    [727:727] <Match> = ♢)♢
|    |    |    [727:727] <Text> = ♢toggleHyphenation♢
|    |    |    [727:727] <Colon> = ♢:♢
|    |    |    [727:727] <Parenthesis>
|    |    |    |    [727:727] <Match> = ♢(♢
|    |    |    |    [727:727] <Text> = ♢id♢
|    |    |    |    [727:727] <Match> = ♢)♢
|    |    |    [727:727] <Text> = ♢sender♢
|    |    |    [727:727] <Whitespace> = ♢•♢
|    |    |    [727:731] <Braces>
|    |    |    |    [727:727] <Match> = ♢{♢
|    |    |    |    [727:728] <Newline> = ♢¶♢
|    |    |    |    [728:728] <Indenting> = ♢••••♢
|    |    |    |    [728:728] <CFloat> = ♢float♢
|    |    |    |    [728:728] <Whitespace> = ♢•♢
|    |    |    |    [728:728] <Text> = ♢currentHyphenation♢
|    |    |    |    [728:728] <Whitespace> = ♢•♢
|    |    |    |    [728:728] <Text> = ♢=♢
|    |    |    |    [728:728] <Whitespace> = ♢•♢
|    |    |    |    [728:728] <ObjCMethodCall>
|    |    |    |    |    [728:728] <Match> = ♢[♢
|    |    |    |    |    [728:728] <ObjCSelf> = ♢self♢
|    |    |    |    |    [728:728] <Whitespace> = ♢•♢
|    |    |    |    |    [728:728] <Text> = ♢hyphenationFactor♢
|    |    |    |    |    [728:728] <Match> = ♢]♢
|    |    |    |    [728:728] <Semicolon> = ♢;♢
|    |    |    |    [728:729] <Newline> = ♢¶♢
|    |    |    |    [729:729] <Indenting> = ♢••••♢
|    |    |    |    [729:729] <ObjCMethodCall>
|    |    |    |    |    [729:729] <Match> = ♢[♢
|    |    |    |    |    [729:729] <ObjCMethodCall>
|    |    |    |    |    |    [729:729] <Match> = ♢[♢
|    |    |    |    |    |    [729:729] <ObjCMethodCall>
|    |    |    |    |    |    |    [729:729] <Match> = ♢[♢
|    |    |    |    |    |    |    [729:729] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [729:729] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [729:729] <Text> = ♢undoManager♢
|    |    |    |    |    |    |    [729:729] <Match> = ♢]♢
|    |    |    |    |    |    [729:729] <Whitespace> = ♢•♢
|    |    |    |    |    |    [729:729] <Text> = ♢prepareWithInvocationTarget♢
|    |    |    |    |    |    [729:729] <Colon> = ♢:♢
|    |    |    |    |    |    [729:729] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    [729:729] <Match> = ♢]♢
|    |    |    |    |    [729:729] <Whitespace> = ♢•♢
|    |    |    |    |    [729:729] <Text> = ♢setHyphenationFactor♢
|    |    |    |    |    [729:729] <Colon> = ♢:♢
|    |    |    |    |    [729:729] <Text> = ♢currentHyphenation♢
|    |    |    |    |    [729:729] <Match> = ♢]♢
|    |    |    |    [729:729] <Semicolon> = ♢;♢
|    |    |    |    [729:730] <Newline> = ♢¶♢
|    |    |    |    [730:730] <Indenting> = ♢••••♢
|    |    |    |    [730:730] <ObjCMethodCall>
|    |    |    |    |    [730:730] <Match> = ♢[♢
|    |    |    |    |    [730:730] <ObjCSelf> = ♢self♢
|    |    |    |    |    [730:730] <Whitespace> = ♢•♢
|    |    |    |    |    [730:730] <Text> = ♢setHyphenationFactor♢
|    |    |    |    |    [730:730] <Colon> = ♢:♢
|    |    |    |    |    [730:730] <CConditionalOperator>
|    |    |    |    |    |    [730:730] <Parenthesis>
|    |    |    |    |    |    |    [730:730] <Match> = ♢(♢
|    |    |    |    |    |    |    [730:730] <Text> = ♢currentHyphenation♢
|    |    |    |    |    |    |    [730:730] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [730:730] <Text> = ♢>♢
|    |    |    |    |    |    |    [730:730] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [730:730] <Text> = ♢0.0♢
|    |    |    |    |    |    |    [730:730] <Match> = ♢)♢
|    |    |    |    |    |    [730:730] <Whitespace> = ♢•♢
|    |    |    |    |    |    [730:730] <QuestionMark> = ♢?♢
|    |    |    |    |    |    [730:730] <Whitespace> = ♢•♢
|    |    |    |    |    |    [730:730] <Text> = ♢0.0♢
|    |    |    |    |    |    [730:730] <Whitespace> = ♢•♢
|    |    |    |    |    |    [730:730] <Colon> = ♢:♢
|    |    |    |    |    |    [730:730] <Whitespace> = ♢•♢
|    |    |    |    |    |    [730:730] <Text> = ♢0.9♢
|    |    |    |    |    [730:730] <Match> = ♢]♢
|    |    |    |    [730:730] <Semicolon> = ♢;♢
|    |    |    |    [730:730] <Whitespace> = ♢→♢
|    |    |    |    [730:730] <CComment> = ♢/*•Toggle•between•0.0•and•0.9•*/♢
|    |    |    |    [730:731] <Newline> = ♢¶♢
|    |    |    |    [731:731] <Match> = ♢}♢
|    |    [731:732] <Newline> = ♢¶♢
|    |    [732:733] <Newline> = ♢¶♢
|    |    [733:734] <CComment> = ♢/*•Action•method•for•the•"Append•'.txt'•extension"•button¶*/♢
|    |    [734:735] <Newline> = ♢¶♢
|    |    [735:739] <ObjCMethodImplementation>
|    |    |    [735:735] <Match> = ♢-♢
|    |    |    [735:735] <Whitespace> = ♢•♢
|    |    |    [735:735] <Parenthesis>
|    |    |    |    [735:735] <Match> = ♢(♢
|    |    |    |    [735:735] <CVoid> = ♢void♢
|    |    |    |    [735:735] <Match> = ♢)♢
|    |    |    [735:735] <Text> = ♢appendPlainTextExtensionChanged♢
|    |    |    [735:735] <Colon> = ♢:♢
|    |    |    [735:735] <Parenthesis>
|    |    |    |    [735:735] <Match> = ♢(♢
|    |    |    |    [735:735] <Text> = ♢id♢
|    |    |    |    [735:735] <Match> = ♢)♢
|    |    |    [735:735] <Text> = ♢sender♢
|    |    |    [735:735] <Whitespace> = ♢•♢
|    |    |    [735:739] <Braces>
|    |    |    |    [735:735] <Match> = ♢{♢
|    |    |    |    [735:736] <Newline> = ♢¶♢
|    |    |    |    [736:736] <Indenting> = ♢••••♢
|    |    |    |    [736:736] <Text> = ♢NSSavePanel♢
|    |    |    |    [736:736] <Whitespace> = ♢•♢
|    |    |    |    [736:736] <Asterisk> = ♢*♢
|    |    |    |    [736:736] <Text> = ♢panel♢
|    |    |    |    [736:736] <Whitespace> = ♢•♢
|    |    |    |    [736:736] <Text> = ♢=♢
|    |    |    |    [736:736] <Whitespace> = ♢•♢
|    |    |    |    [736:736] <Parenthesis>
|    |    |    |    |    [736:736] <Match> = ♢(♢
|    |    |    |    |    [736:736] <Text> = ♢NSSavePanel♢
|    |    |    |    |    [736:736] <Whitespace> = ♢•♢
|    |    |    |    |    [736:736] <Asterisk> = ♢*♢
|    |    |    |    |    [736:736] <Match> = ♢)♢
|    |    |    |    [736:736] <ObjCMethodCall>
|    |    |    |    |    [736:736] <Match> = ♢[♢
|    |    |    |    |    [736:736] <Match> = ♢sender♢
|    |    |    |    |    [736:736] <Whitespace> = ♢•♢
|    |    |    |    |    [736:736] <Text> = ♢window♢
|    |    |    |    |    [736:736] <Match> = ♢]♢
|    |    |    |    [736:736] <Semicolon> = ♢;♢
|    |    |    |    [736:737] <Newline> = ♢¶♢
|    |    |    |    [737:737] <Indenting> = ♢••••♢
|    |    |    |    [737:737] <ObjCMethodCall>
|    |    |    |    |    [737:737] <Match> = ♢[♢
|    |    |    |    |    [737:737] <Match> = ♢panel♢
|    |    |    |    |    [737:737] <Whitespace> = ♢•♢
|    |    |    |    |    [737:737] <Text> = ♢setAllowsOtherFileTypes♢
|    |    |    |    |    [737:737] <Colon> = ♢:♢
|    |    |    |    |    [737:737] <ObjCMethodCall>
|    |    |    |    |    |    [737:737] <Match> = ♢[♢
|    |    |    |    |    |    [737:737] <Match> = ♢sender♢
|    |    |    |    |    |    [737:737] <Whitespace> = ♢•♢
|    |    |    |    |    |    [737:737] <Text> = ♢state♢
|    |    |    |    |    |    [737:737] <Match> = ♢]♢
|    |    |    |    |    [737:737] <Match> = ♢]♢
|    |    |    |    [737:737] <Semicolon> = ♢;♢
|    |    |    |    [737:738] <Newline> = ♢¶♢
|    |    |    |    [738:738] <Indenting> = ♢••••♢
|    |    |    |    [738:738] <ObjCMethodCall>
|    |    |    |    |    [738:738] <Match> = ♢[♢
|    |    |    |    |    [738:738] <Match> = ♢panel♢
|    |    |    |    |    [738:738] <Whitespace> = ♢•♢
|    |    |    |    |    [738:738] <Text> = ♢setAllowedFileTypes♢
|    |    |    |    |    [738:738] <Colon> = ♢:♢
|    |    |    |    |    [738:738] <ObjCMethodCall>
|    |    |    |    |    |    [738:738] <Match> = ♢[♢
|    |    |    |    |    |    [738:738] <Match> = ♢sender♢
|    |    |    |    |    |    [738:738] <Whitespace> = ♢•♢
|    |    |    |    |    |    [738:738] <Text> = ♢state♢
|    |    |    |    |    |    [738:738] <Match> = ♢]♢
|    |    |    |    |    [738:738] <Whitespace> = ♢•♢
|    |    |    |    |    [738:738] <QuestionMark> = ♢?♢
|    |    |    |    |    [738:738] <Whitespace> = ♢•♢
|    |    |    |    |    [738:738] <ObjCMethodCall>
|    |    |    |    |    |    [738:738] <Match> = ♢[♢
|    |    |    |    |    |    [738:738] <Match> = ♢NSArray♢
|    |    |    |    |    |    [738:738] <Whitespace> = ♢•♢
|    |    |    |    |    |    [738:738] <Text> = ♢arrayWithObject♢
|    |    |    |    |    |    [738:738] <Colon> = ♢:♢
|    |    |    |    |    |    [738:738] <Parenthesis>
|    |    |    |    |    |    |    [738:738] <Match> = ♢(♢
|    |    |    |    |    |    |    [738:738] <Text> = ♢NSString♢
|    |    |    |    |    |    |    [738:738] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [738:738] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    [738:738] <Match> = ♢)♢
|    |    |    |    |    |    [738:738] <Text> = ♢kUTTypePlainText♢
|    |    |    |    |    |    [738:738] <Match> = ♢]♢
|    |    |    |    |    [738:738] <Whitespace> = ♢•♢
|    |    |    |    |    [738:738] <Colon> = ♢:♢
|    |    |    |    |    [738:738] <Whitespace> = ♢•♢
|    |    |    |    |    [738:738] <ObjCNil> = ♢nil♢
|    |    |    |    |    [738:738] <Match> = ♢]♢
|    |    |    |    [738:738] <Semicolon> = ♢;♢
|    |    |    |    [738:739] <Newline> = ♢¶♢
|    |    |    |    [739:739] <Match> = ♢}♢
|    |    [739:740] <Newline> = ♢¶♢
|    |    [740:741] <Newline> = ♢¶♢
|    |    [741:743] <ObjCMethodImplementation>
|    |    |    [741:741] <Match> = ♢-♢
|    |    |    [741:741] <Whitespace> = ♢•♢
|    |    |    [741:741] <Parenthesis>
|    |    |    |    [741:741] <Match> = ♢(♢
|    |    |    |    [741:741] <CVoid> = ♢void♢
|    |    |    |    [741:741] <Match> = ♢)♢
|    |    |    [741:741] <Text> = ♢encodingPopupChanged♢
|    |    |    [741:741] <Colon> = ♢:♢
|    |    |    [741:741] <Parenthesis>
|    |    |    |    [741:741] <Match> = ♢(♢
|    |    |    |    [741:741] <Text> = ♢NSPopUpButton♢
|    |    |    |    [741:741] <Whitespace> = ♢•♢
|    |    |    |    [741:741] <Asterisk> = ♢*♢
|    |    |    |    [741:741] <Match> = ♢)♢
|    |    |    [741:741] <Text> = ♢popup♢
|    |    |    [741:741] <Whitespace> = ♢•♢
|    |    |    [741:743] <Braces>
|    |    |    |    [741:741] <Match> = ♢{♢
|    |    |    |    [741:742] <Newline> = ♢¶♢
|    |    |    |    [742:742] <Indenting> = ♢••••♢
|    |    |    |    [742:742] <ObjCMethodCall>
|    |    |    |    |    [742:742] <Match> = ♢[♢
|    |    |    |    |    [742:742] <ObjCSelf> = ♢self♢
|    |    |    |    |    [742:742] <Whitespace> = ♢•♢
|    |    |    |    |    [742:742] <Text> = ♢setEncodingForSaving♢
|    |    |    |    |    [742:742] <Colon> = ♢:♢
|    |    |    |    |    [742:742] <ObjCMethodCall>
|    |    |    |    |    |    [742:742] <Match> = ♢[♢
|    |    |    |    |    |    [742:742] <ObjCMethodCall>
|    |    |    |    |    |    |    [742:742] <Match> = ♢[♢
|    |    |    |    |    |    |    [742:742] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [742:742] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [742:742] <Match> = ♢popup♢
|    |    |    |    |    |    |    |    [742:742] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [742:742] <Text> = ♢selectedItem♢
|    |    |    |    |    |    |    |    [742:742] <Match> = ♢]♢
|    |    |    |    |    |    |    [742:742] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [742:742] <Text> = ♢representedObject♢
|    |    |    |    |    |    |    [742:742] <Match> = ♢]♢
|    |    |    |    |    |    [742:742] <Whitespace> = ♢•♢
|    |    |    |    |    |    [742:742] <Text> = ♢unsignedIntegerValue♢
|    |    |    |    |    |    [742:742] <Match> = ♢]♢
|    |    |    |    |    [742:742] <Match> = ♢]♢
|    |    |    |    [742:742] <Semicolon> = ♢;♢
|    |    |    |    [742:743] <Newline> = ♢¶♢
|    |    |    |    [743:743] <Match> = ♢}♢
|    |    [743:744] <Newline> = ♢¶♢
|    |    [744:745] <Newline> = ♢¶♢
|    |    [745:745] <CComment> = ♢/*•Menu•validation:•Arbitrary•numbers•to•determine•the•state•of•the•menu•items•whose•titles•change.•Speeds•up•the•validation...•Not•zero.•*/♢
|    |    [745:745] <Whitespace> = ♢•••♢
|    |    [745:746] <Newline> = ♢¶♢
|    |    [746:746] <CPreprocessorDefine>
|    |    |    [746:746] <Match> = ♢#define♢
|    |    |    [746:746] <Whitespace> = ♢•♢
|    |    |    [746:746] <Text> = ♢TagForFirst♢
|    |    |    [746:746] <Whitespace> = ♢•♢
|    |    |    [746:746] <Text> = ♢42♢
|    |    [746:747] <Newline> = ♢¶♢
|    |    [747:747] <CPreprocessorDefine>
|    |    |    [747:747] <Match> = ♢#define♢
|    |    |    [747:747] <Whitespace> = ♢•♢
|    |    |    [747:747] <Text> = ♢TagForSecond♢
|    |    |    [747:747] <Whitespace> = ♢•♢
|    |    |    [747:747] <Text> = ♢43♢
|    |    [747:748] <Newline> = ♢¶♢
|    |    [748:749] <Newline> = ♢¶♢
|    |    [749:761] <CFunctionDefinition>
|    |    |    [749:749] <CVoid> = ♢void♢
|    |    |    [749:749] <Whitespace> = ♢•♢
|    |    |    [749:749] <Match> = ♢validateToggleItem♢
|    |    |    [749:749] <Parenthesis>
|    |    |    |    [749:749] <Match> = ♢(♢
|    |    |    |    [749:749] <Text> = ♢NSMenuItem♢
|    |    |    |    [749:749] <Whitespace> = ♢•♢
|    |    |    |    [749:749] <Asterisk> = ♢*♢
|    |    |    |    [749:749] <Text> = ♢aCell,♢
|    |    |    |    [749:749] <Whitespace> = ♢•♢
|    |    |    |    [749:749] <Text> = ♢BOOL♢
|    |    |    |    [749:749] <Whitespace> = ♢•♢
|    |    |    |    [749:749] <Text> = ♢useFirst,♢
|    |    |    |    [749:749] <Whitespace> = ♢•♢
|    |    |    |    [749:749] <Text> = ♢NSString♢
|    |    |    |    [749:749] <Whitespace> = ♢•♢
|    |    |    |    [749:749] <Asterisk> = ♢*♢
|    |    |    |    [749:749] <Text> = ♢first,♢
|    |    |    |    [749:749] <Whitespace> = ♢•♢
|    |    |    |    [749:749] <Text> = ♢NSString♢
|    |    |    |    [749:749] <Whitespace> = ♢•♢
|    |    |    |    [749:749] <Asterisk> = ♢*♢
|    |    |    |    [749:749] <Text> = ♢second♢
|    |    |    |    [749:749] <Match> = ♢)♢
|    |    |    [749:749] <Whitespace> = ♢•♢
|    |    |    [749:761] <Braces>
|    |    |    |    [749:749] <Match> = ♢{♢
|    |    |    |    [749:750] <Newline> = ♢¶♢
|    |    |    |    [750:750] <Indenting> = ♢••••♢
|    |    |    |    [750:755] <CConditionIf>
|    |    |    |    |    [750:750] <Match> = ♢if♢
|    |    |    |    |    [750:750] <Whitespace> = ♢•♢
|    |    |    |    |    [750:750] <Parenthesis>
|    |    |    |    |    |    [750:750] <Match> = ♢(♢
|    |    |    |    |    |    [750:750] <Text> = ♢useFirst♢
|    |    |    |    |    |    [750:750] <Match> = ♢)♢
|    |    |    |    |    [750:750] <Whitespace> = ♢•♢
|    |    |    |    |    [750:755] <Braces>
|    |    |    |    |    |    [750:750] <Match> = ♢{♢
|    |    |    |    |    |    [750:751] <Newline> = ♢¶♢
|    |    |    |    |    |    [751:751] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [751:754] <CConditionIf>
|    |    |    |    |    |    |    [751:751] <Match> = ♢if♢
|    |    |    |    |    |    |    [751:751] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [751:751] <Parenthesis>
|    |    |    |    |    |    |    |    [751:751] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [751:751] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [751:751] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [751:751] <Match> = ♢aCell♢
|    |    |    |    |    |    |    |    |    [751:751] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [751:751] <Text> = ♢tag♢
|    |    |    |    |    |    |    |    |    [751:751] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [751:751] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [751:751] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    [751:751] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [751:751] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [751:751] <Text> = ♢TagForFirst♢
|    |    |    |    |    |    |    |    [751:751] <Match> = ♢)♢
|    |    |    |    |    |    |    [751:751] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [751:754] <Braces>
|    |    |    |    |    |    |    |    [751:751] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [751:752] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [752:752] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [752:752] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [752:752] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [752:752] <Match> = ♢aCell♢
|    |    |    |    |    |    |    |    |    [752:752] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [752:752] <Text> = ♢setTitleWithMnemonic♢
|    |    |    |    |    |    |    |    |    [752:752] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [752:752] <Text> = ♢first♢
|    |    |    |    |    |    |    |    |    [752:752] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [752:752] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [752:753] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [753:753] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [753:753] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [753:753] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [753:753] <Match> = ♢aCell♢
|    |    |    |    |    |    |    |    |    [753:753] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [753:753] <Text> = ♢setTag♢
|    |    |    |    |    |    |    |    |    [753:753] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [753:753] <Text> = ♢TagForFirst♢
|    |    |    |    |    |    |    |    |    [753:753] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [753:753] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [753:754] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [754:754] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    |    |    [754:754] <Match> = ♢}♢
|    |    |    |    |    |    [754:755] <Newline> = ♢¶♢
|    |    |    |    |    |    [755:755] <Indenting> = ♢••••♢
|    |    |    |    |    |    [755:755] <Match> = ♢}♢
|    |    |    |    [755:755] <Whitespace> = ♢•♢
|    |    |    |    [755:760] <CConditionElse>
|    |    |    |    |    [755:755] <Match> = ♢else♢
|    |    |    |    |    [755:755] <Whitespace> = ♢•♢
|    |    |    |    |    [755:760] <Braces>
|    |    |    |    |    |    [755:755] <Match> = ♢{♢
|    |    |    |    |    |    [755:756] <Newline> = ♢¶♢
|    |    |    |    |    |    [756:756] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [756:759] <CConditionIf>
|    |    |    |    |    |    |    [756:756] <Match> = ♢if♢
|    |    |    |    |    |    |    [756:756] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [756:756] <Parenthesis>
|    |    |    |    |    |    |    |    [756:756] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [756:756] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [756:756] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [756:756] <Match> = ♢aCell♢
|    |    |    |    |    |    |    |    |    [756:756] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [756:756] <Text> = ♢tag♢
|    |    |    |    |    |    |    |    |    [756:756] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [756:756] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [756:756] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    [756:756] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [756:756] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [756:756] <Text> = ♢TagForSecond♢
|    |    |    |    |    |    |    |    [756:756] <Match> = ♢)♢
|    |    |    |    |    |    |    [756:756] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [756:759] <Braces>
|    |    |    |    |    |    |    |    [756:756] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [756:757] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [757:757] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [757:757] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [757:757] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [757:757] <Match> = ♢aCell♢
|    |    |    |    |    |    |    |    |    [757:757] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [757:757] <Text> = ♢setTitleWithMnemonic♢
|    |    |    |    |    |    |    |    |    [757:757] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [757:757] <Text> = ♢second♢
|    |    |    |    |    |    |    |    |    [757:757] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [757:757] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [757:758] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [758:758] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [758:758] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [758:758] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [758:758] <Match> = ♢aCell♢
|    |    |    |    |    |    |    |    |    [758:758] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [758:758] <Text> = ♢setTag♢
|    |    |    |    |    |    |    |    |    [758:758] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [758:758] <Text> = ♢TagForSecond♢
|    |    |    |    |    |    |    |    |    [758:758] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [758:758] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [758:759] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [759:759] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    |    |    [759:759] <Match> = ♢}♢
|    |    |    |    |    |    [759:760] <Newline> = ♢¶♢
|    |    |    |    |    |    [760:760] <Indenting> = ♢••••♢
|    |    |    |    |    |    [760:760] <Match> = ♢}♢
|    |    |    |    [760:761] <Newline> = ♢¶♢
|    |    |    |    [761:761] <Match> = ♢}♢
|    |    [761:762] <Newline> = ♢¶♢
|    |    [762:763] <Newline> = ♢¶♢
|    |    [763:764] <CComment> = ♢/*•Menu•validation¶*/♢
|    |    [764:765] <Newline> = ♢¶♢
|    |    [765:778] <ObjCMethodImplementation>
|    |    |    [765:765] <Match> = ♢-♢
|    |    |    [765:765] <Whitespace> = ♢•♢
|    |    |    [765:765] <Parenthesis>
|    |    |    |    [765:765] <Match> = ♢(♢
|    |    |    |    [765:765] <Text> = ♢BOOL♢
|    |    |    |    [765:765] <Match> = ♢)♢
|    |    |    [765:765] <Text> = ♢validateMenuItem♢
|    |    |    [765:765] <Colon> = ♢:♢
|    |    |    [765:765] <Parenthesis>
|    |    |    |    [765:765] <Match> = ♢(♢
|    |    |    |    [765:765] <Text> = ♢NSMenuItem♢
|    |    |    |    [765:765] <Whitespace> = ♢•♢
|    |    |    |    [765:765] <Asterisk> = ♢*♢
|    |    |    |    [765:765] <Match> = ♢)♢
|    |    |    [765:765] <Text> = ♢aCell♢
|    |    |    [765:765] <Whitespace> = ♢•♢
|    |    |    [765:778] <Braces>
|    |    |    |    [765:765] <Match> = ♢{♢
|    |    |    |    [765:766] <Newline> = ♢¶♢
|    |    |    |    [766:766] <Indenting> = ♢••••♢
|    |    |    |    [766:766] <Text> = ♢SEL♢
|    |    |    |    [766:766] <Whitespace> = ♢•♢
|    |    |    |    [766:766] <Text> = ♢action♢
|    |    |    |    [766:766] <Whitespace> = ♢•♢
|    |    |    |    [766:766] <Text> = ♢=♢
|    |    |    |    [766:766] <Whitespace> = ♢•♢
|    |    |    |    [766:766] <ObjCMethodCall>
|    |    |    |    |    [766:766] <Match> = ♢[♢
|    |    |    |    |    [766:766] <Match> = ♢aCell♢
|    |    |    |    |    [766:766] <Whitespace> = ♢•♢
|    |    |    |    |    [766:766] <Text> = ♢action♢
|    |    |    |    |    [766:766] <Match> = ♢]♢
|    |    |    |    [766:766] <Semicolon> = ♢;♢
|    |    |    |    [766:767] <Newline> = ♢¶♢
|    |    |    |    [767:767] <Indenting> = ♢••••♢
|    |    |    |    [767:768] <Newline> = ♢¶♢
|    |    |    |    [768:768] <Indenting> = ♢••••♢
|    |    |    |    [768:770] <CConditionIf>
|    |    |    |    |    [768:768] <Match> = ♢if♢
|    |    |    |    |    [768:768] <Whitespace> = ♢•♢
|    |    |    |    |    [768:768] <Parenthesis>
|    |    |    |    |    |    [768:768] <Match> = ♢(♢
|    |    |    |    |    |    [768:768] <Text> = ♢action♢
|    |    |    |    |    |    [768:768] <Whitespace> = ♢•♢
|    |    |    |    |    |    [768:768] <Text> = ♢==♢
|    |    |    |    |    |    [768:768] <Whitespace> = ♢•♢
|    |    |    |    |    |    [768:768] <ObjCSelector>
|    |    |    |    |    |    |    [768:768] <Match> = ♢@selector♢
|    |    |    |    |    |    |    [768:768] <Parenthesis>
|    |    |    |    |    |    |    |    [768:768] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [768:768] <Text> = ♢toggleReadOnly♢
|    |    |    |    |    |    |    |    [768:768] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [768:768] <Match> = ♢)♢
|    |    |    |    |    |    [768:768] <Match> = ♢)♢
|    |    |    |    |    [768:768] <Whitespace> = ♢•♢
|    |    |    |    |    [768:770] <Braces>
|    |    |    |    |    |    [768:768] <Match> = ♢{♢
|    |    |    |    |    |    [768:769] <Newline> = ♢¶♢
|    |    |    |    |    |    [769:769] <Indenting> = ♢→♢
|    |    |    |    |    |    [769:769] <CFunctionCall>
|    |    |    |    |    |    |    [769:769] <Match> = ♢validateToggleItem♢
|    |    |    |    |    |    |    [769:769] <Parenthesis>
|    |    |    |    |    |    |    |    [769:769] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [769:769] <Text> = ♢aCell,♢
|    |    |    |    |    |    |    |    [769:769] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [769:769] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [769:769] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [769:769] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    [769:769] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [769:769] <Text> = ♢isReadOnly♢
|    |    |    |    |    |    |    |    |    [769:769] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [769:769] <Text> = ♢,♢
|    |    |    |    |    |    |    |    [769:769] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [769:769] <CFunctionCall>
|    |    |    |    |    |    |    |    |    [769:769] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    [769:769] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [769:769] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [769:769] <ObjCString> = ♢@"Allow•Editing"♢
|    |    |    |    |    |    |    |    |    |    [769:769] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    [769:769] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [769:769] <ObjCString> = ♢@"Menu•item•to•make•the•current•document•editable•(not•read-only)"♢
|    |    |    |    |    |    |    |    |    |    [769:769] <Match> = ♢)♢
|    |    |    |    |    |    |    |    [769:769] <Text> = ♢,♢
|    |    |    |    |    |    |    |    [769:769] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [769:769] <CFunctionCall>
|    |    |    |    |    |    |    |    |    [769:769] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    [769:769] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [769:769] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [769:769] <ObjCString> = ♢@"Prevent•Editing"♢
|    |    |    |    |    |    |    |    |    |    [769:769] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    [769:769] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [769:769] <ObjCString> = ♢@"Menu•item•to•make•the•current•document•read-only"♢
|    |    |    |    |    |    |    |    |    |    [769:769] <Match> = ♢)♢
|    |    |    |    |    |    |    |    [769:769] <Match> = ♢)♢
|    |    |    |    |    |    [769:769] <Semicolon> = ♢;♢
|    |    |    |    |    |    [769:770] <Newline> = ♢¶♢
|    |    |    |    |    |    [770:770] <Indenting> = ♢••••♢
|    |    |    |    |    |    [770:770] <Match> = ♢}♢
|    |    |    |    [770:770] <Whitespace> = ♢•♢
|    |    |    |    [770:772] <CConditionElseIf>
|    |    |    |    |    [770:770] <Match> = ♢else•if♢
|    |    |    |    |    [770:770] <Whitespace> = ♢•♢
|    |    |    |    |    [770:770] <Parenthesis>
|    |    |    |    |    |    [770:770] <Match> = ♢(♢
|    |    |    |    |    |    [770:770] <Text> = ♢action♢
|    |    |    |    |    |    [770:770] <Whitespace> = ♢•♢
|    |    |    |    |    |    [770:770] <Text> = ♢==♢
|    |    |    |    |    |    [770:770] <Whitespace> = ♢•♢
|    |    |    |    |    |    [770:770] <ObjCSelector>
|    |    |    |    |    |    |    [770:770] <Match> = ♢@selector♢
|    |    |    |    |    |    |    [770:770] <Parenthesis>
|    |    |    |    |    |    |    |    [770:770] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [770:770] <Text> = ♢togglePageBreaks♢
|    |    |    |    |    |    |    |    [770:770] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [770:770] <Match> = ♢)♢
|    |    |    |    |    |    [770:770] <Match> = ♢)♢
|    |    |    |    |    [770:770] <Whitespace> = ♢•♢
|    |    |    |    |    [770:772] <Braces>
|    |    |    |    |    |    [770:770] <Match> = ♢{♢
|    |    |    |    |    |    [770:771] <Newline> = ♢¶♢
|    |    |    |    |    |    [771:771] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [771:771] <CFunctionCall>
|    |    |    |    |    |    |    [771:771] <Match> = ♢validateToggleItem♢
|    |    |    |    |    |    |    [771:771] <Parenthesis>
|    |    |    |    |    |    |    |    [771:771] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [771:771] <Text> = ♢aCell,♢
|    |    |    |    |    |    |    |    [771:771] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [771:771] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [771:771] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [771:771] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    [771:771] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [771:771] <Text> = ♢hasMultiplePages♢
|    |    |    |    |    |    |    |    |    [771:771] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [771:771] <Text> = ♢,♢
|    |    |    |    |    |    |    |    [771:771] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [771:771] <CFunctionCall>
|    |    |    |    |    |    |    |    |    [771:771] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    [771:771] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [771:771] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [771:771] <ObjCString> = ♢@"&Wrap•to•Window"♢
|    |    |    |    |    |    |    |    |    |    [771:771] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    [771:771] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [771:771] <ObjCString> = ♢@"Menu•item•to•cause•text•to•be•laid•out•to•size•of•the•window"♢
|    |    |    |    |    |    |    |    |    |    [771:771] <Match> = ♢)♢
|    |    |    |    |    |    |    |    [771:771] <Text> = ♢,♢
|    |    |    |    |    |    |    |    [771:771] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [771:771] <CFunctionCall>
|    |    |    |    |    |    |    |    |    [771:771] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    [771:771] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [771:771] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [771:771] <ObjCString> = ♢@"&Wrap•to•Page"♢
|    |    |    |    |    |    |    |    |    |    [771:771] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    [771:771] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [771:771] <ObjCString> = ♢@"Menu•item•to•cause•text•to•be•laid•out•to•the•size•of•the•currently•selected•page•type"♢
|    |    |    |    |    |    |    |    |    |    [771:771] <Match> = ♢)♢
|    |    |    |    |    |    |    |    [771:771] <Match> = ♢)♢
|    |    |    |    |    |    [771:771] <Semicolon> = ♢;♢
|    |    |    |    |    |    [771:772] <Newline> = ♢¶♢
|    |    |    |    |    |    [772:772] <Indenting> = ♢••••♢
|    |    |    |    |    |    [772:772] <Match> = ♢}♢
|    |    |    |    [772:772] <Whitespace> = ♢•♢
|    |    |    |    [772:775] <CConditionElseIf>
|    |    |    |    |    [772:772] <Match> = ♢else•if♢
|    |    |    |    |    [772:772] <Whitespace> = ♢•♢
|    |    |    |    |    [772:772] <Parenthesis>
|    |    |    |    |    |    [772:772] <Match> = ♢(♢
|    |    |    |    |    |    [772:772] <Text> = ♢action♢
|    |    |    |    |    |    [772:772] <Whitespace> = ♢•♢
|    |    |    |    |    |    [772:772] <Text> = ♢==♢
|    |    |    |    |    |    [772:772] <Whitespace> = ♢•♢
|    |    |    |    |    |    [772:772] <ObjCSelector>
|    |    |    |    |    |    |    [772:772] <Match> = ♢@selector♢
|    |    |    |    |    |    |    [772:772] <Parenthesis>
|    |    |    |    |    |    |    |    [772:772] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [772:772] <Text> = ♢toggleHyphenation♢
|    |    |    |    |    |    |    |    [772:772] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [772:772] <Match> = ♢)♢
|    |    |    |    |    |    [772:772] <Match> = ♢)♢
|    |    |    |    |    [772:772] <Whitespace> = ♢•♢
|    |    |    |    |    [772:775] <Braces>
|    |    |    |    |    |    [772:772] <Match> = ♢{♢
|    |    |    |    |    |    [772:773] <Newline> = ♢¶♢
|    |    |    |    |    |    [773:773] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [773:773] <CFunctionCall>
|    |    |    |    |    |    |    [773:773] <Match> = ♢validateToggleItem♢
|    |    |    |    |    |    |    [773:773] <Parenthesis>
|    |    |    |    |    |    |    |    [773:773] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [773:773] <Text> = ♢aCell,♢
|    |    |    |    |    |    |    |    [773:773] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [773:773] <Parenthesis>
|    |    |    |    |    |    |    |    |    [773:773] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    [773:773] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [773:773] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [773:773] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    [773:773] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [773:773] <Text> = ♢hyphenationFactor♢
|    |    |    |    |    |    |    |    |    |    [773:773] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [773:773] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [773:773] <Text> = ♢>♢
|    |    |    |    |    |    |    |    |    [773:773] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [773:773] <Text> = ♢0.0♢
|    |    |    |    |    |    |    |    |    [773:773] <Match> = ♢)♢
|    |    |    |    |    |    |    |    [773:773] <Text> = ♢,♢
|    |    |    |    |    |    |    |    [773:773] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [773:773] <CFunctionCall>
|    |    |    |    |    |    |    |    |    [773:773] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    [773:773] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [773:773] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [773:773] <ObjCString> = ♢@"Do•not•Allow•Hyphenation"♢
|    |    |    |    |    |    |    |    |    |    [773:773] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    [773:773] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [773:773] <ObjCString> = ♢@"Menu•item•to•disallow•hyphenation•in•the•document"♢
|    |    |    |    |    |    |    |    |    |    [773:773] <Match> = ♢)♢
|    |    |    |    |    |    |    |    [773:773] <Text> = ♢,♢
|    |    |    |    |    |    |    |    [773:773] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [773:773] <CFunctionCall>
|    |    |    |    |    |    |    |    |    [773:773] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    [773:773] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [773:773] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [773:773] <ObjCString> = ♢@"Allow•Hyphenation"♢
|    |    |    |    |    |    |    |    |    |    [773:773] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    [773:773] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [773:773] <ObjCString> = ♢@"Menu•item•to•allow•hyphenation•in•the•document"♢
|    |    |    |    |    |    |    |    |    |    [773:773] <Match> = ♢)♢
|    |    |    |    |    |    |    |    [773:773] <Match> = ♢)♢
|    |    |    |    |    |    [773:773] <Semicolon> = ♢;♢
|    |    |    |    |    |    [773:774] <Newline> = ♢¶♢
|    |    |    |    |    |    [774:774] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [774:774] <CConditionIf>
|    |    |    |    |    |    |    [774:774] <Match> = ♢if♢
|    |    |    |    |    |    |    [774:774] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [774:774] <Parenthesis>
|    |    |    |    |    |    |    |    [774:774] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [774:774] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [774:774] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [774:774] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    [774:774] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [774:774] <Text> = ♢isReadOnly♢
|    |    |    |    |    |    |    |    |    [774:774] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [774:774] <Match> = ♢)♢
|    |    |    |    |    |    |    [774:774] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [774:774] <CFlowReturn>
|    |    |    |    |    |    |    |    [774:774] <Match> = ♢return♢
|    |    |    |    |    |    |    |    [774:774] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [774:774] <Text> = ♢NO♢
|    |    |    |    |    |    |    |    [774:774] <Semicolon> = ♢;♢
|    |    |    |    |    |    [774:775] <Newline> = ♢¶♢
|    |    |    |    |    |    [775:775] <Indenting> = ♢••••♢
|    |    |    |    |    |    [775:775] <Match> = ♢}♢
|    |    |    |    [775:776] <Newline> = ♢¶♢
|    |    |    |    [776:776] <Indenting> = ♢••••♢
|    |    |    |    [776:777] <Newline> = ♢¶♢
|    |    |    |    [777:777] <Indenting> = ♢••••♢
|    |    |    |    [777:777] <CFlowReturn>
|    |    |    |    |    [777:777] <Match> = ♢return♢
|    |    |    |    |    [777:777] <Whitespace> = ♢•♢
|    |    |    |    |    [777:777] <Text> = ♢YES♢
|    |    |    |    |    [777:777] <Semicolon> = ♢;♢
|    |    |    |    [777:778] <Newline> = ♢¶♢
|    |    |    |    [778:778] <Match> = ♢}♢
|    |    [778:779] <Newline> = ♢¶♢
|    |    [779:780] <Newline> = ♢¶♢
|    |    [780:780] <CPPComment> = ♢//•For•scripting.•We•already•have•a•-textStorage•method•implemented•above.♢
|    |    [780:781] <Newline> = ♢¶♢
|    |    [781:793] <ObjCMethodImplementation>
|    |    |    [781:781] <Match> = ♢-♢
|    |    |    [781:781] <Whitespace> = ♢•♢
|    |    |    [781:781] <Parenthesis>
|    |    |    |    [781:781] <Match> = ♢(♢
|    |    |    |    [781:781] <CVoid> = ♢void♢
|    |    |    |    [781:781] <Match> = ♢)♢
|    |    |    [781:781] <Text> = ♢setTextStorage♢
|    |    |    [781:781] <Colon> = ♢:♢
|    |    |    [781:781] <Parenthesis>
|    |    |    |    [781:781] <Match> = ♢(♢
|    |    |    |    [781:781] <Text> = ♢id♢
|    |    |    |    [781:781] <Match> = ♢)♢
|    |    |    [781:781] <Text> = ♢ts♢
|    |    |    [781:781] <Whitespace> = ♢•♢
|    |    |    [781:793] <Braces>
|    |    |    |    [781:781] <Match> = ♢{♢
|    |    |    |    [781:782] <Newline> = ♢¶♢
|    |    |    |    [782:782] <Indenting> = ♢••••♢
|    |    |    |    [782:782] <CPPComment> = ♢//•Warning,•undo•support•can•eat•a•lot•of•memory•if•a•long•text•is•changed•frequently♢
|    |    |    |    [782:783] <Newline> = ♢¶♢
|    |    |    |    [783:783] <Indenting> = ♢••••♢
|    |    |    |    [783:783] <Text> = ♢NSAttributedString♢
|    |    |    |    [783:783] <Whitespace> = ♢•♢
|    |    |    |    [783:783] <Asterisk> = ♢*♢
|    |    |    |    [783:783] <Text> = ♢textStorageCopy♢
|    |    |    |    [783:783] <Whitespace> = ♢•♢
|    |    |    |    [783:783] <Text> = ♢=♢
|    |    |    |    [783:783] <Whitespace> = ♢•♢
|    |    |    |    [783:783] <ObjCMethodCall>
|    |    |    |    |    [783:783] <Match> = ♢[♢
|    |    |    |    |    [783:783] <ObjCMethodCall>
|    |    |    |    |    |    [783:783] <Match> = ♢[♢
|    |    |    |    |    |    [783:783] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    [783:783] <Whitespace> = ♢•♢
|    |    |    |    |    |    [783:783] <Text> = ♢textStorage♢
|    |    |    |    |    |    [783:783] <Match> = ♢]♢
|    |    |    |    |    [783:783] <Whitespace> = ♢•♢
|    |    |    |    |    [783:783] <Text> = ♢copy♢
|    |    |    |    |    [783:783] <Match> = ♢]♢
|    |    |    |    [783:783] <Semicolon> = ♢;♢
|    |    |    |    [783:784] <Newline> = ♢¶♢
|    |    |    |    [784:784] <Indenting> = ♢••••♢
|    |    |    |    [784:784] <ObjCMethodCall>
|    |    |    |    |    [784:784] <Match> = ♢[♢
|    |    |    |    |    [784:784] <ObjCMethodCall>
|    |    |    |    |    |    [784:784] <Match> = ♢[♢
|    |    |    |    |    |    [784:784] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    [784:784] <Whitespace> = ♢•♢
|    |    |    |    |    |    [784:784] <Text> = ♢undoManager♢
|    |    |    |    |    |    [784:784] <Match> = ♢]♢
|    |    |    |    |    [784:784] <Whitespace> = ♢•♢
|    |    |    |    |    [784:784] <Text> = ♢registerUndoWithTarget♢
|    |    |    |    |    [784:784] <Colon> = ♢:♢
|    |    |    |    |    [784:784] <ObjCSelf> = ♢self♢
|    |    |    |    |    [784:784] <Whitespace> = ♢•♢
|    |    |    |    |    [784:784] <Text> = ♢selector♢
|    |    |    |    |    [784:784] <Colon> = ♢:♢
|    |    |    |    |    [784:784] <ObjCSelector>
|    |    |    |    |    |    [784:784] <Match> = ♢@selector♢
|    |    |    |    |    |    [784:784] <Parenthesis>
|    |    |    |    |    |    |    [784:784] <Match> = ♢(♢
|    |    |    |    |    |    |    [784:784] <Text> = ♢setTextStorage♢
|    |    |    |    |    |    |    [784:784] <Colon> = ♢:♢
|    |    |    |    |    |    |    [784:784] <Match> = ♢)♢
|    |    |    |    |    [784:784] <Whitespace> = ♢•♢
|    |    |    |    |    [784:784] <Text> = ♢object♢
|    |    |    |    |    [784:784] <Colon> = ♢:♢
|    |    |    |    |    [784:784] <Text> = ♢textStorageCopy♢
|    |    |    |    |    [784:784] <Match> = ♢]♢
|    |    |    |    [784:784] <Semicolon> = ♢;♢
|    |    |    |    [784:785] <Newline> = ♢¶♢
|    |    |    |    [785:785] <Indenting> = ♢••••♢
|    |    |    |    [785:785] <ObjCMethodCall>
|    |    |    |    |    [785:785] <Match> = ♢[♢
|    |    |    |    |    [785:785] <Match> = ♢textStorageCopy♢
|    |    |    |    |    [785:785] <Whitespace> = ♢•♢
|    |    |    |    |    [785:785] <Text> = ♢release♢
|    |    |    |    |    [785:785] <Match> = ♢]♢
|    |    |    |    [785:785] <Semicolon> = ♢;♢
|    |    |    |    [785:786] <Newline> = ♢¶♢
|    |    |    |    [786:787] <Newline> = ♢¶♢
|    |    |    |    [787:787] <Indenting> = ♢••••♢
|    |    |    |    [787:787] <CPPComment> = ♢//•ts•can•actually•be•a•string•or•an•attributed•string.♢
|    |    |    |    [787:788] <Newline> = ♢¶♢
|    |    |    |    [788:788] <Indenting> = ♢••••♢
|    |    |    |    [788:790] <CConditionIf>
|    |    |    |    |    [788:788] <Match> = ♢if♢
|    |    |    |    |    [788:788] <Whitespace> = ♢•♢
|    |    |    |    |    [788:788] <Parenthesis>
|    |    |    |    |    |    [788:788] <Match> = ♢(♢
|    |    |    |    |    |    [788:788] <ObjCMethodCall>
|    |    |    |    |    |    |    [788:788] <Match> = ♢[♢
|    |    |    |    |    |    |    [788:788] <Match> = ♢ts♢
|    |    |    |    |    |    |    [788:788] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [788:788] <Text> = ♢isKindOfClass♢
|    |    |    |    |    |    |    [788:788] <Colon> = ♢:♢
|    |    |    |    |    |    |    [788:788] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [788:788] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [788:788] <Match> = ♢NSAttributedString♢
|    |    |    |    |    |    |    |    [788:788] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [788:788] <Text> = ♢class♢
|    |    |    |    |    |    |    |    [788:788] <Match> = ♢]♢
|    |    |    |    |    |    |    [788:788] <Match> = ♢]♢
|    |    |    |    |    |    [788:788] <Match> = ♢)♢
|    |    |    |    |    [788:788] <Whitespace> = ♢•♢
|    |    |    |    |    [788:790] <Braces>
|    |    |    |    |    |    [788:788] <Match> = ♢{♢
|    |    |    |    |    |    [788:789] <Newline> = ♢¶♢
|    |    |    |    |    |    [789:789] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [789:789] <ObjCMethodCall>
|    |    |    |    |    |    |    [789:789] <Match> = ♢[♢
|    |    |    |    |    |    |    [789:789] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [789:789] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [789:789] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [789:789] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [789:789] <Text> = ♢textStorage♢
|    |    |    |    |    |    |    |    [789:789] <Match> = ♢]♢
|    |    |    |    |    |    |    [789:789] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [789:789] <Text> = ♢replaceCharactersInRange♢
|    |    |    |    |    |    |    [789:789] <Colon> = ♢:♢
|    |    |    |    |    |    |    [789:789] <CFunctionCall>
|    |    |    |    |    |    |    |    [789:789] <Match> = ♢NSMakeRange♢
|    |    |    |    |    |    |    |    [789:789] <Parenthesis>
|    |    |    |    |    |    |    |    |    [789:789] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    [789:789] <Text> = ♢0,♢
|    |    |    |    |    |    |    |    |    [789:789] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [789:789] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [789:789] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [789:789] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [789:789] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [789:789] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    [789:789] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [789:789] <Text> = ♢textStorage♢
|    |    |    |    |    |    |    |    |    |    |    [789:789] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [789:789] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [789:789] <Text> = ♢length♢
|    |    |    |    |    |    |    |    |    |    [789:789] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [789:789] <Match> = ♢)♢
|    |    |    |    |    |    |    [789:789] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [789:789] <Text> = ♢withAttributedString♢
|    |    |    |    |    |    |    [789:789] <Colon> = ♢:♢
|    |    |    |    |    |    |    [789:789] <Text> = ♢ts♢
|    |    |    |    |    |    |    [789:789] <Match> = ♢]♢
|    |    |    |    |    |    [789:789] <Semicolon> = ♢;♢
|    |    |    |    |    |    [789:790] <Newline> = ♢¶♢
|    |    |    |    |    |    [790:790] <Indenting> = ♢••••♢
|    |    |    |    |    |    [790:790] <Match> = ♢}♢
|    |    |    |    [790:790] <Whitespace> = ♢•♢
|    |    |    |    [790:792] <CConditionElse>
|    |    |    |    |    [790:790] <Match> = ♢else♢
|    |    |    |    |    [790:790] <Whitespace> = ♢•♢
|    |    |    |    |    [790:792] <Braces>
|    |    |    |    |    |    [790:790] <Match> = ♢{♢
|    |    |    |    |    |    [790:791] <Newline> = ♢¶♢
|    |    |    |    |    |    [791:791] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [791:791] <ObjCMethodCall>
|    |    |    |    |    |    |    [791:791] <Match> = ♢[♢
|    |    |    |    |    |    |    [791:791] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [791:791] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [791:791] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [791:791] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [791:791] <Text> = ♢textStorage♢
|    |    |    |    |    |    |    |    [791:791] <Match> = ♢]♢
|    |    |    |    |    |    |    [791:791] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [791:791] <Text> = ♢replaceCharactersInRange♢
|    |    |    |    |    |    |    [791:791] <Colon> = ♢:♢
|    |    |    |    |    |    |    [791:791] <CFunctionCall>
|    |    |    |    |    |    |    |    [791:791] <Match> = ♢NSMakeRange♢
|    |    |    |    |    |    |    |    [791:791] <Parenthesis>
|    |    |    |    |    |    |    |    |    [791:791] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    [791:791] <Text> = ♢0,♢
|    |    |    |    |    |    |    |    |    [791:791] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [791:791] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [791:791] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [791:791] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [791:791] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [791:791] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    [791:791] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [791:791] <Text> = ♢textStorage♢
|    |    |    |    |    |    |    |    |    |    |    [791:791] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [791:791] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [791:791] <Text> = ♢length♢
|    |    |    |    |    |    |    |    |    |    [791:791] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [791:791] <Match> = ♢)♢
|    |    |    |    |    |    |    [791:791] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [791:791] <Text> = ♢withString♢
|    |    |    |    |    |    |    [791:791] <Colon> = ♢:♢
|    |    |    |    |    |    |    [791:791] <Text> = ♢ts♢
|    |    |    |    |    |    |    [791:791] <Match> = ♢]♢
|    |    |    |    |    |    [791:791] <Semicolon> = ♢;♢
|    |    |    |    |    |    [791:792] <Newline> = ♢¶♢
|    |    |    |    |    |    [792:792] <Indenting> = ♢••••♢
|    |    |    |    |    |    [792:792] <Match> = ♢}♢
|    |    |    |    [792:793] <Newline> = ♢¶♢
|    |    |    |    [793:793] <Match> = ♢}♢
|    |    [793:794] <Newline> = ♢¶♢
|    |    [794:795] <Newline> = ♢¶♢
|    |    [795:802] <ObjCMethodImplementation>
|    |    |    [795:795] <Match> = ♢-♢
|    |    |    [795:795] <Whitespace> = ♢•♢
|    |    |    [795:795] <Parenthesis>
|    |    |    |    [795:795] <Match> = ♢(♢
|    |    |    |    [795:795] <Text> = ♢IBAction♢
|    |    |    |    [795:795] <Match> = ♢)♢
|    |    |    [795:795] <Text> = ♢revertDocumentToSaved♢
|    |    |    [795:795] <Colon> = ♢:♢
|    |    |    [795:795] <Parenthesis>
|    |    |    |    [795:795] <Match> = ♢(♢
|    |    |    |    [795:795] <Text> = ♢id♢
|    |    |    |    [795:795] <Match> = ♢)♢
|    |    |    [795:795] <Text> = ♢sender♢
|    |    |    [795:795] <Whitespace> = ♢•♢
|    |    |    [795:802] <Braces>
|    |    |    |    [795:795] <Match> = ♢{♢
|    |    |    |    [795:796] <Newline> = ♢¶♢
|    |    |    |    [796:796] <Indenting> = ♢••••♢
|    |    |    |    [796:796] <CPPComment> = ♢//•This•is•necessary,•because•document•reverting•doesn't•happen•within•NSDocument•if•the•fileURL•is•nil.♢
|    |    |    |    [796:797] <Newline> = ♢¶♢
|    |    |    |    [797:797] <Indenting> = ♢••••♢
|    |    |    |    [797:797] <CPPComment> = ♢//•However,•this•is•only•a•temporary•workaround•because•it•would•be•better•if•fileURL•was•never•set•to•nil.♢
|    |    |    |    [797:798] <Newline> = ♢¶♢
|    |    |    |    [798:798] <Indenting> = ♢••••♢
|    |    |    |    [798:800] <CConditionIf>
|    |    |    |    |    [798:798] <Match> = ♢if♢
|    |    |    |    |    [798:798] <Parenthesis>
|    |    |    |    |    |    [798:798] <Match> = ♢(♢
|    |    |    |    |    |    [798:798] <Whitespace> = ♢•♢
|    |    |    |    |    |    [798:798] <ObjCMethodCall>
|    |    |    |    |    |    |    [798:798] <Match> = ♢[♢
|    |    |    |    |    |    |    [798:798] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [798:798] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [798:798] <Text> = ♢fileURL♢
|    |    |    |    |    |    |    [798:798] <Match> = ♢]♢
|    |    |    |    |    |    [798:798] <Whitespace> = ♢•♢
|    |    |    |    |    |    [798:798] <Text> = ♢==♢
|    |    |    |    |    |    [798:798] <Whitespace> = ♢•♢
|    |    |    |    |    |    [798:798] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    [798:798] <Whitespace> = ♢•♢
|    |    |    |    |    |    [798:798] <Ampersand> = ♢&♢
|    |    |    |    |    |    [798:798] <Ampersand> = ♢&♢
|    |    |    |    |    |    [798:798] <Whitespace> = ♢•♢
|    |    |    |    |    |    [798:798] <Text> = ♢defaultDestination♢
|    |    |    |    |    |    [798:798] <Whitespace> = ♢•♢
|    |    |    |    |    |    [798:798] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    [798:798] <Text> = ♢=♢
|    |    |    |    |    |    [798:798] <Whitespace> = ♢•♢
|    |    |    |    |    |    [798:798] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    [798:798] <Whitespace> = ♢•♢
|    |    |    |    |    |    [798:798] <Match> = ♢)♢
|    |    |    |    |    [798:798] <Whitespace> = ♢•♢
|    |    |    |    |    [798:800] <Braces>
|    |    |    |    |    |    [798:798] <Match> = ♢{♢
|    |    |    |    |    |    [798:799] <Newline> = ♢¶♢
|    |    |    |    |    |    [799:799] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [799:799] <ObjCMethodCall>
|    |    |    |    |    |    |    [799:799] <Match> = ♢[♢
|    |    |    |    |    |    |    [799:799] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [799:799] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [799:799] <Text> = ♢setFileURL♢
|    |    |    |    |    |    |    [799:799] <Colon> = ♢:♢
|    |    |    |    |    |    |    [799:799] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [799:799] <Text> = ♢defaultDestination♢
|    |    |    |    |    |    |    [799:799] <Match> = ♢]♢
|    |    |    |    |    |    [799:799] <Semicolon> = ♢;♢
|    |    |    |    |    |    [799:800] <Newline> = ♢¶♢
|    |    |    |    |    |    [800:800] <Indenting> = ♢••••♢
|    |    |    |    |    |    [800:800] <Match> = ♢}♢
|    |    |    |    [800:801] <Newline> = ♢¶♢
|    |    |    |    [801:801] <Indenting> = ♢••••♢
|    |    |    |    [801:801] <ObjCMethodCall>
|    |    |    |    |    [801:801] <Match> = ♢[♢
|    |    |    |    |    [801:801] <ObjCSuper> = ♢super♢
|    |    |    |    |    [801:801] <Whitespace> = ♢•♢
|    |    |    |    |    [801:801] <Text> = ♢revertDocumentToSaved♢
|    |    |    |    |    [801:801] <Colon> = ♢:♢
|    |    |    |    |    [801:801] <Text> = ♢sender♢
|    |    |    |    |    [801:801] <Match> = ♢]♢
|    |    |    |    [801:801] <Semicolon> = ♢;♢
|    |    |    |    [801:802] <Newline> = ♢¶♢
|    |    |    |    [802:802] <Match> = ♢}♢
|    |    [802:803] <Newline> = ♢¶♢
|    |    [803:804] <Newline> = ♢¶♢
|    |    [804:819] <ObjCMethodImplementation>
|    |    |    [804:804] <Match> = ♢-♢
|    |    |    [804:804] <Whitespace> = ♢•♢
|    |    |    [804:804] <Parenthesis>
|    |    |    |    [804:804] <Match> = ♢(♢
|    |    |    |    [804:804] <Text> = ♢BOOL♢
|    |    |    |    [804:804] <Match> = ♢)♢
|    |    |    [804:804] <Text> = ♢revertToContentsOfURL♢
|    |    |    [804:804] <Colon> = ♢:♢
|    |    |    [804:804] <Parenthesis>
|    |    |    |    [804:804] <Match> = ♢(♢
|    |    |    |    [804:804] <Text> = ♢NSURL♢
|    |    |    |    [804:804] <Whitespace> = ♢•♢
|    |    |    |    [804:804] <Asterisk> = ♢*♢
|    |    |    |    [804:804] <Match> = ♢)♢
|    |    |    [804:804] <Text> = ♢url♢
|    |    |    [804:804] <Whitespace> = ♢•♢
|    |    |    [804:804] <Text> = ♢ofType♢
|    |    |    [804:804] <Colon> = ♢:♢
|    |    |    [804:804] <Parenthesis>
|    |    |    |    [804:804] <Match> = ♢(♢
|    |    |    |    [804:804] <Text> = ♢NSString♢
|    |    |    |    [804:804] <Whitespace> = ♢•♢
|    |    |    |    [804:804] <Asterisk> = ♢*♢
|    |    |    |    [804:804] <Match> = ♢)♢
|    |    |    [804:804] <Text> = ♢type♢
|    |    |    [804:804] <Whitespace> = ♢•♢
|    |    |    [804:804] <Text> = ♢error♢
|    |    |    [804:804] <Colon> = ♢:♢
|    |    |    [804:804] <Parenthesis>
|    |    |    |    [804:804] <Match> = ♢(♢
|    |    |    |    [804:804] <Text> = ♢NSError♢
|    |    |    |    [804:804] <Whitespace> = ♢•♢
|    |    |    |    [804:804] <Asterisk> = ♢*♢
|    |    |    |    [804:804] <Asterisk> = ♢*♢
|    |    |    |    [804:804] <Match> = ♢)♢
|    |    |    [804:804] <Text> = ♢outError♢
|    |    |    [804:804] <Whitespace> = ♢•♢
|    |    |    [804:819] <Braces>
|    |    |    |    [804:804] <Match> = ♢{♢
|    |    |    |    [804:805] <Newline> = ♢¶♢
|    |    |    |    [805:805] <Indenting> = ♢••••♢
|    |    |    |    [805:805] <CPPComment> = ♢//•See•the•comment•in•the•above•override•of•-revertDocumentToSaved:.♢
|    |    |    |    [805:806] <Newline> = ♢¶♢
|    |    |    |    [806:806] <Indenting> = ♢••••♢
|    |    |    |    [806:806] <Text> = ♢BOOL♢
|    |    |    |    [806:806] <Whitespace> = ♢•♢
|    |    |    |    [806:806] <Text> = ♢success♢
|    |    |    |    [806:806] <Whitespace> = ♢•♢
|    |    |    |    [806:806] <Text> = ♢=♢
|    |    |    |    [806:806] <Whitespace> = ♢•♢
|    |    |    |    [806:806] <ObjCMethodCall>
|    |    |    |    |    [806:806] <Match> = ♢[♢
|    |    |    |    |    [806:806] <ObjCSuper> = ♢super♢
|    |    |    |    |    [806:806] <Whitespace> = ♢•♢
|    |    |    |    |    [806:806] <Text> = ♢revertToContentsOfURL♢
|    |    |    |    |    [806:806] <Colon> = ♢:♢
|    |    |    |    |    [806:806] <Text> = ♢url♢
|    |    |    |    |    [806:806] <Whitespace> = ♢•♢
|    |    |    |    |    [806:806] <Text> = ♢ofType♢
|    |    |    |    |    [806:806] <Colon> = ♢:♢
|    |    |    |    |    [806:806] <Text> = ♢type♢
|    |    |    |    |    [806:806] <Whitespace> = ♢•♢
|    |    |    |    |    [806:806] <Text> = ♢error♢
|    |    |    |    |    [806:806] <Colon> = ♢:♢
|    |    |    |    |    [806:806] <Text> = ♢outError♢
|    |    |    |    |    [806:806] <Match> = ♢]♢
|    |    |    |    [806:806] <Semicolon> = ♢;♢
|    |    |    |    [806:807] <Newline> = ♢¶♢
|    |    |    |    [807:807] <Indenting> = ♢••••♢
|    |    |    |    [807:813] <CConditionIf>
|    |    |    |    |    [807:807] <Match> = ♢if♢
|    |    |    |    |    [807:807] <Whitespace> = ♢•♢
|    |    |    |    |    [807:807] <Parenthesis>
|    |    |    |    |    |    [807:807] <Match> = ♢(♢
|    |    |    |    |    |    [807:807] <Text> = ♢success♢
|    |    |    |    |    |    [807:807] <Match> = ♢)♢
|    |    |    |    |    [807:807] <Whitespace> = ♢•♢
|    |    |    |    |    [807:813] <Braces>
|    |    |    |    |    |    [807:807] <Match> = ♢{♢
|    |    |    |    |    |    [807:808] <Newline> = ♢¶♢
|    |    |    |    |    |    [808:808] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [808:808] <ObjCMethodCall>
|    |    |    |    |    |    |    [808:808] <Match> = ♢[♢
|    |    |    |    |    |    |    [808:808] <Match> = ♢defaultDestination♢
|    |    |    |    |    |    |    [808:808] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [808:808] <Text> = ♢release♢
|    |    |    |    |    |    |    [808:808] <Match> = ♢]♢
|    |    |    |    |    |    [808:808] <Semicolon> = ♢;♢
|    |    |    |    |    |    [808:809] <Newline> = ♢¶♢
|    |    |    |    |    |    [809:809] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [809:809] <Text> = ♢defaultDestination♢
|    |    |    |    |    |    [809:809] <Whitespace> = ♢•♢
|    |    |    |    |    |    [809:809] <Text> = ♢=♢
|    |    |    |    |    |    [809:809] <Whitespace> = ♢•♢
|    |    |    |    |    |    [809:809] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    [809:809] <Semicolon> = ♢;♢
|    |    |    |    |    |    [809:810] <Newline> = ♢¶♢
|    |    |    |    |    |    [810:810] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [810:810] <ObjCMethodCall>
|    |    |    |    |    |    |    [810:810] <Match> = ♢[♢
|    |    |    |    |    |    |    [810:810] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [810:810] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [810:810] <Text> = ♢setHasMultiplePages♢
|    |    |    |    |    |    |    [810:810] <Colon> = ♢:♢
|    |    |    |    |    |    |    [810:810] <Text> = ♢hasMultiplePages♢
|    |    |    |    |    |    |    [810:810] <Match> = ♢]♢
|    |    |    |    |    |    [810:810] <Semicolon> = ♢;♢
|    |    |    |    |    |    [810:811] <Newline> = ♢¶♢
|    |    |    |    |    |    [811:811] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [811:811] <ObjCMethodCall>
|    |    |    |    |    |    |    [811:811] <Match> = ♢[♢
|    |    |    |    |    |    |    [811:811] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [811:811] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [811:811] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [811:811] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [811:811] <Text> = ♢windowControllers♢
|    |    |    |    |    |    |    |    [811:811] <Match> = ♢]♢
|    |    |    |    |    |    |    [811:811] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [811:811] <Text> = ♢makeObjectsPerformSelector♢
|    |    |    |    |    |    |    [811:811] <Colon> = ♢:♢
|    |    |    |    |    |    |    [811:811] <ObjCSelector>
|    |    |    |    |    |    |    |    [811:811] <Match> = ♢@selector♢
|    |    |    |    |    |    |    |    [811:811] <Parenthesis>
|    |    |    |    |    |    |    |    |    [811:811] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    [811:811] <Text> = ♢setupTextViewForDocument♢
|    |    |    |    |    |    |    |    |    [811:811] <Match> = ♢)♢
|    |    |    |    |    |    |    [811:811] <Match> = ♢]♢
|    |    |    |    |    |    [811:811] <Semicolon> = ♢;♢
|    |    |    |    |    |    [811:812] <Newline> = ♢¶♢
|    |    |    |    |    |    [812:812] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [812:812] <ObjCMethodCall>
|    |    |    |    |    |    |    [812:812] <Match> = ♢[♢
|    |    |    |    |    |    |    [812:812] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [812:812] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [812:812] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [812:812] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [812:812] <Text> = ♢undoManager♢
|    |    |    |    |    |    |    |    [812:812] <Match> = ♢]♢
|    |    |    |    |    |    |    [812:812] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [812:812] <Text> = ♢removeAllActions♢
|    |    |    |    |    |    |    [812:812] <Match> = ♢]♢
|    |    |    |    |    |    [812:812] <Semicolon> = ♢;♢
|    |    |    |    |    |    [812:813] <Newline> = ♢¶♢
|    |    |    |    |    |    [813:813] <Indenting> = ♢••••♢
|    |    |    |    |    |    [813:813] <Match> = ♢}♢
|    |    |    |    [813:813] <Whitespace> = ♢•♢
|    |    |    |    [813:817] <CConditionElse>
|    |    |    |    |    [813:813] <Match> = ♢else♢
|    |    |    |    |    [813:813] <Whitespace> = ♢•♢
|    |    |    |    |    [813:817] <Braces>
|    |    |    |    |    |    [813:813] <Match> = ♢{♢
|    |    |    |    |    |    [813:814] <Newline> = ♢¶♢
|    |    |    |    |    |    [814:814] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [814:814] <CPPComment> = ♢//•The•document•failed•to•revert•correctly,•or•the•user•decided•to•cancel•the•revert.♢
|    |    |    |    |    |    [814:815] <Newline> = ♢¶♢
|    |    |    |    |    |    [815:815] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [815:815] <CPPComment> = ♢//•This•just•restores•the•file•URL•to•how•it•was•before•the•sheet•was•displayed.♢
|    |    |    |    |    |    [815:816] <Newline> = ♢¶♢
|    |    |    |    |    |    [816:816] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [816:816] <ObjCMethodCall>
|    |    |    |    |    |    |    [816:816] <Match> = ♢[♢
|    |    |    |    |    |    |    [816:816] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [816:816] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [816:816] <Text> = ♢setFileURL♢
|    |    |    |    |    |    |    [816:816] <Colon> = ♢:♢
|    |    |    |    |    |    |    [816:816] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    [816:816] <Match> = ♢]♢
|    |    |    |    |    |    [816:816] <Semicolon> = ♢;♢
|    |    |    |    |    |    [816:817] <Newline> = ♢¶♢
|    |    |    |    |    |    [817:817] <Indenting> = ♢••••♢
|    |    |    |    |    |    [817:817] <Match> = ♢}♢
|    |    |    |    [817:818] <Newline> = ♢¶♢
|    |    |    |    [818:818] <Indenting> = ♢••••♢
|    |    |    |    [818:818] <CFlowReturn>
|    |    |    |    |    [818:818] <Match> = ♢return♢
|    |    |    |    |    [818:818] <Whitespace> = ♢•♢
|    |    |    |    |    [818:818] <Text> = ♢success♢
|    |    |    |    |    [818:818] <Semicolon> = ♢;♢
|    |    |    |    [818:819] <Newline> = ♢¶♢
|    |    |    |    [819:819] <Match> = ♢}♢
|    |    [819:820] <Newline> = ♢¶♢
|    |    [820:821] <Newline> = ♢¶♢
|    |    [821:822] <CComment> = ♢/*•Target/action•method•for•saving•as•(actually•"saving•to")•PDF.•Note•that•this•approach•of•omitting•the•path•will•not•work•on•Leopard;•see•TextEdit's•README.rtf¶*/♢
|    |    [822:823] <Newline> = ♢¶♢
|    |    [823:825] <ObjCMethodImplementation>
|    |    |    [823:823] <Match> = ♢-♢
|    |    |    [823:823] <Whitespace> = ♢•♢
|    |    |    [823:823] <Parenthesis>
|    |    |    |    [823:823] <Match> = ♢(♢
|    |    |    |    [823:823] <Text> = ♢IBAction♢
|    |    |    |    [823:823] <Match> = ♢)♢
|    |    |    [823:823] <Text> = ♢saveDocumentAsPDFTo♢
|    |    |    [823:823] <Colon> = ♢:♢
|    |    |    [823:823] <Parenthesis>
|    |    |    |    [823:823] <Match> = ♢(♢
|    |    |    |    [823:823] <Text> = ♢id♢
|    |    |    |    [823:823] <Match> = ♢)♢
|    |    |    [823:823] <Text> = ♢sender♢
|    |    |    [823:823] <Whitespace> = ♢•♢
|    |    |    [823:825] <Braces>
|    |    |    |    [823:823] <Match> = ♢{♢
|    |    |    |    [823:824] <Newline> = ♢¶♢
|    |    |    |    [824:824] <Indenting> = ♢••••♢
|    |    |    |    [824:824] <ObjCMethodCall>
|    |    |    |    |    [824:824] <Match> = ♢[♢
|    |    |    |    |    [824:824] <ObjCSelf> = ♢self♢
|    |    |    |    |    [824:824] <Whitespace> = ♢•♢
|    |    |    |    |    [824:824] <Text> = ♢printDocumentWithSettings♢
|    |    |    |    |    [824:824] <Colon> = ♢:♢
|    |    |    |    |    [824:824] <ObjCMethodCall>
|    |    |    |    |    |    [824:824] <Match> = ♢[♢
|    |    |    |    |    |    [824:824] <Match> = ♢NSDictionary♢
|    |    |    |    |    |    [824:824] <Whitespace> = ♢•♢
|    |    |    |    |    |    [824:824] <Text> = ♢dictionaryWithObjectsAndKeys♢
|    |    |    |    |    |    [824:824] <Colon> = ♢:♢
|    |    |    |    |    |    [824:824] <Text> = ♢NSPrintSaveJob,♢
|    |    |    |    |    |    [824:824] <Whitespace> = ♢•♢
|    |    |    |    |    |    [824:824] <Text> = ♢NSPrintJobDisposition,♢
|    |    |    |    |    |    [824:824] <Whitespace> = ♢•♢
|    |    |    |    |    |    [824:824] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    [824:824] <Match> = ♢]♢
|    |    |    |    |    [824:824] <Whitespace> = ♢•♢
|    |    |    |    |    [824:824] <Text> = ♢showPrintPanel♢
|    |    |    |    |    [824:824] <Colon> = ♢:♢
|    |    |    |    |    [824:824] <Text> = ♢NO♢
|    |    |    |    |    [824:824] <Whitespace> = ♢•♢
|    |    |    |    |    [824:824] <Text> = ♢delegate♢
|    |    |    |    |    [824:824] <Colon> = ♢:♢
|    |    |    |    |    [824:824] <ObjCNil> = ♢nil♢
|    |    |    |    |    [824:824] <Whitespace> = ♢•♢
|    |    |    |    |    [824:824] <Text> = ♢didPrintSelector♢
|    |    |    |    |    [824:824] <Colon> = ♢:♢
|    |    |    |    |    [824:824] <CNULL> = ♢NULL♢
|    |    |    |    |    [824:824] <Whitespace> = ♢•♢
|    |    |    |    |    [824:824] <Text> = ♢contextInfo♢
|    |    |    |    |    [824:824] <Colon> = ♢:♢
|    |    |    |    |    [824:824] <CNULL> = ♢NULL♢
|    |    |    |    |    [824:824] <Match> = ♢]♢
|    |    |    |    [824:824] <Semicolon> = ♢;♢
|    |    |    |    [824:825] <Newline> = ♢¶♢
|    |    |    |    [825:825] <Match> = ♢}♢
|    |    [825:826] <Newline> = ♢¶♢
|    |    [826:827] <Newline> = ♢¶♢
|    |    [827:827] <Match> = ♢@end♢
|    [827:828] <Newline> = ♢¶♢
|    [828:829] <Newline> = ♢¶♢
|    [829:830] <Newline> = ♢¶♢
|    [830:831] <CComment> = ♢/*•Returns•the•default•padding•on•the•left/right•edges•of•text•views¶*/♢
|    [831:832] <Newline> = ♢¶♢
|    [832:840] <CFunctionDefinition>
|    |    [832:832] <Text> = ♢CGFloat♢
|    |    [832:832] <Whitespace> = ♢•♢
|    |    [832:832] <Match> = ♢defaultTextPadding♢
|    |    [832:832] <Parenthesis>
|    |    |    [832:832] <Match> = ♢(♢
|    |    |    [832:832] <CVoid> = ♢void♢
|    |    |    [832:832] <Match> = ♢)♢
|    |    [832:832] <Whitespace> = ♢•♢
|    |    [832:840] <Braces>
|    |    |    [832:832] <Match> = ♢{♢
|    |    |    [832:833] <Newline> = ♢¶♢
|    |    |    [833:833] <Indenting> = ♢••••♢
|    |    |    [833:833] <CStatic> = ♢static♢
|    |    |    [833:833] <Whitespace> = ♢•♢
|    |    |    [833:833] <Text> = ♢CGFloat♢
|    |    |    [833:833] <Whitespace> = ♢•♢
|    |    |    [833:833] <Text> = ♢padding♢
|    |    |    [833:833] <Whitespace> = ♢•♢
|    |    |    [833:833] <Text> = ♢=♢
|    |    |    [833:833] <Whitespace> = ♢•♢
|    |    |    [833:833] <Text> = ♢-1♢
|    |    |    [833:833] <Semicolon> = ♢;♢
|    |    |    [833:834] <Newline> = ♢¶♢
|    |    |    [834:834] <Indenting> = ♢••••♢
|    |    |    [834:838] <CConditionIf>
|    |    |    |    [834:834] <Match> = ♢if♢
|    |    |    |    [834:834] <Whitespace> = ♢•♢
|    |    |    |    [834:834] <Parenthesis>
|    |    |    |    |    [834:834] <Match> = ♢(♢
|    |    |    |    |    [834:834] <Text> = ♢padding♢
|    |    |    |    |    [834:834] <Whitespace> = ♢•♢
|    |    |    |    |    [834:834] <Text> = ♢<♢
|    |    |    |    |    [834:834] <Whitespace> = ♢•♢
|    |    |    |    |    [834:834] <Text> = ♢0.0♢
|    |    |    |    |    [834:834] <Match> = ♢)♢
|    |    |    |    [834:834] <Whitespace> = ♢•♢
|    |    |    |    [834:838] <Braces>
|    |    |    |    |    [834:834] <Match> = ♢{♢
|    |    |    |    |    [834:835] <Newline> = ♢¶♢
|    |    |    |    |    [835:835] <Indenting> = ♢••••••••♢
|    |    |    |    |    [835:835] <Text> = ♢NSTextContainer♢
|    |    |    |    |    [835:835] <Whitespace> = ♢•♢
|    |    |    |    |    [835:835] <Asterisk> = ♢*♢
|    |    |    |    |    [835:835] <Text> = ♢container♢
|    |    |    |    |    [835:835] <Whitespace> = ♢•♢
|    |    |    |    |    [835:835] <Text> = ♢=♢
|    |    |    |    |    [835:835] <Whitespace> = ♢•♢
|    |    |    |    |    [835:835] <ObjCMethodCall>
|    |    |    |    |    |    [835:835] <Match> = ♢[♢
|    |    |    |    |    |    [835:835] <ObjCMethodCall>
|    |    |    |    |    |    |    [835:835] <Match> = ♢[♢
|    |    |    |    |    |    |    [835:835] <Match> = ♢NSTextContainer♢
|    |    |    |    |    |    |    [835:835] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [835:835] <Text> = ♢alloc♢
|    |    |    |    |    |    |    [835:835] <Match> = ♢]♢
|    |    |    |    |    |    [835:835] <Whitespace> = ♢•♢
|    |    |    |    |    |    [835:835] <Text> = ♢init♢
|    |    |    |    |    |    [835:835] <Match> = ♢]♢
|    |    |    |    |    [835:835] <Semicolon> = ♢;♢
|    |    |    |    |    [835:836] <Newline> = ♢¶♢
|    |    |    |    |    [836:836] <Indenting> = ♢••••••••♢
|    |    |    |    |    [836:836] <Text> = ♢padding♢
|    |    |    |    |    [836:836] <Whitespace> = ♢•♢
|    |    |    |    |    [836:836] <Text> = ♢=♢
|    |    |    |    |    [836:836] <Whitespace> = ♢•♢
|    |    |    |    |    [836:836] <ObjCMethodCall>
|    |    |    |    |    |    [836:836] <Match> = ♢[♢
|    |    |    |    |    |    [836:836] <Match> = ♢container♢
|    |    |    |    |    |    [836:836] <Whitespace> = ♢•♢
|    |    |    |    |    |    [836:836] <Text> = ♢lineFragmentPadding♢
|    |    |    |    |    |    [836:836] <Match> = ♢]♢
|    |    |    |    |    [836:836] <Semicolon> = ♢;♢
|    |    |    |    |    [836:837] <Newline> = ♢¶♢
|    |    |    |    |    [837:837] <Indenting> = ♢••••••••♢
|    |    |    |    |    [837:837] <ObjCMethodCall>
|    |    |    |    |    |    [837:837] <Match> = ♢[♢
|    |    |    |    |    |    [837:837] <Match> = ♢container♢
|    |    |    |    |    |    [837:837] <Whitespace> = ♢•♢
|    |    |    |    |    |    [837:837] <Text> = ♢release♢
|    |    |    |    |    |    [837:837] <Match> = ♢]♢
|    |    |    |    |    [837:837] <Semicolon> = ♢;♢
|    |    |    |    |    [837:838] <Newline> = ♢¶♢
|    |    |    |    |    [838:838] <Indenting> = ♢••••♢
|    |    |    |    |    [838:838] <Match> = ♢}♢
|    |    |    [838:839] <Newline> = ♢¶♢
|    |    |    [839:839] <Indenting> = ♢••••♢
|    |    |    [839:839] <CFlowReturn>
|    |    |    |    [839:839] <Match> = ♢return♢
|    |    |    |    [839:839] <Whitespace> = ♢•♢
|    |    |    |    [839:839] <Text> = ♢padding♢
|    |    |    |    [839:839] <Semicolon> = ♢;♢
|    |    |    [839:840] <Newline> = ♢¶♢
|    |    |    [840:840] <Match> = ♢}♢
|    [840:841] <Newline> = ♢¶♢
|    [841:842] <Newline> = ♢¶♢
|    [842:1131] <ObjCImplementation>
|    |    [842:842] <Match> = ♢@implementation•Document•(TextEditNSDocumentOverrides)♢
|    |    [842:843] <Newline> = ♢¶♢
|    |    [843:844] <Newline> = ♢¶♢
|    |    [844:847] <ObjCMethodImplementation>
|    |    |    [844:844] <Match> = ♢+♢
|    |    |    [844:844] <Whitespace> = ♢•♢
|    |    |    [844:844] <Parenthesis>
|    |    |    |    [844:844] <Match> = ♢(♢
|    |    |    |    [844:844] <Text> = ♢BOOL♢
|    |    |    |    [844:844] <Match> = ♢)♢
|    |    |    [844:844] <Text> = ♢canConcurrentlyReadDocumentsOfType♢
|    |    |    [844:844] <Colon> = ♢:♢
|    |    |    [844:844] <Parenthesis>
|    |    |    |    [844:844] <Match> = ♢(♢
|    |    |    |    [844:844] <Text> = ♢NSString♢
|    |    |    |    [844:844] <Whitespace> = ♢•♢
|    |    |    |    [844:844] <Asterisk> = ♢*♢
|    |    |    |    [844:844] <Match> = ♢)♢
|    |    |    [844:844] <Text> = ♢typeName♢
|    |    |    [844:844] <Whitespace> = ♢•♢
|    |    |    [844:847] <Braces>
|    |    |    |    [844:844] <Match> = ♢{♢
|    |    |    |    [844:845] <Newline> = ♢¶♢
|    |    |    |    [845:845] <Indenting> = ♢••••♢
|    |    |    |    [845:845] <Text> = ♢NSWorkspace♢
|    |    |    |    [845:845] <Whitespace> = ♢•♢
|    |    |    |    [845:845] <Asterisk> = ♢*♢
|    |    |    |    [845:845] <Text> = ♢workspace♢
|    |    |    |    [845:845] <Whitespace> = ♢•♢
|    |    |    |    [845:845] <Text> = ♢=♢
|    |    |    |    [845:845] <Whitespace> = ♢•♢
|    |    |    |    [845:845] <ObjCMethodCall>
|    |    |    |    |    [845:845] <Match> = ♢[♢
|    |    |    |    |    [845:845] <Match> = ♢NSWorkspace♢
|    |    |    |    |    [845:845] <Whitespace> = ♢•♢
|    |    |    |    |    [845:845] <Text> = ♢sharedWorkspace♢
|    |    |    |    |    [845:845] <Match> = ♢]♢
|    |    |    |    [845:845] <Semicolon> = ♢;♢
|    |    |    |    [845:846] <Newline> = ♢¶♢
|    |    |    |    [846:846] <Indenting> = ♢••••♢
|    |    |    |    [846:846] <CFlowReturn>
|    |    |    |    |    [846:846] <Match> = ♢return♢
|    |    |    |    |    [846:846] <Whitespace> = ♢•♢
|    |    |    |    |    [846:846] <ExclamationMark> = ♢!♢
|    |    |    |    |    [846:846] <Parenthesis>
|    |    |    |    |    |    [846:846] <Match> = ♢(♢
|    |    |    |    |    |    [846:846] <ObjCMethodCall>
|    |    |    |    |    |    |    [846:846] <Match> = ♢[♢
|    |    |    |    |    |    |    [846:846] <Match> = ♢workspace♢
|    |    |    |    |    |    |    [846:846] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [846:846] <Text> = ♢type♢
|    |    |    |    |    |    |    [846:846] <Colon> = ♢:♢
|    |    |    |    |    |    |    [846:846] <Text> = ♢typeName♢
|    |    |    |    |    |    |    [846:846] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [846:846] <Text> = ♢conformsToType♢
|    |    |    |    |    |    |    [846:846] <Colon> = ♢:♢
|    |    |    |    |    |    |    [846:846] <Parenthesis>
|    |    |    |    |    |    |    |    [846:846] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [846:846] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    [846:846] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [846:846] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [846:846] <Match> = ♢)♢
|    |    |    |    |    |    |    [846:846] <Text> = ♢kUTTypeHTML♢
|    |    |    |    |    |    |    [846:846] <Match> = ♢]♢
|    |    |    |    |    |    [846:846] <Whitespace> = ♢•♢
|    |    |    |    |    |    [846:846] <Text> = ♢||♢
|    |    |    |    |    |    [846:846] <Whitespace> = ♢•♢
|    |    |    |    |    |    [846:846] <ObjCMethodCall>
|    |    |    |    |    |    |    [846:846] <Match> = ♢[♢
|    |    |    |    |    |    |    [846:846] <Match> = ♢workspace♢
|    |    |    |    |    |    |    [846:846] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [846:846] <Text> = ♢type♢
|    |    |    |    |    |    |    [846:846] <Colon> = ♢:♢
|    |    |    |    |    |    |    [846:846] <Text> = ♢typeName♢
|    |    |    |    |    |    |    [846:846] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [846:846] <Text> = ♢conformsToType♢
|    |    |    |    |    |    |    [846:846] <Colon> = ♢:♢
|    |    |    |    |    |    |    [846:846] <Parenthesis>
|    |    |    |    |    |    |    |    [846:846] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [846:846] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    [846:846] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [846:846] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [846:846] <Match> = ♢)♢
|    |    |    |    |    |    |    [846:846] <Text> = ♢kUTTypeWebArchive♢
|    |    |    |    |    |    |    [846:846] <Match> = ♢]♢
|    |    |    |    |    |    [846:846] <Match> = ♢)♢
|    |    |    |    |    [846:846] <Semicolon> = ♢;♢
|    |    |    |    [846:847] <Newline> = ♢¶♢
|    |    |    |    [847:847] <Match> = ♢}♢
|    |    [847:848] <Newline> = ♢¶♢
|    |    [848:849] <Newline> = ♢¶♢
|    |    [849:864] <ObjCMethodImplementation>
|    |    |    [849:849] <Match> = ♢-♢
|    |    |    [849:849] <Whitespace> = ♢•♢
|    |    |    [849:849] <Parenthesis>
|    |    |    |    [849:849] <Match> = ♢(♢
|    |    |    |    [849:849] <Text> = ♢id♢
|    |    |    |    [849:849] <Match> = ♢)♢
|    |    |    [849:849] <Text> = ♢initForURL♢
|    |    |    [849:849] <Colon> = ♢:♢
|    |    |    [849:849] <Parenthesis>
|    |    |    |    [849:849] <Match> = ♢(♢
|    |    |    |    [849:849] <Text> = ♢NSURL♢
|    |    |    |    [849:849] <Whitespace> = ♢•♢
|    |    |    |    [849:849] <Asterisk> = ♢*♢
|    |    |    |    [849:849] <Match> = ♢)♢
|    |    |    [849:849] <Text> = ♢absoluteDocumentURL♢
|    |    |    [849:849] <Whitespace> = ♢•♢
|    |    |    [849:849] <Text> = ♢withContentsOfURL♢
|    |    |    [849:849] <Colon> = ♢:♢
|    |    |    [849:849] <Parenthesis>
|    |    |    |    [849:849] <Match> = ♢(♢
|    |    |    |    [849:849] <Text> = ♢NSURL♢
|    |    |    |    [849:849] <Whitespace> = ♢•♢
|    |    |    |    [849:849] <Asterisk> = ♢*♢
|    |    |    |    [849:849] <Match> = ♢)♢
|    |    |    [849:849] <Text> = ♢absoluteDocumentContentsURL♢
|    |    |    [849:849] <Whitespace> = ♢•♢
|    |    |    [849:849] <Text> = ♢ofType♢
|    |    |    [849:849] <Colon> = ♢:♢
|    |    |    [849:849] <Parenthesis>
|    |    |    |    [849:849] <Match> = ♢(♢
|    |    |    |    [849:849] <Text> = ♢NSString♢
|    |    |    |    [849:849] <Whitespace> = ♢•♢
|    |    |    |    [849:849] <Asterisk> = ♢*♢
|    |    |    |    [849:849] <Match> = ♢)♢
|    |    |    [849:849] <Text> = ♢typeName♢
|    |    |    [849:849] <Whitespace> = ♢•♢
|    |    |    [849:849] <Text> = ♢error♢
|    |    |    [849:849] <Colon> = ♢:♢
|    |    |    [849:849] <Parenthesis>
|    |    |    |    [849:849] <Match> = ♢(♢
|    |    |    |    [849:849] <Text> = ♢NSError♢
|    |    |    |    [849:849] <Whitespace> = ♢•♢
|    |    |    |    [849:849] <Asterisk> = ♢*♢
|    |    |    |    [849:849] <Asterisk> = ♢*♢
|    |    |    |    [849:849] <Match> = ♢)♢
|    |    |    [849:849] <Text> = ♢outError♢
|    |    |    [849:849] <Whitespace> = ♢•♢
|    |    |    [849:864] <Braces>
|    |    |    |    [849:849] <Match> = ♢{♢
|    |    |    |    [849:850] <Newline> = ♢¶♢
|    |    |    |    [850:850] <Indenting> = ♢••••♢
|    |    |    |    [850:850] <CPPComment> = ♢//•This•is•the•method•that•NSDocumentController•invokes•during•reopening•of•an•autosaved•document•after•a•crash.•The•passed-in•type•name•might•be•NSRTFDPboardType,•but•absoluteDocumentURL•might•point•to•an•RTF•document,•and•if•we•did•nothing•this•document's•fileURL•and•fileType•might•not•agree,•which•would•cause•trouble•the•next•time•the•user•saved•this•document.•absoluteDocumentURL•might•also•be•nil,•if•the•document•being•reopened•has•never•been•saved•before.•It's•an•oddity•of•NSDocument•that•if•you•override•-autosavingFileType•you•probably•have•to•override•this•method•too.♢
|    |    |    |    [850:851] <Newline> = ♢¶♢
|    |    |    |    [851:851] <Indenting> = ♢••••♢
|    |    |    |    [851:860] <CConditionIf>
|    |    |    |    |    [851:851] <Match> = ♢if♢
|    |    |    |    |    [851:851] <Whitespace> = ♢•♢
|    |    |    |    |    [851:851] <Parenthesis>
|    |    |    |    |    |    [851:851] <Match> = ♢(♢
|    |    |    |    |    |    [851:851] <Text> = ♢absoluteDocumentURL♢
|    |    |    |    |    |    [851:851] <Match> = ♢)♢
|    |    |    |    |    [851:851] <Whitespace> = ♢•♢
|    |    |    |    |    [851:860] <Braces>
|    |    |    |    |    |    [851:851] <Match> = ♢{♢
|    |    |    |    |    |    [851:852] <Newline> = ♢¶♢
|    |    |    |    |    |    [852:852] <Indenting> = ♢→♢
|    |    |    |    |    |    [852:852] <Text> = ♢NSString♢
|    |    |    |    |    |    [852:852] <Whitespace> = ♢•♢
|    |    |    |    |    |    [852:852] <Asterisk> = ♢*♢
|    |    |    |    |    |    [852:852] <Text> = ♢realTypeName♢
|    |    |    |    |    |    [852:852] <Whitespace> = ♢•♢
|    |    |    |    |    |    [852:852] <Text> = ♢=♢
|    |    |    |    |    |    [852:852] <Whitespace> = ♢•♢
|    |    |    |    |    |    [852:852] <ObjCMethodCall>
|    |    |    |    |    |    |    [852:852] <Match> = ♢[♢
|    |    |    |    |    |    |    [852:852] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [852:852] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [852:852] <Match> = ♢NSDocumentController♢
|    |    |    |    |    |    |    |    [852:852] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [852:852] <Text> = ♢sharedDocumentController♢
|    |    |    |    |    |    |    |    [852:852] <Match> = ♢]♢
|    |    |    |    |    |    |    [852:852] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [852:852] <Text> = ♢typeForContentsOfURL♢
|    |    |    |    |    |    |    [852:852] <Colon> = ♢:♢
|    |    |    |    |    |    |    [852:852] <Text> = ♢absoluteDocumentURL♢
|    |    |    |    |    |    |    [852:852] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [852:852] <Text> = ♢error♢
|    |    |    |    |    |    |    [852:852] <Colon> = ♢:♢
|    |    |    |    |    |    |    [852:852] <Text> = ♢outError♢
|    |    |    |    |    |    |    [852:852] <Match> = ♢]♢
|    |    |    |    |    |    [852:852] <Semicolon> = ♢;♢
|    |    |    |    |    |    [852:853] <Newline> = ♢¶♢
|    |    |    |    |    |    [853:853] <Indenting> = ♢→♢
|    |    |    |    |    |    [853:856] <CConditionIf>
|    |    |    |    |    |    |    [853:853] <Match> = ♢if♢
|    |    |    |    |    |    |    [853:853] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [853:853] <Parenthesis>
|    |    |    |    |    |    |    |    [853:853] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [853:853] <Text> = ♢realTypeName♢
|    |    |    |    |    |    |    |    [853:853] <Match> = ♢)♢
|    |    |    |    |    |    |    [853:853] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [853:856] <Braces>
|    |    |    |    |    |    |    |    [853:853] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [853:854] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [854:854] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [854:854] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [854:854] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [854:854] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [854:854] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [854:854] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [854:854] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [854:854] <ObjCSuper> = ♢super♢
|    |    |    |    |    |    |    |    |    [854:854] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [854:854] <Text> = ♢initForURL♢
|    |    |    |    |    |    |    |    |    [854:854] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [854:854] <Text> = ♢absoluteDocumentURL♢
|    |    |    |    |    |    |    |    |    [854:854] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [854:854] <Text> = ♢withContentsOfURL♢
|    |    |    |    |    |    |    |    |    [854:854] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [854:854] <Text> = ♢absoluteDocumentContentsURL♢
|    |    |    |    |    |    |    |    |    [854:854] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [854:854] <Text> = ♢ofType♢
|    |    |    |    |    |    |    |    |    [854:854] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [854:854] <Text> = ♢typeName♢
|    |    |    |    |    |    |    |    |    [854:854] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [854:854] <Text> = ♢error♢
|    |    |    |    |    |    |    |    |    [854:854] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [854:854] <Text> = ♢outError♢
|    |    |    |    |    |    |    |    |    [854:854] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [854:854] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [854:855] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [855:855] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [855:855] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [855:855] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [855:855] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    [855:855] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [855:855] <Text> = ♢setFileType♢
|    |    |    |    |    |    |    |    |    [855:855] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [855:855] <Text> = ♢realTypeName♢
|    |    |    |    |    |    |    |    |    [855:855] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [855:855] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [855:856] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [856:856] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [856:856] <Match> = ♢}♢
|    |    |    |    |    |    [856:856] <Whitespace> = ♢•♢
|    |    |    |    |    |    [856:859] <CConditionElse>
|    |    |    |    |    |    |    [856:856] <Match> = ♢else♢
|    |    |    |    |    |    |    [856:856] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [856:859] <Braces>
|    |    |    |    |    |    |    |    [856:856] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [856:857] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [857:857] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [857:857] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [857:857] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [857:857] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    [857:857] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [857:857] <Text> = ♢release♢
|    |    |    |    |    |    |    |    |    [857:857] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [857:857] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [857:858] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [858:858] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [858:858] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [858:858] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [858:858] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [858:858] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [858:858] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    |    [858:858] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [858:859] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [859:859] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [859:859] <Match> = ♢}♢
|    |    |    |    |    |    [859:860] <Newline> = ♢¶♢
|    |    |    |    |    |    [860:860] <Indenting> = ♢••••♢
|    |    |    |    |    |    [860:860] <Match> = ♢}♢
|    |    |    |    [860:860] <Whitespace> = ♢•♢
|    |    |    |    [860:862] <CConditionElse>
|    |    |    |    |    [860:860] <Match> = ♢else♢
|    |    |    |    |    [860:860] <Whitespace> = ♢•♢
|    |    |    |    |    [860:862] <Braces>
|    |    |    |    |    |    [860:860] <Match> = ♢{♢
|    |    |    |    |    |    [860:861] <Newline> = ♢¶♢
|    |    |    |    |    |    [861:861] <Indenting> = ♢→♢
|    |    |    |    |    |    [861:861] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    [861:861] <Whitespace> = ♢•♢
|    |    |    |    |    |    [861:861] <Text> = ♢=♢
|    |    |    |    |    |    [861:861] <Whitespace> = ♢•♢
|    |    |    |    |    |    [861:861] <ObjCMethodCall>
|    |    |    |    |    |    |    [861:861] <Match> = ♢[♢
|    |    |    |    |    |    |    [861:861] <ObjCSuper> = ♢super♢
|    |    |    |    |    |    |    [861:861] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [861:861] <Text> = ♢initForURL♢
|    |    |    |    |    |    |    [861:861] <Colon> = ♢:♢
|    |    |    |    |    |    |    [861:861] <Text> = ♢absoluteDocumentURL♢
|    |    |    |    |    |    |    [861:861] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [861:861] <Text> = ♢withContentsOfURL♢
|    |    |    |    |    |    |    [861:861] <Colon> = ♢:♢
|    |    |    |    |    |    |    [861:861] <Text> = ♢absoluteDocumentContentsURL♢
|    |    |    |    |    |    |    [861:861] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [861:861] <Text> = ♢ofType♢
|    |    |    |    |    |    |    [861:861] <Colon> = ♢:♢
|    |    |    |    |    |    |    [861:861] <Text> = ♢typeName♢
|    |    |    |    |    |    |    [861:861] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [861:861] <Text> = ♢error♢
|    |    |    |    |    |    |    [861:861] <Colon> = ♢:♢
|    |    |    |    |    |    |    [861:861] <Text> = ♢outError♢
|    |    |    |    |    |    |    [861:861] <Match> = ♢]♢
|    |    |    |    |    |    [861:861] <Semicolon> = ♢;♢
|    |    |    |    |    |    [861:862] <Newline> = ♢¶♢
|    |    |    |    |    |    [862:862] <Indenting> = ♢••••♢
|    |    |    |    |    |    [862:862] <Match> = ♢}♢
|    |    |    |    [862:863] <Newline> = ♢¶♢
|    |    |    |    [863:863] <Indenting> = ♢••••♢
|    |    |    |    [863:863] <CFlowReturn>
|    |    |    |    |    [863:863] <Match> = ♢return♢
|    |    |    |    |    [863:863] <Whitespace> = ♢•♢
|    |    |    |    |    [863:863] <ObjCSelf> = ♢self♢
|    |    |    |    |    [863:863] <Semicolon> = ♢;♢
|    |    |    |    [863:864] <Newline> = ♢¶♢
|    |    |    |    [864:864] <Match> = ♢}♢
|    |    [864:865] <Newline> = ♢¶♢
|    |    [865:866] <Newline> = ♢¶♢
|    |    [866:873] <ObjCMethodImplementation>
|    |    |    [866:866] <Match> = ♢-♢
|    |    |    [866:866] <Whitespace> = ♢•♢
|    |    |    [866:866] <Parenthesis>
|    |    |    |    [866:866] <Match> = ♢(♢
|    |    |    |    [866:866] <CVoid> = ♢void♢
|    |    |    |    [866:866] <Match> = ♢)♢
|    |    |    [866:866] <Text> = ♢makeWindowControllers♢
|    |    |    [866:866] <Whitespace> = ♢•♢
|    |    |    [866:873] <Braces>
|    |    |    |    [866:866] <Match> = ♢{♢
|    |    |    |    [866:867] <Newline> = ♢¶♢
|    |    |    |    [867:867] <Indenting> = ♢••••♢
|    |    |    |    [867:867] <Text> = ♢NSArray♢
|    |    |    |    [867:867] <Whitespace> = ♢•♢
|    |    |    |    [867:867] <Asterisk> = ♢*♢
|    |    |    |    [867:867] <Text> = ♢myControllers♢
|    |    |    |    [867:867] <Whitespace> = ♢•♢
|    |    |    |    [867:867] <Text> = ♢=♢
|    |    |    |    [867:867] <Whitespace> = ♢•♢
|    |    |    |    [867:867] <ObjCMethodCall>
|    |    |    |    |    [867:867] <Match> = ♢[♢
|    |    |    |    |    [867:867] <ObjCSelf> = ♢self♢
|    |    |    |    |    [867:867] <Whitespace> = ♢•♢
|    |    |    |    |    [867:867] <Text> = ♢windowControllers♢
|    |    |    |    |    [867:867] <Match> = ♢]♢
|    |    |    |    [867:867] <Semicolon> = ♢;♢
|    |    |    |    [867:868] <Newline> = ♢¶♢
|    |    |    |    [868:868] <Indenting> = ♢••••♢
|    |    |    |    [868:869] <Newline> = ♢¶♢
|    |    |    |    [869:869] <Indenting> = ♢••••♢
|    |    |    |    [869:869] <CComment> = ♢/*•If•this•document•displaced•a•transient•document,•it•will•already•have•been•assigned•a•window•controller.•If•that•is•not•the•case,•create•one.•*/♢
|    |    |    |    [869:870] <Newline> = ♢¶♢
|    |    |    |    [870:870] <Indenting> = ♢••••♢
|    |    |    |    [870:872] <CConditionIf>
|    |    |    |    |    [870:870] <Match> = ♢if♢
|    |    |    |    |    [870:870] <Whitespace> = ♢•♢
|    |    |    |    |    [870:870] <Parenthesis>
|    |    |    |    |    |    [870:870] <Match> = ♢(♢
|    |    |    |    |    |    [870:870] <ObjCMethodCall>
|    |    |    |    |    |    |    [870:870] <Match> = ♢[♢
|    |    |    |    |    |    |    [870:870] <Match> = ♢myControllers♢
|    |    |    |    |    |    |    [870:870] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [870:870] <Text> = ♢count♢
|    |    |    |    |    |    |    [870:870] <Match> = ♢]♢
|    |    |    |    |    |    [870:870] <Whitespace> = ♢•♢
|    |    |    |    |    |    [870:870] <Text> = ♢==♢
|    |    |    |    |    |    [870:870] <Whitespace> = ♢•♢
|    |    |    |    |    |    [870:870] <Text> = ♢0♢
|    |    |    |    |    |    [870:870] <Match> = ♢)♢
|    |    |    |    |    [870:870] <Whitespace> = ♢•♢
|    |    |    |    |    [870:872] <Braces>
|    |    |    |    |    |    [870:870] <Match> = ♢{♢
|    |    |    |    |    |    [870:871] <Newline> = ♢¶♢
|    |    |    |    |    |    [871:871] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    [871:871] <ObjCMethodCall>
|    |    |    |    |    |    |    [871:871] <Match> = ♢[♢
|    |    |    |    |    |    |    [871:871] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [871:871] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [871:871] <Text> = ♢addWindowController♢
|    |    |    |    |    |    |    [871:871] <Colon> = ♢:♢
|    |    |    |    |    |    |    [871:871] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [871:871] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [871:871] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [871:871] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [871:871] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [871:871] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [871:871] <Match> = ♢DocumentWindowController♢
|    |    |    |    |    |    |    |    |    |    [871:871] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [871:871] <Text> = ♢allocWithZone♢
|    |    |    |    |    |    |    |    |    |    [871:871] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [871:871] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [871:871] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [871:871] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    [871:871] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [871:871] <Text> = ♢zone♢
|    |    |    |    |    |    |    |    |    |    |    [871:871] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [871:871] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [871:871] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [871:871] <Text> = ♢init♢
|    |    |    |    |    |    |    |    |    [871:871] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [871:871] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [871:871] <Text> = ♢autorelease♢
|    |    |    |    |    |    |    |    [871:871] <Match> = ♢]♢
|    |    |    |    |    |    |    [871:871] <Match> = ♢]♢
|    |    |    |    |    |    [871:871] <Semicolon> = ♢;♢
|    |    |    |    |    |    [871:872] <Newline> = ♢¶♢
|    |    |    |    |    |    [872:872] <Indenting> = ♢••••♢
|    |    |    |    |    |    [872:872] <Match> = ♢}♢
|    |    |    |    [872:873] <Newline> = ♢¶♢
|    |    |    |    [873:873] <Match> = ♢}♢
|    |    [873:874] <Newline> = ♢¶♢
|    |    [874:875] <Newline> = ♢¶♢
|    |    [875:889] <ObjCMethodImplementation>
|    |    |    [875:875] <Match> = ♢-♢
|    |    |    [875:875] <Whitespace> = ♢•♢
|    |    |    [875:875] <Parenthesis>
|    |    |    |    [875:875] <Match> = ♢(♢
|    |    |    |    [875:875] <Text> = ♢NSArray♢
|    |    |    |    [875:875] <Whitespace> = ♢•♢
|    |    |    |    [875:875] <Asterisk> = ♢*♢
|    |    |    |    [875:875] <Match> = ♢)♢
|    |    |    [875:875] <Text> = ♢writableTypesForSaveOperation♢
|    |    |    [875:875] <Colon> = ♢:♢
|    |    |    [875:875] <Parenthesis>
|    |    |    |    [875:875] <Match> = ♢(♢
|    |    |    |    [875:875] <Text> = ♢NSSaveOperationType♢
|    |    |    |    [875:875] <Match> = ♢)♢
|    |    |    [875:875] <Text> = ♢saveOperation♢
|    |    |    [875:875] <Whitespace> = ♢•♢
|    |    |    [875:889] <Braces>
|    |    |    |    [875:875] <Match> = ♢{♢
|    |    |    |    [875:876] <Newline> = ♢¶♢
|    |    |    |    [876:876] <Indenting> = ♢••••♢
|    |    |    |    [876:876] <Text> = ♢NSMutableArray♢
|    |    |    |    [876:876] <Whitespace> = ♢•♢
|    |    |    |    [876:876] <Asterisk> = ♢*♢
|    |    |    |    [876:876] <Text> = ♢outArray♢
|    |    |    |    [876:876] <Whitespace> = ♢•♢
|    |    |    |    [876:876] <Text> = ♢=♢
|    |    |    |    [876:876] <Whitespace> = ♢•♢
|    |    |    |    [876:876] <ObjCMethodCall>
|    |    |    |    |    [876:876] <Match> = ♢[♢
|    |    |    |    |    [876:876] <ObjCMethodCall>
|    |    |    |    |    |    [876:876] <Match> = ♢[♢
|    |    |    |    |    |    [876:876] <ObjCMethodCall>
|    |    |    |    |    |    |    [876:876] <Match> = ♢[♢
|    |    |    |    |    |    |    [876:876] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [876:876] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [876:876] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [876:876] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [876:876] <Text> = ♢class♢
|    |    |    |    |    |    |    |    [876:876] <Match> = ♢]♢
|    |    |    |    |    |    |    [876:876] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [876:876] <Text> = ♢writableTypes♢
|    |    |    |    |    |    |    [876:876] <Match> = ♢]♢
|    |    |    |    |    |    [876:876] <Whitespace> = ♢•♢
|    |    |    |    |    |    [876:876] <Text> = ♢mutableCopy♢
|    |    |    |    |    |    [876:876] <Match> = ♢]♢
|    |    |    |    |    [876:876] <Whitespace> = ♢•♢
|    |    |    |    |    [876:876] <Text> = ♢autorelease♢
|    |    |    |    |    [876:876] <Match> = ♢]♢
|    |    |    |    [876:876] <Semicolon> = ♢;♢
|    |    |    |    [876:877] <Newline> = ♢¶♢
|    |    |    |    [877:877] <Indenting> = ♢••••♢
|    |    |    |    [877:887] <CConditionIf>
|    |    |    |    |    [877:877] <Match> = ♢if♢
|    |    |    |    |    [877:877] <Whitespace> = ♢•♢
|    |    |    |    |    [877:877] <Parenthesis>
|    |    |    |    |    |    [877:877] <Match> = ♢(♢
|    |    |    |    |    |    [877:877] <Text> = ♢saveOperation♢
|    |    |    |    |    |    [877:877] <Whitespace> = ♢•♢
|    |    |    |    |    |    [877:877] <Text> = ♢==♢
|    |    |    |    |    |    [877:877] <Whitespace> = ♢•♢
|    |    |    |    |    |    [877:877] <Text> = ♢NSSaveAsOperation♢
|    |    |    |    |    |    [877:877] <Match> = ♢)♢
|    |    |    |    |    [877:877] <Whitespace> = ♢•♢
|    |    |    |    |    [877:887] <Braces>
|    |    |    |    |    |    [877:877] <Match> = ♢{♢
|    |    |    |    |    |    [877:878] <Newline> = ♢¶♢
|    |    |    |    |    |    [878:878] <Indenting> = ♢→♢
|    |    |    |    |    |    [878:878] <CComment> = ♢/*•Rich-text•documents•cannot•be•saved•as•plain•text.•*/♢
|    |    |    |    |    |    [878:879] <Newline> = ♢¶♢
|    |    |    |    |    |    [879:879] <Indenting> = ♢→♢
|    |    |    |    |    |    [879:881] <CConditionIf>
|    |    |    |    |    |    |    [879:879] <Match> = ♢if♢
|    |    |    |    |    |    |    [879:879] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [879:879] <Parenthesis>
|    |    |    |    |    |    |    |    [879:879] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [879:879] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [879:879] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [879:879] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    [879:879] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [879:879] <Text> = ♢isRichText♢
|    |    |    |    |    |    |    |    |    [879:879] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [879:879] <Match> = ♢)♢
|    |    |    |    |    |    |    [879:879] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [879:881] <Braces>
|    |    |    |    |    |    |    |    [879:879] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [879:880] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [880:880] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [880:880] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [880:880] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [880:880] <Match> = ♢outArray♢
|    |    |    |    |    |    |    |    |    [880:880] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [880:880] <Text> = ♢removeObject♢
|    |    |    |    |    |    |    |    |    [880:880] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [880:880] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [880:880] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [880:880] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    |    |    [880:880] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [880:880] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    |    |    [880:880] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [880:880] <Text> = ♢kUTTypePlainText♢
|    |    |    |    |    |    |    |    |    [880:880] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [880:880] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [880:881] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [881:881] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [881:881] <Match> = ♢}♢
|    |    |    |    |    |    [881:882] <Newline> = ♢¶♢
|    |    |    |    |    |    [882:882] <Indenting> = ♢→♢
|    |    |    |    |    |    [882:883] <Newline> = ♢¶♢
|    |    |    |    |    |    [883:883] <Indenting> = ♢→♢
|    |    |    |    |    |    [883:883] <CComment> = ♢/*•Documents•that•contain•attacments•can•only•be•saved•in•formats•that•support•embedded•graphics.•*/♢
|    |    |    |    |    |    [883:884] <Newline> = ♢¶♢
|    |    |    |    |    |    [884:884] <Indenting> = ♢→♢
|    |    |    |    |    |    [884:886] <CConditionIf>
|    |    |    |    |    |    |    [884:884] <Match> = ♢if♢
|    |    |    |    |    |    |    [884:884] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [884:884] <Parenthesis>
|    |    |    |    |    |    |    |    [884:884] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [884:884] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [884:884] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [884:884] <Match> = ♢textStorage♢
|    |    |    |    |    |    |    |    |    [884:884] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [884:884] <Text> = ♢containsAttachments♢
|    |    |    |    |    |    |    |    |    [884:884] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [884:884] <Match> = ♢)♢
|    |    |    |    |    |    |    [884:884] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [884:886] <Braces>
|    |    |    |    |    |    |    |    [884:884] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [884:885] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [885:885] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [885:885] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [885:885] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [885:885] <Match> = ♢outArray♢
|    |    |    |    |    |    |    |    |    [885:885] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [885:885] <Text> = ♢setArray♢
|    |    |    |    |    |    |    |    |    [885:885] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [885:885] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [885:885] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [885:885] <Match> = ♢NSArray♢
|    |    |    |    |    |    |    |    |    |    [885:885] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [885:885] <Text> = ♢arrayWithObjects♢
|    |    |    |    |    |    |    |    |    |    [885:885] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [885:885] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    [885:885] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    [885:885] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    |    |    |    [885:885] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [885:885] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    |    |    |    [885:885] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    [885:885] <Text> = ♢kUTTypeRTFD,♢
|    |    |    |    |    |    |    |    |    |    [885:885] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [885:885] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    [885:885] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    [885:885] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    |    |    |    [885:885] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [885:885] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    |    |    |    [885:885] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    [885:885] <Text> = ♢kUTTypeWebArchive,♢
|    |    |    |    |    |    |    |    |    |    [885:885] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [885:885] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    |    |    |    [885:885] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [885:885] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [885:885] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [885:886] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [886:886] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [886:886] <Match> = ♢}♢
|    |    |    |    |    |    [886:887] <Newline> = ♢¶♢
|    |    |    |    |    |    [887:887] <Indenting> = ♢••••♢
|    |    |    |    |    |    [887:887] <Match> = ♢}♢
|    |    |    |    [887:888] <Newline> = ♢¶♢
|    |    |    |    [888:888] <Indenting> = ♢••••♢
|    |    |    |    [888:888] <CFlowReturn>
|    |    |    |    |    [888:888] <Match> = ♢return♢
|    |    |    |    |    [888:888] <Whitespace> = ♢•♢
|    |    |    |    |    [888:888] <Text> = ♢outArray♢
|    |    |    |    |    [888:888] <Semicolon> = ♢;♢
|    |    |    |    [888:889] <Newline> = ♢¶♢
|    |    |    |    [889:889] <Match> = ♢}♢
|    |    [889:890] <Newline> = ♢¶♢
|    |    [890:891] <Newline> = ♢¶♢
|    |    [891:892] <CComment> = ♢/*•Whether•to•keep•the•backup•file¶*/♢
|    |    [892:893] <Newline> = ♢¶♢
|    |    [893:895] <ObjCMethodImplementation>
|    |    |    [893:893] <Match> = ♢-♢
|    |    |    [893:893] <Whitespace> = ♢•♢
|    |    |    [893:893] <Parenthesis>
|    |    |    |    [893:893] <Match> = ♢(♢
|    |    |    |    [893:893] <Text> = ♢BOOL♢
|    |    |    |    [893:893] <Match> = ♢)♢
|    |    |    [893:893] <Text> = ♢keepBackupFile♢
|    |    |    [893:893] <Whitespace> = ♢•♢
|    |    |    [893:895] <Braces>
|    |    |    |    [893:893] <Match> = ♢{♢
|    |    |    |    [893:894] <Newline> = ♢¶♢
|    |    |    |    [894:894] <Indenting> = ♢••••♢
|    |    |    |    [894:894] <CFlowReturn>
|    |    |    |    |    [894:894] <Match> = ♢return♢
|    |    |    |    |    [894:894] <Whitespace> = ♢•♢
|    |    |    |    |    [894:894] <ExclamationMark> = ♢!♢
|    |    |    |    |    [894:894] <ObjCMethodCall>
|    |    |    |    |    |    [894:894] <Match> = ♢[♢
|    |    |    |    |    |    [894:894] <ObjCMethodCall>
|    |    |    |    |    |    |    [894:894] <Match> = ♢[♢
|    |    |    |    |    |    |    [894:894] <Match> = ♢NSUserDefaults♢
|    |    |    |    |    |    |    [894:894] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [894:894] <Text> = ♢standardUserDefaults♢
|    |    |    |    |    |    |    [894:894] <Match> = ♢]♢
|    |    |    |    |    |    [894:894] <Whitespace> = ♢•♢
|    |    |    |    |    |    [894:894] <Text> = ♢boolForKey♢
|    |    |    |    |    |    [894:894] <Colon> = ♢:♢
|    |    |    |    |    |    [894:894] <Text> = ♢DeleteBackup♢
|    |    |    |    |    |    [894:894] <Match> = ♢]♢
|    |    |    |    |    [894:894] <Semicolon> = ♢;♢
|    |    |    |    [894:895] <Newline> = ♢¶♢
|    |    |    |    [895:895] <Match> = ♢}♢
|    |    [895:896] <Newline> = ♢¶♢
|    |    [896:897] <Newline> = ♢¶♢
|    |    [897:898] <CComment> = ♢/*•When•a•document•is•changed,•it•ceases•to•be•transient.•¶*/♢
|    |    [898:899] <Newline> = ♢¶♢
|    |    [899:902] <ObjCMethodImplementation>
|    |    |    [899:899] <Match> = ♢-♢
|    |    |    [899:899] <Whitespace> = ♢•♢
|    |    |    [899:899] <Parenthesis>
|    |    |    |    [899:899] <Match> = ♢(♢
|    |    |    |    [899:899] <CVoid> = ♢void♢
|    |    |    |    [899:899] <Match> = ♢)♢
|    |    |    [899:899] <Text> = ♢updateChangeCount♢
|    |    |    [899:899] <Colon> = ♢:♢
|    |    |    [899:899] <Parenthesis>
|    |    |    |    [899:899] <Match> = ♢(♢
|    |    |    |    [899:899] <Text> = ♢NSDocumentChangeType♢
|    |    |    |    [899:899] <Match> = ♢)♢
|    |    |    [899:899] <Text> = ♢change♢
|    |    |    [899:899] <Whitespace> = ♢•♢
|    |    |    [899:902] <Braces>
|    |    |    |    [899:899] <Match> = ♢{♢
|    |    |    |    [899:900] <Newline> = ♢¶♢
|    |    |    |    [900:900] <Indenting> = ♢••••♢
|    |    |    |    [900:900] <ObjCMethodCall>
|    |    |    |    |    [900:900] <Match> = ♢[♢
|    |    |    |    |    [900:900] <ObjCSelf> = ♢self♢
|    |    |    |    |    [900:900] <Whitespace> = ♢•♢
|    |    |    |    |    [900:900] <Text> = ♢setTransient♢
|    |    |    |    |    [900:900] <Colon> = ♢:♢
|    |    |    |    |    [900:900] <Text> = ♢NO♢
|    |    |    |    |    [900:900] <Match> = ♢]♢
|    |    |    |    [900:900] <Semicolon> = ♢;♢
|    |    |    |    [900:901] <Newline> = ♢¶♢
|    |    |    |    [901:901] <Indenting> = ♢••••♢
|    |    |    |    [901:901] <ObjCMethodCall>
|    |    |    |    |    [901:901] <Match> = ♢[♢
|    |    |    |    |    [901:901] <ObjCSuper> = ♢super♢
|    |    |    |    |    [901:901] <Whitespace> = ♢•♢
|    |    |    |    |    [901:901] <Text> = ♢updateChangeCount♢
|    |    |    |    |    [901:901] <Colon> = ♢:♢
|    |    |    |    |    [901:901] <Text> = ♢change♢
|    |    |    |    |    [901:901] <Match> = ♢]♢
|    |    |    |    [901:901] <Semicolon> = ♢;♢
|    |    |    |    [901:902] <Newline> = ♢¶♢
|    |    |    |    [902:902] <Match> = ♢}♢
|    |    [902:903] <Newline> = ♢¶♢
|    |    [903:904] <Newline> = ♢¶♢
|    |    [904:909] <CComment> = ♢/*•When•we•save,•we•send•a•notification•so•that•views•that•are•currently•coalescing•undo•actions•can•break•that.•This•is•done•for•two•reasons,•one•technical•and•the•other•HI•oriented.•¶¶Firstly,•since•the•dirty•state•tracking•is•based•on•undo,•for•a•coalesced•set•of•changes•that•span•over•a•save•operation,•the•changes•that•occur•between•the•save•and•the•next•time•the•undo•coalescing•stops•will•not•mark•the•document•as•dirty.•Secondly,•allowing•the•user•to•undo•back•to•the•precise•point•of•a•save•is•good•UI.•¶¶In•addition•we•overwrite•this•method•as•a•way•to•tell•that•the•document•has•been•saved•successfully.•If•so,•we•set•the•save•time•parameters•in•the•document.¶*/♢
|    |    [909:910] <Newline> = ♢¶♢
|    |    [910:920] <ObjCMethodImplementation>
|    |    |    [910:910] <Match> = ♢-♢
|    |    |    [910:910] <Whitespace> = ♢•♢
|    |    |    [910:910] <Parenthesis>
|    |    |    |    [910:910] <Match> = ♢(♢
|    |    |    |    [910:910] <Text> = ♢BOOL♢
|    |    |    |    [910:910] <Match> = ♢)♢
|    |    |    [910:910] <Text> = ♢saveToURL♢
|    |    |    [910:910] <Colon> = ♢:♢
|    |    |    [910:910] <Parenthesis>
|    |    |    |    [910:910] <Match> = ♢(♢
|    |    |    |    [910:910] <Text> = ♢NSURL♢
|    |    |    |    [910:910] <Whitespace> = ♢•♢
|    |    |    |    [910:910] <Asterisk> = ♢*♢
|    |    |    |    [910:910] <Match> = ♢)♢
|    |    |    [910:910] <Text> = ♢absoluteURL♢
|    |    |    [910:910] <Whitespace> = ♢•♢
|    |    |    [910:910] <Text> = ♢ofType♢
|    |    |    [910:910] <Colon> = ♢:♢
|    |    |    [910:910] <Parenthesis>
|    |    |    |    [910:910] <Match> = ♢(♢
|    |    |    |    [910:910] <Text> = ♢NSString♢
|    |    |    |    [910:910] <Whitespace> = ♢•♢
|    |    |    |    [910:910] <Asterisk> = ♢*♢
|    |    |    |    [910:910] <Match> = ♢)♢
|    |    |    [910:910] <Text> = ♢typeName♢
|    |    |    [910:910] <Whitespace> = ♢•♢
|    |    |    [910:910] <Text> = ♢forSaveOperation♢
|    |    |    [910:910] <Colon> = ♢:♢
|    |    |    [910:910] <Parenthesis>
|    |    |    |    [910:910] <Match> = ♢(♢
|    |    |    |    [910:910] <Text> = ♢NSSaveOperationType♢
|    |    |    |    [910:910] <Match> = ♢)♢
|    |    |    [910:910] <Text> = ♢saveOperation♢
|    |    |    [910:910] <Whitespace> = ♢•♢
|    |    |    [910:910] <Text> = ♢error♢
|    |    |    [910:910] <Colon> = ♢:♢
|    |    |    [910:910] <Parenthesis>
|    |    |    |    [910:910] <Match> = ♢(♢
|    |    |    |    [910:910] <Text> = ♢NSError♢
|    |    |    |    [910:910] <Whitespace> = ♢•♢
|    |    |    |    [910:910] <Asterisk> = ♢*♢
|    |    |    |    [910:910] <Asterisk> = ♢*♢
|    |    |    |    [910:910] <Match> = ♢)♢
|    |    |    [910:910] <Text> = ♢outError♢
|    |    |    [910:910] <Whitespace> = ♢•♢
|    |    |    [910:920] <Braces>
|    |    |    |    [910:910] <Match> = ♢{♢
|    |    |    |    [910:911] <Newline> = ♢¶♢
|    |    |    |    [911:911] <Indenting> = ♢••••♢
|    |    |    |    [911:911] <CPPComment> = ♢//•Note•that•we•do•the•breakUndoCoalescing•call•even•during•autosave,•which•means•the•user's•undo•of•long•typing•will•take•them•back•to•the•last•spot•an•autosave•occured.•This•might•seem•confusing,•and•a•more•elaborate•solution•may•be•possible•(cause•an•autosave•without•having•to•breakUndoCoalescing),•but•since•this•change•is•coming•late•in•Leopard,•we•decided•to•go•with•the•lower•risk•fix.♢
|    |    |    |    [911:912] <Newline> = ♢¶♢
|    |    |    |    [912:912] <Indenting> = ♢••••♢
|    |    |    |    [912:912] <ObjCMethodCall>
|    |    |    |    |    [912:912] <Match> = ♢[♢
|    |    |    |    |    [912:912] <ObjCMethodCall>
|    |    |    |    |    |    [912:912] <Match> = ♢[♢
|    |    |    |    |    |    [912:912] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    [912:912] <Whitespace> = ♢•♢
|    |    |    |    |    |    [912:912] <Text> = ♢windowControllers♢
|    |    |    |    |    |    [912:912] <Match> = ♢]♢
|    |    |    |    |    [912:912] <Whitespace> = ♢•♢
|    |    |    |    |    [912:912] <Text> = ♢makeObjectsPerformSelector♢
|    |    |    |    |    [912:912] <Colon> = ♢:♢
|    |    |    |    |    [912:912] <ObjCSelector>
|    |    |    |    |    |    [912:912] <Match> = ♢@selector♢
|    |    |    |    |    |    [912:912] <Parenthesis>
|    |    |    |    |    |    |    [912:912] <Match> = ♢(♢
|    |    |    |    |    |    |    [912:912] <Text> = ♢breakUndoCoalescing♢
|    |    |    |    |    |    |    [912:912] <Match> = ♢)♢
|    |    |    |    |    [912:912] <Match> = ♢]♢
|    |    |    |    [912:912] <Semicolon> = ♢;♢
|    |    |    |    [912:913] <Newline> = ♢¶♢
|    |    |    |    [913:914] <Newline> = ♢¶♢
|    |    |    |    [914:914] <Indenting> = ♢••••♢
|    |    |    |    [914:914] <Text> = ♢BOOL♢
|    |    |    |    [914:914] <Whitespace> = ♢•♢
|    |    |    |    [914:914] <Text> = ♢success♢
|    |    |    |    [914:914] <Whitespace> = ♢•♢
|    |    |    |    [914:914] <Text> = ♢=♢
|    |    |    |    [914:914] <Whitespace> = ♢•♢
|    |    |    |    [914:914] <ObjCMethodCall>
|    |    |    |    |    [914:914] <Match> = ♢[♢
|    |    |    |    |    [914:914] <ObjCSuper> = ♢super♢
|    |    |    |    |    [914:914] <Whitespace> = ♢•♢
|    |    |    |    |    [914:914] <Text> = ♢saveToURL♢
|    |    |    |    |    [914:914] <Colon> = ♢:♢
|    |    |    |    |    [914:914] <Text> = ♢absoluteURL♢
|    |    |    |    |    [914:914] <Whitespace> = ♢•♢
|    |    |    |    |    [914:914] <Text> = ♢ofType♢
|    |    |    |    |    [914:914] <Colon> = ♢:♢
|    |    |    |    |    [914:914] <Text> = ♢typeName♢
|    |    |    |    |    [914:914] <Whitespace> = ♢•♢
|    |    |    |    |    [914:914] <Text> = ♢forSaveOperation♢
|    |    |    |    |    [914:914] <Colon> = ♢:♢
|    |    |    |    |    [914:914] <Text> = ♢saveOperation♢
|    |    |    |    |    [914:914] <Whitespace> = ♢•♢
|    |    |    |    |    [914:914] <Text> = ♢error♢
|    |    |    |    |    [914:914] <Colon> = ♢:♢
|    |    |    |    |    [914:914] <Text> = ♢outError♢
|    |    |    |    |    [914:914] <Match> = ♢]♢
|    |    |    |    [914:914] <Semicolon> = ♢;♢
|    |    |    |    [914:915] <Newline> = ♢¶♢
|    |    |    |    [915:915] <Indenting> = ♢••••♢
|    |    |    |    [915:917] <CConditionIf>
|    |    |    |    |    [915:915] <Match> = ♢if♢
|    |    |    |    |    [915:915] <Whitespace> = ♢•♢
|    |    |    |    |    [915:915] <Parenthesis>
|    |    |    |    |    |    [915:915] <Match> = ♢(♢
|    |    |    |    |    |    [915:915] <Text> = ♢success♢
|    |    |    |    |    |    [915:915] <Whitespace> = ♢•♢
|    |    |    |    |    |    [915:915] <Ampersand> = ♢&♢
|    |    |    |    |    |    [915:915] <Ampersand> = ♢&♢
|    |    |    |    |    |    [915:915] <Whitespace> = ♢•♢
|    |    |    |    |    |    [915:915] <Parenthesis>
|    |    |    |    |    |    |    [915:915] <Match> = ♢(♢
|    |    |    |    |    |    |    [915:915] <Text> = ♢saveOperation♢
|    |    |    |    |    |    |    [915:915] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [915:915] <Text> = ♢==♢
|    |    |    |    |    |    |    [915:915] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [915:915] <Text> = ♢NSSaveOperation♢
|    |    |    |    |    |    |    [915:915] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [915:915] <Text> = ♢||♢
|    |    |    |    |    |    |    [915:915] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [915:915] <Parenthesis>
|    |    |    |    |    |    |    |    [915:915] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [915:915] <Text> = ♢saveOperation♢
|    |    |    |    |    |    |    |    [915:915] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [915:915] <Text> = ♢==♢
|    |    |    |    |    |    |    |    [915:915] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [915:915] <Text> = ♢NSSaveAsOperation♢
|    |    |    |    |    |    |    |    [915:915] <Match> = ♢)♢
|    |    |    |    |    |    |    [915:915] <Match> = ♢)♢
|    |    |    |    |    |    [915:915] <Match> = ♢)♢
|    |    |    |    |    [915:915] <Whitespace> = ♢•♢
|    |    |    |    |    [915:917] <Braces>
|    |    |    |    |    |    [915:915] <Match> = ♢{♢
|    |    |    |    |    |    [915:915] <Whitespace> = ♢••••♢
|    |    |    |    |    |    [915:915] <CPPComment> = ♢//•If•successful,•set•document•parameters•changed•during•the•save•operation♢
|    |    |    |    |    |    [915:916] <Newline> = ♢¶♢
|    |    |    |    |    |    [916:916] <Indenting> = ♢→♢
|    |    |    |    |    |    [916:916] <CConditionIf>
|    |    |    |    |    |    |    [916:916] <Match> = ♢if♢
|    |    |    |    |    |    |    [916:916] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [916:916] <Parenthesis>
|    |    |    |    |    |    |    |    [916:916] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [916:916] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [916:916] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [916:916] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    [916:916] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [916:916] <Text> = ♢encodingForSaving♢
|    |    |    |    |    |    |    |    |    [916:916] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [916:916] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [916:916] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    [916:916] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [916:916] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [916:916] <Text> = ♢NoStringEncoding♢
|    |    |    |    |    |    |    |    [916:916] <Match> = ♢)♢
|    |    |    |    |    |    |    [916:916] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [916:916] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [916:916] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [916:916] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [916:916] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [916:916] <Text> = ♢setEncoding♢
|    |    |    |    |    |    |    |    [916:916] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [916:916] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [916:916] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [916:916] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    [916:916] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [916:916] <Text> = ♢encodingForSaving♢
|    |    |    |    |    |    |    |    |    [916:916] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [916:916] <Match> = ♢]♢
|    |    |    |    |    |    |    [916:916] <Semicolon> = ♢;♢
|    |    |    |    |    |    [916:917] <Newline> = ♢¶♢
|    |    |    |    |    |    [917:917] <Indenting> = ♢••••♢
|    |    |    |    |    |    [917:917] <Match> = ♢}♢
|    |    |    |    [917:918] <Newline> = ♢¶♢
|    |    |    |    [918:918] <Indenting> = ♢••••♢
|    |    |    |    [918:918] <ObjCMethodCall>
|    |    |    |    |    [918:918] <Match> = ♢[♢
|    |    |    |    |    [918:918] <ObjCSelf> = ♢self♢
|    |    |    |    |    [918:918] <Whitespace> = ♢•♢
|    |    |    |    |    [918:918] <Text> = ♢setEncodingForSaving♢
|    |    |    |    |    [918:918] <Colon> = ♢:♢
|    |    |    |    |    [918:918] <Text> = ♢NoStringEncoding♢
|    |    |    |    |    [918:918] <Match> = ♢]♢
|    |    |    |    [918:918] <Semicolon> = ♢;♢
|    |    |    |    [918:918] <Whitespace> = ♢•••♢
|    |    |    |    [918:918] <CPPComment> = ♢//•This•is•set•during•prepareSavePanel:,•but•should•be•cleared•for•future•save•operation•without•save•panel♢
|    |    |    |    [918:919] <Newline> = ♢¶♢
|    |    |    |    [919:919] <Indenting> = ♢••••♢
|    |    |    |    [919:919] <CFlowReturn>
|    |    |    |    |    [919:919] <Match> = ♢return♢
|    |    |    |    |    [919:919] <Whitespace> = ♢•♢
|    |    |    |    |    [919:919] <Text> = ♢success♢
|    |    |    |    |    [919:919] <Semicolon> = ♢;♢
|    |    |    |    [919:919] <Whitespace> = ♢••••♢
|    |    |    |    [919:920] <Newline> = ♢¶♢
|    |    |    |    [920:920] <Match> = ♢}♢
|    |    [920:921] <Newline> = ♢¶♢
|    |    [921:922] <Newline> = ♢¶♢
|    |    [922:923] <CComment> = ♢/*•Since•a•document•into•which•the•user•has•dragged•graphics•should•autosave•as•RTFD,•we•override•this•method•to•return•RTFD,•unless•the•document•was•already•RTFD,•WebArchive,•or•plain•(the•last•one•done•for•optimization,•to•avoid•calling•containsAttachments).¶*/♢
|    |    [923:924] <Newline> = ♢¶♢
|    |    [924:930] <ObjCMethodImplementation>
|    |    |    [924:924] <Match> = ♢-♢
|    |    |    [924:924] <Whitespace> = ♢•♢
|    |    |    [924:924] <Parenthesis>
|    |    |    |    [924:924] <Match> = ♢(♢
|    |    |    |    [924:924] <Text> = ♢NSString♢
|    |    |    |    [924:924] <Whitespace> = ♢•♢
|    |    |    |    [924:924] <Asterisk> = ♢*♢
|    |    |    |    [924:924] <Match> = ♢)♢
|    |    |    [924:924] <Text> = ♢autosavingFileType♢
|    |    |    [924:924] <Whitespace> = ♢•♢
|    |    |    [924:930] <Braces>
|    |    |    |    [924:924] <Match> = ♢{♢
|    |    |    |    [924:925] <Newline> = ♢¶♢
|    |    |    |    [925:925] <Indenting> = ♢••••♢
|    |    |    |    [925:925] <Text> = ♢NSWorkspace♢
|    |    |    |    [925:925] <Whitespace> = ♢•♢
|    |    |    |    [925:925] <Asterisk> = ♢*♢
|    |    |    |    [925:925] <Text> = ♢workspace♢
|    |    |    |    [925:925] <Whitespace> = ♢•♢
|    |    |    |    [925:925] <Text> = ♢=♢
|    |    |    |    [925:925] <Whitespace> = ♢•♢
|    |    |    |    [925:925] <ObjCMethodCall>
|    |    |    |    |    [925:925] <Match> = ♢[♢
|    |    |    |    |    [925:925] <Match> = ♢NSWorkspace♢
|    |    |    |    |    [925:925] <Whitespace> = ♢•♢
|    |    |    |    |    [925:925] <Text> = ♢sharedWorkspace♢
|    |    |    |    |    [925:925] <Match> = ♢]♢
|    |    |    |    [925:925] <Semicolon> = ♢;♢
|    |    |    |    [925:926] <Newline> = ♢¶♢
|    |    |    |    [926:926] <Indenting> = ♢••••♢
|    |    |    |    [926:926] <Text> = ♢NSString♢
|    |    |    |    [926:926] <Whitespace> = ♢•♢
|    |    |    |    [926:926] <Asterisk> = ♢*♢
|    |    |    |    [926:926] <Text> = ♢type♢
|    |    |    |    [926:926] <Whitespace> = ♢•♢
|    |    |    |    [926:926] <Text> = ♢=♢
|    |    |    |    [926:926] <Whitespace> = ♢•♢
|    |    |    |    [926:926] <ObjCMethodCall>
|    |    |    |    |    [926:926] <Match> = ♢[♢
|    |    |    |    |    [926:926] <ObjCSuper> = ♢super♢
|    |    |    |    |    [926:926] <Whitespace> = ♢•♢
|    |    |    |    |    [926:926] <Text> = ♢autosavingFileType♢
|    |    |    |    |    [926:926] <Match> = ♢]♢
|    |    |    |    [926:926] <Semicolon> = ♢;♢
|    |    |    |    [926:927] <Newline> = ♢¶♢
|    |    |    |    [927:927] <Indenting> = ♢••••♢
|    |    |    |    [927:927] <CConditionIf>
|    |    |    |    |    [927:927] <Match> = ♢if♢
|    |    |    |    |    [927:927] <Whitespace> = ♢•♢
|    |    |    |    |    [927:927] <Parenthesis>
|    |    |    |    |    |    [927:927] <Match> = ♢(♢
|    |    |    |    |    |    [927:927] <ObjCMethodCall>
|    |    |    |    |    |    |    [927:927] <Match> = ♢[♢
|    |    |    |    |    |    |    [927:927] <Match> = ♢workspace♢
|    |    |    |    |    |    |    [927:927] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [927:927] <Text> = ♢type♢
|    |    |    |    |    |    |    [927:927] <Colon> = ♢:♢
|    |    |    |    |    |    |    [927:927] <Text> = ♢type♢
|    |    |    |    |    |    |    [927:927] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [927:927] <Text> = ♢conformsToType♢
|    |    |    |    |    |    |    [927:927] <Colon> = ♢:♢
|    |    |    |    |    |    |    [927:927] <Parenthesis>
|    |    |    |    |    |    |    |    [927:927] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [927:927] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    [927:927] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [927:927] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [927:927] <Match> = ♢)♢
|    |    |    |    |    |    |    [927:927] <Text> = ♢kUTTypeRTFD♢
|    |    |    |    |    |    |    [927:927] <Match> = ♢]♢
|    |    |    |    |    |    [927:927] <Whitespace> = ♢•♢
|    |    |    |    |    |    [927:927] <Text> = ♢||♢
|    |    |    |    |    |    [927:927] <Whitespace> = ♢•♢
|    |    |    |    |    |    [927:927] <ObjCMethodCall>
|    |    |    |    |    |    |    [927:927] <Match> = ♢[♢
|    |    |    |    |    |    |    [927:927] <Match> = ♢workspace♢
|    |    |    |    |    |    |    [927:927] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [927:927] <Text> = ♢type♢
|    |    |    |    |    |    |    [927:927] <Colon> = ♢:♢
|    |    |    |    |    |    |    [927:927] <Text> = ♢type♢
|    |    |    |    |    |    |    [927:927] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [927:927] <Text> = ♢conformsToType♢
|    |    |    |    |    |    |    [927:927] <Colon> = ♢:♢
|    |    |    |    |    |    |    [927:927] <Parenthesis>
|    |    |    |    |    |    |    |    [927:927] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [927:927] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    [927:927] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [927:927] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [927:927] <Match> = ♢)♢
|    |    |    |    |    |    |    [927:927] <Text> = ♢kUTTypeWebArchive♢
|    |    |    |    |    |    |    [927:927] <Match> = ♢]♢
|    |    |    |    |    |    [927:927] <Whitespace> = ♢•♢
|    |    |    |    |    |    [927:927] <Text> = ♢||♢
|    |    |    |    |    |    [927:927] <Whitespace> = ♢•♢
|    |    |    |    |    |    [927:927] <ObjCMethodCall>
|    |    |    |    |    |    |    [927:927] <Match> = ♢[♢
|    |    |    |    |    |    |    [927:927] <Match> = ♢workspace♢
|    |    |    |    |    |    |    [927:927] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [927:927] <Text> = ♢type♢
|    |    |    |    |    |    |    [927:927] <Colon> = ♢:♢
|    |    |    |    |    |    |    [927:927] <Text> = ♢type♢
|    |    |    |    |    |    |    [927:927] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [927:927] <Text> = ♢conformsToType♢
|    |    |    |    |    |    |    [927:927] <Colon> = ♢:♢
|    |    |    |    |    |    |    [927:927] <Parenthesis>
|    |    |    |    |    |    |    |    [927:927] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [927:927] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    [927:927] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [927:927] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [927:927] <Match> = ♢)♢
|    |    |    |    |    |    |    [927:927] <Text> = ♢kUTTypePlainText♢
|    |    |    |    |    |    |    [927:927] <Match> = ♢]♢
|    |    |    |    |    |    [927:927] <Match> = ♢)♢
|    |    |    |    |    [927:927] <Whitespace> = ♢•♢
|    |    |    |    |    [927:927] <CFlowReturn>
|    |    |    |    |    |    [927:927] <Match> = ♢return♢
|    |    |    |    |    |    [927:927] <Whitespace> = ♢•♢
|    |    |    |    |    |    [927:927] <Text> = ♢type♢
|    |    |    |    |    |    [927:927] <Semicolon> = ♢;♢
|    |    |    |    [927:928] <Newline> = ♢¶♢
|    |    |    |    [928:928] <Indenting> = ♢••••♢
|    |    |    |    [928:928] <CConditionIf>
|    |    |    |    |    [928:928] <Match> = ♢if♢
|    |    |    |    |    [928:928] <Whitespace> = ♢•♢
|    |    |    |    |    [928:928] <Parenthesis>
|    |    |    |    |    |    [928:928] <Match> = ♢(♢
|    |    |    |    |    |    [928:928] <ObjCMethodCall>
|    |    |    |    |    |    |    [928:928] <Match> = ♢[♢
|    |    |    |    |    |    |    [928:928] <Match> = ♢textStorage♢
|    |    |    |    |    |    |    [928:928] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [928:928] <Text> = ♢containsAttachments♢
|    |    |    |    |    |    |    [928:928] <Match> = ♢]♢
|    |    |    |    |    |    [928:928] <Match> = ♢)♢
|    |    |    |    |    [928:928] <Whitespace> = ♢•♢
|    |    |    |    |    [928:928] <CFlowReturn>
|    |    |    |    |    |    [928:928] <Match> = ♢return♢
|    |    |    |    |    |    [928:928] <Whitespace> = ♢•♢
|    |    |    |    |    |    [928:928] <Parenthesis>
|    |    |    |    |    |    |    [928:928] <Match> = ♢(♢
|    |    |    |    |    |    |    [928:928] <Text> = ♢NSString♢
|    |    |    |    |    |    |    [928:928] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [928:928] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    [928:928] <Match> = ♢)♢
|    |    |    |    |    |    [928:928] <Text> = ♢kUTTypeRTFD♢
|    |    |    |    |    |    [928:928] <Semicolon> = ♢;♢
|    |    |    |    [928:929] <Newline> = ♢¶♢
|    |    |    |    [929:929] <Indenting> = ♢••••♢
|    |    |    |    [929:929] <CFlowReturn>
|    |    |    |    |    [929:929] <Match> = ♢return♢
|    |    |    |    |    [929:929] <Whitespace> = ♢•♢
|    |    |    |    |    [929:929] <Text> = ♢type♢
|    |    |    |    |    [929:929] <Semicolon> = ♢;♢
|    |    |    |    [929:930] <Newline> = ♢¶♢
|    |    |    |    [930:930] <Match> = ♢}♢
|    |    [930:931] <Newline> = ♢¶♢
|    |    [931:932] <Newline> = ♢¶♢
|    |    [932:933] <Newline> = ♢¶♢
|    |    [933:934] <CComment> = ♢/*•When•the•file•URL•is•set•to•nil,•we•store•away•the•old•URL.•This•happens•when•a•document•is•converted•to•and•from•rich•text.•If•the•document•exists•on•disk,•we•default•to•use•the•same•base•file•when•subsequently•saving•the•document.•¶*/♢
|    |    [934:935] <Newline> = ♢¶♢
|    |    [935:942] <ObjCMethodImplementation>
|    |    |    [935:935] <Match> = ♢-♢
|    |    |    [935:935] <Whitespace> = ♢•♢
|    |    |    [935:935] <Parenthesis>
|    |    |    |    [935:935] <Match> = ♢(♢
|    |    |    |    [935:935] <CVoid> = ♢void♢
|    |    |    |    [935:935] <Match> = ♢)♢
|    |    |    [935:935] <Text> = ♢setFileURL♢
|    |    |    [935:935] <Colon> = ♢:♢
|    |    |    [935:935] <Parenthesis>
|    |    |    |    [935:935] <Match> = ♢(♢
|    |    |    |    [935:935] <Text> = ♢NSURL♢
|    |    |    |    [935:935] <Whitespace> = ♢•♢
|    |    |    |    [935:935] <Asterisk> = ♢*♢
|    |    |    |    [935:935] <Match> = ♢)♢
|    |    |    [935:935] <Text> = ♢url♢
|    |    |    [935:935] <Whitespace> = ♢•♢
|    |    |    [935:942] <Braces>
|    |    |    |    [935:935] <Match> = ♢{♢
|    |    |    |    [935:936] <Newline> = ♢¶♢
|    |    |    |    [936:936] <Indenting> = ♢••••♢
|    |    |    |    [936:936] <Text> = ♢NSURL♢
|    |    |    |    [936:936] <Whitespace> = ♢•♢
|    |    |    |    [936:936] <Asterisk> = ♢*♢
|    |    |    |    [936:936] <Text> = ♢previousURL♢
|    |    |    |    [936:936] <Whitespace> = ♢•♢
|    |    |    |    [936:936] <Text> = ♢=♢
|    |    |    |    [936:936] <Whitespace> = ♢•♢
|    |    |    |    [936:936] <ObjCMethodCall>
|    |    |    |    |    [936:936] <Match> = ♢[♢
|    |    |    |    |    [936:936] <ObjCSelf> = ♢self♢
|    |    |    |    |    [936:936] <Whitespace> = ♢•♢
|    |    |    |    |    [936:936] <Text> = ♢fileURL♢
|    |    |    |    |    [936:936] <Match> = ♢]♢
|    |    |    |    [936:936] <Semicolon> = ♢;♢
|    |    |    |    [936:937] <Newline> = ♢¶♢
|    |    |    |    [937:937] <Indenting> = ♢••••♢
|    |    |    |    [937:940] <CConditionIf>
|    |    |    |    |    [937:937] <Match> = ♢if♢
|    |    |    |    |    [937:937] <Whitespace> = ♢•♢
|    |    |    |    |    [937:937] <Parenthesis>
|    |    |    |    |    |    [937:937] <Match> = ♢(♢
|    |    |    |    |    |    [937:937] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    [937:937] <Text> = ♢url♢
|    |    |    |    |    |    [937:937] <Whitespace> = ♢•♢
|    |    |    |    |    |    [937:937] <Ampersand> = ♢&♢
|    |    |    |    |    |    [937:937] <Ampersand> = ♢&♢
|    |    |    |    |    |    [937:937] <Whitespace> = ♢•♢
|    |    |    |    |    |    [937:937] <Text> = ♢previousURL♢
|    |    |    |    |    |    [937:937] <Match> = ♢)♢
|    |    |    |    |    [937:937] <Whitespace> = ♢•♢
|    |    |    |    |    [937:940] <Braces>
|    |    |    |    |    |    [937:937] <Match> = ♢{♢
|    |    |    |    |    |    [937:938] <Newline> = ♢¶♢
|    |    |    |    |    |    [938:938] <Indenting> = ♢→♢
|    |    |    |    |    |    [938:938] <ObjCMethodCall>
|    |    |    |    |    |    |    [938:938] <Match> = ♢[♢
|    |    |    |    |    |    |    [938:938] <Match> = ♢defaultDestination♢
|    |    |    |    |    |    |    [938:938] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [938:938] <Text> = ♢release♢
|    |    |    |    |    |    |    [938:938] <Match> = ♢]♢
|    |    |    |    |    |    [938:938] <Semicolon> = ♢;♢
|    |    |    |    |    |    [938:939] <Newline> = ♢¶♢
|    |    |    |    |    |    [939:939] <Indenting> = ♢→♢
|    |    |    |    |    |    [939:939] <Text> = ♢defaultDestination♢
|    |    |    |    |    |    [939:939] <Whitespace> = ♢•♢
|    |    |    |    |    |    [939:939] <Text> = ♢=♢
|    |    |    |    |    |    [939:939] <Whitespace> = ♢•♢
|    |    |    |    |    |    [939:939] <ObjCMethodCall>
|    |    |    |    |    |    |    [939:939] <Match> = ♢[♢
|    |    |    |    |    |    |    [939:939] <Match> = ♢previousURL♢
|    |    |    |    |    |    |    [939:939] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [939:939] <Text> = ♢copy♢
|    |    |    |    |    |    |    [939:939] <Match> = ♢]♢
|    |    |    |    |    |    [939:939] <Semicolon> = ♢;♢
|    |    |    |    |    |    [939:940] <Newline> = ♢¶♢
|    |    |    |    |    |    [940:940] <Indenting> = ♢••••♢
|    |    |    |    |    |    [940:940] <Match> = ♢}♢
|    |    |    |    [940:941] <Newline> = ♢¶♢
|    |    |    |    [941:941] <Indenting> = ♢••••♢
|    |    |    |    [941:941] <ObjCMethodCall>
|    |    |    |    |    [941:941] <Match> = ♢[♢
|    |    |    |    |    [941:941] <ObjCSuper> = ♢super♢
|    |    |    |    |    [941:941] <Whitespace> = ♢•♢
|    |    |    |    |    [941:941] <Text> = ♢setFileURL♢
|    |    |    |    |    [941:941] <Colon> = ♢:♢
|    |    |    |    |    [941:941] <Text> = ♢url♢
|    |    |    |    |    [941:941] <Match> = ♢]♢
|    |    |    |    [941:941] <Semicolon> = ♢;♢
|    |    |    |    [941:942] <Newline> = ♢¶♢
|    |    |    |    [942:942] <Match> = ♢}♢
|    |    [942:943] <Newline> = ♢¶♢
|    |    [943:944] <Newline> = ♢¶♢
|    |    [944:948] <ObjCMethodImplementation>
|    |    |    [944:944] <Match> = ♢-♢
|    |    |    [944:944] <Whitespace> = ♢•♢
|    |    |    [944:944] <Parenthesis>
|    |    |    |    [944:944] <Match> = ♢(♢
|    |    |    |    [944:944] <CVoid> = ♢void♢
|    |    |    |    [944:944] <Match> = ♢)♢
|    |    |    [944:944] <Text> = ♢didPresentErrorWithRecovery♢
|    |    |    [944:944] <Colon> = ♢:♢
|    |    |    [944:944] <Parenthesis>
|    |    |    |    [944:944] <Match> = ♢(♢
|    |    |    |    [944:944] <Text> = ♢BOOL♢
|    |    |    |    [944:944] <Match> = ♢)♢
|    |    |    [944:944] <Text> = ♢didRecover♢
|    |    |    [944:944] <Whitespace> = ♢•♢
|    |    |    [944:944] <Text> = ♢contextInfo♢
|    |    |    [944:944] <Colon> = ♢:♢
|    |    |    [944:944] <Parenthesis>
|    |    |    |    [944:944] <Match> = ♢(♢
|    |    |    |    [944:944] <CVoid> = ♢void♢
|    |    |    |    [944:944] <Whitespace> = ♢•♢
|    |    |    |    [944:944] <Asterisk> = ♢*♢
|    |    |    |    [944:944] <Match> = ♢)♢
|    |    |    [944:944] <Text> = ♢contextInfo♢
|    |    |    [944:944] <Whitespace> = ♢•♢
|    |    |    [944:948] <Braces>
|    |    |    |    [944:944] <Match> = ♢{♢
|    |    |    |    [944:945] <Newline> = ♢¶♢
|    |    |    |    [945:945] <Indenting> = ♢••••♢
|    |    |    |    [945:947] <CConditionIf>
|    |    |    |    |    [945:945] <Match> = ♢if♢
|    |    |    |    |    [945:945] <Whitespace> = ♢•♢
|    |    |    |    |    [945:945] <Parenthesis>
|    |    |    |    |    |    [945:945] <Match> = ♢(♢
|    |    |    |    |    |    [945:945] <Text> = ♢didRecover♢
|    |    |    |    |    |    [945:945] <Match> = ♢)♢
|    |    |    |    |    [945:945] <Whitespace> = ♢•♢
|    |    |    |    |    [945:947] <Braces>
|    |    |    |    |    |    [945:945] <Match> = ♢{♢
|    |    |    |    |    |    [945:946] <Newline> = ♢¶♢
|    |    |    |    |    |    [946:946] <Indenting> = ♢→♢
|    |    |    |    |    |    [946:946] <ObjCMethodCall>
|    |    |    |    |    |    |    [946:946] <Match> = ♢[♢
|    |    |    |    |    |    |    [946:946] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [946:946] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [946:946] <Text> = ♢performSelector♢
|    |    |    |    |    |    |    [946:946] <Colon> = ♢:♢
|    |    |    |    |    |    |    [946:946] <ObjCSelector>
|    |    |    |    |    |    |    |    [946:946] <Match> = ♢@selector♢
|    |    |    |    |    |    |    |    [946:946] <Parenthesis>
|    |    |    |    |    |    |    |    |    [946:946] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    [946:946] <Text> = ♢saveDocument♢
|    |    |    |    |    |    |    |    |    [946:946] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [946:946] <Match> = ♢)♢
|    |    |    |    |    |    |    [946:946] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [946:946] <Text> = ♢withObject♢
|    |    |    |    |    |    |    [946:946] <Colon> = ♢:♢
|    |    |    |    |    |    |    [946:946] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [946:946] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [946:946] <Text> = ♢afterDelay♢
|    |    |    |    |    |    |    [946:946] <Colon> = ♢:♢
|    |    |    |    |    |    |    [946:946] <Text> = ♢0.0♢
|    |    |    |    |    |    |    [946:946] <Match> = ♢]♢
|    |    |    |    |    |    [946:946] <Semicolon> = ♢;♢
|    |    |    |    |    |    [946:947] <Newline> = ♢¶♢
|    |    |    |    |    |    [947:947] <Indenting> = ♢••••♢
|    |    |    |    |    |    [947:947] <Match> = ♢}♢
|    |    |    |    [947:948] <Newline> = ♢¶♢
|    |    |    |    [948:948] <Match> = ♢}♢
|    |    [948:949] <Newline> = ♢¶♢
|    |    [949:950] <Newline> = ♢¶♢
|    |    [950:999] <ObjCMethodImplementation>
|    |    |    [950:950] <Match> = ♢-♢
|    |    |    [950:950] <Whitespace> = ♢•♢
|    |    |    [950:950] <Parenthesis>
|    |    |    |    [950:950] <Match> = ♢(♢
|    |    |    |    [950:950] <CVoid> = ♢void♢
|    |    |    |    [950:950] <Match> = ♢)♢
|    |    |    [950:950] <Text> = ♢attemptRecoveryFromError♢
|    |    |    [950:950] <Colon> = ♢:♢
|    |    |    [950:950] <Parenthesis>
|    |    |    |    [950:950] <Match> = ♢(♢
|    |    |    |    [950:950] <Text> = ♢NSError♢
|    |    |    |    [950:950] <Whitespace> = ♢•♢
|    |    |    |    [950:950] <Asterisk> = ♢*♢
|    |    |    |    [950:950] <Match> = ♢)♢
|    |    |    [950:950] <Text> = ♢error♢
|    |    |    [950:950] <Whitespace> = ♢•♢
|    |    |    [950:950] <Text> = ♢optionIndex♢
|    |    |    [950:950] <Colon> = ♢:♢
|    |    |    [950:950] <Parenthesis>
|    |    |    |    [950:950] <Match> = ♢(♢
|    |    |    |    [950:950] <Text> = ♢NSUInteger♢
|    |    |    |    [950:950] <Match> = ♢)♢
|    |    |    [950:950] <Text> = ♢recoveryOptionIndex♢
|    |    |    [950:950] <Whitespace> = ♢•♢
|    |    |    [950:950] <Text> = ♢delegate♢
|    |    |    [950:950] <Colon> = ♢:♢
|    |    |    [950:950] <Parenthesis>
|    |    |    |    [950:950] <Match> = ♢(♢
|    |    |    |    [950:950] <Text> = ♢id♢
|    |    |    |    [950:950] <Match> = ♢)♢
|    |    |    [950:950] <Text> = ♢delegate♢
|    |    |    [950:950] <Whitespace> = ♢•♢
|    |    |    [950:950] <Text> = ♢didRecoverSelector♢
|    |    |    [950:950] <Colon> = ♢:♢
|    |    |    [950:950] <Parenthesis>
|    |    |    |    [950:950] <Match> = ♢(♢
|    |    |    |    [950:950] <Text> = ♢SEL♢
|    |    |    |    [950:950] <Match> = ♢)♢
|    |    |    [950:950] <Text> = ♢didRecoverSelector♢
|    |    |    [950:950] <Whitespace> = ♢•♢
|    |    |    [950:950] <Text> = ♢contextInfo♢
|    |    |    [950:950] <Colon> = ♢:♢
|    |    |    [950:950] <Parenthesis>
|    |    |    |    [950:950] <Match> = ♢(♢
|    |    |    |    [950:950] <CVoid> = ♢void♢
|    |    |    |    [950:950] <Whitespace> = ♢•♢
|    |    |    |    [950:950] <Asterisk> = ♢*♢
|    |    |    |    [950:950] <Match> = ♢)♢
|    |    |    [950:950] <Text> = ♢contextInfo♢
|    |    |    [950:950] <Whitespace> = ♢•♢
|    |    |    [950:999] <Braces>
|    |    |    |    [950:950] <Match> = ♢{♢
|    |    |    |    [950:951] <Newline> = ♢¶♢
|    |    |    |    [951:951] <Indenting> = ♢••••♢
|    |    |    |    [951:951] <Text> = ♢BOOL♢
|    |    |    |    [951:951] <Whitespace> = ♢•♢
|    |    |    |    [951:951] <Text> = ♢saveAgain♢
|    |    |    |    [951:951] <Whitespace> = ♢•♢
|    |    |    |    [951:951] <Text> = ♢=♢
|    |    |    |    [951:951] <Whitespace> = ♢•♢
|    |    |    |    [951:951] <Text> = ♢NO♢
|    |    |    |    [951:951] <Semicolon> = ♢;♢
|    |    |    |    [951:952] <Newline> = ♢¶♢
|    |    |    |    [952:952] <Indenting> = ♢••••♢
|    |    |    |    [952:996] <CConditionIf>
|    |    |    |    |    [952:952] <Match> = ♢if♢
|    |    |    |    |    [952:952] <Whitespace> = ♢•♢
|    |    |    |    |    [952:952] <Parenthesis>
|    |    |    |    |    |    [952:952] <Match> = ♢(♢
|    |    |    |    |    |    [952:952] <ObjCMethodCall>
|    |    |    |    |    |    |    [952:952] <Match> = ♢[♢
|    |    |    |    |    |    |    [952:952] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [952:952] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [952:952] <Match> = ♢error♢
|    |    |    |    |    |    |    |    [952:952] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [952:952] <Text> = ♢domain♢
|    |    |    |    |    |    |    |    [952:952] <Match> = ♢]♢
|    |    |    |    |    |    |    [952:952] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [952:952] <Text> = ♢isEqualToString♢
|    |    |    |    |    |    |    [952:952] <Colon> = ♢:♢
|    |    |    |    |    |    |    [952:952] <Text> = ♢TextEditErrorDomain♢
|    |    |    |    |    |    |    [952:952] <Match> = ♢]♢
|    |    |    |    |    |    [952:952] <Match> = ♢)♢
|    |    |    |    |    [952:952] <Whitespace> = ♢•♢
|    |    |    |    |    [952:996] <Braces>
|    |    |    |    |    |    [952:952] <Match> = ♢{♢
|    |    |    |    |    |    [952:953] <Newline> = ♢¶♢
|    |    |    |    |    |    [953:953] <Indenting> = ♢→♢
|    |    |    |    |    |    [953:995] <CFlowSwitch>
|    |    |    |    |    |    |    [953:953] <Match> = ♢switch♢
|    |    |    |    |    |    |    [953:953] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [953:953] <Parenthesis>
|    |    |    |    |    |    |    |    [953:953] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [953:953] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [953:953] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [953:953] <Match> = ♢error♢
|    |    |    |    |    |    |    |    |    [953:953] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [953:953] <Text> = ♢code♢
|    |    |    |    |    |    |    |    |    [953:953] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [953:953] <Match> = ♢)♢
|    |    |    |    |    |    |    [953:953] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [953:995] <Braces>
|    |    |    |    |    |    |    |    [953:953] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [953:954] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [954:954] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [954:961] <CFlowCase>
|    |    |    |    |    |    |    |    |    [954:954] <Match> = ♢case♢
|    |    |    |    |    |    |    |    |    [954:954] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [954:954] <Text> = ♢TextEditSaveErrorConvertedDocument♢
|    |    |    |    |    |    |    |    |    [954:954] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [954:955] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    [955:955] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    [955:960] <CConditionIf>
|    |    |    |    |    |    |    |    |    |    [955:955] <Match> = ♢if♢
|    |    |    |    |    |    |    |    |    |    [955:955] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [955:955] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    [955:955] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    [955:955] <Text> = ♢recoveryOptionIndex♢
|    |    |    |    |    |    |    |    |    |    |    [955:955] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [955:955] <Text> = ♢==♢
|    |    |    |    |    |    |    |    |    |    |    [955:955] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [955:955] <Text> = ♢0♢
|    |    |    |    |    |    |    |    |    |    |    [955:955] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    [955:955] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [955:960] <Braces>
|    |    |    |    |    |    |    |    |    |    |    [955:955] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    |    [955:955] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [955:955] <CPPComment> = ♢//•Save•with•new•name♢
|    |    |    |    |    |    |    |    |    |    |    [955:956] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    [956:956] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    [956:956] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    [956:956] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Text> = ♢setFileType♢
|    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [956:956] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Match> = ♢textStorage♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Text> = ♢containsAttachments♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [956:956] <QuestionMark> = ♢?♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Text> = ♢kUTTypeRTFD♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Text> = ♢kUTTypeRTF♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    |    [956:956] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    [956:956] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    [956:957] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    [957:957] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    [957:957] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    [957:957] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    [957:957] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    |    [957:957] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [957:957] <Text> = ♢setFileURL♢
|    |    |    |    |    |    |    |    |    |    |    |    [957:957] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    [957:957] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    |    |    |    |    |    [957:957] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    [957:957] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    [957:958] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    [958:958] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    [958:958] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    [958:958] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    [958:958] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    |    [958:958] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [958:958] <Text> = ♢setConverted♢
|    |    |    |    |    |    |    |    |    |    |    |    [958:958] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    [958:958] <Text> = ♢NO♢
|    |    |    |    |    |    |    |    |    |    |    |    [958:958] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    [958:958] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    [958:959] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    [959:959] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    [959:959] <Text> = ♢saveAgain♢
|    |    |    |    |    |    |    |    |    |    |    [959:959] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [959:959] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    |    |    [959:959] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [959:959] <Text> = ♢YES♢
|    |    |    |    |    |    |    |    |    |    |    [959:959] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    [959:960] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    [960:960] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    |    [960:960] <Match> = ♢}♢
|    |    |    |    |    |    |    |    |    [960:960] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [960:961] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    [961:961] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    [961:961] <CFlowBreak> = ♢break♢
|    |    |    |    |    |    |    |    |    [961:961] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [961:962] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [962:962] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [962:971] <CFlowCase>
|    |    |    |    |    |    |    |    |    [962:962] <Match> = ♢case♢
|    |    |    |    |    |    |    |    |    [962:962] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [962:962] <Text> = ♢TextEditSaveErrorLossyDocument♢
|    |    |    |    |    |    |    |    |    [962:962] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [962:963] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    [963:963] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    [963:967] <CConditionIf>
|    |    |    |    |    |    |    |    |    |    [963:963] <Match> = ♢if♢
|    |    |    |    |    |    |    |    |    |    [963:963] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [963:963] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    [963:963] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    [963:963] <Text> = ♢recoveryOptionIndex♢
|    |    |    |    |    |    |    |    |    |    |    [963:963] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [963:963] <Text> = ♢==♢
|    |    |    |    |    |    |    |    |    |    |    [963:963] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [963:963] <Text> = ♢0♢
|    |    |    |    |    |    |    |    |    |    |    [963:963] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    [963:963] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [963:967] <Braces>
|    |    |    |    |    |    |    |    |    |    |    [963:963] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    |    [963:963] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [963:963] <CPPComment> = ♢//•Save•with•new•name♢
|    |    |    |    |    |    |    |    |    |    |    [963:964] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    [964:964] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    [964:964] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    [964:964] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    [964:964] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    |    [964:964] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [964:964] <Text> = ♢setFileURL♢
|    |    |    |    |    |    |    |    |    |    |    |    [964:964] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    [964:964] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    |    |    |    |    |    [964:964] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    [964:964] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    [964:965] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    [965:965] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    [965:965] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    [965:965] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    [965:965] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    |    [965:965] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [965:965] <Text> = ♢setLossy♢
|    |    |    |    |    |    |    |    |    |    |    |    [965:965] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    [965:965] <Text> = ♢NO♢
|    |    |    |    |    |    |    |    |    |    |    |    [965:965] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    [965:965] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    [965:966] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    [966:966] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    [966:966] <Text> = ♢saveAgain♢
|    |    |    |    |    |    |    |    |    |    |    [966:966] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [966:966] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    |    |    [966:966] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [966:966] <Text> = ♢YES♢
|    |    |    |    |    |    |    |    |    |    |    [966:966] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    [966:967] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    [967:967] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    |    [967:967] <Match> = ♢}♢
|    |    |    |    |    |    |    |    |    [967:967] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [967:970] <CConditionElseIf>
|    |    |    |    |    |    |    |    |    |    [967:967] <Match> = ♢else•if♢
|    |    |    |    |    |    |    |    |    |    [967:967] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [967:967] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    [967:967] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    [967:967] <Text> = ♢recoveryOptionIndex♢
|    |    |    |    |    |    |    |    |    |    |    [967:967] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [967:967] <Text> = ♢==♢
|    |    |    |    |    |    |    |    |    |    |    [967:967] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [967:967] <Text> = ♢1♢
|    |    |    |    |    |    |    |    |    |    |    [967:967] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    [967:967] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [967:970] <Braces>
|    |    |    |    |    |    |    |    |    |    |    [967:967] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    |    [967:967] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [967:967] <CPPComment> = ♢//•Overwrite♢
|    |    |    |    |    |    |    |    |    |    |    [967:968] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    [968:968] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    [968:968] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    [968:968] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    [968:968] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    |    [968:968] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [968:968] <Text> = ♢setLossy♢
|    |    |    |    |    |    |    |    |    |    |    |    [968:968] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    [968:968] <Text> = ♢NO♢
|    |    |    |    |    |    |    |    |    |    |    |    [968:968] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    [968:968] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    [968:969] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    [969:969] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    [969:969] <Text> = ♢saveAgain♢
|    |    |    |    |    |    |    |    |    |    |    [969:969] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [969:969] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    |    |    [969:969] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [969:969] <Text> = ♢YES♢
|    |    |    |    |    |    |    |    |    |    |    [969:969] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    [969:970] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    [970:970] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    |    [970:970] <Match> = ♢}♢
|    |    |    |    |    |    |    |    |    [970:970] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [970:971] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    [971:971] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    [971:971] <CFlowBreak> = ♢break♢
|    |    |    |    |    |    |    |    |    [971:971] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [971:972] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [972:972] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [972:989] <CFlowCase>
|    |    |    |    |    |    |    |    |    [972:972] <Match> = ♢case♢
|    |    |    |    |    |    |    |    |    [972:972] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [972:972] <Text> = ♢TextEditSaveErrorRTFDRequired♢
|    |    |    |    |    |    |    |    |    [972:972] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [972:973] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    [973:973] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    [973:977] <CConditionIf>
|    |    |    |    |    |    |    |    |    |    [973:973] <Match> = ♢if♢
|    |    |    |    |    |    |    |    |    |    [973:973] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [973:973] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    [973:973] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    [973:973] <Text> = ♢recoveryOptionIndex♢
|    |    |    |    |    |    |    |    |    |    |    [973:973] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [973:973] <Text> = ♢==♢
|    |    |    |    |    |    |    |    |    |    |    [973:973] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [973:973] <Text> = ♢0♢
|    |    |    |    |    |    |    |    |    |    |    [973:973] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    [973:973] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [973:977] <Braces>
|    |    |    |    |    |    |    |    |    |    |    [973:973] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    |    [973:973] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [973:973] <CPPComment> = ♢//•Save•with•new•name;•enable•the•user•to•choose•a•new•name•to•save•with♢
|    |    |    |    |    |    |    |    |    |    |    [973:974] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    [974:974] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    [974:974] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    [974:974] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    [974:974] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    |    [974:974] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [974:974] <Text> = ♢setFileType♢
|    |    |    |    |    |    |    |    |    |    |    |    [974:974] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    [974:974] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    [974:974] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [974:974] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [974:974] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [974:974] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [974:974] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    |    [974:974] <Text> = ♢kUTTypeRTFD♢
|    |    |    |    |    |    |    |    |    |    |    |    [974:974] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    [974:974] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    [974:975] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    [975:975] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    [975:975] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    [975:975] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    [975:975] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    |    [975:975] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [975:975] <Text> = ♢setFileURL♢
|    |    |    |    |    |    |    |    |    |    |    |    [975:975] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    [975:975] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    |    |    |    |    |    [975:975] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    [975:975] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    [975:976] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    [976:976] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    [976:976] <Text> = ♢saveAgain♢
|    |    |    |    |    |    |    |    |    |    |    [976:976] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [976:976] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    |    |    [976:976] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [976:976] <Text> = ♢YES♢
|    |    |    |    |    |    |    |    |    |    |    [976:976] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    [976:977] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    [977:977] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    |    [977:977] <Match> = ♢}♢
|    |    |    |    |    |    |    |    |    [977:977] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [977:988] <CConditionElseIf>
|    |    |    |    |    |    |    |    |    |    [977:977] <Match> = ♢else•if♢
|    |    |    |    |    |    |    |    |    |    [977:977] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [977:977] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    [977:977] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    [977:977] <Text> = ♢recoveryOptionIndex♢
|    |    |    |    |    |    |    |    |    |    |    [977:977] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [977:977] <Text> = ♢==♢
|    |    |    |    |    |    |    |    |    |    |    [977:977] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [977:977] <Text> = ♢1♢
|    |    |    |    |    |    |    |    |    |    |    [977:977] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    [977:977] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [977:988] <Braces>
|    |    |    |    |    |    |    |    |    |    |    [977:977] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    |    [977:977] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [977:977] <CPPComment> = ♢//•Save•as•RTFD•with•the•same•name♢
|    |    |    |    |    |    |    |    |    |    |    [977:978] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    [978:978] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    [978:978] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    |    |    |    [978:978] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [978:978] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    |    |    |    [978:978] <Text> = ♢oldFilename♢
|    |    |    |    |    |    |    |    |    |    |    [978:978] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [978:978] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    |    |    [978:978] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [978:978] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    [978:978] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    [978:978] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    [978:978] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [978:978] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [978:978] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [978:978] <Text> = ♢fileURL♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [978:978] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    |    [978:978] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [978:978] <Text> = ♢path♢
|    |    |    |    |    |    |    |    |    |    |    |    [978:978] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    [978:978] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    [978:979] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    [979:979] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    [979:979] <Text> = ♢NSError♢
|    |    |    |    |    |    |    |    |    |    |    [979:979] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [979:979] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    |    |    |    [979:979] <Text> = ♢newError♢
|    |    |    |    |    |    |    |    |    |    |    [979:979] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    [979:980] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    [980:980] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    [980:983] <CConditionIf>
|    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Match> = ♢if♢
|    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Text> = ♢saveToURL♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Match> = ♢NSURL♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Text> = ♢fileURLWithPath♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Match> = ♢oldFilename♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Text> = ♢stringByDeletingPathExtension♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Text> = ♢stringByAppendingPathExtension♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <ObjCString> = ♢@"rtfd"♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Text> = ♢ofType♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Text> = ♢kUTTypeRTFD♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Text> = ♢forSaveOperation♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Text> = ♢NSSaveAsOperation♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Text> = ♢error♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Text> = ♢newError♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [980:983] <Braces>
|    |    |    |    |    |    |    |    |    |    |    |    |    [980:980] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [980:981] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [981:981] <Indenting> = ♢→→→♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [981:981] <CPPComment> = ♢//•If•attempt•to•save•as•RTFD•fails,•let•the•user•know♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [981:982] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Indenting> = ♢→→→♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Text> = ♢presentError♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Text> = ♢newError♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Text> = ♢modalForWindow♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Text> = ♢windowForSheet♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Text> = ♢delegate♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Text> = ♢didPresentSelector♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <CNULL> = ♢NULL♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Text> = ♢contextInfo♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Text> = ♢contextInfo♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [982:982] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [982:983] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [983:983] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [983:983] <Match> = ♢}♢
|    |    |    |    |    |    |    |    |    |    |    [983:983] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [983:986] <CConditionElse>
|    |    |    |    |    |    |    |    |    |    |    |    [983:983] <Match> = ♢else♢
|    |    |    |    |    |    |    |    |    |    |    |    [983:983] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [983:986] <Braces>
|    |    |    |    |    |    |    |    |    |    |    |    |    [983:983] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [983:984] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [984:984] <Indenting> = ♢→→→♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [984:984] <CPPComment> = ♢//•The•RTFD•is•saved;•we•ignore•error•from•trying•to•delete•the•RTF•file♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [984:985] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <Indenting> = ♢→→→♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <CVoid> = ♢void♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <Match> = ♢NSFileManager♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <Text> = ♢defaultManager♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <Text> = ♢removeItemAtPath♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <Text> = ♢oldFilename♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <Text> = ♢error♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <CNULL> = ♢NULL♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [985:985] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [985:986] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [986:986] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [986:986] <Match> = ♢}♢
|    |    |    |    |    |    |    |    |    |    |    [986:987] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    [987:987] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    [987:987] <Text> = ♢saveAgain♢
|    |    |    |    |    |    |    |    |    |    |    [987:987] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [987:987] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    |    |    [987:987] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [987:987] <Text> = ♢NO♢
|    |    |    |    |    |    |    |    |    |    |    [987:987] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    [987:988] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    [988:988] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    |    [988:988] <Match> = ♢}♢
|    |    |    |    |    |    |    |    |    [988:988] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [988:989] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    [989:989] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    [989:989] <CFlowBreak> = ♢break♢
|    |    |    |    |    |    |    |    |    [989:989] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [989:990] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [990:990] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [990:994] <CFlowCase>
|    |    |    |    |    |    |    |    |    [990:990] <Match> = ♢case♢
|    |    |    |    |    |    |    |    |    [990:990] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [990:990] <Text> = ♢TextEditSaveErrorEncodingInapplicable♢
|    |    |    |    |    |    |    |    |    [990:990] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [990:991] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    [991:991] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    [991:991] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [991:991] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [991:991] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    [991:991] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [991:991] <Text> = ♢setEncodingForSaving♢
|    |    |    |    |    |    |    |    |    |    [991:991] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [991:991] <Text> = ♢NoStringEncoding♢
|    |    |    |    |    |    |    |    |    |    [991:991] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [991:991] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    [991:992] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    [992:992] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    [992:992] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [992:992] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [992:992] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    [992:992] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [992:992] <Text> = ♢setFileURL♢
|    |    |    |    |    |    |    |    |    |    [992:992] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [992:992] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    |    |    |    [992:992] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [992:992] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    [992:993] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    [993:993] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    [993:993] <Text> = ♢saveAgain♢
|    |    |    |    |    |    |    |    |    [993:993] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [993:993] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    [993:993] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [993:993] <Text> = ♢YES♢
|    |    |    |    |    |    |    |    |    [993:993] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    [993:994] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    [994:994] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    [994:994] <CFlowBreak> = ♢break♢
|    |    |    |    |    |    |    |    |    [994:994] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [994:995] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [995:995] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [995:995] <Match> = ♢}♢
|    |    |    |    |    |    [995:996] <Newline> = ♢¶♢
|    |    |    |    |    |    [996:996] <Indenting> = ♢••••♢
|    |    |    |    |    |    [996:996] <Match> = ♢}♢
|    |    |    |    [996:997] <Newline> = ♢¶♢
|    |    |    |    [997:998] <Newline> = ♢¶♢
|    |    |    |    [998:998] <Indenting> = ♢••••♢
|    |    |    |    [998:998] <ObjCMethodCall>
|    |    |    |    |    [998:998] <Match> = ♢[♢
|    |    |    |    |    [998:998] <Match> = ♢delegate♢
|    |    |    |    |    [998:998] <Whitespace> = ♢•♢
|    |    |    |    |    [998:998] <Text> = ♢didPresentErrorWithRecovery♢
|    |    |    |    |    [998:998] <Colon> = ♢:♢
|    |    |    |    |    [998:998] <Text> = ♢saveAgain♢
|    |    |    |    |    [998:998] <Whitespace> = ♢•♢
|    |    |    |    |    [998:998] <Text> = ♢contextInfo♢
|    |    |    |    |    [998:998] <Colon> = ♢:♢
|    |    |    |    |    [998:998] <Text> = ♢contextInfo♢
|    |    |    |    |    [998:998] <Match> = ♢]♢
|    |    |    |    [998:998] <Semicolon> = ♢;♢
|    |    |    |    [998:999] <Newline> = ♢¶♢
|    |    |    |    [999:999] <Match> = ♢}♢
|    |    [999:1000] <Newline> = ♢¶♢
|    |    [1000:1001] <Newline> = ♢¶♢
|    |    [1001:1048] <ObjCMethodImplementation>
|    |    |    [1001:1001] <Match> = ♢-♢
|    |    |    [1001:1001] <Whitespace> = ♢•♢
|    |    |    [1001:1001] <Parenthesis>
|    |    |    |    [1001:1001] <Match> = ♢(♢
|    |    |    |    [1001:1001] <CVoid> = ♢void♢
|    |    |    |    [1001:1001] <Match> = ♢)♢
|    |    |    [1001:1001] <Text> = ♢saveDocumentWithDelegate♢
|    |    |    [1001:1001] <Colon> = ♢:♢
|    |    |    [1001:1001] <Parenthesis>
|    |    |    |    [1001:1001] <Match> = ♢(♢
|    |    |    |    [1001:1001] <Text> = ♢id♢
|    |    |    |    [1001:1001] <Match> = ♢)♢
|    |    |    [1001:1001] <Text> = ♢delegate♢
|    |    |    [1001:1001] <Whitespace> = ♢•♢
|    |    |    [1001:1001] <Text> = ♢didSaveSelector♢
|    |    |    [1001:1001] <Colon> = ♢:♢
|    |    |    [1001:1001] <Parenthesis>
|    |    |    |    [1001:1001] <Match> = ♢(♢
|    |    |    |    [1001:1001] <Text> = ♢SEL♢
|    |    |    |    [1001:1001] <Match> = ♢)♢
|    |    |    [1001:1001] <Text> = ♢didSaveSelector♢
|    |    |    [1001:1001] <Whitespace> = ♢•♢
|    |    |    [1001:1001] <Text> = ♢contextInfo♢
|    |    |    [1001:1001] <Colon> = ♢:♢
|    |    |    [1001:1001] <Parenthesis>
|    |    |    |    [1001:1001] <Match> = ♢(♢
|    |    |    |    [1001:1001] <CVoid> = ♢void♢
|    |    |    |    [1001:1001] <Whitespace> = ♢•♢
|    |    |    |    [1001:1001] <Asterisk> = ♢*♢
|    |    |    |    [1001:1001] <Match> = ♢)♢
|    |    |    [1001:1001] <Text> = ♢contextInfo♢
|    |    |    [1001:1001] <Whitespace> = ♢•♢
|    |    |    [1001:1048] <Braces>
|    |    |    |    [1001:1001] <Match> = ♢{♢
|    |    |    |    [1001:1002] <Newline> = ♢¶♢
|    |    |    |    [1002:1002] <Indenting> = ♢••••♢
|    |    |    |    [1002:1002] <Text> = ♢NSString♢
|    |    |    |    [1002:1002] <Whitespace> = ♢•♢
|    |    |    |    [1002:1002] <Asterisk> = ♢*♢
|    |    |    |    [1002:1002] <Text> = ♢currType♢
|    |    |    |    [1002:1002] <Whitespace> = ♢•♢
|    |    |    |    [1002:1002] <Text> = ♢=♢
|    |    |    |    [1002:1002] <Whitespace> = ♢•♢
|    |    |    |    [1002:1002] <ObjCMethodCall>
|    |    |    |    |    [1002:1002] <Match> = ♢[♢
|    |    |    |    |    [1002:1002] <ObjCSelf> = ♢self♢
|    |    |    |    |    [1002:1002] <Whitespace> = ♢•♢
|    |    |    |    |    [1002:1002] <Text> = ♢fileType♢
|    |    |    |    |    [1002:1002] <Match> = ♢]♢
|    |    |    |    [1002:1002] <Semicolon> = ♢;♢
|    |    |    |    [1002:1003] <Newline> = ♢¶♢
|    |    |    |    [1003:1003] <Indenting> = ♢••••♢
|    |    |    |    [1003:1003] <Text> = ♢NSError♢
|    |    |    |    [1003:1003] <Whitespace> = ♢•♢
|    |    |    |    [1003:1003] <Asterisk> = ♢*♢
|    |    |    |    [1003:1003] <Text> = ♢error♢
|    |    |    |    [1003:1003] <Whitespace> = ♢•♢
|    |    |    |    [1003:1003] <Text> = ♢=♢
|    |    |    |    [1003:1003] <Whitespace> = ♢•♢
|    |    |    |    [1003:1003] <ObjCNil> = ♢nil♢
|    |    |    |    [1003:1003] <Semicolon> = ♢;♢
|    |    |    |    [1003:1004] <Newline> = ♢¶♢
|    |    |    |    [1004:1004] <Indenting> = ♢••••♢
|    |    |    |    [1004:1004] <Text> = ♢BOOL♢
|    |    |    |    [1004:1004] <Whitespace> = ♢•♢
|    |    |    |    [1004:1004] <Text> = ♢containsAttachments♢
|    |    |    |    [1004:1004] <Whitespace> = ♢•♢
|    |    |    |    [1004:1004] <Text> = ♢=♢
|    |    |    |    [1004:1004] <Whitespace> = ♢•♢
|    |    |    |    [1004:1004] <ObjCMethodCall>
|    |    |    |    |    [1004:1004] <Match> = ♢[♢
|    |    |    |    |    [1004:1004] <Match> = ♢textStorage♢
|    |    |    |    |    [1004:1004] <Whitespace> = ♢•♢
|    |    |    |    |    [1004:1004] <Text> = ♢containsAttachments♢
|    |    |    |    |    [1004:1004] <Match> = ♢]♢
|    |    |    |    [1004:1004] <Semicolon> = ♢;♢
|    |    |    |    [1004:1005] <Newline> = ♢¶♢
|    |    |    |    [1005:1005] <Indenting> = ♢••••♢
|    |    |    |    [1005:1006] <Newline> = ♢¶♢
|    |    |    |    [1006:1006] <Indenting> = ♢••••♢
|    |    |    |    [1006:1041] <CConditionIf>
|    |    |    |    |    [1006:1006] <Match> = ♢if♢
|    |    |    |    |    [1006:1006] <Whitespace> = ♢•♢
|    |    |    |    |    [1006:1006] <Parenthesis>
|    |    |    |    |    |    [1006:1006] <Match> = ♢(♢
|    |    |    |    |    |    [1006:1006] <ObjCMethodCall>
|    |    |    |    |    |    |    [1006:1006] <Match> = ♢[♢
|    |    |    |    |    |    |    [1006:1006] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [1006:1006] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1006:1006] <Text> = ♢fileURL♢
|    |    |    |    |    |    |    [1006:1006] <Match> = ♢]♢
|    |    |    |    |    |    [1006:1006] <Match> = ♢)♢
|    |    |    |    |    [1006:1006] <Whitespace> = ♢•♢
|    |    |    |    |    [1006:1041] <Braces>
|    |    |    |    |    |    [1006:1006] <Match> = ♢{♢
|    |    |    |    |    |    [1006:1007] <Newline> = ♢¶♢
|    |    |    |    |    |    [1007:1007] <Indenting> = ♢→♢
|    |    |    |    |    |    [1007:1016] <CConditionIf>
|    |    |    |    |    |    |    [1007:1007] <Match> = ♢if♢
|    |    |    |    |    |    |    [1007:1007] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1007:1007] <Parenthesis>
|    |    |    |    |    |    |    |    [1007:1007] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [1007:1007] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [1007:1007] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [1007:1007] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    [1007:1007] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1007:1007] <Text> = ♢isConverted♢
|    |    |    |    |    |    |    |    |    [1007:1007] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [1007:1007] <Match> = ♢)♢
|    |    |    |    |    |    |    [1007:1007] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1007:1016] <Braces>
|    |    |    |    |    |    |    |    [1007:1007] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [1007:1008] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1008:1008] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [1008:1008] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    [1008:1008] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1008:1008] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [1008:1008] <Text> = ♢newFormatName♢
|    |    |    |    |    |    |    |    [1008:1008] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1008:1008] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [1008:1008] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1008:1008] <Text> = ♢containsAttachments♢
|    |    |    |    |    |    |    |    [1008:1008] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1008:1008] <QuestionMark> = ♢?♢
|    |    |    |    |    |    |    |    [1008:1008] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1008:1008] <CFunctionCall>
|    |    |    |    |    |    |    |    |    [1008:1008] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    [1008:1008] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [1008:1008] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [1008:1008] <ObjCString> = ♢@"rich•text•with•graphics•(RTFD)"♢
|    |    |    |    |    |    |    |    |    |    [1008:1008] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    [1008:1008] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1008:1008] <ObjCString> = ♢@"Rich•text•with•graphics•file•format•name,•displayed•in•alert"♢
|    |    |    |    |    |    |    |    |    |    [1008:1008] <Match> = ♢)♢
|    |    |    |    |    |    |    |    [1008:1008] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1008:1009] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1009:1009] <Indenting> = ♢→→→→→→→••♢
|    |    |    |    |    |    |    |    [1009:1009] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [1009:1009] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1009:1009] <CFunctionCall>
|    |    |    |    |    |    |    |    |    [1009:1009] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    [1009:1009] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [1009:1009] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [1009:1009] <ObjCString> = ♢@"rich•text"♢
|    |    |    |    |    |    |    |    |    |    [1009:1009] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    [1009:1009] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1009:1009] <ObjCString> = ♢@"Rich•text•file•format•name,•displayed•in•alert"♢
|    |    |    |    |    |    |    |    |    |    [1009:1009] <Match> = ♢)♢
|    |    |    |    |    |    |    |    [1009:1009] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [1009:1010] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1010:1010] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [1010:1010] <Text> = ♢error♢
|    |    |    |    |    |    |    |    [1010:1010] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1010:1010] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [1010:1010] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1010:1015] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [1010:1010] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [1010:1010] <Match> = ♢NSError♢
|    |    |    |    |    |    |    |    |    [1010:1010] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1010:1010] <Text> = ♢errorWithDomain♢
|    |    |    |    |    |    |    |    |    [1010:1010] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1010:1010] <Text> = ♢TextEditErrorDomain♢
|    |    |    |    |    |    |    |    |    [1010:1010] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1010:1010] <Text> = ♢code♢
|    |    |    |    |    |    |    |    |    [1010:1010] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1010:1010] <Text> = ♢TextEditSaveErrorConvertedDocument♢
|    |    |    |    |    |    |    |    |    [1010:1010] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1010:1010] <Text> = ♢userInfo♢
|    |    |    |    |    |    |    |    |    [1010:1010] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1010:1015] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [1010:1010] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [1010:1010] <Match> = ♢NSDictionary♢
|    |    |    |    |    |    |    |    |    |    [1010:1010] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1010:1010] <Text> = ♢dictionaryWithObjectsAndKeys♢
|    |    |    |    |    |    |    |    |    |    [1010:1010] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [1010:1011] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1011:1011] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [1011:1011] <CFunctionCall>
|    |    |    |    |    |    |    |    |    |    |    [1011:1011] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    |    |    [1011:1011] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    [1011:1011] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    [1011:1011] <ObjCString> = ♢@"Please•supply•a•new•name."♢
|    |    |    |    |    |    |    |    |    |    |    |    [1011:1011] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    |    [1011:1011] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [1011:1011] <ObjCString> = ♢@"Title•of•alert•panel•which•brings•up•a•warning•while•saving,•asking•for•new•name"♢
|    |    |    |    |    |    |    |    |    |    |    |    [1011:1011] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    [1011:1011] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    [1011:1011] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1011:1011] <Text> = ♢NSLocalizedDescriptionKey,♢
|    |    |    |    |    |    |    |    |    |    [1011:1012] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1012:1012] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [1012:1012] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [1012:1012] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [1012:1012] <Match> = ♢NSString♢
|    |    |    |    |    |    |    |    |    |    |    [1012:1012] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1012:1012] <Text> = ♢stringWithFormat♢
|    |    |    |    |    |    |    |    |    |    |    [1012:1012] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    [1012:1012] <CFunctionCall>
|    |    |    |    |    |    |    |    |    |    |    |    [1012:1012] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    |    |    |    [1012:1012] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    [1012:1012] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1012:1012] <ObjCString> = ♢@"This•document•was•converted•from•a•format•that•TextEdit•cannot•save.•It•will•be•saved•in•%@•format•with•a•new•name."♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1012:1012] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1012:1012] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1012:1012] <ObjCString> = ♢@"Contents•of•alert•panel•informing•user•that•they•need•to•supply•a•new•file•name•because•the•file•needs•to•be•saved•using•a•different•format•than•originally•read•in"♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1012:1012] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    [1012:1012] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    [1012:1012] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1012:1012] <Text> = ♢newFormatName♢
|    |    |    |    |    |    |    |    |    |    |    [1012:1012] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [1012:1012] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    [1012:1012] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1012:1012] <Text> = ♢NSLocalizedRecoverySuggestionErrorKey,♢
|    |    |    |    |    |    |    |    |    |    [1012:1012] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1012:1013] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1013:1013] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [1013:1013] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Match> = ♢NSArray♢
|    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Text> = ♢arrayWithObjects♢
|    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    [1013:1013] <CFunctionCall>
|    |    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1013:1013] <ObjCString> = ♢@"Save•with•new•name"♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1013:1013] <ObjCString> = ♢@"Button•choice•allowing•user•to•choose•a•new•name"♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1013:1013] <CFunctionCall>
|    |    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1013:1013] <ObjCString> = ♢@"Cancel"♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1013:1013] <ObjCString> = ♢@"Button•choice•allowing•user•to•cancel."♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1013:1013] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    |    |    |    |    [1013:1013] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [1013:1013] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    [1013:1013] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1013:1013] <Text> = ♢NSLocalizedRecoveryOptionsErrorKey,♢
|    |    |    |    |    |    |    |    |    |    [1013:1014] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1014:1014] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [1014:1014] <Text> = ♢self,♢
|    |    |    |    |    |    |    |    |    |    [1014:1014] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1014:1014] <Text> = ♢NSRecoveryAttempterErrorKey,♢
|    |    |    |    |    |    |    |    |    |    [1014:1015] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1015:1015] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [1015:1015] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    |    |    |    [1015:1015] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [1015:1015] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [1015:1015] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [1015:1016] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1016:1016] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [1016:1016] <Match> = ♢}♢
|    |    |    |    |    |    [1016:1016] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1016:1023] <CConditionElseIf>
|    |    |    |    |    |    |    [1016:1016] <Match> = ♢else•if♢
|    |    |    |    |    |    |    [1016:1016] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1016:1016] <Parenthesis>
|    |    |    |    |    |    |    |    [1016:1016] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [1016:1016] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [1016:1016] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [1016:1016] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    [1016:1016] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1016:1016] <Text> = ♢isLossy♢
|    |    |    |    |    |    |    |    |    [1016:1016] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [1016:1016] <Match> = ♢)♢
|    |    |    |    |    |    |    [1016:1016] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1016:1023] <Braces>
|    |    |    |    |    |    |    |    [1016:1016] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [1016:1017] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1017:1017] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [1017:1017] <Text> = ♢error♢
|    |    |    |    |    |    |    |    [1017:1017] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1017:1017] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [1017:1017] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1017:1022] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [1017:1017] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [1017:1017] <Match> = ♢NSError♢
|    |    |    |    |    |    |    |    |    [1017:1017] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1017:1017] <Text> = ♢errorWithDomain♢
|    |    |    |    |    |    |    |    |    [1017:1017] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1017:1017] <Text> = ♢TextEditErrorDomain♢
|    |    |    |    |    |    |    |    |    [1017:1017] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1017:1017] <Text> = ♢code♢
|    |    |    |    |    |    |    |    |    [1017:1017] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1017:1017] <Text> = ♢TextEditSaveErrorLossyDocument♢
|    |    |    |    |    |    |    |    |    [1017:1017] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1017:1017] <Text> = ♢userInfo♢
|    |    |    |    |    |    |    |    |    [1017:1017] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1017:1022] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [1017:1017] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [1017:1017] <Match> = ♢NSDictionary♢
|    |    |    |    |    |    |    |    |    |    [1017:1017] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1017:1017] <Text> = ♢dictionaryWithObjectsAndKeys♢
|    |    |    |    |    |    |    |    |    |    [1017:1017] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [1017:1018] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1018:1018] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [1018:1018] <CFunctionCall>
|    |    |    |    |    |    |    |    |    |    |    [1018:1018] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    |    |    [1018:1018] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    [1018:1018] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    [1018:1018] <ObjCString> = ♢@"Are•you•sure•you•want•to•overwrite•the•document?"♢
|    |    |    |    |    |    |    |    |    |    |    |    [1018:1018] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    |    [1018:1018] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [1018:1018] <ObjCString> = ♢@"Title•of•alert•panel•which•brings•up•a•warning•about•saving•over•the•same•document"♢
|    |    |    |    |    |    |    |    |    |    |    |    [1018:1018] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    [1018:1018] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    [1018:1018] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1018:1018] <Text> = ♢NSLocalizedDescriptionKey,♢
|    |    |    |    |    |    |    |    |    |    [1018:1019] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1019:1019] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [1019:1019] <CFunctionCall>
|    |    |    |    |    |    |    |    |    |    |    [1019:1019] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    |    |    [1019:1019] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    [1019:1019] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    [1019:1019] <ObjCString> = ♢@"Overwriting•this•document•might•cause•you•to•lose•some•of•the•original•formatting.••Would•you•like•to•save•the•document•using•a•new•name?"♢
|    |    |    |    |    |    |    |    |    |    |    |    [1019:1019] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    |    [1019:1019] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [1019:1019] <ObjCString> = ♢@"Contents•of•alert•panel•informing•user•that•they•need•to•supply•a•new•file•name•because•the•save•might•be•lossy"♢
|    |    |    |    |    |    |    |    |    |    |    |    [1019:1019] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    [1019:1019] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    [1019:1019] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1019:1019] <Text> = ♢NSLocalizedRecoverySuggestionErrorKey,♢
|    |    |    |    |    |    |    |    |    |    [1019:1020] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1020:1020] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [1020:1020] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Match> = ♢NSArray♢
|    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Text> = ♢arrayWithObjects♢
|    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    [1020:1020] <CFunctionCall>
|    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <ObjCString> = ♢@"Save•with•new•name"♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <ObjCString> = ♢@"Button•choice•allowing•user•to•choose•a•new•name"♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1020:1020] <CFunctionCall>
|    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <ObjCString> = ♢@"Overwrite"♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <ObjCString> = ♢@"Button•choice•allowing•user•to•overwrite•the•document."♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1020:1020] <CFunctionCall>
|    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <ObjCString> = ♢@"Cancel"♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <ObjCString> = ♢@"Button•choice•allowing•user•to•cancel."♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1020:1020] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    |    |    |    |    [1020:1020] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [1020:1020] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    [1020:1020] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1020:1020] <Text> = ♢NSLocalizedRecoveryOptionsErrorKey,♢
|    |    |    |    |    |    |    |    |    |    [1020:1021] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1021:1021] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [1021:1021] <Text> = ♢self,♢
|    |    |    |    |    |    |    |    |    |    [1021:1021] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1021:1021] <Text> = ♢NSRecoveryAttempterErrorKey,♢
|    |    |    |    |    |    |    |    |    |    [1021:1022] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1022:1022] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [1022:1022] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    |    |    |    [1022:1022] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [1022:1022] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [1022:1022] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [1022:1023] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1023:1023] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [1023:1023] <Match> = ♢}♢
|    |    |    |    |    |    [1023:1023] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1023:1030] <CConditionElseIf>
|    |    |    |    |    |    |    [1023:1023] <Match> = ♢else•if♢
|    |    |    |    |    |    |    [1023:1023] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1023:1023] <Parenthesis>
|    |    |    |    |    |    |    |    [1023:1023] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [1023:1023] <Text> = ♢containsAttachments♢
|    |    |    |    |    |    |    |    [1023:1023] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1023:1023] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    [1023:1023] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    [1023:1023] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1023:1023] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    [1023:1023] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [1023:1023] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [1023:1023] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [1023:1023] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [1023:1023] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    [1023:1023] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1023:1023] <Text> = ♢writableTypesForSaveOperation♢
|    |    |    |    |    |    |    |    |    |    [1023:1023] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [1023:1023] <Text> = ♢NSSaveAsOperation♢
|    |    |    |    |    |    |    |    |    |    [1023:1023] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [1023:1023] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1023:1023] <Text> = ♢containsObject♢
|    |    |    |    |    |    |    |    |    [1023:1023] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1023:1023] <Text> = ♢currType♢
|    |    |    |    |    |    |    |    |    [1023:1023] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [1023:1023] <Match> = ♢)♢
|    |    |    |    |    |    |    [1023:1023] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1023:1030] <Braces>
|    |    |    |    |    |    |    |    [1023:1023] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [1023:1024] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1024:1024] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [1024:1024] <Text> = ♢error♢
|    |    |    |    |    |    |    |    [1024:1024] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1024:1024] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [1024:1024] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1024:1029] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [1024:1024] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [1024:1024] <Match> = ♢NSError♢
|    |    |    |    |    |    |    |    |    [1024:1024] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1024:1024] <Text> = ♢errorWithDomain♢
|    |    |    |    |    |    |    |    |    [1024:1024] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1024:1024] <Text> = ♢TextEditErrorDomain♢
|    |    |    |    |    |    |    |    |    [1024:1024] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1024:1024] <Text> = ♢code♢
|    |    |    |    |    |    |    |    |    [1024:1024] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1024:1024] <Text> = ♢TextEditSaveErrorRTFDRequired♢
|    |    |    |    |    |    |    |    |    [1024:1024] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1024:1024] <Text> = ♢userInfo♢
|    |    |    |    |    |    |    |    |    [1024:1024] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1024:1029] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [1024:1024] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [1024:1024] <Match> = ♢NSDictionary♢
|    |    |    |    |    |    |    |    |    |    [1024:1024] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1024:1024] <Text> = ♢dictionaryWithObjectsAndKeys♢
|    |    |    |    |    |    |    |    |    |    [1024:1024] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [1024:1025] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1025:1025] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [1025:1025] <CFunctionCall>
|    |    |    |    |    |    |    |    |    |    |    [1025:1025] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    |    |    [1025:1025] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    [1025:1025] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    [1025:1025] <ObjCString> = ♢@"Are•you•sure•you•want•to•save•using•RTFD•format?"♢
|    |    |    |    |    |    |    |    |    |    |    |    [1025:1025] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    |    [1025:1025] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [1025:1025] <ObjCString> = ♢@"Title•of•alert•panel•which•brings•up•a•warning•while•saving"♢
|    |    |    |    |    |    |    |    |    |    |    |    [1025:1025] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    [1025:1025] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    [1025:1025] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1025:1025] <Text> = ♢NSLocalizedDescriptionKey,♢
|    |    |    |    |    |    |    |    |    |    [1025:1026] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1026:1026] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [1026:1026] <CFunctionCall>
|    |    |    |    |    |    |    |    |    |    |    [1026:1026] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    |    |    [1026:1026] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    [1026:1026] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    [1026:1026] <ObjCString> = ♢@"This•document•contains•graphics•and•will•be•saved•using•RTFD•(RTF•with•graphics)•format.•RTFD•documents•are•not•compatible•with•some•applications.•Save•anyway?"♢
|    |    |    |    |    |    |    |    |    |    |    |    [1026:1026] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    |    [1026:1026] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [1026:1026] <ObjCString> = ♢@"Contents•of•alert•panel•informing•user•that•the•document•is•being•converted•from•RTF•to•RTFD,•and•allowing•them•to•cancel,•save•anyway,•or•save•with•new•name"♢
|    |    |    |    |    |    |    |    |    |    |    |    [1026:1026] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    [1026:1026] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    [1026:1026] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1026:1026] <Text> = ♢NSLocalizedRecoverySuggestionErrorKey,♢
|    |    |    |    |    |    |    |    |    |    [1026:1027] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1027:1027] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [1027:1027] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Match> = ♢NSArray♢
|    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Text> = ♢arrayWithObjects♢
|    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    [1027:1027] <CFunctionCall>
|    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <ObjCString> = ♢@"Save•with•new•name"♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <ObjCString> = ♢@"Button•choice•allowing•user•to•choose•a•new•name"♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1027:1027] <CFunctionCall>
|    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <ObjCString> = ♢@"Save"♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <ObjCString> = ♢@"Button•choice•which•allows•the•user•to•save•the•document."♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1027:1027] <CFunctionCall>
|    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <ObjCString> = ♢@"Cancel"♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <ObjCString> = ♢@"Button•choice•allowing•user•to•cancel."♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1027:1027] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    |    |    |    |    [1027:1027] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [1027:1027] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    [1027:1027] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1027:1027] <Text> = ♢NSLocalizedRecoveryOptionsErrorKey,♢
|    |    |    |    |    |    |    |    |    |    [1027:1028] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1028:1028] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [1028:1028] <Text> = ♢self,♢
|    |    |    |    |    |    |    |    |    |    [1028:1028] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1028:1028] <Text> = ♢NSRecoveryAttempterErrorKey,♢
|    |    |    |    |    |    |    |    |    |    [1028:1029] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1029:1029] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [1029:1029] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    |    |    |    [1029:1029] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [1029:1029] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [1029:1029] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [1029:1030] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1030:1030] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [1030:1030] <Match> = ♢}♢
|    |    |    |    |    |    [1030:1030] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1030:1040] <CConditionElseIf>
|    |    |    |    |    |    |    [1030:1030] <Match> = ♢else•if♢
|    |    |    |    |    |    |    [1030:1030] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1030:1030] <Parenthesis>
|    |    |    |    |    |    |    |    [1030:1030] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [1030:1030] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    [1030:1030] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [1030:1030] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [1030:1030] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    [1030:1030] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1030:1030] <Text> = ♢isRichText♢
|    |    |    |    |    |    |    |    |    [1030:1030] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [1030:1030] <Match> = ♢)♢
|    |    |    |    |    |    |    [1030:1030] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1030:1040] <Braces>
|    |    |    |    |    |    |    |    [1030:1030] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [1030:1031] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1031:1031] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [1031:1031] <Text> = ♢NSUInteger♢
|    |    |    |    |    |    |    |    [1031:1031] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1031:1031] <Text> = ♢enc♢
|    |    |    |    |    |    |    |    [1031:1031] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1031:1031] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [1031:1031] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1031:1031] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [1031:1031] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [1031:1031] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    [1031:1031] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1031:1031] <Text> = ♢encodingForSaving♢
|    |    |    |    |    |    |    |    |    [1031:1031] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [1031:1031] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [1031:1032] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1032:1032] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [1032:1032] <CConditionIf>
|    |    |    |    |    |    |    |    |    [1032:1032] <Match> = ♢if♢
|    |    |    |    |    |    |    |    |    [1032:1032] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1032:1032] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [1032:1032] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [1032:1032] <Text> = ♢enc♢
|    |    |    |    |    |    |    |    |    |    [1032:1032] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1032:1032] <Text> = ♢==♢
|    |    |    |    |    |    |    |    |    |    [1032:1032] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1032:1032] <Text> = ♢NoStringEncoding♢
|    |    |    |    |    |    |    |    |    |    [1032:1032] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [1032:1032] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1032:1032] <Text> = ♢enc♢
|    |    |    |    |    |    |    |    |    [1032:1032] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1032:1032] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    [1032:1032] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1032:1032] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [1032:1032] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [1032:1032] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    [1032:1032] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1032:1032] <Text> = ♢encoding♢
|    |    |    |    |    |    |    |    |    |    [1032:1032] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [1032:1032] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [1032:1033] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1033:1033] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [1033:1039] <CConditionIf>
|    |    |    |    |    |    |    |    |    [1033:1033] <Match> = ♢if♢
|    |    |    |    |    |    |    |    |    [1033:1033] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1033:1033] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [1033:1033] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [1033:1033] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    |    |    [1033:1033] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [1033:1033] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [1033:1033] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    [1033:1033] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    [1033:1033] <Match> = ♢textStorage♢
|    |    |    |    |    |    |    |    |    |    |    |    [1033:1033] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [1033:1033] <Text> = ♢string♢
|    |    |    |    |    |    |    |    |    |    |    |    [1033:1033] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    [1033:1033] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1033:1033] <Text> = ♢canBeConvertedToEncoding♢
|    |    |    |    |    |    |    |    |    |    |    [1033:1033] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    [1033:1033] <Text> = ♢enc♢
|    |    |    |    |    |    |    |    |    |    |    [1033:1033] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [1033:1033] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [1033:1033] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1033:1039] <Braces>
|    |    |    |    |    |    |    |    |    |    [1033:1033] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    [1033:1034] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1034:1034] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [1034:1034] <Text> = ♢error♢
|    |    |    |    |    |    |    |    |    |    [1034:1034] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1034:1034] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    |    [1034:1034] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1034:1038] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [1034:1034] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [1034:1034] <Match> = ♢NSError♢
|    |    |    |    |    |    |    |    |    |    |    [1034:1034] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1034:1034] <Text> = ♢errorWithDomain♢
|    |    |    |    |    |    |    |    |    |    |    [1034:1034] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    [1034:1034] <Text> = ♢TextEditErrorDomain♢
|    |    |    |    |    |    |    |    |    |    |    [1034:1034] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1034:1034] <Text> = ♢code♢
|    |    |    |    |    |    |    |    |    |    |    [1034:1034] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    [1034:1034] <Text> = ♢TextEditSaveErrorEncodingInapplicable♢
|    |    |    |    |    |    |    |    |    |    |    [1034:1034] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1034:1034] <Text> = ♢userInfo♢
|    |    |    |    |    |    |    |    |    |    |    [1034:1034] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    [1034:1038] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    [1034:1034] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    [1034:1034] <Match> = ♢NSDictionary♢
|    |    |    |    |    |    |    |    |    |    |    |    [1034:1034] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [1034:1034] <Text> = ♢dictionaryWithObjectsAndKeys♢
|    |    |    |    |    |    |    |    |    |    |    |    [1034:1034] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    [1034:1035] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Match> = ♢NSString♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Text> = ♢stringWithFormat♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <CFunctionCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <ObjCString> = ♢@"This•document•can•no•longer•be•saved•using•its•original•%@•encoding."♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <ObjCString> = ♢@"Title•of•alert•panel•informing•user•that•the•file's•string•encoding•needs•to•be•changed."♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Match> = ♢NSString♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Text> = ♢localizedNameOfStringEncoding♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Text> = ♢enc♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [1035:1035] <Text> = ♢NSLocalizedDescriptionKey,♢
|    |    |    |    |    |    |    |    |    |    |    |    [1035:1036] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    [1036:1036] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    |    [1036:1036] <CFunctionCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    [1036:1036] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1036:1036] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1036:1036] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1036:1036] <ObjCString> = ♢@"Please•choose•another•encoding•(such•as•UTF-8)."♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1036:1036] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1036:1036] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1036:1036] <ObjCString> = ♢@"Subtitle•of•alert•panel•informing•user•that•the•file's•string•encoding•needs•to•be•changed"♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1036:1036] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    |    [1036:1036] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    |    |    |    [1036:1036] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [1036:1036] <Text> = ♢NSLocalizedRecoverySuggestionErrorKey,♢
|    |    |    |    |    |    |    |    |    |    |    |    [1036:1037] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    [1037:1037] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    |    [1037:1037] <Text> = ♢self,♢
|    |    |    |    |    |    |    |    |    |    |    |    [1037:1037] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [1037:1037] <Text> = ♢NSRecoveryAttempterErrorKey,♢
|    |    |    |    |    |    |    |    |    |    |    |    [1037:1038] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    [1038:1038] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    |    [1038:1038] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    |    |    |    |    |    [1038:1038] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    [1038:1038] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [1038:1038] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    [1038:1039] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1039:1039] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    |    |    [1039:1039] <Match> = ♢}♢
|    |    |    |    |    |    |    |    [1039:1040] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1040:1040] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [1040:1040] <Match> = ♢}♢
|    |    |    |    |    |    [1040:1041] <Newline> = ♢¶♢
|    |    |    |    |    |    [1041:1041] <Indenting> = ♢••••♢
|    |    |    |    |    |    [1041:1041] <Match> = ♢}♢
|    |    |    |    [1041:1042] <Newline> = ♢¶♢
|    |    |    |    [1042:1042] <Indenting> = ♢••••♢
|    |    |    |    [1042:1043] <Newline> = ♢¶♢
|    |    |    |    [1043:1043] <Indenting> = ♢••••♢
|    |    |    |    [1043:1045] <CConditionIf>
|    |    |    |    |    [1043:1043] <Match> = ♢if♢
|    |    |    |    |    [1043:1043] <Whitespace> = ♢•♢
|    |    |    |    |    [1043:1043] <Parenthesis>
|    |    |    |    |    |    [1043:1043] <Match> = ♢(♢
|    |    |    |    |    |    [1043:1043] <Text> = ♢error♢
|    |    |    |    |    |    [1043:1043] <Match> = ♢)♢
|    |    |    |    |    [1043:1043] <Whitespace> = ♢•♢
|    |    |    |    |    [1043:1045] <Braces>
|    |    |    |    |    |    [1043:1043] <Match> = ♢{♢
|    |    |    |    |    |    [1043:1044] <Newline> = ♢¶♢
|    |    |    |    |    |    [1044:1044] <Indenting> = ♢→♢
|    |    |    |    |    |    [1044:1044] <ObjCMethodCall>
|    |    |    |    |    |    |    [1044:1044] <Match> = ♢[♢
|    |    |    |    |    |    |    [1044:1044] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [1044:1044] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1044:1044] <Text> = ♢presentError♢
|    |    |    |    |    |    |    [1044:1044] <Colon> = ♢:♢
|    |    |    |    |    |    |    [1044:1044] <Text> = ♢error♢
|    |    |    |    |    |    |    [1044:1044] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1044:1044] <Text> = ♢modalForWindow♢
|    |    |    |    |    |    |    [1044:1044] <Colon> = ♢:♢
|    |    |    |    |    |    |    [1044:1044] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [1044:1044] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [1044:1044] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [1044:1044] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1044:1044] <Text> = ♢windowForSheet♢
|    |    |    |    |    |    |    |    [1044:1044] <Match> = ♢]♢
|    |    |    |    |    |    |    [1044:1044] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1044:1044] <Text> = ♢delegate♢
|    |    |    |    |    |    |    [1044:1044] <Colon> = ♢:♢
|    |    |    |    |    |    |    [1044:1044] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [1044:1044] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1044:1044] <Text> = ♢didPresentSelector♢
|    |    |    |    |    |    |    [1044:1044] <Colon> = ♢:♢
|    |    |    |    |    |    |    [1044:1044] <ObjCSelector>
|    |    |    |    |    |    |    |    [1044:1044] <Match> = ♢@selector♢
|    |    |    |    |    |    |    |    [1044:1044] <Parenthesis>
|    |    |    |    |    |    |    |    |    [1044:1044] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    [1044:1044] <Text> = ♢didPresentErrorWithRecovery♢
|    |    |    |    |    |    |    |    |    [1044:1044] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1044:1044] <Text> = ♢contextInfo♢
|    |    |    |    |    |    |    |    |    [1044:1044] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1044:1044] <Match> = ♢)♢
|    |    |    |    |    |    |    [1044:1044] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1044:1044] <Text> = ♢contextInfo♢
|    |    |    |    |    |    |    [1044:1044] <Colon> = ♢:♢
|    |    |    |    |    |    |    [1044:1044] <CNULL> = ♢NULL♢
|    |    |    |    |    |    |    [1044:1044] <Match> = ♢]♢
|    |    |    |    |    |    [1044:1044] <Semicolon> = ♢;♢
|    |    |    |    |    |    [1044:1045] <Newline> = ♢¶♢
|    |    |    |    |    |    [1045:1045] <Indenting> = ♢••••♢
|    |    |    |    |    |    [1045:1045] <Match> = ♢}♢
|    |    |    |    [1045:1045] <Whitespace> = ♢•♢
|    |    |    |    [1045:1047] <CConditionElse>
|    |    |    |    |    [1045:1045] <Match> = ♢else♢
|    |    |    |    |    [1045:1045] <Whitespace> = ♢•♢
|    |    |    |    |    [1045:1047] <Braces>
|    |    |    |    |    |    [1045:1045] <Match> = ♢{♢
|    |    |    |    |    |    [1045:1046] <Newline> = ♢¶♢
|    |    |    |    |    |    [1046:1046] <Indenting> = ♢→♢
|    |    |    |    |    |    [1046:1046] <ObjCMethodCall>
|    |    |    |    |    |    |    [1046:1046] <Match> = ♢[♢
|    |    |    |    |    |    |    [1046:1046] <ObjCSuper> = ♢super♢
|    |    |    |    |    |    |    [1046:1046] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1046:1046] <Text> = ♢saveDocumentWithDelegate♢
|    |    |    |    |    |    |    [1046:1046] <Colon> = ♢:♢
|    |    |    |    |    |    |    [1046:1046] <Text> = ♢delegate♢
|    |    |    |    |    |    |    [1046:1046] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1046:1046] <Text> = ♢didSaveSelector♢
|    |    |    |    |    |    |    [1046:1046] <Colon> = ♢:♢
|    |    |    |    |    |    |    [1046:1046] <Text> = ♢didSaveSelector♢
|    |    |    |    |    |    |    [1046:1046] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1046:1046] <Text> = ♢contextInfo♢
|    |    |    |    |    |    |    [1046:1046] <Colon> = ♢:♢
|    |    |    |    |    |    |    [1046:1046] <Text> = ♢contextInfo♢
|    |    |    |    |    |    |    [1046:1046] <Match> = ♢]♢
|    |    |    |    |    |    [1046:1046] <Semicolon> = ♢;♢
|    |    |    |    |    |    [1046:1047] <Newline> = ♢¶♢
|    |    |    |    |    |    [1047:1047] <Indenting> = ♢••••♢
|    |    |    |    |    |    [1047:1047] <Match> = ♢}♢
|    |    |    |    [1047:1048] <Newline> = ♢¶♢
|    |    |    |    [1048:1048] <Match> = ♢}♢
|    |    [1048:1049] <Newline> = ♢¶♢
|    |    [1049:1050] <Newline> = ♢¶♢
|    |    [1050:1051] <CComment> = ♢/*•For•plain-text•documents,•we•add•our•own•accessory•view•for•selecting•encodings.•The•plain•text•case•does•not•require•a•format•popup.•¶*/♢
|    |    [1051:1052] <Newline> = ♢¶♢
|    |    [1052:1054] <ObjCMethodImplementation>
|    |    |    [1052:1052] <Match> = ♢-♢
|    |    |    [1052:1052] <Whitespace> = ♢•♢
|    |    |    [1052:1052] <Parenthesis>
|    |    |    |    [1052:1052] <Match> = ♢(♢
|    |    |    |    [1052:1052] <Text> = ♢BOOL♢
|    |    |    |    [1052:1052] <Match> = ♢)♢
|    |    |    [1052:1052] <Text> = ♢shouldRunSavePanelWithAccessoryView♢
|    |    |    [1052:1052] <Whitespace> = ♢•♢
|    |    |    [1052:1054] <Braces>
|    |    |    |    [1052:1052] <Match> = ♢{♢
|    |    |    |    [1052:1053] <Newline> = ♢¶♢
|    |    |    |    [1053:1053] <Indenting> = ♢••••♢
|    |    |    |    [1053:1053] <CFlowReturn>
|    |    |    |    |    [1053:1053] <Match> = ♢return♢
|    |    |    |    |    [1053:1053] <Whitespace> = ♢•♢
|    |    |    |    |    [1053:1053] <ObjCMethodCall>
|    |    |    |    |    |    [1053:1053] <Match> = ♢[♢
|    |    |    |    |    |    [1053:1053] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    [1053:1053] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1053:1053] <Text> = ♢isRichText♢
|    |    |    |    |    |    [1053:1053] <Match> = ♢]♢
|    |    |    |    |    [1053:1053] <Semicolon> = ♢;♢
|    |    |    |    [1053:1054] <Newline> = ♢¶♢
|    |    |    |    [1054:1054] <Match> = ♢}♢
|    |    [1054:1055] <Newline> = ♢¶♢
|    |    [1055:1056] <Newline> = ♢¶♢
|    |    [1056:1057] <CComment> = ♢/*•If•the•document•is•a•converted•version•of•a•document•that•existed•on•disk,•set•the•default•directory•to•the•directory•in•which•the•source•file•(converted•file)•resided•at•the•time•the•document•was•converted.•If•the•document•is•plain•text,•we•additionally•add•an•encoding•popup.•¶*/♢
|    |    [1057:1058] <Newline> = ♢¶♢
|    |    [1058:1119] <ObjCMethodImplementation>
|    |    |    [1058:1058] <Match> = ♢-♢
|    |    |    [1058:1058] <Whitespace> = ♢•♢
|    |    |    [1058:1058] <Parenthesis>
|    |    |    |    [1058:1058] <Match> = ♢(♢
|    |    |    |    [1058:1058] <Text> = ♢BOOL♢
|    |    |    |    [1058:1058] <Match> = ♢)♢
|    |    |    [1058:1058] <Text> = ♢prepareSavePanel♢
|    |    |    [1058:1058] <Colon> = ♢:♢
|    |    |    [1058:1058] <Parenthesis>
|    |    |    |    [1058:1058] <Match> = ♢(♢
|    |    |    |    [1058:1058] <Text> = ♢NSSavePanel♢
|    |    |    |    [1058:1058] <Whitespace> = ♢•♢
|    |    |    |    [1058:1058] <Asterisk> = ♢*♢
|    |    |    |    [1058:1058] <Match> = ♢)♢
|    |    |    [1058:1058] <Text> = ♢savePanel♢
|    |    |    [1058:1058] <Whitespace> = ♢•♢
|    |    |    [1058:1119] <Braces>
|    |    |    |    [1058:1058] <Match> = ♢{♢
|    |    |    |    [1058:1059] <Newline> = ♢¶♢
|    |    |    |    [1059:1059] <Indenting> = ♢••••♢
|    |    |    |    [1059:1059] <Text> = ♢NSPopUpButton♢
|    |    |    |    [1059:1059] <Whitespace> = ♢•♢
|    |    |    |    [1059:1059] <Asterisk> = ♢*♢
|    |    |    |    [1059:1059] <Text> = ♢encodingPopup♢
|    |    |    |    [1059:1059] <Semicolon> = ♢;♢
|    |    |    |    [1059:1060] <Newline> = ♢¶♢
|    |    |    |    [1060:1060] <Indenting> = ♢••••♢
|    |    |    |    [1060:1060] <Text> = ♢NSButton♢
|    |    |    |    [1060:1060] <Whitespace> = ♢•♢
|    |    |    |    [1060:1060] <Asterisk> = ♢*♢
|    |    |    |    [1060:1060] <Text> = ♢extCheckbox♢
|    |    |    |    [1060:1060] <Semicolon> = ♢;♢
|    |    |    |    [1060:1061] <Newline> = ♢¶♢
|    |    |    |    [1061:1061] <Indenting> = ♢••••♢
|    |    |    |    [1061:1061] <Text> = ♢NSUInteger♢
|    |    |    |    [1061:1061] <Whitespace> = ♢•♢
|    |    |    |    [1061:1061] <Text> = ♢cnt♢
|    |    |    |    [1061:1061] <Semicolon> = ♢;♢
|    |    |    |    [1061:1062] <Newline> = ♢¶♢
|    |    |    |    [1062:1062] <Indenting> = ♢••••♢
|    |    |    |    [1062:1062] <Text> = ♢NSString♢
|    |    |    |    [1062:1062] <Whitespace> = ♢•♢
|    |    |    |    [1062:1062] <Asterisk> = ♢*♢
|    |    |    |    [1062:1062] <Text> = ♢string♢
|    |    |    |    [1062:1062] <Semicolon> = ♢;♢
|    |    |    |    [1062:1063] <Newline> = ♢¶♢
|    |    |    |    [1063:1063] <Indenting> = ♢••••♢
|    |    |    |    [1063:1064] <Newline> = ♢¶♢
|    |    |    |    [1064:1064] <Indenting> = ♢••••♢
|    |    |    |    [1064:1070] <CConditionIf>
|    |    |    |    |    [1064:1064] <Match> = ♢if♢
|    |    |    |    |    [1064:1064] <Whitespace> = ♢•♢
|    |    |    |    |    [1064:1064] <Parenthesis>
|    |    |    |    |    |    [1064:1064] <Match> = ♢(♢
|    |    |    |    |    |    [1064:1064] <Text> = ♢defaultDestination♢
|    |    |    |    |    |    [1064:1064] <Match> = ♢)♢
|    |    |    |    |    [1064:1064] <Whitespace> = ♢•♢
|    |    |    |    |    [1064:1070] <Braces>
|    |    |    |    |    |    [1064:1064] <Match> = ♢{♢
|    |    |    |    |    |    [1064:1065] <Newline> = ♢¶♢
|    |    |    |    |    |    [1065:1065] <Indenting> = ♢→♢
|    |    |    |    |    |    [1065:1065] <Text> = ♢NSString♢
|    |    |    |    |    |    [1065:1065] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1065:1065] <Asterisk> = ♢*♢
|    |    |    |    |    |    [1065:1065] <Text> = ♢dirPath♢
|    |    |    |    |    |    [1065:1065] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1065:1065] <Text> = ♢=♢
|    |    |    |    |    |    [1065:1065] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1065:1065] <ObjCMethodCall>
|    |    |    |    |    |    |    [1065:1065] <Match> = ♢[♢
|    |    |    |    |    |    |    [1065:1065] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [1065:1065] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [1065:1065] <Match> = ♢defaultDestination♢
|    |    |    |    |    |    |    |    [1065:1065] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1065:1065] <Text> = ♢path♢
|    |    |    |    |    |    |    |    [1065:1065] <Match> = ♢]♢
|    |    |    |    |    |    |    [1065:1065] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1065:1065] <Text> = ♢stringByDeletingPathExtension♢
|    |    |    |    |    |    |    [1065:1065] <Match> = ♢]♢
|    |    |    |    |    |    [1065:1065] <Semicolon> = ♢;♢
|    |    |    |    |    |    [1065:1066] <Newline> = ♢¶♢
|    |    |    |    |    |    [1066:1066] <Indenting> = ♢→♢
|    |    |    |    |    |    [1066:1066] <Text> = ♢BOOL♢
|    |    |    |    |    |    [1066:1066] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1066:1066] <Text> = ♢isDir♢
|    |    |    |    |    |    [1066:1066] <Semicolon> = ♢;♢
|    |    |    |    |    |    [1066:1067] <Newline> = ♢¶♢
|    |    |    |    |    |    [1067:1067] <Indenting> = ♢→♢
|    |    |    |    |    |    [1067:1069] <CConditionIf>
|    |    |    |    |    |    |    [1067:1067] <Match> = ♢if♢
|    |    |    |    |    |    |    [1067:1067] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1067:1067] <Parenthesis>
|    |    |    |    |    |    |    |    [1067:1067] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [1067:1067] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [1067:1067] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [1067:1067] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [1067:1067] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [1067:1067] <Match> = ♢NSFileManager♢
|    |    |    |    |    |    |    |    |    |    [1067:1067] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1067:1067] <Text> = ♢defaultManager♢
|    |    |    |    |    |    |    |    |    |    [1067:1067] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [1067:1067] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1067:1067] <Text> = ♢fileExistsAtPath♢
|    |    |    |    |    |    |    |    |    [1067:1067] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1067:1067] <Text> = ♢dirPath♢
|    |    |    |    |    |    |    |    |    [1067:1067] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1067:1067] <Text> = ♢isDirectory♢
|    |    |    |    |    |    |    |    |    [1067:1067] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1067:1067] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    [1067:1067] <Text> = ♢isDir♢
|    |    |    |    |    |    |    |    |    [1067:1067] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [1067:1067] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1067:1067] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    [1067:1067] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    [1067:1067] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1067:1067] <Text> = ♢isDir♢
|    |    |    |    |    |    |    |    [1067:1067] <Match> = ♢)♢
|    |    |    |    |    |    |    [1067:1067] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1067:1069] <Braces>
|    |    |    |    |    |    |    |    [1067:1067] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [1067:1068] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1068:1068] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [1068:1068] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [1068:1068] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [1068:1068] <Match> = ♢savePanel♢
|    |    |    |    |    |    |    |    |    [1068:1068] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1068:1068] <Text> = ♢setDirectory♢
|    |    |    |    |    |    |    |    |    [1068:1068] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1068:1068] <Text> = ♢dirPath♢
|    |    |    |    |    |    |    |    |    [1068:1068] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [1068:1068] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [1068:1069] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1069:1069] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [1069:1069] <Match> = ♢}♢
|    |    |    |    |    |    [1069:1070] <Newline> = ♢¶♢
|    |    |    |    |    |    [1070:1070] <Indenting> = ♢••••♢
|    |    |    |    |    |    [1070:1070] <Match> = ♢}♢
|    |    |    |    [1070:1071] <Newline> = ♢¶♢
|    |    |    |    [1071:1071] <Indenting> = ♢••••♢
|    |    |    |    [1071:1072] <Newline> = ♢¶♢
|    |    |    |    [1072:1072] <Indenting> = ♢••••♢
|    |    |    |    [1072:1116] <CConditionIf>
|    |    |    |    |    [1072:1072] <Match> = ♢if♢
|    |    |    |    |    [1072:1072] <Whitespace> = ♢•♢
|    |    |    |    |    [1072:1072] <Parenthesis>
|    |    |    |    |    |    [1072:1072] <Match> = ♢(♢
|    |    |    |    |    |    [1072:1072] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    [1072:1072] <ObjCMethodCall>
|    |    |    |    |    |    |    [1072:1072] <Match> = ♢[♢
|    |    |    |    |    |    |    [1072:1072] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [1072:1072] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1072:1072] <Text> = ♢isRichText♢
|    |    |    |    |    |    |    [1072:1072] <Match> = ♢]♢
|    |    |    |    |    |    [1072:1072] <Match> = ♢)♢
|    |    |    |    |    [1072:1072] <Whitespace> = ♢•♢
|    |    |    |    |    [1072:1116] <Braces>
|    |    |    |    |    |    [1072:1072] <Match> = ♢{♢
|    |    |    |    |    |    [1072:1073] <Newline> = ♢¶♢
|    |    |    |    |    |    [1073:1073] <Indenting> = ♢→♢
|    |    |    |    |    |    [1073:1073] <Text> = ♢BOOL♢
|    |    |    |    |    |    [1073:1073] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1073:1073] <Text> = ♢addExt♢
|    |    |    |    |    |    [1073:1073] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1073:1073] <Text> = ♢=♢
|    |    |    |    |    |    [1073:1073] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1073:1073] <ObjCMethodCall>
|    |    |    |    |    |    |    [1073:1073] <Match> = ♢[♢
|    |    |    |    |    |    |    [1073:1073] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [1073:1073] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [1073:1073] <Match> = ♢NSUserDefaults♢
|    |    |    |    |    |    |    |    [1073:1073] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1073:1073] <Text> = ♢standardUserDefaults♢
|    |    |    |    |    |    |    |    [1073:1073] <Match> = ♢]♢
|    |    |    |    |    |    |    [1073:1073] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1073:1073] <Text> = ♢boolForKey♢
|    |    |    |    |    |    |    [1073:1073] <Colon> = ♢:♢
|    |    |    |    |    |    |    [1073:1073] <Text> = ♢AddExtensionToNewPlainTextFiles♢
|    |    |    |    |    |    |    [1073:1073] <Match> = ♢]♢
|    |    |    |    |    |    [1073:1073] <Semicolon> = ♢;♢
|    |    |    |    |    |    [1073:1074] <Newline> = ♢¶♢
|    |    |    |    |    |    [1074:1074] <Indenting> = ♢→♢
|    |    |    |    |    |    [1074:1074] <CPPComment> = ♢//•If•no•encoding,•figure•out•which•encoding•should•be•default•in•encoding•popup,•set•as•document•encoding.♢
|    |    |    |    |    |    [1074:1075] <Newline> = ♢¶♢
|    |    |    |    |    |    [1075:1075] <Indenting> = ♢→♢
|    |    |    |    |    |    [1075:1075] <Text> = ♢NSStringEncoding♢
|    |    |    |    |    |    [1075:1075] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1075:1075] <Text> = ♢enc♢
|    |    |    |    |    |    [1075:1075] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1075:1075] <Text> = ♢=♢
|    |    |    |    |    |    [1075:1075] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1075:1075] <ObjCMethodCall>
|    |    |    |    |    |    |    [1075:1075] <Match> = ♢[♢
|    |    |    |    |    |    |    [1075:1075] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [1075:1075] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1075:1075] <Text> = ♢encoding♢
|    |    |    |    |    |    |    [1075:1075] <Match> = ♢]♢
|    |    |    |    |    |    [1075:1075] <Semicolon> = ♢;♢
|    |    |    |    |    |    [1075:1076] <Newline> = ♢¶♢
|    |    |    |    |    |    [1076:1076] <Indenting> = ♢→♢
|    |    |    |    |    |    [1076:1076] <ObjCMethodCall>
|    |    |    |    |    |    |    [1076:1076] <Match> = ♢[♢
|    |    |    |    |    |    |    [1076:1076] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [1076:1076] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1076:1076] <Text> = ♢setEncodingForSaving♢
|    |    |    |    |    |    |    [1076:1076] <Colon> = ♢:♢
|    |    |    |    |    |    |    [1076:1076] <Parenthesis>
|    |    |    |    |    |    |    |    [1076:1076] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [1076:1076] <Text> = ♢enc♢
|    |    |    |    |    |    |    |    [1076:1076] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1076:1076] <Text> = ♢==♢
|    |    |    |    |    |    |    |    [1076:1076] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1076:1076] <Text> = ♢NoStringEncoding♢
|    |    |    |    |    |    |    |    [1076:1076] <Match> = ♢)♢
|    |    |    |    |    |    |    [1076:1076] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1076:1076] <QuestionMark> = ♢?♢
|    |    |    |    |    |    |    [1076:1076] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1076:1076] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [1076:1076] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [1076:1076] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    [1076:1076] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1076:1076] <Text> = ♢suggestedDocumentEncoding♢
|    |    |    |    |    |    |    |    [1076:1076] <Match> = ♢]♢
|    |    |    |    |    |    |    [1076:1076] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1076:1076] <Colon> = ♢:♢
|    |    |    |    |    |    |    [1076:1076] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1076:1076] <Text> = ♢enc♢
|    |    |    |    |    |    |    [1076:1076] <Match> = ♢]♢
|    |    |    |    |    |    [1076:1076] <Semicolon> = ♢;♢
|    |    |    |    |    |    [1076:1077] <Newline> = ♢¶♢
|    |    |    |    |    |    [1077:1077] <Indenting> = ♢→♢
|    |    |    |    |    |    [1077:1077] <ObjCMethodCall>
|    |    |    |    |    |    |    [1077:1077] <Match> = ♢[♢
|    |    |    |    |    |    |    [1077:1077] <Match> = ♢savePanel♢
|    |    |    |    |    |    |    [1077:1077] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1077:1077] <Text> = ♢setAccessoryView♢
|    |    |    |    |    |    |    [1077:1077] <Colon> = ♢:♢
|    |    |    |    |    |    |    [1077:1077] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [1077:1077] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [1077:1077] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [1077:1077] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [1077:1077] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [1077:1077] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [1077:1077] <Match> = ♢NSDocumentController♢
|    |    |    |    |    |    |    |    |    |    [1077:1077] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1077:1077] <Text> = ♢sharedDocumentController♢
|    |    |    |    |    |    |    |    |    |    [1077:1077] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [1077:1077] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1077:1077] <Text> = ♢class♢
|    |    |    |    |    |    |    |    |    [1077:1077] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [1077:1077] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1077:1077] <Text> = ♢encodingAccessory♢
|    |    |    |    |    |    |    |    [1077:1077] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [1077:1077] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [1077:1077] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [1077:1077] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    [1077:1077] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1077:1077] <Text> = ♢encodingForSaving♢
|    |    |    |    |    |    |    |    |    [1077:1077] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [1077:1077] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1077:1077] <Text> = ♢includeDefaultEntry♢
|    |    |    |    |    |    |    |    [1077:1077] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [1077:1077] <Text> = ♢NO♢
|    |    |    |    |    |    |    |    [1077:1077] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1077:1077] <Text> = ♢encodingPopUp♢
|    |    |    |    |    |    |    |    [1077:1077] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [1077:1077] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    [1077:1077] <Text> = ♢encodingPopup♢
|    |    |    |    |    |    |    |    [1077:1077] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1077:1077] <Text> = ♢checkBox♢
|    |    |    |    |    |    |    |    [1077:1077] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    [1077:1077] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    [1077:1077] <Text> = ♢extCheckbox♢
|    |    |    |    |    |    |    |    [1077:1077] <Match> = ♢]♢
|    |    |    |    |    |    |    [1077:1077] <Match> = ♢]♢
|    |    |    |    |    |    [1077:1077] <Semicolon> = ♢;♢
|    |    |    |    |    |    [1077:1078] <Newline> = ♢¶♢
|    |    |    |    |    |    [1078:1078] <Indenting> = ♢→♢
|    |    |    |    |    |    [1078:1079] <Newline> = ♢¶♢
|    |    |    |    |    |    [1079:1079] <Indenting> = ♢→♢
|    |    |    |    |    |    [1079:1079] <CPPComment> = ♢//•Set•up•the•checkbox♢
|    |    |    |    |    |    [1079:1080] <Newline> = ♢¶♢
|    |    |    |    |    |    [1080:1080] <Indenting> = ♢→♢
|    |    |    |    |    |    [1080:1080] <ObjCMethodCall>
|    |    |    |    |    |    |    [1080:1080] <Match> = ♢[♢
|    |    |    |    |    |    |    [1080:1080] <Match> = ♢extCheckbox♢
|    |    |    |    |    |    |    [1080:1080] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1080:1080] <Text> = ♢setTitle♢
|    |    |    |    |    |    |    [1080:1080] <Colon> = ♢:♢
|    |    |    |    |    |    |    [1080:1080] <CFunctionCall>
|    |    |    |    |    |    |    |    [1080:1080] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    [1080:1080] <Parenthesis>
|    |    |    |    |    |    |    |    |    [1080:1080] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    [1080:1080] <ObjCString> = ♢@"If•no•extension•is•provided,•use•\\U201c.txt\\U201d."♢
|    |    |    |    |    |    |    |    |    [1080:1080] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    [1080:1080] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1080:1080] <ObjCString> = ♢@"Checkbox•indicating•that•if•the•user•does•not•specify•an•extension•when•saving•a•plain•text•file,•.txt•will•be•used"♢
|    |    |    |    |    |    |    |    |    [1080:1080] <Match> = ♢)♢
|    |    |    |    |    |    |    [1080:1080] <Match> = ♢]♢
|    |    |    |    |    |    [1080:1080] <Semicolon> = ♢;♢
|    |    |    |    |    |    [1080:1081] <Newline> = ♢¶♢
|    |    |    |    |    |    [1081:1081] <Indenting> = ♢→♢
|    |    |    |    |    |    [1081:1081] <ObjCMethodCall>
|    |    |    |    |    |    |    [1081:1081] <Match> = ♢[♢
|    |    |    |    |    |    |    [1081:1081] <Match> = ♢extCheckbox♢
|    |    |    |    |    |    |    [1081:1081] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1081:1081] <Text> = ♢setToolTip♢
|    |    |    |    |    |    |    [1081:1081] <Colon> = ♢:♢
|    |    |    |    |    |    |    [1081:1081] <CFunctionCall>
|    |    |    |    |    |    |    |    [1081:1081] <Match> = ♢NSLocalizedString♢
|    |    |    |    |    |    |    |    [1081:1081] <Parenthesis>
|    |    |    |    |    |    |    |    |    [1081:1081] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    [1081:1081] <ObjCString> = ♢@"Automatically•append•\\U201c.txt\\U201d•to•the•file•name•if•no•known•file•name•extension•is•provided."♢
|    |    |    |    |    |    |    |    |    [1081:1081] <Text> = ♢,♢
|    |    |    |    |    |    |    |    |    [1081:1081] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1081:1081] <ObjCString> = ♢@"Tooltip•for•checkbox•indicating•that•if•the•user•does•not•specify•an•extension•when•saving•a•plain•text•file,•.txt•will•be•used"♢
|    |    |    |    |    |    |    |    |    [1081:1081] <Match> = ♢)♢
|    |    |    |    |    |    |    [1081:1081] <Match> = ♢]♢
|    |    |    |    |    |    [1081:1081] <Semicolon> = ♢;♢
|    |    |    |    |    |    [1081:1082] <Newline> = ♢¶♢
|    |    |    |    |    |    [1082:1082] <Indenting> = ♢→♢
|    |    |    |    |    |    [1082:1082] <ObjCMethodCall>
|    |    |    |    |    |    |    [1082:1082] <Match> = ♢[♢
|    |    |    |    |    |    |    [1082:1082] <Match> = ♢extCheckbox♢
|    |    |    |    |    |    |    [1082:1082] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1082:1082] <Text> = ♢setState♢
|    |    |    |    |    |    |    [1082:1082] <Colon> = ♢:♢
|    |    |    |    |    |    |    [1082:1082] <Text> = ♢addExt♢
|    |    |    |    |    |    |    [1082:1082] <Match> = ♢]♢
|    |    |    |    |    |    [1082:1082] <Semicolon> = ♢;♢
|    |    |    |    |    |    [1082:1083] <Newline> = ♢¶♢
|    |    |    |    |    |    [1083:1083] <Indenting> = ♢→♢
|    |    |    |    |    |    [1083:1083] <ObjCMethodCall>
|    |    |    |    |    |    |    [1083:1083] <Match> = ♢[♢
|    |    |    |    |    |    |    [1083:1083] <Match> = ♢extCheckbox♢
|    |    |    |    |    |    |    [1083:1083] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1083:1083] <Text> = ♢setAction♢
|    |    |    |    |    |    |    [1083:1083] <Colon> = ♢:♢
|    |    |    |    |    |    |    [1083:1083] <ObjCSelector>
|    |    |    |    |    |    |    |    [1083:1083] <Match> = ♢@selector♢
|    |    |    |    |    |    |    |    [1083:1083] <Parenthesis>
|    |    |    |    |    |    |    |    |    [1083:1083] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    [1083:1083] <Text> = ♢appendPlainTextExtensionChanged♢
|    |    |    |    |    |    |    |    |    [1083:1083] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1083:1083] <Match> = ♢)♢
|    |    |    |    |    |    |    [1083:1083] <Match> = ♢]♢
|    |    |    |    |    |    [1083:1083] <Semicolon> = ♢;♢
|    |    |    |    |    |    [1083:1084] <Newline> = ♢¶♢
|    |    |    |    |    |    [1084:1084] <Indenting> = ♢→♢
|    |    |    |    |    |    [1084:1084] <ObjCMethodCall>
|    |    |    |    |    |    |    [1084:1084] <Match> = ♢[♢
|    |    |    |    |    |    |    [1084:1084] <Match> = ♢extCheckbox♢
|    |    |    |    |    |    |    [1084:1084] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1084:1084] <Text> = ♢setTarget♢
|    |    |    |    |    |    |    [1084:1084] <Colon> = ♢:♢
|    |    |    |    |    |    |    [1084:1084] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [1084:1084] <Match> = ♢]♢
|    |    |    |    |    |    [1084:1084] <Semicolon> = ♢;♢
|    |    |    |    |    |    [1084:1085] <Newline> = ♢¶♢
|    |    |    |    |    |    [1085:1085] <Indenting> = ♢→♢
|    |    |    |    |    |    [1085:1088] <CConditionIf>
|    |    |    |    |    |    |    [1085:1085] <Match> = ♢if♢
|    |    |    |    |    |    |    [1085:1085] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1085:1085] <Parenthesis>
|    |    |    |    |    |    |    |    [1085:1085] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [1085:1085] <Text> = ♢addExt♢
|    |    |    |    |    |    |    |    [1085:1085] <Match> = ♢)♢
|    |    |    |    |    |    |    [1085:1085] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1085:1088] <Braces>
|    |    |    |    |    |    |    |    [1085:1085] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [1085:1086] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1086:1086] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [1086:1086] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [1086:1086] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [1086:1086] <Match> = ♢savePanel♢
|    |    |    |    |    |    |    |    |    [1086:1086] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1086:1086] <Text> = ♢setAllowedFileTypes♢
|    |    |    |    |    |    |    |    |    [1086:1086] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1086:1086] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [1086:1086] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [1086:1086] <Match> = ♢NSArray♢
|    |    |    |    |    |    |    |    |    |    [1086:1086] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1086:1086] <Text> = ♢arrayWithObject♢
|    |    |    |    |    |    |    |    |    |    [1086:1086] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    [1086:1086] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    [1086:1086] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    [1086:1086] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    |    |    |    [1086:1086] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1086:1086] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    |    |    |    [1086:1086] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    [1086:1086] <Text> = ♢kUTTypePlainText♢
|    |    |    |    |    |    |    |    |    |    [1086:1086] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [1086:1086] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [1086:1086] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [1086:1087] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1087:1087] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [1087:1087] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [1087:1087] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [1087:1087] <Match> = ♢savePanel♢
|    |    |    |    |    |    |    |    |    [1087:1087] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1087:1087] <Text> = ♢setAllowsOtherFileTypes♢
|    |    |    |    |    |    |    |    |    [1087:1087] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1087:1087] <Text> = ♢YES♢
|    |    |    |    |    |    |    |    |    [1087:1087] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [1087:1087] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [1087:1088] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1088:1088] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [1088:1088] <Match> = ♢}♢
|    |    |    |    |    |    [1088:1088] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1088:1100] <CConditionElse>
|    |    |    |    |    |    |    [1088:1088] <Match> = ♢else♢
|    |    |    |    |    |    |    [1088:1088] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1088:1100] <Braces>
|    |    |    |    |    |    |    |    [1088:1088] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [1088:1089] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1089:1089] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [1089:1089] <CPPComment> = ♢//•NSDocument•defaults•to•setting•the•allowedFileType•to•kUTTypePlainText,•which•gives•the•fileName•a•".txt"•extension.•We•want•don't•want•to•append•the•extension•for•Untitled•documents.♢
|    |    |    |    |    |    |    |    [1089:1090] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1090:1090] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [1090:1090] <CPPComment> = ♢//•First•we•clear•out•the•allowedFileType•that•NSDocument•set.•We•want•to•allow•anything,•so•we•pass•'nil'.•This•will•prevent•NSSavePanel•from•appending•an•extension.♢
|    |    |    |    |    |    |    |    [1090:1091] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1091:1091] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [1091:1091] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [1091:1091] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [1091:1091] <Match> = ♢savePanel♢
|    |    |    |    |    |    |    |    |    [1091:1091] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1091:1091] <Text> = ♢setAllowedFileTypes♢
|    |    |    |    |    |    |    |    |    [1091:1091] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1091:1091] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    |    |    [1091:1091] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [1091:1091] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [1091:1092] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1092:1092] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [1092:1092] <CPPComment> = ♢//•If•this•document•was•previously•saved,•use•the•URL's•name.♢
|    |    |    |    |    |    |    |    [1092:1093] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1093:1093] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [1093:1093] <Text> = ♢NSString♢
|    |    |    |    |    |    |    |    [1093:1093] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1093:1093] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [1093:1093] <Text> = ♢fileName♢
|    |    |    |    |    |    |    |    [1093:1093] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [1093:1094] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1094:1094] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [1094:1094] <Text> = ♢BOOL♢
|    |    |    |    |    |    |    |    [1094:1094] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1094:1094] <Text> = ♢gotFileName♢
|    |    |    |    |    |    |    |    [1094:1094] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1094:1094] <Text> = ♢=♢
|    |    |    |    |    |    |    |    [1094:1094] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1094:1094] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [1094:1094] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [1094:1094] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [1094:1094] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [1094:1094] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    [1094:1094] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1094:1094] <Text> = ♢fileURL♢
|    |    |    |    |    |    |    |    |    |    [1094:1094] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [1094:1094] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1094:1094] <Text> = ♢getResourceValue♢
|    |    |    |    |    |    |    |    |    [1094:1094] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1094:1094] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    [1094:1094] <Text> = ♢fileName♢
|    |    |    |    |    |    |    |    |    [1094:1094] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1094:1094] <Text> = ♢forKey♢
|    |    |    |    |    |    |    |    |    [1094:1094] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1094:1094] <Text> = ♢NSURLNameKey♢
|    |    |    |    |    |    |    |    |    [1094:1094] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1094:1094] <Text> = ♢error♢
|    |    |    |    |    |    |    |    |    [1094:1094] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1094:1094] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    |    |    [1094:1094] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [1094:1094] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [1094:1095] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1095:1095] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [1095:1095] <CPPComment> = ♢//•If•the•document•has•not•yet•been•seaved,•or•we•couldn't•find•the•fileName,•then•use•the•displayName.♢
|    |    |    |    |    |    |    |    [1095:1095] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1095:1096] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1096:1096] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [1096:1098] <CConditionIf>
|    |    |    |    |    |    |    |    |    [1096:1096] <Match> = ♢if♢
|    |    |    |    |    |    |    |    |    [1096:1096] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1096:1096] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [1096:1096] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [1096:1096] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    |    |    [1096:1096] <Text> = ♢gotFileName♢
|    |    |    |    |    |    |    |    |    |    [1096:1096] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1096:1096] <Text> = ♢||♢
|    |    |    |    |    |    |    |    |    |    [1096:1096] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1096:1096] <Text> = ♢fileName♢
|    |    |    |    |    |    |    |    |    |    [1096:1096] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1096:1096] <Text> = ♢==♢
|    |    |    |    |    |    |    |    |    |    [1096:1096] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1096:1096] <ObjCNil> = ♢nil♢
|    |    |    |    |    |    |    |    |    |    [1096:1096] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [1096:1096] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1096:1098] <Braces>
|    |    |    |    |    |    |    |    |    |    [1096:1096] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    [1096:1097] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1097:1097] <Indenting> = ♢••••••••••••••••♢
|    |    |    |    |    |    |    |    |    |    [1097:1097] <Text> = ♢fileName♢
|    |    |    |    |    |    |    |    |    |    [1097:1097] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1097:1097] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    |    [1097:1097] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1097:1097] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [1097:1097] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [1097:1097] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    |    |    |    |    [1097:1097] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1097:1097] <Text> = ♢displayName♢
|    |    |    |    |    |    |    |    |    |    |    [1097:1097] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [1097:1097] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    [1097:1098] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1098:1098] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    |    |    [1098:1098] <Match> = ♢}♢
|    |    |    |    |    |    |    |    [1098:1099] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1099:1099] <Indenting> = ♢••••••••••••♢
|    |    |    |    |    |    |    |    [1099:1099] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [1099:1099] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [1099:1099] <Match> = ♢savePanel♢
|    |    |    |    |    |    |    |    |    [1099:1099] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1099:1099] <Text> = ♢setNameFieldStringValue♢
|    |    |    |    |    |    |    |    |    [1099:1099] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1099:1099] <Text> = ♢fileName♢
|    |    |    |    |    |    |    |    |    [1099:1099] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [1099:1099] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    [1099:1100] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1100:1100] <Indenting> = ♢••••••••♢
|    |    |    |    |    |    |    |    [1100:1100] <Match> = ♢}♢
|    |    |    |    |    |    [1100:1101] <Newline> = ♢¶♢
|    |    |    |    |    |    [1101:1101] <Indenting> = ♢→♢
|    |    |    |    |    |    [1101:1102] <Newline> = ♢¶♢
|    |    |    |    |    |    [1102:1102] <Indenting> = ♢→♢
|    |    |    |    |    |    [1102:1102] <CPPComment> = ♢//•Further•set•up•the•encoding•popup♢
|    |    |    |    |    |    [1102:1103] <Newline> = ♢¶♢
|    |    |    |    |    |    [1103:1103] <Indenting> = ♢→♢
|    |    |    |    |    |    [1103:1103] <Text> = ♢cnt♢
|    |    |    |    |    |    [1103:1103] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1103:1103] <Text> = ♢=♢
|    |    |    |    |    |    [1103:1103] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1103:1103] <ObjCMethodCall>
|    |    |    |    |    |    |    [1103:1103] <Match> = ♢[♢
|    |    |    |    |    |    |    [1103:1103] <Match> = ♢encodingPopup♢
|    |    |    |    |    |    |    [1103:1103] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1103:1103] <Text> = ♢numberOfItems♢
|    |    |    |    |    |    |    [1103:1103] <Match> = ♢]♢
|    |    |    |    |    |    [1103:1103] <Semicolon> = ♢;♢
|    |    |    |    |    |    [1103:1104] <Newline> = ♢¶♢
|    |    |    |    |    |    [1104:1104] <Indenting> = ♢→♢
|    |    |    |    |    |    [1104:1104] <Text> = ♢string♢
|    |    |    |    |    |    [1104:1104] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1104:1104] <Text> = ♢=♢
|    |    |    |    |    |    [1104:1104] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1104:1104] <ObjCMethodCall>
|    |    |    |    |    |    |    [1104:1104] <Match> = ♢[♢
|    |    |    |    |    |    |    [1104:1104] <Match> = ♢textStorage♢
|    |    |    |    |    |    |    [1104:1104] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1104:1104] <Text> = ♢string♢
|    |    |    |    |    |    |    [1104:1104] <Match> = ♢]♢
|    |    |    |    |    |    [1104:1104] <Semicolon> = ♢;♢
|    |    |    |    |    |    [1104:1105] <Newline> = ♢¶♢
|    |    |    |    |    |    [1105:1105] <Indenting> = ♢→♢
|    |    |    |    |    |    [1105:1113] <CConditionIf>
|    |    |    |    |    |    |    [1105:1105] <Match> = ♢if♢
|    |    |    |    |    |    |    [1105:1105] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1105:1105] <Parenthesis>
|    |    |    |    |    |    |    |    [1105:1105] <Match> = ♢(♢
|    |    |    |    |    |    |    |    [1105:1105] <Text> = ♢cnt♢
|    |    |    |    |    |    |    |    [1105:1105] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1105:1105] <Asterisk> = ♢*♢
|    |    |    |    |    |    |    |    [1105:1105] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1105:1105] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [1105:1105] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [1105:1105] <Match> = ♢string♢
|    |    |    |    |    |    |    |    |    [1105:1105] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1105:1105] <Text> = ♢length♢
|    |    |    |    |    |    |    |    |    [1105:1105] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [1105:1105] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1105:1105] <Text> = ♢<♢
|    |    |    |    |    |    |    |    [1105:1105] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1105:1105] <Text> = ♢5000000♢
|    |    |    |    |    |    |    |    [1105:1105] <Match> = ♢)♢
|    |    |    |    |    |    |    [1105:1105] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1105:1113] <Braces>
|    |    |    |    |    |    |    |    [1105:1105] <Match> = ♢{♢
|    |    |    |    |    |    |    |    [1105:1105] <Whitespace> = ♢→♢
|    |    |    |    |    |    |    |    [1105:1105] <CPPComment> = ♢//•Otherwise•it's•just•too•slow;•would•be•nice•to•make•this•more•dynamic.•With•large•docs•and•many•encodings,•the•items•just•won't•be•validated.♢
|    |    |    |    |    |    |    |    [1105:1106] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1106:1106] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    [1106:1112] <CFlowWhile>
|    |    |    |    |    |    |    |    |    [1106:1106] <Match> = ♢while♢
|    |    |    |    |    |    |    |    |    [1106:1106] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1106:1106] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    [1106:1106] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    [1106:1106] <Text> = ♢cnt--♢
|    |    |    |    |    |    |    |    |    |    [1106:1106] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    [1106:1106] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1106:1112] <Braces>
|    |    |    |    |    |    |    |    |    |    [1106:1106] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    [1106:1106] <Whitespace> = ♢→♢
|    |    |    |    |    |    |    |    |    |    [1106:1106] <CPPComment> = ♢//•No•reason•go•backwards•except•to•use•one•variable•instead•of•two♢
|    |    |    |    |    |    |    |    |    |    [1106:1107] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1107:1107] <Indenting> = ♢••••••••••••••••♢
|    |    |    |    |    |    |    |    |    |    [1107:1107] <Text> = ♢NSStringEncoding♢
|    |    |    |    |    |    |    |    |    |    [1107:1107] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1107:1107] <Text> = ♢encoding♢
|    |    |    |    |    |    |    |    |    |    [1107:1107] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1107:1107] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    |    [1107:1107] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1107:1107] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    [1107:1107] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    [1107:1107] <Text> = ♢NSStringEncoding♢
|    |    |    |    |    |    |    |    |    |    |    [1107:1107] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    [1107:1107] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    [1107:1107] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    [1107:1107] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    [1107:1107] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    [1107:1107] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    [1107:1107] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1107:1107] <Match> = ♢encodingPopup♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1107:1107] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1107:1107] <Text> = ♢itemAtIndex♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1107:1107] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1107:1107] <Text> = ♢cnt♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1107:1107] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    |    [1107:1107] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [1107:1107] <Text> = ♢representedObject♢
|    |    |    |    |    |    |    |    |    |    |    |    [1107:1107] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    [1107:1107] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1107:1107] <Text> = ♢unsignedIntegerValue♢
|    |    |    |    |    |    |    |    |    |    |    [1107:1107] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    [1107:1107] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    [1107:1108] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1108:1108] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [1108:1108] <CPPComment> = ♢//•Hardwire•some•encodings•known•to•allow•any•content♢
|    |    |    |    |    |    |    |    |    |    [1108:1109] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1109:1109] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    [1109:1111] <CConditionIf>
|    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Match> = ♢if♢
|    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Text> = ♢encoding♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Text> = ♢NoStringEncoding♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Text> = ♢encoding♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Text> = ♢NSUnicodeStringEncoding♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Text> = ♢encoding♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Text> = ♢NSUTF8StringEncoding♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Parenthesis>
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Text> = ♢encoding♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Text> = ♢=♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Text> = ♢NSNonLossyASCIIStringEncoding♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Ampersand> = ♢&♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Match> = ♢string♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Text> = ♢canBeConvertedToEncoding♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Text> = ♢encoding♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Match> = ♢)♢
|    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    [1109:1111] <Braces>
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1109] <Match> = ♢{♢
|    |    |    |    |    |    |    |    |    |    |    |    [1109:1110] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    [1110:1110] <Indenting> = ♢→→••••♢
|    |    |    |    |    |    |    |    |    |    |    |    [1110:1110] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    [1110:1110] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1110:1110] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1110:1110] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1110:1110] <Match> = ♢encodingPopup♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1110:1110] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1110:1110] <Text> = ♢itemAtIndex♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1110:1110] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1110:1110] <Text> = ♢cnt♢
|    |    |    |    |    |    |    |    |    |    |    |    |    |    [1110:1110] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1110:1110] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1110:1110] <Text> = ♢setEnabled♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1110:1110] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1110:1110] <Text> = ♢NO♢
|    |    |    |    |    |    |    |    |    |    |    |    |    [1110:1110] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    |    |    |    [1110:1110] <Semicolon> = ♢;♢
|    |    |    |    |    |    |    |    |    |    |    |    [1110:1111] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    |    |    [1111:1111] <Indenting> = ♢→→♢
|    |    |    |    |    |    |    |    |    |    |    |    [1111:1111] <Match> = ♢}♢
|    |    |    |    |    |    |    |    |    |    [1111:1112] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    |    |    [1112:1112] <Indenting> = ♢→••••♢
|    |    |    |    |    |    |    |    |    |    [1112:1112] <Match> = ♢}♢
|    |    |    |    |    |    |    |    [1112:1113] <Newline> = ♢¶♢
|    |    |    |    |    |    |    |    [1113:1113] <Indenting> = ♢→♢
|    |    |    |    |    |    |    |    [1113:1113] <Match> = ♢}♢
|    |    |    |    |    |    [1113:1114] <Newline> = ♢¶♢
|    |    |    |    |    |    [1114:1114] <Indenting> = ♢→♢
|    |    |    |    |    |    [1114:1114] <ObjCMethodCall>
|    |    |    |    |    |    |    [1114:1114] <Match> = ♢[♢
|    |    |    |    |    |    |    [1114:1114] <Match> = ♢encodingPopup♢
|    |    |    |    |    |    |    [1114:1114] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1114:1114] <Text> = ♢setAction♢
|    |    |    |    |    |    |    [1114:1114] <Colon> = ♢:♢
|    |    |    |    |    |    |    [1114:1114] <ObjCSelector>
|    |    |    |    |    |    |    |    [1114:1114] <Match> = ♢@selector♢
|    |    |    |    |    |    |    |    [1114:1114] <Parenthesis>
|    |    |    |    |    |    |    |    |    [1114:1114] <Match> = ♢(♢
|    |    |    |    |    |    |    |    |    [1114:1114] <Text> = ♢encodingPopupChanged♢
|    |    |    |    |    |    |    |    |    [1114:1114] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1114:1114] <Match> = ♢)♢
|    |    |    |    |    |    |    [1114:1114] <Match> = ♢]♢
|    |    |    |    |    |    [1114:1114] <Semicolon> = ♢;♢
|    |    |    |    |    |    [1114:1115] <Newline> = ♢¶♢
|    |    |    |    |    |    [1115:1115] <Indenting> = ♢→♢
|    |    |    |    |    |    [1115:1115] <ObjCMethodCall>
|    |    |    |    |    |    |    [1115:1115] <Match> = ♢[♢
|    |    |    |    |    |    |    [1115:1115] <Match> = ♢encodingPopup♢
|    |    |    |    |    |    |    [1115:1115] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1115:1115] <Text> = ♢setTarget♢
|    |    |    |    |    |    |    [1115:1115] <Colon> = ♢:♢
|    |    |    |    |    |    |    [1115:1115] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [1115:1115] <Match> = ♢]♢
|    |    |    |    |    |    [1115:1115] <Semicolon> = ♢;♢
|    |    |    |    |    |    [1115:1116] <Newline> = ♢¶♢
|    |    |    |    |    |    [1116:1116] <Indenting> = ♢••••♢
|    |    |    |    |    |    [1116:1116] <Match> = ♢}♢
|    |    |    |    [1116:1117] <Newline> = ♢¶♢
|    |    |    |    [1117:1117] <Indenting> = ♢••••♢
|    |    |    |    [1117:1118] <Newline> = ♢¶♢
|    |    |    |    [1118:1118] <Indenting> = ♢••••♢
|    |    |    |    [1118:1118] <CFlowReturn>
|    |    |    |    |    [1118:1118] <Match> = ♢return♢
|    |    |    |    |    [1118:1118] <Whitespace> = ♢•♢
|    |    |    |    |    [1118:1118] <Text> = ♢YES♢
|    |    |    |    |    [1118:1118] <Semicolon> = ♢;♢
|    |    |    |    [1118:1119] <Newline> = ♢¶♢
|    |    |    |    [1119:1119] <Match> = ♢}♢
|    |    [1119:1120] <Newline> = ♢¶♢
|    |    [1120:1121] <Newline> = ♢¶♢
|    |    [1121:1122] <CComment> = ♢/*•If•the•document•does•not•exist•on•disk,•but•it•has•been•converted•from•a•document•that•existed•on•disk,•return•the•base•file•name•without•the•path•extension.•Otherwise•return•the•default•("Untitled").•This•is•used•for•the•window•title•and•for•the•default•name•when•saving.•¶*/♢
|    |    [1122:1123] <Newline> = ♢¶♢
|    |    [1123:1129] <ObjCMethodImplementation>
|    |    |    [1123:1123] <Match> = ♢-♢
|    |    |    [1123:1123] <Whitespace> = ♢•♢
|    |    |    [1123:1123] <Parenthesis>
|    |    |    |    [1123:1123] <Match> = ♢(♢
|    |    |    |    [1123:1123] <Text> = ♢NSString♢
|    |    |    |    [1123:1123] <Whitespace> = ♢•♢
|    |    |    |    [1123:1123] <Asterisk> = ♢*♢
|    |    |    |    [1123:1123] <Match> = ♢)♢
|    |    |    [1123:1123] <Text> = ♢displayName♢
|    |    |    [1123:1123] <Whitespace> = ♢•♢
|    |    |    [1123:1129] <Braces>
|    |    |    |    [1123:1123] <Match> = ♢{♢
|    |    |    |    [1123:1124] <Newline> = ♢¶♢
|    |    |    |    [1124:1124] <Indenting> = ♢••••♢
|    |    |    |    [1124:1126] <CConditionIf>
|    |    |    |    |    [1124:1124] <Match> = ♢if♢
|    |    |    |    |    [1124:1124] <Whitespace> = ♢•♢
|    |    |    |    |    [1124:1124] <Parenthesis>
|    |    |    |    |    |    [1124:1124] <Match> = ♢(♢
|    |    |    |    |    |    [1124:1124] <ExclamationMark> = ♢!♢
|    |    |    |    |    |    [1124:1124] <ObjCMethodCall>
|    |    |    |    |    |    |    [1124:1124] <Match> = ♢[♢
|    |    |    |    |    |    |    [1124:1124] <ObjCSelf> = ♢self♢
|    |    |    |    |    |    |    [1124:1124] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1124:1124] <Text> = ♢fileURL♢
|    |    |    |    |    |    |    [1124:1124] <Match> = ♢]♢
|    |    |    |    |    |    [1124:1124] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1124:1124] <Ampersand> = ♢&♢
|    |    |    |    |    |    [1124:1124] <Ampersand> = ♢&♢
|    |    |    |    |    |    [1124:1124] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1124:1124] <Text> = ♢defaultDestination♢
|    |    |    |    |    |    [1124:1124] <Match> = ♢)♢
|    |    |    |    |    [1124:1124] <Whitespace> = ♢•♢
|    |    |    |    |    [1124:1126] <Braces>
|    |    |    |    |    |    [1124:1124] <Match> = ♢{♢
|    |    |    |    |    |    [1124:1125] <Newline> = ♢¶♢
|    |    |    |    |    |    [1125:1125] <Indenting> = ♢→♢
|    |    |    |    |    |    [1125:1125] <CFlowReturn>
|    |    |    |    |    |    |    [1125:1125] <Match> = ♢return♢
|    |    |    |    |    |    |    [1125:1125] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1125:1125] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [1125:1125] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [1125:1125] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    [1125:1125] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    [1125:1125] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [1125:1125] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [1125:1125] <Match> = ♢NSFileManager♢
|    |    |    |    |    |    |    |    |    |    [1125:1125] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1125:1125] <Text> = ♢defaultManager♢
|    |    |    |    |    |    |    |    |    |    [1125:1125] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [1125:1125] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    [1125:1125] <Text> = ♢displayNameAtPath♢
|    |    |    |    |    |    |    |    |    [1125:1125] <Colon> = ♢:♢
|    |    |    |    |    |    |    |    |    [1125:1125] <ObjCMethodCall>
|    |    |    |    |    |    |    |    |    |    [1125:1125] <Match> = ♢[♢
|    |    |    |    |    |    |    |    |    |    [1125:1125] <Match> = ♢defaultDestination♢
|    |    |    |    |    |    |    |    |    |    [1125:1125] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    |    |    [1125:1125] <Text> = ♢path♢
|    |    |    |    |    |    |    |    |    |    [1125:1125] <Match> = ♢]♢
|    |    |    |    |    |    |    |    |    [1125:1125] <Match> = ♢]♢
|    |    |    |    |    |    |    |    [1125:1125] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1125:1125] <Text> = ♢stringByDeletingPathExtension♢
|    |    |    |    |    |    |    |    [1125:1125] <Match> = ♢]♢
|    |    |    |    |    |    |    [1125:1125] <Semicolon> = ♢;♢
|    |    |    |    |    |    [1125:1126] <Newline> = ♢¶♢
|    |    |    |    |    |    [1126:1126] <Indenting> = ♢••••♢
|    |    |    |    |    |    [1126:1126] <Match> = ♢}♢
|    |    |    |    [1126:1126] <Whitespace> = ♢•♢
|    |    |    |    [1126:1128] <CConditionElse>
|    |    |    |    |    [1126:1126] <Match> = ♢else♢
|    |    |    |    |    [1126:1126] <Whitespace> = ♢•♢
|    |    |    |    |    [1126:1128] <Braces>
|    |    |    |    |    |    [1126:1126] <Match> = ♢{♢
|    |    |    |    |    |    [1126:1127] <Newline> = ♢¶♢
|    |    |    |    |    |    [1127:1127] <Indenting> = ♢→♢
|    |    |    |    |    |    [1127:1127] <CFlowReturn>
|    |    |    |    |    |    |    [1127:1127] <Match> = ♢return♢
|    |    |    |    |    |    |    [1127:1127] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    [1127:1127] <ObjCMethodCall>
|    |    |    |    |    |    |    |    [1127:1127] <Match> = ♢[♢
|    |    |    |    |    |    |    |    [1127:1127] <ObjCSuper> = ♢super♢
|    |    |    |    |    |    |    |    [1127:1127] <Whitespace> = ♢•♢
|    |    |    |    |    |    |    |    [1127:1127] <Text> = ♢displayName♢
|    |    |    |    |    |    |    |    [1127:1127] <Match> = ♢]♢
|    |    |    |    |    |    |    [1127:1127] <Semicolon> = ♢;♢
|    |    |    |    |    |    [1127:1128] <Newline> = ♢¶♢
|    |    |    |    |    |    [1128:1128] <Indenting> = ♢••••♢
|    |    |    |    |    |    [1128:1128] <Match> = ♢}♢
|    |    |    |    [1128:1129] <Newline> = ♢¶♢
|    |    |    |    [1129:1129] <Match> = ♢}♢
|    |    [1129:1130] <Newline> = ♢¶♢
|    |    [1130:1131] <Newline> = ♢¶♢
|    |    [1131:1131] <Match> = ♢@end♢
|    [1131:1132] <Newline> = ♢¶♢
|    [1132:1133] <Newline> = ♢¶♢
|    [1133:1134] <Newline> = ♢¶♢
|    [1134:1135] <CComment> = ♢/*•Truncate•string•to•no•longer•than•truncationLength;•should•be•>•10¶*/♢
|    [1135:1136] <Newline> = ♢¶♢
|    [1136:1140] <CFunctionDefinition>
|    |    [1136:1136] <Text> = ♢NSString♢
|    |    [1136:1136] <Whitespace> = ♢•♢
|    |    [1136:1136] <Asterisk> = ♢*♢
|    |    [1136:1136] <Match> = ♢truncatedString♢
|    |    [1136:1136] <Parenthesis>
|    |    |    [1136:1136] <Match> = ♢(♢
|    |    |    [1136:1136] <Text> = ♢NSString♢
|    |    |    [1136:1136] <Whitespace> = ♢•♢
|    |    |    [1136:1136] <Asterisk> = ♢*♢
|    |    |    [1136:1136] <Text> = ♢str,♢
|    |    |    [1136:1136] <Whitespace> = ♢•♢
|    |    |    [1136:1136] <Text> = ♢NSUInteger♢
|    |    |    [1136:1136] <Whitespace> = ♢•♢
|    |    |    [1136:1136] <Text> = ♢truncationLength♢
|    |    |    [1136:1136] <Match> = ♢)♢
|    |    [1136:1136] <Whitespace> = ♢•♢
|    |    [1136:1140] <Braces>
|    |    |    [1136:1136] <Match> = ♢{♢
|    |    |    [1136:1137] <Newline> = ♢¶♢
|    |    |    [1137:1137] <Indenting> = ♢••••♢
|    |    |    [1137:1137] <Text> = ♢NSUInteger♢
|    |    |    [1137:1137] <Whitespace> = ♢•♢
|    |    |    [1137:1137] <Text> = ♢len♢
|    |    |    [1137:1137] <Whitespace> = ♢•♢
|    |    |    [1137:1137] <Text> = ♢=♢
|    |    |    [1137:1137] <Whitespace> = ♢•♢
|    |    |    [1137:1137] <ObjCMethodCall>
|    |    |    |    [1137:1137] <Match> = ♢[♢
|    |    |    |    [1137:1137] <Match> = ♢str♢
|    |    |    |    [1137:1137] <Whitespace> = ♢•♢
|    |    |    |    [1137:1137] <Text> = ♢length♢
|    |    |    |    [1137:1137] <Match> = ♢]♢
|    |    |    [1137:1137] <Semicolon> = ♢;♢
|    |    |    [1137:1138] <Newline> = ♢¶♢
|    |    |    [1138:1138] <Indenting> = ♢••••♢
|    |    |    [1138:1138] <CConditionIf>
|    |    |    |    [1138:1138] <Match> = ♢if♢
|    |    |    |    [1138:1138] <Whitespace> = ♢•♢
|    |    |    |    [1138:1138] <Parenthesis>
|    |    |    |    |    [1138:1138] <Match> = ♢(♢
|    |    |    |    |    [1138:1138] <Text> = ♢len♢
|    |    |    |    |    [1138:1138] <Whitespace> = ♢•♢
|    |    |    |    |    [1138:1138] <Text> = ♢<♢
|    |    |    |    |    [1138:1138] <Whitespace> = ♢•♢
|    |    |    |    |    [1138:1138] <Text> = ♢truncationLength♢
|    |    |    |    |    [1138:1138] <Match> = ♢)♢
|    |    |    |    [1138:1138] <Whitespace> = ♢•♢
|    |    |    |    [1138:1138] <CFlowReturn>
|    |    |    |    |    [1138:1138] <Match> = ♢return♢
|    |    |    |    |    [1138:1138] <Whitespace> = ♢•♢
|    |    |    |    |    [1138:1138] <Text> = ♢str♢
|    |    |    |    |    [1138:1138] <Semicolon> = ♢;♢
|    |    |    [1138:1139] <Newline> = ♢¶♢
|    |    |    [1139:1139] <Indenting> = ♢••••♢
|    |    |    [1139:1139] <CFlowReturn>
|    |    |    |    [1139:1139] <Match> = ♢return♢
|    |    |    |    [1139:1139] <Whitespace> = ♢•♢
|    |    |    |    [1139:1139] <ObjCMethodCall>
|    |    |    |    |    [1139:1139] <Match> = ♢[♢
|    |    |    |    |    [1139:1139] <ObjCMethodCall>
|    |    |    |    |    |    [1139:1139] <Match> = ♢[♢
|    |    |    |    |    |    [1139:1139] <Match> = ♢str♢
|    |    |    |    |    |    [1139:1139] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1139:1139] <Text> = ♢substringToIndex♢
|    |    |    |    |    |    [1139:1139] <Colon> = ♢:♢
|    |    |    |    |    |    [1139:1139] <Text> = ♢truncationLength♢
|    |    |    |    |    |    [1139:1139] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1139:1139] <Text> = ♢-♢
|    |    |    |    |    |    [1139:1139] <Whitespace> = ♢•♢
|    |    |    |    |    |    [1139:1139] <Text> = ♢10♢
|    |    |    |    |    |    [1139:1139] <Match> = ♢]♢
|    |    |    |    |    [1139:1139] <Whitespace> = ♢•♢
|    |    |    |    |    [1139:1139] <Text> = ♢stringByAppendingString♢
|    |    |    |    |    [1139:1139] <Colon> = ♢:♢
|    |    |    |    |    [1139:1139] <ObjCString> = ♢@"\u2026"♢
|    |    |    |    |    [1139:1139] <Match> = ♢]♢
|    |    |    |    [1139:1139] <Semicolon> = ♢;♢
|    |    |    [1139:1139] <Whitespace> = ♢→♢
|    |    |    [1139:1139] <CPPComment> = ♢//•Unicode•character•2026•is•ellipsis♢
|    |    |    [1139:1140] <Newline> = ♢¶♢
|    |    |    [1140:1140] <Match> = ♢}♢
|    [1140:1141] <Newline> = ♢¶♢
|    [1141:1142] <Newline> = ♢¶♢
