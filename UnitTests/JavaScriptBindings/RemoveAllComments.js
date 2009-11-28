// Remove C & C++ comments
if((this.type == Node.TYPE_CCOMMENT) || (this.type == Node.TYPE_CPPCOMMENT))
        this.removeFromParent();

<----->

// Strip whitespace (including former indenting) at end of lines
if(this.type == Node.TYPE_NEWLINE) {
    if(this.previousSibling && (this.previousSibling.isWhitespace()))
    	this.previousSibling.removeFromParent();
}

<----->

// Concatenate multiple newlines
if(this.type == Node.TYPE_NEWLINE) {
    if(this.nextSibling && (this.nextSibling.type == Node.TYPE_NEWLINE))
    	this.removeFromParent();
}
