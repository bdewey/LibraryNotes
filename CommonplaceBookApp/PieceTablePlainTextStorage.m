// Copyright © 2020 Brian's Brain. All rights reserved.

#import "CommonplaceBookApp-Swift.h"
#import "PieceTablePlainTextStorage.h"

@interface PieceTablePlainTextStorage ()

@property (nonatomic, copy) NSDictionary<NSAttributedStringKey, id> *plainTextAttributes;
@property (nonatomic, strong) PieceTableString *pieceTableString;

@end

@implementation PieceTablePlainTextStorage

- (instancetype)init {
  return [self initWithPlainTextAttributes:@{}];
}

- (instancetype)initWithPlainTextAttributes:(NSDictionary<NSAttributedStringKey,id> *)attributes {
  self = [super init];
  if (self != nil) {
    _plainTextAttributes = [attributes copy];
    _pieceTableString = [[PieceTableString alloc] init];
  }
  return self;
}

- (NSString *)string {
  return _pieceTableString;
}

- (NSMutableString *)mutableString {
  return _pieceTableString;
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"%@ attributes=%@ length=%lu", [super description], _plainTextAttributes, (unsigned long)_pieceTableString.length];
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str {
  [_pieceTableString replaceCharactersInRange:range withString:str];
  [self edited:NSTextStorageEditedCharacters
         range:range
changeInLength:str.length - range.length];
}

- (NSDictionary<NSAttributedStringKey,id> *)attributesAtIndex:(NSUInteger)location
                                               effectiveRange:(NSRangePointer)range {
  if (range != NULL) {
    *range = NSMakeRange(0, _pieceTableString.length);
  }
  return [_plainTextAttributes copy];
}

- (void)setAttributes:(NSDictionary<NSAttributedStringKey,id> *)attrs range:(NSRange)range {
  // NOTHING
}

@end
