//
//  TMCSVParser.h
//  TMCSVParser
//
//  Created by Tommaso Madonia on 17/12/13.
//  Copyright (c) 2013 Tommaso Madonia. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

@protocol TMCSVParserDelegate;

@interface TMCSVParser : NSObject

@property (nonatomic, weak) id<TMCSVParserDelegate> delegate;
@property (nonatomic, assign) BOOL hasHeader;
@property (nonatomic, assign) BOOL sanitizeFields;
@property (nonatomic, assign) BOOL trimFieldWhitespaces;
@property (nonatomic, assign) BOOL nullifyEmptyFields;
@property (nonatomic, assign) BOOL ignoreEmptyLines;
@property (nonatomic, assign) unichar delimiter;
@property (nonatomic, assign) unichar quoteChar;
@property (nonatomic, assign) unichar escapeChar;
@property (nonatomic, assign) unichar commentChar;
@property (nonatomic, assign) NSInteger bufferSize;
@property (nonatomic, strong, readonly) NSArray *header;
@property (nonatomic, strong, readonly) NSInputStream *inputStream;
@property (nonatomic, assign, readonly) NSStringEncoding encoding;
@property (nonatomic, assign, readonly) NSUInteger totalBytesRead;

+ (instancetype)parserWithString:(NSString *)string;
+ (instancetype)parserWithFileAtPath:(NSString *)filePath encoding:(NSStringEncoding)encoding;
+ (instancetype)parserWithData:(NSData *)data encoding:(NSStringEncoding)encoding;
+ (instancetype)parserWithInputStream:(NSInputStream *)inputStream encoding:(NSStringEncoding)encoding;

- (void)parse;
- (void)cancel;

@end

@protocol TMCSVParserDelegate <NSObject>

@optional

- (void)parserDidBeginParsing:(TMCSVParser *)parser;
- (void)parserDidEndParsing:(TMCSVParser *)parser;

- (void)parser:(TMCSVParser *)parser didBeginRecord:(NSUInteger)recordIndex;
- (void)parser:(TMCSVParser *)parser didEndRecord:(NSUInteger)recordIndex;

- (void)parser:(TMCSVParser *)parser didReadHeader:(NSArray *)header;
- (void)parser:(TMCSVParser *)parser didReadRecord:(NSArray *)record atIndex:(NSInteger)recordIndex;
- (void)parser:(TMCSVParser *)parser didReadField:(NSString *)field atIndex:(NSInteger)fieldIndex;
- (void)parser:(TMCSVParser *)parser didReadComment:(NSString *)comment;

- (void)parser:(TMCSVParser *)parser didFailsWithError:(NSError *)error;

@end
