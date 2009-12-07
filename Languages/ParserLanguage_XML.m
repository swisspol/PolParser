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

#import "Parser_Internal.h"
#import "ParserLanguage_XML.h"

@interface ParserLanguageXML : ParserLanguageSGML
@end

@implementation ParserLanguageXML

/* WARNING: Keep in sync with ParserLanguage_SGML */
+ (NSArray*) languageNodeClasses {
	NSMutableArray* classes = [NSMutableArray array];
    
    [classes addObject:[ParserNodeIndenting class]];
    
    [classes addObject:[ParserNodeXMLDeclaration class]];
    [classes addObject:[ParserNodeXMLProcessingInstructions class]];
    
    [classes addObject:[ParserNodeXMLDOCTYPE class]];
    [classes addObject:[ParserNodeXMLComment class]];
    [classes addObject:[ParserNodeXMLCDATA class]];
    [classes addObject:[ParserNodeXMLTag class]];
    [classes addObject:[ParserNodeXMLEntity class]];
    
    [classes addObject:[ParserNodeXMLElement class]];
    
    return classes;
}

+ (NSString*) stringWithReplacedEntities:(NSString*)string {
	static NSDictionary* entities = nil;
    if(entities == nil) {
    	entities = [[NSDictionary alloc] initWithObjectsAndKeys:
        	@"&quot;", @"\x22",
            @"&amp;", @"\x26",
            @"&apos;", @"\x27",
            @"&lt;", @"\x3C",
            @"&gt;", @"\x3E",
        nil];
    }
    NSMutableString* newString = [NSMutableString stringWithString:string];
    for(NSString* key in entities)
    	[newString replaceOccurrencesOfString:[entities objectForKey:key] withString:key options:0 range:NSMakeRange(0, newString.length)];
    return newString;
}

+ (Class) SGMLElementClass {
	return [ParserNodeXMLElement class];
}

- (NSString*) name {
    return @"XML";
}

- (NSSet*) fileExtensions {
    return [NSSet setWithObject:@"xml"];
}

@end

@implementation ParserNodeXMLTag
@end

@implementation ParserNodeXMLComment

- (NSString*) cleanContent {
	NSRange range = self.range;
    return [ParserLanguageXML stringWithReplacedEntities:[self.text substringWithRange:NSMakeRange(range.location + 4, range.length - 7)]];
}

@end

@implementation ParserNodeXMLCDATA
@end

@implementation ParserNodeXMLDOCTYPE
@end

@implementation ParserNodeXMLElement
@end

@implementation ParserNodeXMLEntity

- (NSString*) cleanContent {
    return [ParserLanguageXML stringWithReplacedEntities:[self.text substringWithRange:self.range]];
}

@end

PREFIX_SUFFIX_CLASS_IMPLEMENTATION(XMLDeclaration, "<?xml ", "?>")
PREFIX_SUFFIX_CLASS_IMPLEMENTATION(XMLProcessingInstructions, "<?", "?>")

@implementation ParserNodeXMLDeclaration (Internal)

+ (NSSet*) patchedClasses {
	return [NSSet setWithObject:[ParserNodeXMLProcessingInstructions class]];
}

@end

@implementation ParserNodeXMLProcessingInstructions (Internal)

+ (NSSet*) patchedClasses {
	return [NSSet setWithObject:[ParserNodeXMLTag class]];
}

- (NSString*) cleanContent {
	NSRange range = self.range;
    return [ParserLanguageXML stringWithReplacedEntities:[self.text substringWithRange:NSMakeRange(range.location + 2, range.length - 4)]];
}

@end
