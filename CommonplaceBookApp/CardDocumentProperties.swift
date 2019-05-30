// Copyright © 2018-present Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown
import TextBundleKit

/// A struct that combines a TextBundle with the parsing rules for interpreting the contents
/// of the document.
public struct CardDocumentProperties {
  /// The document name that the card came from.
  public let documentName: String

  /// Attribution to use when displaying cards from the document, with markdown formatting.
  public let attributionMarkdown: String

  /// Parsing rules for the document content, including `attributionMarkdown`
  public let parsingRules: ParsingRules

  public init(documentName: String, attributionMarkdown: String, parsingRules: ParsingRules) {
    self.documentName = documentName
    self.attributionMarkdown = attributionMarkdown
    self.parsingRules = parsingRules
  }
}
