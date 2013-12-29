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

#import "Parser_Internal.h"
#import "JavaScriptBindings_Internal.h"

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

JSValueRef _JSValueMakeString(NSString* string, JSContextRef context) {
    JSStringRef jsString = JSStringCreateWithCFString((CFStringRef)string);
    JSValueRef value = JSValueMakeString(context, jsString);
    JSStringRelease(jsString);
    return value;
}

JSValueRef _JSValueMakeException(JSContextRef context, NSString* format, ...) {
    va_list args;
    va_start(args, format);
    NSString* string = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    JSValueRef value = _JSValueMakeString(string, context);
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

static JSObjectRef _CallAsConstructorCallback(JSContextRef ctx, JSObjectRef constructor, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
    if((argumentCount == 1) && JSValueIsString(ctx, arguments[0])) {
        JSStringRef jsString = JSValueToStringCopy(ctx, arguments[0], NULL);
        CFStringRef cfString = JSStringCopyCFString(kCFAllocatorDefault, jsString);
        JSStringRelease(jsString);
        if(cfString) {
            ParserNode* node = [[ParserNodeText alloc] initWithText:(NSString*)cfString];
            if(node == nil) {
                goto Fail;
            }
            JSObjectRef object = (JSObjectRef)_JSValueMakeParserNode(node, ctx);
            [node autorelease];
            CFRelease(cfString);
            return object;
        }
    }
Fail:
    *exception = _JSValueMakeException(ctx, @"Invalid argument(s)");
    return JSContextGetGlobalObject(ctx); //FIXME: Returning anything but a JSObjectRef makes JavaScriptCore crash
}

static ParserNode* _JavaScriptNodeFunctionApplier(ParserNode* node, void* context) {
    void** params = (void**)context;
    JSContextRef ctx = params[0];
    JSObjectRef object = params[1];
    BOOL* successPtr = params[2];
    JSValueRef value = JSObjectCallAsFunction(ctx, object, (JSObjectRef)_JSValueMakeParserNode(node, ctx), 0, NULL, NULL);
    if(!value || !JSValueIsBoolean(ctx, value) || !JSValueToBoolean(ctx, value)) {
        *successPtr = NO;
    }
    return node;
}

static ParserNode* _ResetNodeFunctionApplier(ParserNode* node, void* context) {
    if(node.jsObject) {
        JSValueUnprotect(context, node.jsObject);
        node.jsObject = NULL;
    }
    return node;
}

BOOL RunJavaScriptOnRootNode(NSString* script, ParserNode* root) {
    BOOL success = NO;
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    if(script.length && root) {
        JSGlobalContextRef context = JSGlobalContextCreate(NULL);
        if(context) {
            JSStringRef jsScript = JSStringCreateWithCFString((CFStringRef)[NSString stringWithFormat:_wrapperScript, script]);
            if(jsScript) {
                JSStringRef jsString;
                
                jsString = JSStringCreateWithCFString(CFSTR("Log"));
                JSObjectSetProperty(context, JSContextGetGlobalObject(context), jsString, JSObjectMakeFunctionWithCallback(context, NULL, _LogFunction), kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete, NULL);
                JSStringRelease(jsString);
                
                JSObjectRef jsNode = JSObjectMakeConstructor(context, _GetParserNodeJavaScriptClass(), _CallAsConstructorCallback);
                jsString = JSStringCreateWithCFString(CFSTR("Node"));
                JSObjectSetProperty(context, JSContextGetGlobalObject(context), jsString, jsNode, kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete, NULL);
                JSStringRelease(jsString);
                
                for(ParserLanguage* language in [ParserLanguage allLanguages]) {
                    for(Class nodeClass in language.nodeClasses) {
                        jsString = JSStringCreateWithCFString((CFStringRef)[NSString stringWithFormat:@"TYPE_%@", [[nodeClass name] uppercaseString]]);
                        JSObjectSetProperty(context, jsNode, jsString, JSValueMakeNumber(context, (double)(long)nodeClass), kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete, NULL);
                        JSStringRelease(jsString);
                    }
                }
                
                JSValueRef exception = NULL;
                JSEvaluateScript(context, jsScript, NULL, NULL, 1, &exception);
                if(exception) {
                    printf("<JavaScript Evaluation Failed: %s>\n", [_ExceptionToString(context, exception) UTF8String]);
                } else {
                    jsString = JSStringCreateWithCFString(CFSTR("__wrapper"));
                    JSObjectRef function = JSValueToObject(context, JSObjectGetProperty(context, JSContextGetGlobalObject(context), jsString, NULL), NULL);
                    JSStringRelease(jsString);
                    if(function && JSValueIsObject(context, function)) {
                        success = YES;
                        void* params[3];
                        params[0] = context;
                        params[1] = function;
                        params[2] = &success;
                        _JavaScriptNodeFunctionApplier(root, params);
                        [root applyFunctionOnChildren:_JavaScriptNodeFunctionApplier context:params];
                        _ResetNodeFunctionApplier(root, context);
                        [root applyFunctionOnChildren:_ResetNodeFunctionApplier context:context];
                    }
                }
                
                JSStringRelease(jsScript);
            }
            JSGarbageCollect(context);
            JSGlobalContextRelease(context);
        }
    }
    [pool release];
    return success;
}
