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

static JSValueRef _DictionaryGetPropertyCallback(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
    CFStringRef cfString = JSStringCopyCFString(kCFAllocatorDefault, propertyName);
    if(cfString) {
        NSDictionary* dictionary = JSObjectGetPrivate(object);
        id value = [dictionary objectForKey:(id)cfString];
        CFRelease(cfString);
        if(value)
            return _JSValueMakeString([value description], ctx); //FIXME: We should handle non-string values properly
    }
    return NULL;
}

static JSValueRef _DictionaryConvertToTypeCallback(JSContextRef ctx, JSObjectRef object, JSType type, JSValueRef* exception) {
    if(type == kJSTypeString) {
        NSDictionary* dictionary = JSObjectGetPrivate(object);
        return _JSValueMakeString([dictionary description], ctx);
    }
    return JSValueMakeUndefined(ctx);
}

JSClassRef _GetDictionaryJavaScriptClass() {
    static JSClassRef class = NULL;
    if(class == NULL) {
        JSClassDefinition definition = kJSClassDefinitionEmpty;
        definition.className = "Dictionary";
        definition.getProperty = _DictionaryGetPropertyCallback;
        definition.convertToType = _DictionaryConvertToTypeCallback;
        class = JSClassCreate(&definition);
        if(class == NULL)
            [NSException raise:NSInternalInconsistencyException format:@""];
    }
    return class;
}

JSValueRef _JSValueMakeDictionary(NSDictionary* dictionary, JSContextRef context) {
    if(dictionary == nil)
        return JSValueMakeUndefined(context);
    return JSObjectMake(context, _GetDictionaryJavaScriptClass(), dictionary);
}
