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

#define UNPROTECT_VALUES 1

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

#if UNPROTECT_VALUES

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
    return _JSObjectFromNode(node.firstChild, ctx);
}

static JSValueRef _GetPropertyNextSibling(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
	SourceNode* node = JSObjectGetPrivate(object);
    return _JSObjectFromNode(node.lastChild, ctx);
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
#if UNPROTECT_VALUES
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
#if UNPROTECT_VALUES
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
#if UNPROTECT_VALUES
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

static JSValueRef _CallFunctionFindPreviousSibling(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount <= 1) && ((argumentCount == 0) || JSValueIsNumber(ctx, arguments[0]))) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent) {
        	Class class = (argumentCount == 0 ? nil : (Class)(long)JSValueToNumber(ctx, arguments[0], NULL));
        	return _JSObjectFromNode(class ? [node findPreviousSiblingOfClass:class] : [node findPreviousSiblingIgnoringWhitespaceAndNewline], ctx);
        }
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static JSValueRef _CallFunctionFindNextSibling(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if((argumentCount <= 1) && ((argumentCount == 0) || JSValueIsNumber(ctx, arguments[0]))) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        if(node.parent) {
        	Class class = (argumentCount == 0 ? nil : (Class)(long)JSValueToNumber(ctx, arguments[0], NULL));
        	return _JSObjectFromNode(class ? [node findNextSiblingOfClass:class] : [node findNextSiblingIgnoringWhitespaceAndNewline], ctx);
        }
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
    return NULL;
}

static SourceNode* _JavaScriptFunctionApplier(SourceNode* node, void* context) {
	void** params = (void**)context;
    JSContextRef ctx = params[0];
    JSObjectRef object = params[1];
    void* recursive = params[2];
    JSValueRef exception = NULL;
    JSObjectCallAsFunction(ctx, object, _JSObjectFromNode(node, ctx), 0, NULL, &exception);
    if(exception)
    	printf("<JavaScript Exception: %s>\n", [_ExceptionToString(context, exception) UTF8String]);
    return recursive ? node : nil;
}

static JSValueRef _CallFunctionApplyFunctionOnChildren(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
	if(((argumentCount == 1) || (argumentCount == 2)) && JSValueIsObject(ctx, arguments[0]) && ((argumentCount == 1) || JSValueIsBoolean(ctx, arguments[1]))) {
    	SourceNode* node = JSObjectGetPrivate(thisObject);
        void* params[3];
        params[0] = (void*)ctx;
        params[1] = (void*)arguments[0];
        params[2] = (argumentCount == 2) && !JSValueToBoolean(ctx, arguments[1]) ? NULL : (void*)ctx;
        [node applyFunctionOnChildren:_JavaScriptFunctionApplier context:params];
        return JSValueMakeUndefined(ctx);
    }
    *exception = _MakeException(ctx, @"Invalid argument(s)");
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
    {"findPreviousSibling", _CallFunctionFindPreviousSibling, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"findNextSibling", _CallFunctionFindNextSibling, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
    {"applyFunctionOnChildren", _CallFunctionApplyFunctionOnChildren, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete | kJSPropertyAttributeDontEnum},
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
                JSStringRef jsScript = JSStringCreateWithCFString((CFStringRef)script);
                if(jsScript) {
                    JSStringRef jsString;
                    
                    jsString = JSStringCreateWithCFString(CFSTR("Log"));
                    JSObjectSetProperty(context, JSContextGetGlobalObject(context), jsString, JSObjectMakeFunctionWithCallback(context, NULL, _LogFunction), kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete, NULL);
                    JSStringRelease(jsString);
                    
					jsString = JSStringCreateWithCFString(CFSTR("Node"));
                    JSObjectSetProperty(context, JSContextGetGlobalObject(context), jsString, JSObjectMakeConstructor(context, _class, _CallAsConstructorCallback), kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete, NULL);
                    JSStringRelease(jsString);
                    
                    jsString = JSStringCreateWithCFString(CFSTR("_root"));
                    JSObjectSetProperty(context, JSContextGetGlobalObject(context), jsString, _JSObjectFromNode(root, context), kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete, NULL);
                    JSStringRelease(jsString);
                    
                    for(SourceLanguage* language in [SourceLanguage allLanguages]) {
                    	for(Class nodeClass in language.nodeClasses) {
                        	jsString = JSStringCreateWithCFString((CFStringRef)[NSString stringWithFormat:@"kType%@", [nodeClass name]]);
                            JSObjectSetProperty(context, JSContextGetGlobalObject(context), jsString, JSValueMakeNumber(context, (double)(long)nodeClass), kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete, NULL);
                            JSStringRelease(jsString);
                        }
                    }
                    
                    JSValueRef exception = NULL;
                    JSEvaluateScript(context, jsScript, NULL, NULL, 1, &exception);
                    if(exception)
                        printf("<JavaScript Exception: %s>\n", [_ExceptionToString(context, exception) UTF8String]);
                    else
                    	success = YES;
                    
#if UNPROTECT_VALUES
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
