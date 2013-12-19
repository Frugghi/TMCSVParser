//
//  TMCSVParser.m
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
//  CSV RFC: http://tools.ietf.org/html/rfc4180
//

#import "TMCSVParser.h"

@interface TMCSVParser () <NSStreamDelegate>

@property (nonatomic, strong, readwrite) NSInputStream *inputStream;
@property (nonatomic, strong, readwrite) NSArray *header;
@property (nonatomic, assign, readwrite) NSStringEncoding encoding;
@property (nonatomic, assign, readwrite) NSUInteger totalBytesRead;

@property (nonatomic, strong) NSMutableData *dataBuffer;
@property (nonatomic, strong) NSMutableString *stringBuffer;
@property (nonatomic, strong) NSCharacterSet *newlineSet;
@property (nonatomic, strong) NSCharacterSet *whitespaceSet;
@property (nonatomic, strong) NSCharacterSet *delimiterSet;

@property (atomic, assign) BOOL abort;

@end

@implementation TMCSVParser

- (instancetype)init {
    self = [super init];

    if (self) {
        [self setDelimiter:','];
        [self setQuoteChar:'"'];
        [self setEscapeChar:'\\'];
        [self setCommentChar:'#'];
        [self setHasHeader:NO];
        [self setSanitizeFields:NO];
        [self setTrimFieldWhitespaces:NO];
        [self setNullifyEmptyFields:NO];
        [self setIgnoreEmptyLines:NO];
        [self setEncoding:NSUTF8StringEncoding];
        [self setBufferSize:2048];
        [self setDataBuffer:[[NSMutableData alloc] initWithCapacity:self.bufferSize]];
        [self setStringBuffer:[[NSMutableString alloc] initWithCapacity:self.bufferSize]];
    }

    return self;
}

+ (instancetype)parserWithString:(NSString *)string {
    TMCSVParser *parser = [[TMCSVParser alloc] init];
    [parser setInputStream:[NSInputStream inputStreamWithData:[string dataUsingEncoding:NSUTF8StringEncoding]]];
    [parser setEncoding:NSUTF8StringEncoding];

    return parser;
}

+ (instancetype)parserWithFileAtPath:(NSString *)filePath encoding:(NSStringEncoding)encoding {
    TMCSVParser *parser = [[TMCSVParser alloc] init];
    [parser setInputStream:[NSInputStream inputStreamWithFileAtPath:filePath]];
    [parser setEncoding:encoding];

    return parser;
}

+ (instancetype)parserWithData:(NSData *)data encoding:(NSStringEncoding)encoding {
    TMCSVParser *parser = [[TMCSVParser alloc] init];
    [parser setInputStream:[NSInputStream inputStreamWithData:data]];
    [parser setEncoding:encoding];

    return parser;
}

+ (instancetype)parserWithInputStream:(NSInputStream *)inputStream encoding:(NSStringEncoding)encoding {
    TMCSVParser *parser = [[TMCSVParser alloc] init];
    [parser setInputStream:inputStream];
    [parser setEncoding:encoding];

    return parser;
}

#pragma mark - Parsing

- (void)cancel {
    self.abort = YES;
    [self.inputStream close];
}

- (void)parse {
    [self _initParse];
}

- (void)_initParse {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSMutableCharacterSet *delimiterSet = [[NSCharacterSet newlineCharacterSet] mutableCopy];
        [delimiterSet addCharactersInString:[NSString stringWithFormat:@"%C", self.delimiter]];
        [self setDelimiterSet:[delimiterSet copy]];
        [self setNewlineSet:[NSCharacterSet newlineCharacterSet]];
        [self setWhitespaceSet:[NSCharacterSet whitespaceCharacterSet]];

        [self setAbort:NO];
        [self setTotalBytesRead:0];

        [self.inputStream setDelegate:self];
        [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];

        if ([self.inputStream streamStatus] == NSStreamStatusNotOpen) {
            [self.inputStream open];
        } else if ([self.inputStream streamStatus] == NSStreamStatusError) {
            [self didFailsWithError:[self.inputStream streamError]];

            return;
        } else if ([self.inputStream streamStatus] == NSStreamStatusClosed) {
            [self didFailsWithError:nil];

            return;
        } else if ([self.inputStream streamStatus] == NSStreamStatusOpen) {
            [self _parse];
        }

        [[NSRunLoop currentRunLoop] run];
    });
}

- (void)_parse {
    [self didBeginParsing];

    if (self.hasHeader) {
        [self loadBufferIfNecessary];
        [self trimBufferLeadingWhitespaces];

        [self parseHeader];
    }

    NSUInteger index = 0;
    BOOL isComment, isEmptyLine;
    BOOL shouldReturnRecordComponents = (self.delegate && [self.delegate respondsToSelector:@selector(parser:didReadRecord:atIndex:)]);

    while (!self.abort && ([self.inputStream streamStatus] != NSStreamStatusClosed || [self.stringBuffer length] > 0)) {
        [self loadBufferIfNecessary];
        [self trimBufferLeadingWhitespaces];

        if (self.abort || ([self.inputStream streamStatus] == NSStreamStatusClosed && [self.stringBuffer length] == 0)) {
            break;
        }

        isComment = ([self.stringBuffer length] > 0 && [self.stringBuffer characterAtIndex:0] == self.commentChar);
        isEmptyLine = ([self.stringBuffer length] == 0 || [self.newlineSet characterIsMember:[self.stringBuffer characterAtIndex:0]]);

        if (isComment) {
            [self parseComment];
        }

        if (self.ignoreEmptyLines && isEmptyLine) {
            [self parseNewline];
        }

        if ((!self.ignoreEmptyLines || !isEmptyLine) && !isComment) {
            [self didBeginRecord:index];

            @autoreleasepool {
                NSArray *components = [self parseRecord:shouldReturnRecordComponents isHeader:NO];
                [self didReadRecord:components atIndex:index];
            }

            [self didEndRecord:index];

            index++;
        }
    }

    [self.inputStream close];
    
    [self didEndParsing];
}

- (void)parseHeader {
    self.header = [self parseRecord:YES isHeader:YES];

    [self didReadHeader:self.header];
}

- (NSArray *)parseRecord:(BOOL)returnComponents isHeader:(BOOL)isHeader {
    NSMutableArray *components;
    NSString *field;
    NSUInteger index = 0;
    BOOL isEscaped, recordEnd = NO;

    if (returnComponents) {
        components = [[NSMutableArray alloc] init];
    }

    do {
        field = [self parseField:&isEscaped];

        if (self.abort) {
            break;
        }

        if (self.nullifyEmptyFields && [field length] == 0) {
            field = nil;
        }

        if (self.sanitizeFields) {
            field = [self sanitizedField:field escaped:isEscaped];
        }

        if (components) {
            [components addObject:(field ? field : [NSNull null])];
        }

        if (!isHeader) {
            [self didReadField:field atIndex:index];
        }

        if ([self.stringBuffer length] == 0 || [self.newlineSet characterIsMember:[self.stringBuffer characterAtIndex:0]]) {
            recordEnd = YES;
        }

        if (![self parseNewline] && [self.stringBuffer length] > 0) {
            [self.stringBuffer replaceCharactersInRange:NSMakeRange(0, 1) withString:@""];
        }

        index++;
    } while (!recordEnd && !self.abort);

    return [components copy];
}

- (NSString *)parseComment {
    NSInteger index;
    BOOL commentTerminated = NO;
    NSMutableString *comment = [[NSMutableString alloc] init];

    index = -1;

    do {
        while (index + 1 < [self.stringBuffer length] && !commentTerminated) {
            index++;

            if ([self.newlineSet characterIsMember:[self.stringBuffer characterAtIndex:index]]) {
                commentTerminated = YES;
            }
        }

        if (commentTerminated) {
            [comment appendString:[self.stringBuffer substringToIndex:index]];
            [self.stringBuffer replaceCharactersInRange:NSMakeRange(0, MAX(index, 0)) withString:@""];
            [self parseNewline];
        } else {
            [comment appendString:self.stringBuffer];
            [self.stringBuffer setString:@""];
        }

        index = -1;
    } while (!commentTerminated && !self.abort && [self loadBufferIfNecessary]);

    NSString *returnComment = (self.sanitizeFields ? [comment substringFromIndex:1] : [comment copy]);

    [self didReadComment:returnComment];

    return returnComment;
}

- (NSString *)parseField:(BOOL *)escaped {
    NSInteger index;
    BOOL isEscaped, isDelimiter, isWhitespace, isQuote;
    BOOL moreData, fieldTerminated = NO, lastCharWasQuote = NO, lastCharWasEscape = NO, ignoreChar = NO;
    NSUInteger lastWhitespace = NSNotFound, firstDelimiter = NSNotFound;
    NSMutableString *field = [[NSMutableString alloc] init];

    [self loadBufferIfNecessary];
    [self trimBufferLeadingWhitespaces];

    isEscaped = ([self.stringBuffer length] > 0 && [self.stringBuffer characterAtIndex:0] == self.quoteChar);
    index = (isEscaped ? 1 : 0) - 1;

    do {
        while (index + 1 < [self.stringBuffer length] && !fieldTerminated) {
            index++;
            unichar currentChar = [self.stringBuffer characterAtIndex:index];

            if (lastCharWasEscape) {
                lastCharWasEscape = NO;

                continue;
            } else if (currentChar == self.escapeChar) {
                lastCharWasEscape = YES;
            }

            isWhitespace = [self.whitespaceSet characterIsMember:currentChar];
            ignoreChar = (isWhitespace && self.trimFieldWhitespaces);

            if (!isWhitespace) {
                lastWhitespace = NSNotFound;
            } else if (lastWhitespace == NSNotFound) {
                lastWhitespace = index;
            }

            if (isWhitespace && self.trimFieldWhitespaces) {
                currentChar = [self.stringBuffer characterAtIndex:lastWhitespace - 1];
            }

            isDelimiter = [self.delimiterSet characterIsMember:currentChar];
            isQuote = (currentChar == self.quoteChar);

            if (isEscaped && lastCharWasQuote && !isQuote && !isDelimiter && !ignoreChar) {
                isEscaped = NO;

                index = (firstDelimiter != NSNotFound ? firstDelimiter : index);
                isDelimiter = (firstDelimiter != NSNotFound);
            }

            if (isDelimiter && (!isEscaped || (isEscaped && lastCharWasQuote))) {
                fieldTerminated = YES;
            }

            if (isDelimiter && isEscaped && firstDelimiter == NSNotFound) {
                firstDelimiter = index;
            }

            if (lastCharWasQuote && !ignoreChar) {
                lastCharWasQuote = NO;
            } else if (isQuote && !ignoreChar) {
                lastCharWasQuote = YES;
            }
        }

        if (fieldTerminated) {
            [field appendString:[self.stringBuffer substringToIndex:index]];
            [self.stringBuffer replaceCharactersInRange:NSMakeRange(0, MAX(index, 0)) withString:@""];
            moreData = NO;
        } else {
            [field appendString:self.stringBuffer];
            [self.stringBuffer setString:@""];
            moreData = [self loadBufferIfNecessary];
        }

        index = -1;

        if (!moreData && !fieldTerminated && isEscaped && [field characterAtIndex:[field length] - 1] != self.quoteChar) {
            [self.stringBuffer appendString:field];
            [field setString:@""];

            isEscaped = NO;
            moreData = YES;
            index++;
        }
    } while (!fieldTerminated && moreData && !self.abort);

    if (escaped) {
        *escaped = isEscaped;
    }

    if (self.trimFieldWhitespaces) {
        return [field stringByTrimmingCharactersInSet:self.whitespaceSet];
    } else {
        return [field copy];
    }
}

- (BOOL)parseNewline {
    if ([self.stringBuffer length] == 0 && ![self loadBufferIfNecessary]) {
        return NO;
    }

    BOOL success = NO;
    unichar firstChar = [self.stringBuffer characterAtIndex:0];
    if ([self.newlineSet characterIsMember:firstChar]) {
        [self.stringBuffer replaceCharactersInRange:NSMakeRange(0, 1) withString:@""];
        success = YES;
    }

    [self loadBufferIfNecessary];
    if (firstChar == '\r' && [self.stringBuffer length] > 0 && [self.stringBuffer characterAtIndex:0] == '\n') {
        [self.stringBuffer replaceCharactersInRange:NSMakeRange(0, 1) withString:@""];

        return YES;
    }

    return success;
}

- (BOOL)loadBufferIfNecessary {
    if (self.abort) {
        return NO;
    }

    if ([self.stringBuffer length] != 0) {
        return NO;
    }

    while (![self.inputStream hasBytesAvailable] && [self.inputStream streamStatus] != NSStreamStatusClosed && [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);

    NSInteger bufferSize = self.bufferSize - [self.stringBuffer length];
    uint8_t buffer[bufferSize];
    NSInteger bytesRead = [self.inputStream read:buffer maxLength:bufferSize];
    self.totalBytesRead += MAX(bytesRead, 0);

    if (bytesRead <= 0) {
        [self.inputStream close];

        return NO;
    }

    [self.dataBuffer replaceBytesInRange:NSMakeRange(0, [self.dataBuffer length]) withBytes:buffer length:bytesRead];
    NSString *readString = [[NSString alloc] initWithBytes:buffer length:bytesRead encoding:self.encoding];
    [self.stringBuffer appendString:readString];

    return YES;
}

- (void)trimBufferLeadingWhitespaces {
    if (!self.trimFieldWhitespaces) {
        return;
    }

    while ([self.stringBuffer length] > 0 && [self.whitespaceSet characterIsMember:[self.stringBuffer characterAtIndex:0]]) {
        [self.stringBuffer replaceCharactersInRange:NSMakeRange(0, 1) withString:@""];

        [self loadBufferIfNecessary];
    }
}

- (NSString *)sanitizedField:(NSString *)field escaped:(BOOL)escaped {
    if (!field) {
        return nil;
    }

    NSMutableString *sanitizedField = [[NSMutableString alloc] init];
    BOOL lastCharWasQuote = NO, lastCharWasEscape = NO;

    for (NSUInteger index = (escaped ? 1 : 0); index < [field length] - (escaped ? 1 : 0); index++) {
        unichar currentChar = [field characterAtIndex:index];

        if ((currentChar != self.escapeChar && currentChar != self.quoteChar) || (!lastCharWasQuote && currentChar == self.quoteChar) || lastCharWasEscape) {
            [sanitizedField appendFormat:@"%C", currentChar];
        }

        if (lastCharWasQuote) {
            lastCharWasQuote = NO;
        } else if (currentChar == self.quoteChar && escaped) {
            lastCharWasQuote = YES;
        }

        if (lastCharWasEscape) {
            lastCharWasEscape = NO;
        } else if (currentChar == self.escapeChar) {
            lastCharWasEscape = YES;
        }
    }

    return [sanitizedField copy];
}

#pragma mark - NSStream delegate

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {

        case NSStreamEventOpenCompleted:
            [self _parse];

            break;

        case NSStreamEventErrorOccurred:
            [self cancel];
            [self didFailsWithError:[stream streamError]];

            break;
        case NSStreamEventEndEncountered:
            [stream close];

            break;

        case NSStreamEventHasBytesAvailable:
            break;

        default:
            break;
    }
}

#pragma mark - Delegate

- (void)didBeginParsing {
    if (self.delegate && [self.delegate respondsToSelector:@selector(parserDidBeginParsing:)]) {
        [self.delegate parserDidBeginParsing:self];
    }
}

- (void)didEndParsing {
    if (self.delegate && [self.delegate respondsToSelector:@selector(parserDidEndParsing:)]) {
        [self.delegate parserDidEndParsing:self];
    }
}

- (void)didBeginRecord:(NSUInteger)index {
    if (self.delegate && [self.delegate respondsToSelector:@selector(parser:didBeginRecord:)]) {
        [self.delegate parser:self didBeginRecord:index];
    }
}

- (void)didEndRecord:(NSUInteger)index {
    if (self.delegate && [self.delegate respondsToSelector:@selector(parser:didEndRecord:)]) {
        [self.delegate parser:self didEndRecord:index];
    }
}

- (void)didReadHeader:(NSArray *)header {
    if (self.delegate && [self.delegate respondsToSelector:@selector(parser:didReadHeader:)]) {
        [self.delegate parser:self didReadHeader:self.header];
    }
}

- (void)didReadRecord:(NSArray *)record atIndex:(NSUInteger)index {
    if (self.delegate && [self.delegate respondsToSelector:@selector(parser:didReadRecord:atIndex:)]) {
        [self.delegate parser:self didReadRecord:record atIndex:index];
    }
}

- (void)didReadField:(NSString *)field atIndex:(NSUInteger)index {
    if (self.delegate && [self.delegate respondsToSelector:@selector(parser:didReadField:atIndex:)]) {
        [self.delegate parser:self didReadField:field atIndex:index];
    }
}

- (void)didReadComment:(NSString *)comment {
    if (self.delegate && [self.delegate respondsToSelector:@selector(parser:didReadComment:)]) {
        [self.delegate parser:self didReadComment:comment];
    }
}

- (void)didFailsWithError:(NSError *)error {
    if (self.delegate && [self.delegate respondsToSelector:@selector(parser:didFailsWithError:)]) {
        [self.delegate parser:self didFailsWithError:error];
    }
}

@end
