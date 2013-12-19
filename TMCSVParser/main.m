//
//  main.m
//  TMCSVParser
//
//  Created by Tommaso Madonia on 18/12/13.
//  Copyright (c) 2013 Tommaso Madonia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TMCSVParserTester.h"

int main(int argc, const char * argv[])
{

    @autoreleasepool {

        NSString *filePath = [NSString stringWithFormat:@"%@/TMCSVParser/Test.csv", PROJECT_DIR];
        NSLog(@"File path: %@", filePath);

        TMCSVParserTester *tester = [[TMCSVParserTester alloc] initWithFilePath:filePath];
        [tester startParser];        
    }
    return 0;
}
