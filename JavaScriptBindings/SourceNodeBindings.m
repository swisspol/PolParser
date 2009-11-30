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

#import "JavaScriptBindings_Internal.h"

static JSValueRef _GetPropertyType(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    return JSValueMakeNumber(ctx, (double)(long)[node class]);
}

static JSValueRef _GetPropertyName(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    JSStringRef string = JSStringCreateWithCFString((CFStringRef)node.name);
    JSValueRef value = JSValueMakeString(ctx, string);
    JSStringRelease(string);
    return value;
}

static JSValueRef _GetPropertyAttributes(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    NSDictionary* attributes = node.attributes;
    return attributes ? _JSValueMakeDictionary(attributes, ctx) : JSValueMakeUndefined(ctx);
}

static JSValueRef _GetPropertyContent(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    JSStringRef string = JSStringCreateWithCFString((CFStringRef)node.content);
    JSValueRef value = JSValueMakeString(ctx, string);
    JSStringRelease(string);
    return value;
}

static JSValueRef _GetPropertyCleanContent(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    JSStringRef string = JSStringCreateWithCFString((CFStringRef)node.cleanContent);
    JSValueRef value = JSValueMakeString(ctx, string);
    JSStringRelease(string);
    return value;
}

static JSValueRef _GetPropertyParent(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    return _JSValueMakeSourceNode(node.parent, ctx);
}

static JSValueRef _GetPropertyChildrenCount(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    return JSValueMakeNumber(ctx, node.children.count);
}

static JSValueRef _GetPropertyFirstChild(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    return _JSValueMakeSourceNode(node.firstChild, ctx);
}

static JSValueRef _GetPropertyLastChild(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    return _JSValueMakeSourceNode(node.lastChild, ctx);
}

static JSValueRef _GetPropertyPreviousSibling(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    return _JSValueMakeSourceNode(node.previousSibling, ctx);
}

static JSValueRef _GetPropertyNextSibling(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    return _JSValueMakeSourceNode(node.nextSibling, ctx);
}

static JSValueRef _GetPropertyDescription(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    JSStringRef string = JSStringCreateWithCFString((CFStringRef)node.description);
    JSValueRef value = JSValueMakeString(ctx, string);
    JSStringRelease(string);
    return value;
}

static JSStaticValue _staticValues[] = {
    {"type", _GetPropertyType, NULL, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
	{"name", _GetPropertyName, NULL, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
	{"attributes", _GetPropertyAttributes, NULL, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"content", _GetPropertyContent, NULL, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"cleanContent", _GetPropertyCleanContent, NULL, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"parent", _GetPropertyParent, NULL, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"childrenCount", _GetPropertyChildrenCount, NULL, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"firstChild", _GetPropertyFirstChild, NULL, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"lastChild", _GetPropertyLastChild, NULL, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"previousSibling", _GetPropertyPreviousSibling, NULL, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"nextSibling", _GetPropertyNextSibling, NULL, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"description", _GetPropertyDescription, NULL, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {NULL, NULL, NULL, 0}
};

static JSValueRef _CallFunctionAddChild(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 1) && JSValueIsObjectOfClass(ctx, arguments[0], _GetSourceNodeJavaScriptClass())) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(![node isKindOfClass:[SourceNodeText class]]) {
        	SourceNode* child = JSObjectGetPrivate(JSValueToObject(ctx, arguments[0], NULL));
        	[node addChild:child];
            return JSValueMakeUndefined(ctx);
        }
    }
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionRemoveFromParent(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if(argumentCount == 0) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent) {
            [node removeFromParent];
            return JSValueMakeUndefined(ctx);
        }
    }
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionIndexOfChild(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 1) && JSValueIsObjectOfClass(ctx, arguments[0], _GetSourceNodeJavaScriptClass())) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        SourceNode* child = JSObjectGetPrivate(JSValueToObject(ctx, arguments[0], NULL));
    	if(child.parent == node)
        	return JSValueMakeNumber(ctx, [node indexOfChild:child]);
    }
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionInsertChild(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 2) && JSValueIsObjectOfClass(ctx, arguments[0], _GetSourceNodeJavaScriptClass()) && JSValueIsNumber(ctx, arguments[1])) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(![node isKindOfClass:[SourceNodeText class]]) {
        	SourceNode* child = JSObjectGetPrivate(JSValueToObject(ctx, arguments[0], NULL));
        	NSUInteger index = JSValueToNumber(ctx, arguments[1], NULL);
        	[node insertChild:child atIndex:index];
            return JSValueMakeUndefined(ctx);
        }
    }
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionRemoveChild(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 1) && JSValueIsNumber(ctx, arguments[0])) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        NSUInteger index = JSValueToNumber(ctx, arguments[0], NULL);
        if(index < node.children.count) {
            [node removeChildAtIndex:index];
            return JSValueMakeUndefined(ctx);
        }
    }
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionInsertPreviousSibling(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 1) && JSValueIsObjectOfClass(ctx, arguments[0], _GetSourceNodeJavaScriptClass())) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent) {
        	SourceNode* child = JSObjectGetPrivate(JSValueToObject(ctx, arguments[0], NULL));
        	[node insertPreviousSibling:child];
            return JSValueMakeUndefined(ctx);
        }
    }
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionInsertNextSibling(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 1) && JSValueIsObjectOfClass(ctx, arguments[0], _GetSourceNodeJavaScriptClass())) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent) {
        	SourceNode* child = JSObjectGetPrivate(JSValueToObject(ctx, arguments[0], NULL));
        	[node insertNextSibling:child];
            return JSValueMakeUndefined(ctx);
        }
    }
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionReplaceWithNode(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 1) && JSValueIsObjectOfClass(ctx, arguments[0], _GetSourceNodeJavaScriptClass())) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent) {
        	SourceNode* child = JSObjectGetPrivate(JSValueToObject(ctx, arguments[0], NULL));
        	[node replaceWithNode:child];
            return JSValueMakeUndefined(ctx);
        }
    }
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionReplaceWithText(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 1) && JSValueIsString(ctx, arguments[0])) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent) {
        	JSStringRef jsString = JSValueToStringCopy(ctx, arguments[0], NULL);
            CFStringRef cfString = JSStringCopyCFString(kCFAllocatorDefault, jsString);
            [node replaceWithText:(NSString*)cfString];
            JSStringRelease(jsString);
            CFRelease(cfString);
            return JSValueMakeUndefined(ctx);
        }
    }
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionFindPreviousSiblingIgnoringWhitespaceAndNewline(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if(argumentCount == 0) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent)
        	return _JSValueMakeSourceNode([node findPreviousSiblingIgnoringWhitespaceAndNewline], ctx);
    }
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionFindNextSiblingIgnoringWhitespaceAndNewline(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if(argumentCount == 0) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent)
        	return _JSValueMakeSourceNode([node findNextSiblingIgnoringWhitespaceAndNewline], ctx);
    }
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionFindPreviousSiblingOfType(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 1) && JSValueIsNumber(ctx, arguments[0])) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent) {
        	Class class = (Class)(long)JSValueToNumber(ctx, arguments[0], NULL);
        	return _JSValueMakeSourceNode([node findPreviousSiblingOfClass:class], ctx);
        }
    }
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionFindNextSiblingOfType(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 1) && JSValueIsNumber(ctx, arguments[0])) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent) {
        	Class class = (Class)(long)JSValueToNumber(ctx, arguments[0], NULL);
        	return _JSValueMakeSourceNode([node findNextSiblingOfClass:class], ctx);
        }
    }
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionFindFirstChildOfType(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 1) && JSValueIsNumber(ctx, arguments[0])) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent) {
        	Class class = (Class)(long)JSValueToNumber(ctx, arguments[0], NULL);
        	return _JSValueMakeSourceNode([node findFirstChildOfClass:class], ctx);
        }
    }
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionFindLastChildOfType(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 1) && JSValueIsNumber(ctx, arguments[0])) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent) {
        	Class class = (Class)(long)JSValueToNumber(ctx, arguments[0], NULL);
        	return _JSValueMakeSourceNode([node findLastChildOfClass:class], ctx);
        }
    }
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionGetDepthInParentsOfType(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 0) || ((argumentCount == 1) && JSValueIsNumber(ctx, arguments[0]))) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        Class class = (argumentCount == 1 ? (Class)(long)JSValueToNumber(ctx, arguments[0], NULL) : nil);
        return JSValueMakeNumber(ctx, [node getDepthInParentsOfClass:class]);
    }
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionIsWhitespace(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if(argumentCount == 0) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        return JSValueMakeBoolean(ctx, [node isKindOfClass:[SourceNodeWhitespace class]]);
    }
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionIsWhitespaceOrNewline(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if(argumentCount == 0) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        return JSValueMakeBoolean(ctx, [node isKindOfClass:[SourceNodeWhitespace class]] || [node isKindOfClass:[SourceNodeNewline class]]);
    }
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionIsAnyText(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if(argumentCount == 0) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        return JSValueMakeBoolean(ctx, [node isKindOfClass:[SourceNodeText class]]);
    }
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionIsKeyword(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if(argumentCount == 0) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        return JSValueMakeBoolean(ctx, [node isKindOfClass:[SourceNodeKeyword class]]);
    }
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionIsToken(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if(argumentCount == 0) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        return JSValueMakeBoolean(ctx, [node isKindOfClass:[SourceNodeToken class]]);
    }
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSStaticFunction _staticFunctions[] = {
	{"addChild", _CallFunctionAddChild, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"removeFromParent", _CallFunctionRemoveFromParent, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"indexOfChild", _CallFunctionIndexOfChild, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"insertChildAt", _CallFunctionInsertChild, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"removeChildAt", _CallFunctionRemoveChild, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"insertPreviousSibling", _CallFunctionInsertPreviousSibling, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"insertNextSibling", _CallFunctionInsertNextSibling, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"replaceWithNode", _CallFunctionReplaceWithNode, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"replaceWithText", _CallFunctionReplaceWithText, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"findPreviousSiblingIgnoringWhitespaceAndNewline", _CallFunctionFindPreviousSiblingIgnoringWhitespaceAndNewline, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"findNextSiblingIgnoringWhitespaceAndNewline", _CallFunctionFindNextSiblingIgnoringWhitespaceAndNewline, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"findPreviousSiblingOfType", _CallFunctionFindPreviousSiblingOfType, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"findNextSiblingOfType", _CallFunctionFindNextSiblingOfType, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"findFirstChildOfType", _CallFunctionFindFirstChildOfType, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"findLastChildOfType", _CallFunctionFindLastChildOfType, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"getDepthInParentsOfType", _CallFunctionGetDepthInParentsOfType, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
	{"isWhitespace", _CallFunctionIsWhitespace, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"isWhitespaceOrNewline", _CallFunctionIsWhitespaceOrNewline, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"isAnyText", _CallFunctionIsAnyText, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"isKeyword", _CallFunctionIsKeyword, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"isToken", _CallFunctionIsToken, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {NULL, NULL, 0}
};

static void _GetPropertyNamesCallback(JSContextRef ctx, JSObjectRef object, JSPropertyNameAccumulatorRef propertyNames) {
	static CFMutableArrayRef cache = NULL;
    if(cache == NULL)
    	cache = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    
    SourceNode* node = JSObjectGetPrivate(object);
    CFIndex count = node.children.count + 1;
    if(count > CFArrayGetCount(cache)) {
    	for(CFIndex index = CFArrayGetCount(cache); index < count; ++index) {
        	CFStringRef string = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%i"), index);
            CFArrayAppendValue(cache, string);
            CFRelease(string);
        }
    }
    for(CFIndex index = 1; index < count; ++index) {
    	JSStringRef string = JSStringCreateWithCFString(CFArrayGetValueAtIndex(cache, index));
        JSPropertyNameAccumulatorAddName(propertyNames, string);
        JSStringRelease(string);
    }
}

static JSValueRef _GetPropertyCallback(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	CFStringRef cfString = JSStringCopyCFString(kCFAllocatorDefault, propertyName);
    if(cfString) {
    	SInt32 index = CFStringGetIntValue(cfString);
        CFRelease(cfString);
        if(index > 0) {
        	SourceNode* node = JSObjectGetPrivate(object);
        	return (index <= node.children.count ? _JSValueMakeSourceNode([node.children objectAtIndex:(index - 1)], ctx) : JSValueMakeUndefined(ctx));
        }
    }
    return NULL;
}

static JSValueRef _ConvertToTypeCallback(JSContextRef ctx, JSObjectRef object, JSType type, JSValueRef* exception) {
	if(type == kJSTypeString) {
    	SourceNode* node = JSObjectGetPrivate(object);
        JSStringRef string = JSStringCreateWithCFString((CFStringRef)node.compactDescription);
        JSValueRef value = JSValueMakeString(ctx, string);
        JSStringRelease(string);
        return value;
    }
    return JSValueMakeUndefined(ctx);
}

JSClassRef _GetSourceNodeJavaScriptClass() {
	static JSClassRef class = NULL;
	if(class == NULL) {
        JSClassDefinition definition = kJSClassDefinitionEmpty;
        definition.className = "Node";
        definition.staticValues = _staticValues;
        definition.staticFunctions = _staticFunctions;
        definition.getPropertyNames = _GetPropertyNamesCallback;
        definition.getProperty = _GetPropertyCallback;
        definition.convertToType = _ConvertToTypeCallback;
        class = JSClassCreate(&definition);
        if(class == NULL)
            [NSException raise:NSInternalInconsistencyException format:@""];
    }
    return class;
}

JSValueRef _JSValueMakeSourceNode(SourceNode* node, JSContextRef context) {
	if(node == nil)
    	return JSValueMakeUndefined(context);
    if(node.jsObject == NULL) {
        node.jsObject = JSObjectMake(context, _GetSourceNodeJavaScriptClass(), node);
        JSValueProtect(context, node.jsObject);
    }
    return node.jsObject;
}
