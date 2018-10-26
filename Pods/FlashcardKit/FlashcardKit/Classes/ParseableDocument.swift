// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown
import TextBundleKit

public struct ParseableDocument {
  public let document: TextBundleDocument
  public let parsingRules: ParsingRules

  public init(document: TextBundleDocument, parsingRules: ParsingRules) {
    self.document = document
    self.parsingRules = parsingRules
  }
}
