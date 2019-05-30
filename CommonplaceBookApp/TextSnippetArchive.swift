// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import Foundation

public struct TextSnippetArchive: Equatable {
  public enum Error: Swift.Error {
    case invalidKeyFormat
    case hashNotFound
  }

  public static let identifier = "Text Snippet Archive version 1.0\n"

  /// Publically constructable.
  public init() {}

  /// The chunks that make up this archive.
  public private(set) var snippets: [TextSnippet] = []

  /// Indexes snippets by the sha1 digest
  public private(set) var snippetDigestIndex: [String: TextSnippet] = [:]

  /// References a symbolic name to a hash value.
  public private(set) var symbolicReferences: [String: String] = [:]

  @discardableResult
  public mutating func insert(_ snippet: TextSnippet) -> TextSnippet {
    if let existingSnippet = snippetDigestIndex[snippet.sha1Digest] {
      return existingSnippet
    } else {
      snippets.append(snippet)
      snippetDigestIndex[snippet.sha1Digest] = snippet
      return snippet
    }
  }

  public mutating func insert(_ text: String) -> TextSnippet {
    let snippet = TextSnippet(text)
    return insert(snippet)
  }

  /// Removes a snippet from the archive.
  /// - returns: True if the snippet was in the archive in the first place.
  @discardableResult
  public mutating func removeSnippet(withDigest digest: String) -> Bool {
    guard snippetDigestIndex.removeValue(forKey: digest) != nil else { return false }
    snippets.removeAll(where: { $0.sha1Digest == digest })
    symbolicReferences.removeAll(whereValue: { $0 == digest })
    return true
  }

  /// Adds a symbolic reference to a hash.
  /// - throws: TextSnippetArchive.Error
  public mutating func insertSymbolicReference(key: String, value: String) throws {
    guard !key.isEmpty, !key.contains(":") else { throw Error.invalidKeyFormat }
    guard snippetDigestIndex[value] != nil else { throw Error.hashNotFound }
    symbolicReferences[key] = value
  }

  public func textSerialized() -> String {
    var results = TextSnippetArchive.identifier
    results.append(referencesSerialized())
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
    let references: [String: String]
    if let (parsedReferences, referenceRemainder) = try TextSnippetArchive.parseReferences(
      from: remainder
    ) {
      references = parsedReferences
      remainder = referenceRemainder
    } else {
      references = [:]
    }
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
    self.symbolicReferences = references
  }

  // swiftlint:disable:next force_try
  private static let referenceHeaderRegex = try! NSRegularExpression(
    pattern: "^\\+\\+\\+ References (\\d+)$",
    options: []
  )

  private func referencesSerialized() -> String {
    guard !symbolicReferences.isEmpty else { return "" }
    let serializedText = symbolicReferences
      .map { [$0.key, $0.value].joined(separator: ":") }
      .joined(separator: "\n")
      .appending("\n")
    let lineCount = serializedText.count(of: "\n")
    return "+++ References \(lineCount)\n" + serializedText
  }

  private static func parseReferences(
    from input: Substring
  ) throws -> ([String: String], Substring)? {
    guard let index = input.index(after: 1, character: "\n") else { return nil }
    let header = String(input[input.startIndex ..< index])
    let remainder = input[index...]
    guard
      let match = referenceHeaderRegex.matches(
        in: header,
        options: [],
        range: header.completeRange
      ).first else { return nil }
    guard match.numberOfRanges == 2,
      let lineCount = header.int(at: match.range(at: 1)),
      let endOfReferencesIndex = remainder.index(after: lineCount, character: "\n")
    else {
      throw TextSnippet.SerializationError.invalidHeader
    }
    let referencesSubstring = input[index ..< endOfReferencesIndex]
    let lines = referencesSubstring.split(separator: "\n").compactMap { line -> (String, String)? in
      let components = line.split(separator: ":")
      if components.count == 2 {
        return (String(components[0]), String(components[1]))
      } else {
        return nil
      }
    }
    let references = Dictionary(uniqueKeysWithValues: lines)
    return (references, input[endOfReferencesIndex...])
  }
}

private extension Dictionary {
  /// Removes everything from the dictionary where the value matches a predicate.
  /// - note: O(n) in the number of entries in the dictionary.
  mutating func removeAll(whereValue predicate: (Value) -> Bool) {
    compactMap { predicate($0.value) ? $0.key : nil }
      .forEach { removeValue(forKey: $0) }
  }
}
