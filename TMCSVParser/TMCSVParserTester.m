//
//  TMCSVParserTester.m
//  TMCSVParser
//
//  Created by Tommaso Madonia on 18/12/13.
//  Copyright (c) 2013 Tommaso Madonia. All rights reserved.
//

#import "TMCSVParserTester.h"
#import "TMCSVParser.h"

@interface TMCSVParserTester () <TMCSVParserDelegate>

@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) TMCSVParser *parser;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (nonatomic, assign) NSUInteger totalRecords;

@end

@implementation TMCSVParserTester

- (instancetype)initWithFilePath:(NSString *)filePath {
    self = [super init];

    if (self) {
        [self setFilePath:filePath];
    }

    return self;
}

- (void)startParser {
    [self setSemaphore:dispatch_semaphore_create(0)];
    [self setTotalRecords:0];
    [self setParser:[TMCSVParser parserWithFileAtPath:self.filePath encoding:NSUTF8StringEncoding]];
    [self.parser setDelegate:self];
    [self.parser setHasHeader:YES];
    [self.parser setIgnoreEmptyLines:YES];
    [self.parser setTrimFieldWhitespaces:YES];
    [self.parser setDelimiter:','];

    NSDate *start = [NSDate date];

    [self.parser parse];

    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);

    NSLog(@"Parsing time: %fs", [[NSDate date] timeIntervalSinceDate:start]);
    NSLog(@"Total parsed records: %lu", (unsigned long)self.totalRecords);
}

#pragma mark - TMCSVParser delegate

- (void)parserDidBeginParsing:(TMCSVParser *)parser {
    NSLog(@"Begin parsing...");
    NSLog(@"-----");
}

- (void)parserDidEndParsing:(TMCSVParser *)parser {
    NSLog(@"End parsing...");
    dispatch_semaphore_signal(self.semaphore);
}

- (void)parser:(TMCSVParser *)parser didReadHeader:(NSArray *)header {
    for (NSString *field in header) {
        NSLog(@"Header[%lu]: %@", [header indexOfObject:field], field);
    }
    NSLog(@"-----");
}

- (void)parser:(TMCSVParser *)parser didReadField:(NSString *)field atIndex:(NSInteger)fieldIndex {
    NSLog(@"Field[%lu]: %@", fieldIndex, field);
}

- (void)parser:(TMCSVParser *)parser didReadRecord:(NSArray *)record atIndex:(NSInteger)recordIndex {
    NSLog(@"-----");
    self.totalRecords++;
}

- (void)parser:(TMCSVParser *)parser didReadComment:(NSString *)comment {
    NSLog(@"Comment: %@", comment);
    NSLog(@"-----");
}

- (void)parser:(TMCSVParser *)parser didFailsWithError:(NSError *)error {
    NSLog(@"Error: %@", [error description]);
    dispatch_semaphore_signal(self.semaphore);
}

@end
