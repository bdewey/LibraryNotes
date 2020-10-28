// Copyright © 2020 Brian's Brain. All rights reserved.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// An implementation of NSTextStorage that uses a PieceTable for storing text and always returns a set of default attributes.
@interface PieceTablePlainTextStorage : NSTextStorage

- (instancetype)initWithPlainTextAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
