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

#import "MyDocument.h"

#define kTabWidth 4

@interface RulerView : NSRulerView {
    NSTextView* _textView;
}
@property(nonatomic, assign) NSTextView* textView;
@end

@implementation RulerView

@synthesize textView=_textView;

- (CGFloat) requiredThickness {
    return 36;
}

- (void) drawRect:(NSRect)aRect {
    static NSDictionary* attributes = nil;
    static NSColor* backColor = nil;
    static NSColor* lineColor = nil;
    NSRect bounds = [self bounds];
    unsigned start, i;
    NSPoint point;
    float offset;
    
    if(backColor == nil)
    	backColor = [[NSColor colorWithDeviceRed:0.90 green:0.90 blue:0.90 alpha:1.0] retain];
    if(lineColor == nil)
    	lineColor = [[NSColor grayColor] retain];
    if(attributes == nil)
    	attributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSColor darkGrayColor], NSForegroundColorAttributeName, [NSFont systemFontOfSize:10], NSFontAttributeName, nil];
    
    [backColor set];
    NSRectFill(aRect);
    [lineColor set];
    NSFrameRect(NSMakeRect(bounds.origin.x + bounds.size.width - 1, aRect.origin.y, 1, aRect.size.height));
    
    start = ([_textView visibleRect].origin.y + aRect.origin.y) / 14 + 1;
    offset = fmodf([_textView visibleRect].origin.y + aRect.origin.y, 14);
    for(i = 0; i < aRect.size.height / 14 + 1; ++i) {
        point.x = (start + i < 10 ? bounds.origin.x + 23 : (start + i < 100 ? bounds.origin.x + 17 : (start + i < 1000 ? bounds.origin.x + 11 : bounds.origin.x + 5)));
        point.y = (aRect.origin.y / 14 + i) * 14 - offset;
        [[NSString stringWithFormat:@"%i", start + i] drawAtPoint:point withAttributes:attributes];
    }
}

@end

@implementation MyDocument

@synthesize textView=_textView, pathControl=_pathControl, coloringButton=_coloringButton;

- (void) dealloc {
    [_sourceRoot release];
    [_buttons release];
    [_colors release];
    
    [super dealloc];
}

- (NSString*) windowNibName {
    return @"MyDocument";
}

static NSComparisonResult _SortFunction(Class class1, Class class2, void* context) {
    NSString* name1 = [class1 name];
    NSString* name2 = [class2 name];
    return [name1 caseInsensitiveCompare:name2];
}

static void _FindUsedClasses(SourceNode* node, NSMutableSet* set) {
    [set addObject:[node class]];
    for(node in node.children)
        _FindUsedClasses(node, set);
}

- (void) windowControllerDidLoadNib:(NSWindowController*)controller {
    [super windowControllerDidLoadNib:controller];

    [_textView setMaxSize:NSMakeSize(10000000, 10000000)];
    [_textView setAutoresizingMask:NSViewNotSizable];
    [_textView setFont:[NSFont fontWithName:@"Monaco" size:10]];
    [_textView setTextColor:[NSColor darkGrayColor]];
    NSMutableParagraphStyle* style = [[NSMutableParagraphStyle alloc] init];
    [style setTabStops:[NSArray array]];
    for(NSUInteger i = 0; i < 128; ++i) {
        NSTextTab* tabStop = [[NSTextTab alloc] initWithType:NSLeftTabStopType location:(i * kTabWidth * 6)];
        [style addTabStop:tabStop];
        [tabStop release];
    }
    [[_textView textStorage] addAttributes:[NSDictionary dictionaryWithObject:style forKey:NSParagraphStyleAttributeName] range:NSMakeRange(0, [[[_textView textStorage] string] length])];
    [style release];
    
    NSScrollView* scrollView = (NSScrollView*)[[_textView superview] superview];
    if([scrollView isKindOfClass:[NSScrollView class]]) {
        NSTextContainer* container = [[[_textView layoutManager] textContainers] objectAtIndex:0];
        Class rulerClass = [NSScrollView rulerViewClass];
        [NSScrollView setRulerViewClass:[RulerView class]];
        [scrollView setHasVerticalRuler:YES];
        [scrollView setRulersVisible:YES];
        [NSScrollView setRulerViewClass:rulerClass];
        RulerView* rulerView = (RulerView*)[scrollView verticalRulerView];
        [rulerView setTextView:_textView];
        [rulerView setRuleThickness:36];
        [scrollView setLineScroll:14];
        [container setWidthTracksTextView:NO];
        [container setHeightTracksTextView:NO];
        [container setContainerSize:NSMakeSize(10000000, 10000000)]; //NOTE: This forces a refresh
        [_textView setHorizontallyResizable:YES];
    }
    
    scrollView = (NSScrollView*)[[[_coloringButton superview] superview] superview];
    NSData* data = [NSKeyedArchiver archivedDataWithRootObject:_coloringButton];
    [_coloringButton removeFromSuperview];
    _buttons = [[NSMutableArray alloc] init];
    _colors = [[NSMutableDictionary alloc] init];
    CGFloat offset = 10;
    CGFloat hue = 0.0;
    NSArray* nodeClasses = [[[_sourceRoot language] nodeClasses] sortedArrayUsingFunction:_SortFunction context:NULL];
    for(Class nodeClass in nodeClasses) {
        NSButton* button = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        [button setTag:(NSInteger)nodeClass];
        [button setTitle:[nodeClass name]];
        [button sizeToFit];
        [button setFrameOrigin:NSMakePoint(offset, button.frame.origin.y)];
        [[scrollView documentView] addSubview:button];
        [_buttons addObject:button];
        offset += button.frame.size.width + 10;
        
        [_colors setObject:[NSColor colorWithDeviceHue:hue saturation:0.2 brightness:0.9 alpha:1.0] forKey:nodeClass];
        hue += 1.0 / (CGFloat)nodeClasses.count;
    }
    [[scrollView documentView] setFrameSize:NSMakeSize(offset, [scrollView contentView].frame.size.height)];
    
    NSMutableSet* usedClasses = [NSMutableSet set];
    _FindUsedClasses(_sourceRoot, usedClasses);
    for(NSButton* button in _buttons) {
        Class nodeClass = (Class)[button tag];
        [button setEnabled:[usedClasses containsObject:nodeClass]];
    }
    
    _textView.string = [_sourceRoot source];
    [self updateColoring:nil];
    
    NSTrackingArea* area = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:(NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveAlways | NSTrackingInVisibleRect) owner:self userInfo:nil];
    [_textView addTrackingArea:area];
    [area release];
    [_pathControl setObjectValue:@"/"];
}

- (BOOL) readFromURL:(NSURL*)absoluteURL ofType:(NSString*)typeName error:(NSError**)outError {
    if(![absoluteURL isFileURL])
        return NO;
    
    _sourceRoot = [[SourceLanguage parseSourceFile:[absoluteURL path] encoding:NSUTF8StringEncoding syntaxAnalysis:YES] retain];
    if(_sourceRoot == nil) {
        if(outError)
            *outError = nil;
        return NO;
    }
    
    return YES;
}

- (void) mouseEntered:(NSEvent*)theEvent {
    [_pathControl setObjectValue:@"/"];
}

static void _NodeApplierFunction(SourceNode* node, void* context) {
    void** params = (void**)context;
    NSUInteger index = (NSUInteger)params[0];
    if((index >= node.range.location) && (index < node.range.location + node.range.length)) {
        SourceNode** nodePtr = params[1];
        *nodePtr = node;
    }
}

- (void) mouseMoved:(NSEvent*)theEvent {
    //FIXME: This creates some scrolling issues
    //NSMutableAttributedString* storage = [[_textView layoutManager] textStorage];
    //[storage beginEditing];
    //[storage addAttribute:NSForegroundColorAttributeName value:[NSColor darkGrayColor] range:_lastRange];
    
    void* params[2];
    NSUInteger index = [_textView characterIndexForInsertionAtPoint:[_textView convertPoint:theEvent.locationInWindow fromView:nil]];
    SourceNode* node = _sourceRoot;
    params[0] = (void*)index;
    params[1] = &node;
    [_sourceRoot applyFunctionOnChildren:_NodeApplierFunction context:params recursively:YES];
    //_lastRange = node.range;
    NSMutableString* path = [NSMutableString string];
    while(node) {
        [path insertString:[[node class] name] atIndex:0];
        [path insertString:@"/" atIndex:0];
        node = node.parent;
    }
    [_pathControl setObjectValue:path];
    
    //[storage addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:_lastRange];
    //[storage endEditing];
}

- (void) mouseExited:(NSEvent*)theEvent {
    [_pathControl setObjectValue:@"/"];
}

- (void) _colorizeSource:(SourceNode*)node attributes:(NSDictionary*)attributes {
    for(Class class in attributes) {
        if([node isMemberOfClass:class]) {
            [[[_textView layoutManager] textStorage] addAttribute:NSBackgroundColorAttributeName value:[attributes objectForKey:class] range:node.range];
            break;
        }
    }
    
    for(node in node.children)
        [self _colorizeSource:node attributes:attributes];
}

- (IBAction) updateColoring:(id)sender {
    NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
    for(NSButton* button in _buttons) {
        if([button state] == NSOnState) {
            Class nodeClass = (Class)[button tag];
            [attributes setObject:[_colors objectForKey:nodeClass] forKey:nodeClass];
        }
    }
    
    NSMutableAttributedString* storage = [[_textView layoutManager] textStorage];
    [storage beginEditing];
    [storage removeAttribute:NSBackgroundColorAttributeName range:_sourceRoot.range];
    [self _colorizeSource:_sourceRoot attributes:attributes];
    [storage endEditing];
}

@end
