// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import Foundation

/// A collection of TextSnippets, indexed by the sha1Digest property, that can be serialized & deserialized as plain text.
public struct TextSnippetArchive: Equatable {
  public enum Error: Swift.Error {
    case invalidKeyFormat
    case hashNotFound
  }

  /// Line that identifies a valid snippet archive; will appear as the first line in the archive.
  public static let identifier = "Text Snippet Archive version 1.0\n"

  /// Publically constructable.
  public init() {}

  /// Indexes snippets by the sha1 digest
  public private(set) var snippets: [String: TextSnippet] = [:]

  /// References a symbolic name to a hash value.
  public private(set) var symbolicReferences: [String: String] = [:]

  /// Inserts a snippet into the collection.
  /// - returns: The instance of the TextSnippet class that is actually stored in the collection. This may not be the same instance
  /// that was passed in.
  @discardableResult
  public mutating func insert(_ snippet: TextSnippet) -> TextSnippet {
    if let existingSnippet = snippets[snippet.sha1Digest] {
      return existingSnippet
    } else {
      snippets[snippet.sha1Digest] = snippet
      return snippet
    }
  }

  /// Convenience: Converts a string into a TextSnippet, then inserts it into the collection.
  public mutating func insert(_ text: String) -> TextSnippet {
    let snippet = TextSnippet(text)
    return insert(snippet)
  }

  /// Removes a snippet from the archive.
  /// - returns: True if the snippet was in the archive in the first place.
  @discardableResult
  public mutating func removeSnippet(withDigest digest: String) -> Bool {
    guard snippets.removeValue(forKey: digest) != nil else { return false }
    symbolicReferences.removeAll(whereValue: { $0 == digest })
    return true
  }

  /// Adds `text` to the archive as a symbolic reference.
  ///
  /// This method creates a snippet for `text` and inserts the snippet into the archive. It saves the sha1Digest
  /// of the new snippet in `symbolicReferences` using `key`.
  ///
  /// - note: `key` cannot contain a colon, or it won't properly deserialize. The method throws an error if you
  /// use an invalid key.
  ///
  /// - parameter key: The symbolic reference key.
  /// - parameter text: The text to insert.
  /// - parameter deleteExistingSnippet: If true, any snippet currently referenced by `symbolicReferences[key]` will be removed from the archive.
  /// - throws: `Error.invalidKeyFormat` if `key` is not a valid key.
  @discardableResult
  public mutating func setSymbolicReference(
    key: String,
    text: String,
    deleteExistingSnippet: Bool = true
  ) throws -> String {
    guard !key.isEmpty, !key.contains(":") else { throw Error.invalidKeyFormat }
    if deleteExistingSnippet, let existingSnippet = symbolicReferences[key] {
      removeSnippet(withDigest: existingSnippet)
    }
    let snippet = insert(text)
    symbolicReferences[key] = snippet.sha1Digest
    return snippet.sha1Digest
  }

  /// Merge the contents of another TextSnippetArchive into the receiver.
  ///
  /// - note: This implementation is simple, "correct" (no data is lost), but
  ///         suboptimal. If `other` has saved space by changing a snippet that
  ///         exists in the reciever to a delta encoding based off a new snippet,
  ///         it won't be delta encoded after this operation. Since I'm not sure
  ///         I'll actually drive document conflicts from this method, leaving as is.
  // TODO: Need to do something about symbolic references
  public mutating func merge(other: TextSnippetArchive) {
    for (_, snippet) in other.snippets {
      insert(snippet)
    }
  }

  /// Non-mutating variant of `merge`
  public func merging(other: TextSnippetArchive) -> TextSnippetArchive {
    var copy = self
    copy.merge(other: other)
    return copy
  }

  /// Returns the contents of the archive serialized as a single string.
  public func textSerialized() -> String {
    var results = TextSnippetArchive.identifier
    results.append(referencesSerialized())
    for (_, snippet) in snippets {
      results.append(snippet.textSerialized())
    }
    return results
  }

  /// Initializer that constructs an archive from the serialized text format.
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
    var snippets: [String: TextSnippet] = [:]
    while !remainder.isEmpty {
      let (snippet, nextStep) = try TextSnippet.parse(remainder)
      snippets[snippet.sha1Digest] = snippet
      remainder = nextStep
    }
    for (_, snippet) in snippets {
      try snippet.resolveIndirectEncoding(with: snippets)
    }
    self.snippets = snippets
    self.symbolicReferences = references
  }
}

private extension TextSnippetArchive {
  // swiftlint:disable:next force_try
  static let referenceHeaderRegex = try! NSRegularExpression(
    pattern: "^\\+\\+\\+ References (\\d+)$",
    options: []
  )

  /// Returns symbolic references in serialized form.
  func referencesSerialized() -> String {
    guard !symbolicReferences.isEmpty else { return "" }
    let serializedText = symbolicReferences
      .map { [$0.key, $0.value].joined(separator: ":") }
      .joined(separator: "\n")
      .appending("\n")
    let lineCount = serializedText.count(of: "\n")
    return "+++ References \(lineCount)\n" + serializedText
  }

  /// Parses the symbolic references from the beginning of `input`
  /// - returns: A tuple (symbolic references, unparsed remainder) if parsing succeeds, otherwise nil.
  static func parseReferences(
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
