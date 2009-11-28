
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
	[self setFileType:[[NSDocumentController sharedDocumentController] defaultType]];
        [self setPrintInfo:[self printInfo]];
	hasMultiplePages = [[NSUserDefaults standardUserDefaults] boolForKey:ShowPageBreaks];
        [[self undoManager] enableUndoRegistration];
    }
    return self;
}
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
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    if ((ignoreRTF && ([workspace type:typeName conformsToType:(NSString *)kUTTypeRTF] || [workspace type:typeName conformsToType:Word2003XMLType])) || (ignoreHTML && [workspace type:typeName conformsToType:(NSString *)kUTTypeHTML]) || [self isOpenedIgnoringRichText]) {
        [options setObject:NSPlainTextDocumentType forKey:NSDocumentTypeDocumentOption];
	[self setFileType:(NSString *)kUTTypePlainText];
	[self setOpenedIgnoringRichText:YES];
    }
    [[text mutableString] setString:@""];
    NSMutableArray *layoutMgrs = [[text layoutManagers] mutableCopy];
    NSEnumerator *layoutMgrEnum = [layoutMgrs objectEnumerator];
    NSLayoutManager *layoutMgr = nil;
    while (layoutMgr = [layoutMgrEnum nextObject]) [text removeLayoutManager:layoutMgr];
    BOOL retry;
    do {
	BOOL success;
	NSString *docType;
	retry = NO;
	[text beginEditing];
	success = [text readFromURL:absoluteURL options:options documentAttributes:&docAttrs error:outError];
        if (!success) {
	    [text endEditing];
	    layoutMgrEnum = [layoutMgrs objectEnumerator];
	    while (layoutMgr = [layoutMgrEnum nextObject]) [text addLayoutManager:layoutMgr];
	    [layoutMgrs release];
	    return NO;
	}
	docType = [docAttrs objectForKey:NSDocumentTypeDocumentAttribute];
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
		[self setFileType:(NSString *)kUTTypeRTF];
	    }
	    if ([workspace type:[self fileType] conformsToType:(NSString *)kUTTypePlainText]) [self applyDefaultTextAttributes:NO];
	    [text endEditing];
	}
    } while(retry);
    layoutMgrEnum = [layoutMgrs objectEnumerator];
    while (layoutMgr = [layoutMgrEnum nextObject]) [text addLayoutManager:layoutMgr];
    [layoutMgrs release];
    val = [docAttrs objectForKey:NSCharacterEncodingDocumentAttribute];
    [self setEncoding:(val ? [val unsignedIntegerValue] : NoStringEncoding)];
    if (val = [docAttrs objectForKey:NSConvertedDocumentAttribute]) {
        [self setConverted:([val integerValue] > 0)];
        [self setLossy:([val integerValue] < 0)];
    }
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
    viewSizeVal = [docAttrs objectForKey:NSViewSizeDocumentAttribute];
    paperSizeVal = [docAttrs objectForKey:NSPaperSizeDocumentAttribute];
    if (paperSizeVal && NSEqualSizes([paperSizeVal sizeValue], NSZeroSize)) paperSizeVal = nil;
    if (viewSizeVal) {
        [self setViewSize:[viewSizeVal sizeValue]];
        if (paperSizeVal) [self setPaperSize:[paperSizeVal sizeValue]];
    } else {
        if (paperSizeVal) {
            val = [docAttrs objectForKey:NSCocoaVersionDocumentAttribute];
            if (val && ([val integerValue] < 100)) {
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
    NSDictionary *map = [self documentPropertyToAttributeNameMappings];
    for (NSString *property in [self knownDocumentProperties]) [self setValue:[docAttrs objectForKey:[map objectForKey:property]] forKey:property];
    [self setReadOnly:((val = [docAttrs objectForKey:NSReadOnlyDocumentAttribute]) && ([val integerValue] > 0))];
    [[self undoManager] enableUndoRegistration];
    return YES;
}
- (NSDictionary *)defaultTextAttributes:(BOOL)forRichText {
    static NSParagraphStyle *defaultRichParaStyle = nil;
    NSMutableDictionary *textAttributes = [[[NSMutableDictionary alloc] initWithCapacity:2] autorelease];
    if (forRichText) {
	[textAttributes setObject:[NSFont userFontOfSize:0.0] forKey:NSFontAttributeName];
	if (defaultRichParaStyle == nil) {
	    NSInteger cnt;
            NSString *measurementUnits = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleMeasurementUnits"];
            CGFloat tabInterval = ([@"Centimeters" isEqual:measurementUnits]) ? (72.0 / 2.54) : (72.0 / 2.0);
	    NSMutableParagraphStyle *paraStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
	    [paraStyle setTabStops:[NSArray array]];
	    for (cnt = 0; cnt < 12; cnt++) {
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
	NSMutableParagraphStyle *mStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[mStyle setTabStops:[NSArray array]];
	[mStyle setDefaultTabInterval:(charWidth * tabWidth)];
        [textAttributes setObject:[[mStyle copy] autorelease] forKey:NSParagraphStyleAttributeName];
	[textAttributes setObject:plainFont forKey:NSFontAttributeName];
    }
    return textAttributes;
}
- (void)applyDefaultTextAttributes:(BOOL)forRichText {
    NSDictionary *textAttributes = [self defaultTextAttributes:forRichText];
    NSTextStorage *text = [self textStorage];
    [text enumerateAttribute:NSParagraphStyleAttributeName inRange:NSMakeRange(0, [text length]) options:0 usingBlock:^(id paragraphStyle, NSRange paragraphStyleRange, BOOL *stop){
        NSWritingDirection writingDirection = paragraphStyle ? [(NSParagraphStyle *)paragraphStyle baseWritingDirection] : NSWritingDirectionNatural;
        [text enumerateAttribute:NSWritingDirectionAttributeName inRange:paragraphStyleRange options:0 usingBlock:^(id value, NSRange attributeRange, BOOL *stop){
            [value retain];
            [text setAttributes:textAttributes range:attributeRange];
            if (value) [text addAttribute:NSWritingDirectionAttributeName value:value range:attributeRange];
            [value release];
        }];
        if (writingDirection != NSWritingDirectionNatural) [text setBaseWritingDirection:writingDirection range:paragraphStyleRange];
    }];
}
- (NSStringEncoding)suggestedDocumentEncoding {
    NSUInteger enc = NoStringEncoding;
    NSNumber *val = [[NSUserDefaults standardUserDefaults] objectForKey:PlainTextEncodingForWrite];
    if (val) {
	NSStringEncoding chosenEncoding = [val unsignedIntegerValue];
	if ((chosenEncoding != NoStringEncoding)  && (chosenEncoding != NSUnicodeStringEncoding) && (chosenEncoding != NSUTF8StringEncoding)) {
	    if ([[[self textStorage] string] canBeConvertedToEncoding:chosenEncoding]) enc = chosenEncoding;
	}
    }
    if (enc == NoStringEncoding) enc = NSUTF8StringEncoding;
    return enc;
}
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
    id val = nil;
    NSSize size = [self viewSize];
    if (!NSEqualSizes(size, NSZeroSize)) {
	[dict setObject:[NSValue valueWithSize:size] forKey:NSViewSizeDocumentAttribute];
    }
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
    for (NSString *property in [self knownDocumentProperties]) {
	id value = [self valueForKey:property];
	if (value && ![value isEqual:@""] && ![value isEqual:[NSArray array]]) [dict setObject:value forKey:[[self documentPropertyToAttributeNameMappings] objectForKey:property]];
    }
    NSFileWrapper *result = nil;
    if (docType == NSRTFDTextDocumentType || (docType == NSPlainTextDocumentType && ![self isOpenedIgnoringRichText])) {
        result = [text fileWrapperFromRange:range documentAttributes:dict error:outError];
    } else {
    	NSData *data = [text dataFromRange:range documentAttributes:dict error:outError];
	if (data) {
	    result = [[[NSFileWrapper alloc] initRegularFileWithContents:data] autorelease];
	    if (!result && outError) *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:nil];
        }
    }
    return result;
}
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
- (void)setHyphenationFactor:(float)factor {
    hyphenationFactor = factor;
}
- (float)hyphenationFactor {
    return hyphenationFactor;
}
- (NSUInteger)encoding {
    return documentEncoding;
}
- (void)setEncoding:(NSUInteger)encoding {
    documentEncoding = encoding;
}
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
- (BOOL)isTransient {
    return transient;
}
- (void)setTransient:(BOOL)flag {
    transient = flag;
}
- (BOOL)isTransientAndCanBeReplaced {
    if (![self isTransient]) return NO;
    for (NSWindowController *controller in [self windowControllers]) if ([[controller window] attachedSheet]) return NO;
    return YES;
}
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
- (BOOL)hasDocumentProperties {
    for (NSString *key in [self knownDocumentProperties]) {
	id value = [self valueForKey:key];
	if (value && ![value isEqual:[[NSUserDefaults standardUserDefaults] objectForKey:key]]) return YES;
    }
    return NO;
}
- (void)clearDocumentProperties {
    for (NSString *key in [self knownDocumentProperties]) [self setValue:nil forKey:key];
}
- (void)setDocumentPropertiesToDefaults {
    for (NSString *key in [self knownDocumentProperties]) [self setValue:[[NSUserDefaults standardUserDefaults] objectForKey:key] forKey:key];
}
- (void)setValue:(id)value forDocumentProperty:(NSString *)property {
    id oldValue = [self valueForKey:property];
    [[[self undoManager] prepareWithInvocationTarget:self] setValue:oldValue forDocumentProperty:property];
    [[self undoManager] setActionName:NSLocalizedString(property, "")];
    [super setValue:value forKey:property];
}
- (void)setValue:(id)value forKey:(NSString *)key {
    if ([[self knownDocumentProperties] containsObject:key]) {
	[self setValue:value forDocumentProperty:key];
    } else {
	[super setValue:value forKey:key];
    }
}
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
    [[[self windowControllers] objectAtIndex:0] doForegroundLayoutToCharacterIndex:NSIntegerMax];
    NSPrintPanel *printPanel = [op printPanel];
    [printPanel addAccessoryController:[[[PrintPanelAccessoryController alloc] init] autorelease]];
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
    return ( [self isRichText]
	     && ((length > 0)
		 && (attrs = [textStorage attributesAtIndex:0 effectiveRange:&range])
		 && ((range.length < length)
		     || ![[self defaultTextAttributes:YES] isEqual:attrs])
		 )
	     || [self hasDocumentProperties]);
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
    [self setHyphenationFactor:(currentHyphenation > 0.0) ? 0.0 : 0.9];
}
- (void)appendPlainTextExtensionChanged:(id)sender {
    NSSavePanel *panel = (NSSavePanel *)[sender window];
    [panel setAllowsOtherFileTypes:[sender state]];
    [panel setAllowedFileTypes:[sender state] ? [NSArray arrayWithObject:(NSString *)kUTTypePlainText] : nil];
}
- (void)encodingPopupChanged:(NSPopUpButton *)popup {
    [self setEncodingForSaving:[[[popup selectedItem] representedObject] unsignedIntegerValue]];
}
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
- (void)setTextStorage:(id)ts {
    NSAttributedString *textStorageCopy = [[self textStorage] copy];
    [[self undoManager] registerUndoWithTarget:self selector:@selector(setTextStorage:) object:textStorageCopy];
    [textStorageCopy release];
    if ([ts isKindOfClass:[NSAttributedString class]]) {
        [[self textStorage] replaceCharactersInRange:NSMakeRange(0, [[self textStorage] length]) withAttributedString:ts];
    } else {
        [[self textStorage] replaceCharactersInRange:NSMakeRange(0, [[self textStorage] length]) withString:ts];
    }
}
- (IBAction)revertDocumentToSaved:(id)sender {
    if( [self fileURL] == nil && defaultDestination != nil ) {
        [self setFileURL: defaultDestination];
    }
    [super revertDocumentToSaved:sender];
}
- (BOOL)revertToContentsOfURL:(NSURL *)url ofType:(NSString *)type error:(NSError **)outError {
    BOOL success = [super revertToContentsOfURL:url ofType:type error:outError];
    if (success) {
        [defaultDestination release];
        defaultDestination = nil;
        [self setHasMultiplePages:hasMultiplePages];
        [[self windowControllers] makeObjectsPerformSelector:@selector(setupTextViewForDocument)];
        [[self undoManager] removeAllActions];
    } else {
        [self setFileURL:nil];
    }
    return success;
}
- (IBAction)saveDocumentAsPDFTo:(id)sender {
    [self printDocumentWithSettings:[NSDictionary dictionaryWithObjectsAndKeys:NSPrintSaveJob, NSPrintJobDisposition, nil] showPrintPanel:NO delegate:nil didPrintSelector:NULL contextInfo:NULL];
}
@end
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
    if ([myControllers count] == 0) {
        [self addWindowController:[[[DocumentWindowController allocWithZone:[self zone]] init] autorelease]];
    }
}
- (NSArray *)writableTypesForSaveOperation:(NSSaveOperationType)saveOperation {
    NSMutableArray *outArray = [[[[self class] writableTypes] mutableCopy] autorelease];
    if (saveOperation == NSSaveAsOperation) {
	if ([self isRichText]) {
	    [outArray removeObject:(NSString *)kUTTypePlainText];
	}
	if ([textStorage containsAttachments]) {
	    [outArray setArray:[NSArray arrayWithObjects:(NSString *)kUTTypeRTFD, (NSString *)kUTTypeWebArchive, nil]];
	}
    }
    return outArray;
}
- (BOOL)keepBackupFile {
    return ![[NSUserDefaults standardUserDefaults] boolForKey:DeleteBackup];
}
- (void)updateChangeCount:(NSDocumentChangeType)change {
    [self setTransient:NO];
    [super updateChangeCount:change];
}
- (BOOL)saveToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError {
    [[self windowControllers] makeObjectsPerformSelector:@selector(breakUndoCoalescing)];
    BOOL success = [super saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation error:outError];
    if (success && (saveOperation == NSSaveOperation || (saveOperation == NSSaveAsOperation))) {
	if ([self encodingForSaving] != NoStringEncoding) [self setEncoding:[self encodingForSaving]];
    }
    [self setEncodingForSaving:NoStringEncoding];
    return success;
}
- (NSString *)autosavingFileType {
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    NSString *type = [super autosavingFileType];
    if ([workspace type:type conformsToType:(NSString *)kUTTypeRTFD] || [workspace type:type conformsToType:(NSString *)kUTTypeWebArchive] || [workspace type:type conformsToType:(NSString *)kUTTypePlainText]) return type;
    if ([textStorage containsAttachments]) return (NSString *)kUTTypeRTFD;
    return type;
}
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
		if (recoveryOptionIndex == 0) {
		    [self setFileType:(NSString *)([textStorage containsAttachments] ? kUTTypeRTFD : kUTTypeRTF)];
		    [self setFileURL:nil];
		    [self setConverted:NO];
		    saveAgain = YES;
		}
		break;
	    case TextEditSaveErrorLossyDocument:
		if (recoveryOptionIndex == 0) {
		    [self setFileURL:nil];
		    [self setLossy:NO];
		    saveAgain = YES;
		} else if (recoveryOptionIndex == 1) {
		    [self setLossy:NO];
		    saveAgain = YES;
		}
		break;
	    case TextEditSaveErrorRTFDRequired:
		if (recoveryOptionIndex == 0) {
		    [self setFileType:(NSString *)kUTTypeRTFD];
		    [self setFileURL:nil];
		    saveAgain = YES;
		} else if (recoveryOptionIndex == 1) {
		    NSString *oldFilename = [[self fileURL] path];
		    NSError *newError;
		    if (![self saveToURL:[NSURL fileURLWithPath:[[oldFilename stringByDeletingPathExtension] stringByAppendingPathExtension:@"rtfd"]] ofType:(NSString *)kUTTypeRTFD forSaveOperation:NSSaveAsOperation error:&newError]) {
			[self presentError:newError modalForWindow:[self windowForSheet] delegate:nil didPresentSelector:NULL contextInfo:contextInfo];
		    } else {
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
- (BOOL)shouldRunSavePanelWithAccessoryView {
    return [self isRichText];
}
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
	NSStringEncoding enc = [self encoding];
	[self setEncodingForSaving:(enc == NoStringEncoding) ? [self suggestedDocumentEncoding] : enc];
	[savePanel setAccessoryView:[[[NSDocumentController sharedDocumentController] class] encodingAccessory:[self encodingForSaving] includeDefaultEntry:NO encodingPopUp:&encodingPopup checkBox:&extCheckbox]];
	[extCheckbox setTitle:NSLocalizedString(@"If no extension is provided, use \\U201c.txt\\U201d.", @"Checkbox indicating that if the user does not specify an extension when saving a plain text file, .txt will be used")];
	[extCheckbox setToolTip:NSLocalizedString(@"Automatically append \\U201c.txt\\U201d to the file name if no known file name extension is provided.", @"Tooltip for checkbox indicating that if the user does not specify an extension when saving a plain text file, .txt will be used")];
	[extCheckbox setState:addExt];
	[extCheckbox setAction:@selector(appendPlainTextExtensionChanged:)];
	[extCheckbox setTarget:self];
	if (addExt) {
	    [savePanel setAllowedFileTypes:[NSArray arrayWithObject:(NSString *)kUTTypePlainText]];
	    [savePanel setAllowsOtherFileTypes:YES];
	} else {
            [savePanel setAllowedFileTypes:nil];
            NSString *fileName;
            BOOL gotFileName = [[self fileURL] getResourceValue:&fileName forKey:NSURLNameKey error:nil];
            
            if (!gotFileName || fileName == nil) {
                fileName = [self displayName];
            }
            [savePanel setNameFieldStringValue:fileName];
        }
	cnt = [encodingPopup numberOfItems];
	string = [textStorage string];
	if (cnt * [string length] < 5000000) {
	    while (cnt--) {
                NSStringEncoding encoding = (NSStringEncoding)[[[encodingPopup itemAtIndex:cnt] representedObject] unsignedIntegerValue];
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
- (NSString *)displayName {
    if (![self fileURL] && defaultDestination) {
	return [[[NSFileManager defaultManager] displayNameAtPath:[defaultDestination path]] stringByDeletingPathExtension];
    } else {
	return [super displayName];
    }
}
@end
NSString *truncatedString(NSString *str, NSUInteger truncationLength) {
    NSUInteger len = [str length];
    if (len < truncationLength) return str;
    return [[str substringToIndex:truncationLength - 10] stringByAppendingString:@"\u2026"];
}
