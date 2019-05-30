// Copyright © 2017-present Brian's Brain. All rights reserved.

import CwlSignal
import Foundation
import MiniMarkdown
import TextBundleKit

public final class MiniMarkdownSignal {
  init(textStorage: DocumentProperty<String>, parsingRules: MiniMarkdown.ParsingRules) {
    self.parsingRules = parsingRules
    self.textStorage = textStorage
    self.signal = textStorage.signal
      .map { parsingRules.parse($0.value) }
      .continuous()
  }

  public let parsingRules: MiniMarkdown.ParsingRules
  private let textStorage: DocumentProperty<String>
  public let signal: Signal<[Node]>
}
