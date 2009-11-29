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

#import <JavaScriptCore/JavaScriptCore.h>

#import "SourceParser_Internal.h"

#define __UNPROTECT_VALUES__ 0

static NSString* _wrapperScript = @"\
function __wrapper() {\
	var __success = false; \
    try {\
		%@\
        \
        __success = true;\
    }\
    catch(__exception) {\
    	Log(\"JavaScript Exception: '\" + __exception + \"' occured while processing node:\");\
        Log(\"\t\" + this.description);\
    }\
    return __success;\
}";

static JSClassRef _class = NULL;

static JSObjectRef _JSObjectFromNode(SourceNode* node, JSContextRef context) {
	if(node == nil)
    	return (JSObjectRef)JSValueMakeUndefined(context);
    if(node.jsObject == NULL) {
        node.jsObject = JSObjectMake(context, _class, node);
        JSValueProtect(context, node.jsObject);
    }
    
    return node.jsObject;
}

static JSValueRef _MakeException(JSContextRef context, NSString* format, ...) {
	va_list args;
    va_start(args, format);
    NSString* string = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    JSStringRef jsString = JSStringCreateWithCFString((CFStringRef)string);
    JSValueRef value = JSValueMakeString(context, jsString);
    JSStringRelease(jsString);
    [string release];
    return value;
}

static NSString* _ExceptionToString(JSContextRef context, JSValueRef exception) {
	JSStringRef jsString = JSValueToStringCopy(context, exception, NULL);
    NSString* string = nil;
    if(jsString) {
        string = [NSMakeCollectable(JSStringCopyCFString(kCFAllocatorDefault, jsString)) autorelease];
        JSStringRelease(jsString);
    }
    return string;
}

#if __UNPROTECT_VALUES__

static SourceNode* _NodeApplierFunction(SourceNode* node, void* context) {
    if(node.jsObject) {
    	JSValueUnprotect((JSContextRef)context, node.jsObject);
        node.jsObject = NULL;
    }
    return node;
}

#endif

static JSObjectRef _CallAsConstructorCallback(JSContextRef ctx, JSObjectRef constructor, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
    if((argumentCount == 1) && JSValueIsString(ctx, arguments[0])) {
        JSStringRef jsString = JSValueToStringCopy(ctx, arguments[0], NULL);
        CFStringRef cfString = JSStringCopyCFString(kCFAllocatorDefault, jsString);
        JSStringRelease(jsString);
        if(cfString) {
        	SourceNode* node = [[SourceNodeText alloc] initWithText:(NSString*)cfString];
        	JSObjectRef object = _JSObjectFromNode(node, ctx);
        	[node autorelease];
        	CFRelease(cfString); //FIXME: JSValueUnprotect() is never called
        	return object;
        }
    }
    return JSContextGetGlobalObject(ctx); //FIXME: Returning NULL or JSValueMakeUndefined() makes JavaScriptCore crash
}

static JSValueRef _GetPropertyName(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    JSStringRef string = JSStringCreateWithCFString((CFStringRef)[[node class] name]);
    JSValueRef value = JSValueMakeString(ctx, string);
    JSStringRelease(string);
    return value;
}

static JSValueRef _GetPropertyType(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    return JSValueMakeNumber(ctx, (double)(long)[node class]);
}

static JSValueRef _GetPropertyContent(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    JSStringRef string = JSStringCreateWithCFString((CFStringRef)node.content);
    JSValueRef value = JSValueMakeString(ctx, string);
    JSStringRelease(string);
    return value;
}

static JSValueRef _GetPropertyParent(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    return _JSObjectFromNode(node.parent, ctx);
}

static JSValueRef _GetPropertyChildrenCount(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    return JSValueMakeNumber(ctx, node.children.count);
}

static JSValueRef _GetPropertyFirstChild(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    return _JSObjectFromNode(node.firstChild, ctx);
}

static JSValueRef _GetPropertyLastChild(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    return _JSObjectFromNode(node.lastChild, ctx);
}

static JSValueRef _GetPropertyPreviousSibling(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    return _JSObjectFromNode(node.previousSibling, ctx);
}

static JSValueRef _GetPropertyNextSibling(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    return _JSObjectFromNode(node.nextSibling, ctx);
}

static JSValueRef _GetPropertyDescription(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    JSStringRef string = JSStringCreateWithCFString((CFStringRef)node.description);
    JSValueRef value = JSValueMakeString(ctx, string);
    JSStringRelease(string);
    return value;
}

static JSStaticValue _staticValues[] = {
	{"name", _GetPropertyName, NULL, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"type", _GetPropertyType, NULL, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"content", _GetPropertyContent, NULL, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
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
	if((argumentCount == 1) && JSValueIsObjectOfClass(ctx, arguments[0], _class)) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(![node isKindOfClass:[SourceNodeText class]]) {
        	SourceNode* child = JSObjectGetPrivate(JSValueToObject(ctx, arguments[0], NULL));
        	[node addChild:child];
            return JSValueMakeUndefined(ctx);
        }
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionRemoveFromParent(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if(argumentCount == 0) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent) {
#if __UNPROTECT_VALUES__
            _NodeApplierFunction(node, (void*)ctx);
            [node applyFunctionOnChildren:_NodeApplierFunction context:(void*)ctx];
#endif
            [node removeFromParent];
            return JSValueMakeUndefined(ctx);
        }
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionIndexOfChild(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 1) && JSValueIsObjectOfClass(ctx, arguments[0], _class)) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        SourceNode* child = JSObjectGetPrivate(JSValueToObject(ctx, arguments[0], NULL));
    	if(child.parent == node)
        	return JSValueMakeNumber(ctx, [node indexOfChild:child]);
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionInsertChild(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 2) && JSValueIsObjectOfClass(ctx, arguments[0], _class) && JSValueIsNumber(ctx, arguments[1])) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(![node isKindOfClass:[SourceNodeText class]]) {
        	SourceNode* child = JSObjectGetPrivate(JSValueToObject(ctx, arguments[0], NULL));
        	NSUInteger index = JSValueToNumber(ctx, arguments[1], NULL);
        	[node insertChild:child atIndex:index];
            return JSValueMakeUndefined(ctx);
        }
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionRemoveChild(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 1) && JSValueIsNumber(ctx, arguments[0])) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        NSUInteger index = JSValueToNumber(ctx, arguments[0], NULL);
        if(index < node.children.count) {
#if __UNPROTECT_VALUES__
            _NodeApplierFunction([node.children objectAtIndex:index], (void*)ctx);
            [node applyFunctionOnChildren:_NodeApplierFunction context:(void*)ctx];
#endif
            [node removeChildAtIndex:index];
            return JSValueMakeUndefined(ctx);
        }
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionInsertPreviousSibling(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 1) && JSValueIsObjectOfClass(ctx, arguments[0], _class)) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent) {
        	SourceNode* child = JSObjectGetPrivate(JSValueToObject(ctx, arguments[0], NULL));
        	[node insertPreviousSibling:child];
            return JSValueMakeUndefined(ctx);
        }
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionInsertNextSibling(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 1) && JSValueIsObjectOfClass(ctx, arguments[0], _class)) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent) {
        	SourceNode* child = JSObjectGetPrivate(JSValueToObject(ctx, arguments[0], NULL));
        	[node insertNextSibling:child];
            return JSValueMakeUndefined(ctx);
        }
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionReplaceWithNode(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 1) && JSValueIsObjectOfClass(ctx, arguments[0], _class)) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent) {
        	SourceNode* child = JSObjectGetPrivate(JSValueToObject(ctx, arguments[0], NULL));
#if __UNPROTECT_VALUES__
        	_NodeApplierFunction(node, (void*)ctx);
        	[node applyFunctionOnChildren:_NodeApplierFunction context:(void*)ctx];
#endif
        	[node replaceWithNode:child];
            return JSValueMakeUndefined(ctx);
        }
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionReplaceWithText(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 1) && JSValueIsString(ctx, arguments[0])) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent) {
#if __UNPROTECT_VALUES__
        	_NodeApplierFunction(node, (void*)ctx);
        	[node applyFunctionOnChildren:_NodeApplierFunction context:(void*)ctx];
#endif
        	JSStringRef jsString = JSValueToStringCopy(ctx, arguments[0], NULL);
            CFStringRef cfString = JSStringCopyCFString(kCFAllocatorDefault, jsString);
            [node replaceWithText:(NSString*)cfString];
            JSStringRelease(jsString);
            CFRelease(cfString);
            return JSValueMakeUndefined(ctx);
        }
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionFindPreviousSiblingIgnoringWhitespaceAndNewline(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if(argumentCount == 0) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent)
        	return _JSObjectFromNode([node findPreviousSiblingIgnoringWhitespaceAndNewline], ctx);
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionFindNextSiblingIgnoringWhitespaceAndNewline(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if(argumentCount == 0) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent)
        	return _JSObjectFromNode([node findNextSiblingIgnoringWhitespaceAndNewline], ctx);
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionFindPreviousSiblingOfType(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 1) && JSValueIsNumber(ctx, arguments[0])) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent) {
        	Class class = (Class)(long)JSValueToNumber(ctx, arguments[0], NULL);
        	return _JSObjectFromNode([node findPreviousSiblingOfClass:class], ctx);
        }
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionFindNextSiblingOfType(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 1) && JSValueIsNumber(ctx, arguments[0])) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent) {
        	Class class = (Class)(long)JSValueToNumber(ctx, arguments[0], NULL);
        	return _JSObjectFromNode([node findNextSiblingOfClass:class], ctx);
        }
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionFindFirstChildOfType(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 1) && JSValueIsNumber(ctx, arguments[0])) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent) {
        	Class class = (Class)(long)JSValueToNumber(ctx, arguments[0], NULL);
        	return _JSObjectFromNode([node findFirstChildOfClass:class], ctx);
        }
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionFindLastChildOfType(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 1) && JSValueIsNumber(ctx, arguments[0])) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent) {
        	Class class = (Class)(long)JSValueToNumber(ctx, arguments[0], NULL);
        	return _JSObjectFromNode([node findLastChildOfClass:class], ctx);
        }
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionGetDepthInParentsOfType(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount == 0) || ((argumentCount == 1) && JSValueIsNumber(ctx, arguments[0]))) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        Class class = (argumentCount == 1 ? (Class)(long)JSValueToNumber(ctx, arguments[0], NULL) : nil);
        return JSValueMakeNumber(ctx, [node getDepthInParentsOfClass:class]);
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionIsWhitespace(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if(argumentCount == 0) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        return JSValueMakeBoolean(ctx, [node isKindOfClass:[SourceNodeWhitespace class]]);
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionIsWhitespaceOrNewline(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if(argumentCount == 0) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        return JSValueMakeBoolean(ctx, [node isKindOfClass:[SourceNodeWhitespace class]] || [node isKindOfClass:[SourceNodeNewline class]]);
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionIsAnyText(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if(argumentCount == 0) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        return JSValueMakeBoolean(ctx, [node isKindOfClass:[SourceNodeText class]]);
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionIsKeyword(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if(argumentCount == 0) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        return JSValueMakeBoolean(ctx, [node isKindOfClass:[SourceNodeKeyword class]]);
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionIsToken(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if(argumentCount == 0) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        return JSValueMakeBoolean(ctx, [node isKindOfClass:[SourceNodeToken class]]);
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static SourceNode* _JavaScriptFunctionApplier(SourceNode* node, void* context) {
	void** params = (void**)context;
    JSContextRef ctx = params[0];
    JSObjectRef object = params[1];
	BOOL* successPtr = params[2];
    JSValueRef value = JSObjectCallAsFunction(ctx, object, _JSObjectFromNode(node, ctx), 0, NULL, NULL);
    if(!value || !JSValueIsBoolean(ctx, value) || !JSValueToBoolean(ctx, value))
    	*successPtr = NO;
    return node;
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

/*
static bool _HasPropertyCallback(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName) {
	CFStringRef cfString = JSStringCopyCFString(kCFAllocatorDefault, propertyName);
    if(cfString) {
        bool result = CFEqual(cfString, CFSTR("coucou"));
        CFRelease(cfString);
        return result;
    }
    return false;
}
*/

static JSValueRef _GetPropertyCallback(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	CFStringRef cfString = JSStringCopyCFString(kCFAllocatorDefault, propertyName);
    if(cfString) {
    	SInt32 index = CFStringGetIntValue(cfString);
        CFRelease(cfString);
        if(index > 0) {
        	SourceNode* node = JSObjectGetPrivate(object);
        	return (index <= node.children.count ? _JSObjectFromNode([node.children objectAtIndex:(index - 1)], ctx) : JSValueMakeUndefined(ctx));
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

static JSValueRef _LogFunction(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if(argumentCount == 1) {
    	JSStringRef jsString = JSValueToStringCopy(ctx, arguments[0], NULL);
        CFStringRef cfString = JSStringCopyCFString(kCFAllocatorDefault, jsString);
        if(cfString) {
        	printf("%s\n", [(NSString*)cfString UTF8String]);
        	CFRelease(cfString);
        }
        JSStringRelease(jsString);
    }
    return JSValueMakeUndefined(ctx);
}

BOOL RunJavaScriptOnRootNode(NSString* script, SourceNode* root) {
	BOOL success = NO;
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    if(script.length && root) {
        if(_class == NULL) {
            JSClassDefinition definition = kJSClassDefinitionEmpty;
            definition.className = "Node";
            definition.staticValues = _staticValues;
            definition.staticFunctions = _staticFunctions;
            definition.getPropertyNames = _GetPropertyNamesCallback;
            //definition.hasProperty = _HasPropertyCallback;
            definition.getProperty = _GetPropertyCallback;
            definition.convertToType = _ConvertToTypeCallback;
            _class = JSClassCreate(&definition);
        }
        
        if(_class) {
            JSGlobalContextRef context = JSGlobalContextCreate(NULL);
            if(context) {
                JSStringRef jsScript = JSStringCreateWithCFString((CFStringRef)[NSString stringWithFormat:_wrapperScript, script]);
                if(jsScript) {
                    JSStringRef jsString;
                    
                    jsString = JSStringCreateWithCFString(CFSTR("Log"));
                    JSObjectSetProperty(context, JSContextGetGlobalObject(context), jsString, JSObjectMakeFunctionWithCallback(context, NULL, _LogFunction), kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete, NULL);
                    JSStringRelease(jsString);
                    
                    JSObjectRef jsNode = JSObjectMakeConstructor(context, _class, _CallAsConstructorCallback);
					jsString = JSStringCreateWithCFString(CFSTR("Node"));
                    JSObjectSetProperty(context, JSContextGetGlobalObject(context), jsString, jsNode, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete, NULL);
                    JSStringRelease(jsString);
                    
                    for(SourceLanguage* language in [SourceLanguage allLanguages]) {
                    	for(Class nodeClass in language.nodeClasses) {
                        	jsString = JSStringCreateWithCFString((CFStringRef)[NSString stringWithFormat:@"TYPE_%@", [[nodeClass name] uppercaseString]]);
                            JSObjectSetProperty(context, jsNode, jsString, JSValueMakeNumber(context, (double)(long)nodeClass), kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete, NULL);
                            JSStringRelease(jsString);
                        }
                    }
                    
                    JSValueRef exception = NULL;
                    JSEvaluateScript(context, jsScript, NULL, NULL, 1, &exception);
                    if(exception)
                        printf("<JavaScript Evaluation Failed: %s>\n", [_ExceptionToString(context, exception) UTF8String]);
                    else {
                    	jsString = JSStringCreateWithCFString(CFSTR("__wrapper"));
                        JSObjectRef function = JSValueToObject(context, JSObjectGetProperty(context, JSContextGetGlobalObject(context), jsString, NULL), NULL);
                        JSStringRelease(jsString);
                        if(function && JSValueIsObject(context, function)) {
                            success = YES;
                            void* params[3];
                            params[0] = context;
                            params[1] = function;
                            params[2] = &success;
                            _JavaScriptFunctionApplier(root, params);
                            [root applyFunctionOnChildren:_JavaScriptFunctionApplier context:params];
                        }
                    }
                    
#if __UNPROTECT_VALUES__
                    _NodeApplierFunction(root, (void*)context);
                    [root applyFunctionOnChildren:_NodeApplierFunction context:(void*)context];
#endif
                    
                    JSStringRelease(jsScript);
                }
                JSGarbageCollect(context);
                JSGlobalContextRelease(context);
                JSGarbageCollect(context);
            }
        }
    }
    [pool release];
    return success;
}
