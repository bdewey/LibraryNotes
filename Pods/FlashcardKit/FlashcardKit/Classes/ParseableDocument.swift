// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown
import TextBundleKit

/// A struct that combines a TextBundle with the parsing rules for interpreting the contents
/// of the document.
public struct ParseableDocument {
  public let document: UIDocument
  public let parsingRules: ParsingRules

  public init(document: UIDocument, parsingRules: ParsingRules) {
    self.document = document
    self.parsingRules = parsingRules
  }
}
