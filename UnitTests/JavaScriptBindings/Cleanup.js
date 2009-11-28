if(this.type == Node.TYPE_NEWLINE) {
    // Strip whitespace at end of lines (and therefore lines that are pure "indenting")
	if(this.previousSibling && (this.previousSibling.isWhitespace()))
    	this.previousSibling.removeFromParent();
    
	// Remove extra newlines
    if(this.nextSibling && (this.nextSibling.type == Node.TYPE_NEWLINE) && this.nextSibling.nextSibling && (this.nextSibling.nextSibling.type == Node.TYPE_NEWLINE))
    	this.removeFromParent();
}
// Reformat C++ comments as "  // Comment"
else if(this.type == Node.TYPE_CPPCOMMENT) {
	var comment = this.content.substr(2);
    while(comment.length && (comment.charAt(0) == ' ')) {
    	comment = comment.substr(1);
    }
    if(this.previousSibling && (this.previousSibling.type == Node.TYPE_WHITESPACE))
    	this.previousSibling.removeFromParent();
    if(comment.length) {
    	if(this.previousSibling && (this.previousSibling.type == Node.TYPE_INDENTING))
        	this.replaceWithText("// " + comment);
        else
        	this.replaceWithText("  // " + comment);
    }
}
// Reformat method declarations and implementation as "- (foo) bar"
else if((this.type == Node.TYPE_OBJCMETHODDECLARATION) || (this.type == Node.TYPE_OBJCMETHODIMPLEMENTATION)) {
	var node = this.firstChild;
    if(node.nextSibling.type != Node.TYPE_WHITESPACE)
    	node.insertNextSibling(new Node(" "));
    var node = node.findNextSiblingOfType(Node.TYPE_PARENTHESIS);
    if(node.nextSibling.type != Node.TYPE_WHITESPACE)
    	node.insertNextSibling(new Node(" "));
}

<----->

// Convert tabs indenting to spaces indenting, make sure they are multiple of 4 and their length is greater or equal than to what's expected according to the number of nested braces
if(this.type == Node.TYPE_INDENTING) {
	var indent = this.content.replace(/\t/g, "    ");
	var extra = indent.length % 4;
    if(extra > 0)
		indent = indent.slice(0, -extra);
    var length = indent.length / 4;
    var depth = this.getDepthInParentsOfType(Node.TYPE_BRACES);
    if((this.parent.type == Node.TYPE_BRACES) && (this.nextSibling == this.parent.lastChild))
    	--depth;
    while(depth > length) {
    	indent = indent + "    ";
        --depth;
    }
    this.replaceWithText(indent);
}
