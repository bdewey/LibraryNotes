// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public struct AttributedQuote: Identifiable, Hashable, Sendable {
  public var id: String { "\(noteId):\(key)" }
  public var noteId: String
  public var key: String
  public var text: String
  public var title: String
  public var thumbnailImage: Data?

  public init(noteId: String, key: String, text: String, title: String, thumbnailImage: Data? = nil) {
    self.noteId = noteId
    self.key = key
    self.text = text
    self.title = title
    self.thumbnailImage = thumbnailImage
  }

  public static func == (lhs: AttributedQuote, rhs: AttributedQuote) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
