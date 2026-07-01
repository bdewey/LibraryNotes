// Copyright (c) 2018-2025  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

/// A Card for remembering a sentence with a word/phrase removed and optionally replaced with
/// a hint. The removed word/phrase is a "cloze".
///
/// See https://en.wikipedia.org/wiki/Cloze_test
public struct ClozePrompt {
  /// Designated initializer.
  ///
  /// - parameter markdown: The markdown content that contains at least one cloze.
  /// - parameter closeIndex: The index of the cloze in `markdown` to remove when testing.
  public init(template: ClozePromptCollection, markdown: String, clozeIndex: Int) {
    self.markdown = markdown
    self.clozeIndex = clozeIndex
  }

  /// The markdown content that contains at least one cloze.
  public let markdown: String

  /// The index of the cloze in `markdown` to remove when testing.
  public let clozeIndex: Int
}

extension ClozePrompt: Prompt {}
