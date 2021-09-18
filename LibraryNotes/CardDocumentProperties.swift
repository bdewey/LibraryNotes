// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

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
