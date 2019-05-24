// Copyright © 2019 Brian's Brain. All rights reserved.

import CocoaLumberjack
import Foundation

public struct TextSnippetArchive: Equatable {

  public static let identifier = "Text Snippet Archive version 1.0\n"

  /// Publically constructable.
  public init() { }

  /// The chunks that make up this archive.
  public var snippets: [TextSnippet] = []

  public mutating func append(_ text: String) -> TextSnippet {
    let chunk = TextSnippet(text)
    snippets.append(chunk)
    return chunk
  }

  public mutating func append(_ text: String, parent: TextSnippet) -> TextSnippet {
    let chunk = TextSnippet(text: text, parent: parent)
    snippets.append(chunk)
    return chunk
  }

  public func textSerialized() -> String {
    var results = TextSnippetArchive.identifier
    for chunk in snippets {
      results.append(chunk.textSerialized())
    }
    return results
  }

  public init(textSerialization: String) throws {
    let prefix = textSerialization.prefix(TextSnippetArchive.identifier.count)
    if prefix != TextSnippetArchive.identifier {
      throw TextSnippet.SerializationError.invalidHeader
    }
    var remainder = textSerialization[prefix.endIndex...]
    var chunks: [TextSnippet] = []
    var chunkForId: [String: TextSnippet] = [:]
    while !remainder.isEmpty {
      let (chunk, nextStep) = try TextSnippet.parse(remainder)
      chunks.append(chunk)
      chunkForId[chunk.sha1Digest] = chunk
      remainder = nextStep
    }
    for chunk in chunks {
      try chunk.resolveParentReference(using: chunkForId)
    }
    self.snippets = chunks
  }
}
