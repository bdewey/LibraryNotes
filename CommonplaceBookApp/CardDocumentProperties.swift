// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation

/// A struct that combines document attribution with the parsing rules for interpreting the contents
/// of the document.
public struct CardDocumentProperties {
  /// The document name that the card came from.
  public let documentName: Note.Identifier

  /// Attribution to use when displaying cards from the document, with markdown formatting.
  public let attributionMarkdown: String

  public init(documentName: Note.Identifier, attributionMarkdown: String) {
    self.documentName = documentName
    self.attributionMarkdown = attributionMarkdown
  }
}
