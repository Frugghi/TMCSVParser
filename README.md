# TMCSVParser

An Objective-C lightweight CSV parser.

## Requirements

- **OS X**: 10.7+
- **iOS**: 5.0+
- **ARC**: Yes

## Installation

1. Download the source from GitHub
2. Copy `TMCSVParser.h` and `TMCSVParser.m` into your project
3. Import the header `#import "TMCSVParser.h"`

## How to use?

```objc
/* Create the parser */
self.parser = [TMCSVParser parserWithFileAtPath:self.filePath encoding:NSUTF8StringEncoding];

/* Set the delegate */
[self.parser setDelegate:self];

/* Configure the parser */
[self.parser setHasHeader:YES];
[self.parser setIgnoreEmptyLines:YES];
[self.parser setTrimFieldWhitespaces:YES];

/* Start it! */
[self.parser parse];

/* Wait for delegate calls */
```

## License

Copyright (c) 2013 Tommaso Madonia. All rights reserved.

```
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```
