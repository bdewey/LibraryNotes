//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

#import "GrailDiary-Swift.h"
#import "ParsedTextStorage.h"

@interface ParsedTextStorage () <ParsedAttributedStringDelegate>

@end

@implementation ParsedTextStorage {
  // _storage provides these values through its delegate callback, which we need to save and use.
  NSRange _oldRange;
  NSInteger _changeInLength;
  NSRange _changedAttributesRange;
  
  // How many times did we get a delegate message?
  NSUInteger _countOfDelegateMessages;
}

- (instancetype)init {
  return [self initWithStorage:[[ParsedAttributedString alloc] init]];
}

- (instancetype)initWithStorage:(ParsedAttributedString *)storage {
  if ((self = [super init]) != nil) {
    _storage = storage;
    _storage.delegate = self;
  }
  return self;
}

/// Provide O(1) access to the underlying character storage.
- (NSString *)string {
  return _storage._string;
}

- (NSDictionary<NSAttributedStringKey,id> *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range {
  return [_storage attributesAtIndex:location effectiveRange:range];
}

- (void)setAttributes:(NSDictionary<NSAttributedStringKey,id> *)attrs range:(NSRange)range {
  [_storage setAttributes:attrs range:range];
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str {
  _countOfDelegateMessages = 0;
  [_storage replaceCharactersInRange:range withString:str];
  NSAssert(_countOfDelegateMessages == 1, @"Expected exactly one delegate message from editing");
  [self beginEditing];
  [self edited:NSTextStorageEditedCharacters range:_oldRange changeInLength:_changeInLength];
  [self edited:NSTextStorageEditedAttributes range:_changedAttributesRange changeInLength:0];
  [self endEditing];
}

- (void)attributedStringDidChangeWithOldRange:(NSRange)oldRange
                               changeInLength:(NSInteger)changeInLength
                       changedAttributesRange:(NSRange)changedAttributesRange {
  _countOfDelegateMessages += 1;
  _oldRange = oldRange;
  _changeInLength = changeInLength;
  _changedAttributesRange = changedAttributesRange;
}

@end
