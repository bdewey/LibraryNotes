// Copyright © 2018 Brian's Brain. All rights reserved.

import CwlSignal
import Foundation
import MiniMarkdown
import TextBundleKit

public final class MiniMarkdownSignal {
  init(textStorage: TextStorage, parsingRules: MiniMarkdown.ParsingRules) {
    self.parsingRules = parsingRules
    self.textStorage = textStorage
    self.signal = textStorage.text.signal
      .map { parsingRules.parse($0.value) }
      .continuous()
  }

  private let parsingRules: MiniMarkdown.ParsingRules
  private let textStorage: TextStorage
  public let signal: Signal<[Node]>
}
