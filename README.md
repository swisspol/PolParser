Overview
========

**PolParser is lightweight generic text parser in Obj-C for Mac OS X Leopard and later.**

PolParser creates a tree from the parsing of the input text. It currently supports various text formats like XML, RSS, Atom, HTML, Apple Property Lists, CSV... as well as source code for C style languages like C, C++, Obj-C..., and it's quite easy to add support for new text formats or languages. The fact PolParser generates a tree makes it quite easier to use than NSScanner & friends for complex parsing and batch text modifications (or source code refactoring).

PolParser uses a 2 passes approach: the first pass isolates all language specific tokens and the second pass (which is optional) performs high-level syntax analysis e.g. locating function definitions or finding logic blocks in the case of source code.

PolParser currently comes with a test application to browse the generated tree, as well as a command line tool that can print the tree and / or apply some refactoring operations to it expressed in JavaScript - more information below.

Finally, PolParser is a well factored piece of code with minimal dependencies, ready to be embedded into any kind of project requiring text parsing.

*The entire project is available open-source under GPLv3 license. If you are interested in using PolParser in a non-open-source project and need a commercial license, please contact info@pol-online.net.*

Currently Known Limitations
===========================

 * C++ language: Templates parsing is not supported
 * C style languages: Blocks (as defined in Snow Leopard) parsing is not supported

Example Generated Source Tree
=============================

For an example parsing result, printed in both "compact" and "detailed" styles, see this test file: [UnitTests/Parser/Language-CPP-Source.cc](UnitTests/Parser/Language-CPP-Source.cc).

Sample Code
===========

```
// Read source file and parse into a source tree
SourceNodeRoot* root = [SourceLanguage parseSourceFile:@"MyFile.m" syntaxAnalysis:YES];

// Modify the source tree - see example applier functions below
// You can directly add / remove nodes from the source tree or use this convenient API to do it recursively
[root applyFunctionOnChildren:_ApplierFunction context:NULL recursively:YES];

// Write updated source tree as a new source file
[root writeContentToFile:@"MyFile.m"];
```

```
// Deleting whitespace at end of lines
static void _ApplierFunction(SourceNode* node, void* context) {
    if([node isKindOfClass:[SourceNodeNewline class]]) {
        if([node.previousSibling isKindOfClass:[SourceNodeWhitespace class]])
            [node.previousSibling removeFromParent];
    }
}
```

```
// Deleting empty C++ comments and reformat the others as "  // Comment"
static void _ApplierFunction(SourceNode* node, void* context) {
    if([node isKindOfClass:[SourceNodeCPPComment class]]) {
        if([node.previousSibling isKindOfClass:[SourceNodeWhitespace class]])
            [node.previousSibling removeFromParent];
        
        NSString* text = node.content;
        NSRange range = [node.content rangeOfCharacterFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet] options:0 range:NSMakeRange(2, text.length - 2)];
        if(range.location != NSNotFound)
            text = [NSString stringWithFormat:@"%@// %@", [node.previousSibling isKindOfClass:[SourceNodeNewline class]] ? @"": @"  ", [text substringFromIndex:range.location]];
        else
            text = nil;
        [node replaceWithText:text];
    }
}
```

```
//Reformat "if()", "for()" and "while()" as "if ()", "for ()" and "while ()"
static void _ApplierFunction(SourceNode* node, void* context) {
    if(([node isKindOfClass:[SourceNodeCFlowIf class]]    [node isKindOfClass:[SourceNodeCFlowFor class]]    [node isKindOfClass:[SourceNodeCFlowWhile class]]) && node.children.count) {
        SourceNode* subnode = node.firstChild;
        while([subnode.nextSibling isKindOfClass:[SourceNodeWhitespace class]]    [subnode.nextSibling isKindOfClass:[SourceNodeNewline class]])
            [subnode.nextSibling removeFromParent];
        [subnode insertNextSibling:[SourceNodeText sourceNodeWithText:@" "]];
    }
}
```

JavaScript Bindings
===================

Instead of using Obj-C code to manipulate the source tree, you can use JavaScript for which PolParser exposes bindings. The script is run recursively on each node, same as with the -applyFunctionOnChildren:context:recursive: function.

```
// Strip whitespace at end of lines
if(this.type == Node.TYPE_NEWLINE) {
    if(this.previousSibling && (this.previousSibling.type == Node.TYPE_WHITESPACE))
    	this.previousSibling.removeFromParent();
}
```

Test Application
================

PolParser comes with a test application you can use to verify the parsing works as expected and to browse the generated source tree in a more user friendly way.
