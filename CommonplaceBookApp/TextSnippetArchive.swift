// Copyright © 2019 Brian's Brain. All rights reserved.

import CocoaLumberjack
import Foundation

public struct TextSnippetArchive: Equatable {

  public static let identifier = "Text Snippet Archive version 1.0\n"

  /// Publically constructable.
  public init() { }

  /// The chunks that make up this archive.
  public private(set) var snippets: [TextSnippet] = []

  /// Indexes snippets by the sha1 digest
  public private(set) var snippetDigestIndex: [String: TextSnippet] = [:]

  @discardableResult
  public mutating func insert(_ snippet: TextSnippet) -> Bool {
    if let existingSnippet = snippetDigestIndex[snippet.sha1Digest] {
      return false
    } else {
      snippets.append(snippet)
      snippetDigestIndex[snippet.sha1Digest] = snippet
      return true
    }
  }

  public mutating func insert(_ text: String) -> TextSnippet {
    let snippet = TextSnippet(text)
    insert(snippet)
    return snippet
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
    self.snippetDigestIndex = chunkForId
  }
}
