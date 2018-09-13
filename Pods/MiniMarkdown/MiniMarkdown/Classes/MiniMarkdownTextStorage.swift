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

import UIKit

/// Text storage with syntax highlighting.
public final class MiniMarkdownTextStorage: NSTextStorage {

  /// The core storage
  private let storage = NSMutableAttributedString()

  /// Default text attributes
  public var defaultAttributes = NSAttributedString.Attributes(
    UIFont.preferredFont(forTextStyle: .body)
  )

  public var stylesheet = AttributedStringStylesheet()
  public var editedRangeBeforeHighlighting: NSRange?
  public var parsingRules = ParsingRules()

  public override func processEditing() {
    editedRangeBeforeHighlighting = editedRange
    guard let range = Range(self.editedRange, in: self.string) else { return }
    try? self.applySyntaxHighlighting(
      to: range,
      baseAttributes: defaultAttributes,
      stylesheet: stylesheet,
      parsingRules: parsingRules
    )
    super.processEditing()
    editedRangeBeforeHighlighting = nil
  }

  // MARK: - Required overrides

  override public var string: String {
    return storage.string
  }

  override public func attributes(at location: Int, effectiveRange range: NSRangePointer?)
    -> [NSAttributedString.Key: Any] {
    return storage.attributes(at: location, effectiveRange: range)
  }

  override public func replaceCharacters(in range: NSRange, with str: String) {
    storage.replaceCharacters(in: range, with: str)
    self.edited(
      NSTextStorage.EditActions.editedCharacters,
      range: range,
      changeInLength: str.count - range.length
    )
  }

  override public func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
    storage.setAttributes(attrs, range: range)
    self.edited(.editedAttributes, range: range, changeInLength: 0)
  }
}
