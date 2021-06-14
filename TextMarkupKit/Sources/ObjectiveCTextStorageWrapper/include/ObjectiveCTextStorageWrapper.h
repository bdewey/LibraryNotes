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

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol WrappableTextStorageDelegate
- (void)attributedStringDidChangeWithOldRange:(NSRange)oldRange
                               changeInLength:(NSInteger)changeInLength
                       changedAttributesRange:(NSRange)changedAttributesRange;
@end

@interface WrappableTextStorage: NSMutableAttributedString
@property (nonatomic, weak) id<WrappableTextStorageDelegate> delegate;
@end

/// An NSTextStorage implementation that uses a ParsedAttributedString as its underlying storage.
@interface ObjectiveCTextStorageWrapper : NSTextStorage

/// The underlying ParsedAttributedString for this NSTextStorage instance. Exposed to provide access to things like the AST for the contents.
@property (nonatomic, strong) WrappableTextStorage *storage;

/// Initializes ParsedTextStorage that wraps and underlying `ParsedAttributedString`.
- (instancetype)initWithStorage:(WrappableTextStorage *)storage NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
