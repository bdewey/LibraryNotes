// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import Foundation

/// A "semantically immutable" collection of lines of text.
///
/// - note: "Semantically immutable" means the actual *contents* of the text will not change once created.
/// However, the *encoding* of the text might change.
public final class TextSnippet {
  /// Designated public initalizer.
  ///
  /// This will insert a newline if needed to `text`, count the number of lines, and compute the SHA1 digest
  /// of the text to use as the snippet identifier.
  public init(_ text: String) {
    let text = text.appendingNewlineIfNecessary()
    self.encoding = .raw(text: text)
    self.sha1Digest = text.sha1Digest()
    self.lineCount = text.count(of: "\n")
  }

  /// Private memberwise initializer.
  ///
  /// Unlike the public initializer, this does no validation that `text` ends in a newline, that the hashes match, etc.
  private init(
    encoding: TextSnippetEncoding,
    sha1Digest: String,
    lineCount: Int
  ) {
    self.encoding = encoding
    self.sha1Digest = sha1Digest
    self.lineCount = lineCount
  }

  /// The SHA-1 digest of `text`
  public let sha1Digest: String

  /// How many lines in this chunk.
  public private(set) var lineCount: Int

  /// Synchronization for the encoding of this text snippet.
  /// Accessing "parent" and "_text" should happen on this queue.
  private let encodingQueue = DispatchQueue(
    label: "org.brians-brain.encoding",
    qos: .default,
    attributes: [.concurrent]
  )

  /// Internal representation of the text snippet. This could either be the raw text, or it could be a diff.
  // TODO: Make this an enum with associated values.
  private var encoding: TextSnippetEncoding

  /// The text in this chunk. Guaranteed to end in a "\n"
  public var text: String {
    return encodingQueue.sync {
      switch encoding {
      case .raw(let text):
        return text
      case .direct(parent: let snippet, diff: let diff):
        let dmp = DiffMatchPatch()
        do {
          if let patches = try dmp.patch_(fromText: diff) as? [Any],
            let results = dmp.patch_apply(patches, to: snippet.text),
            let result = results[0] as? String {
            return result
          } else {
            throw SerializationError.invalidPatch(patch: diff)
          }
        } catch {
          DDLogError("Unexpected error applying patch: \(error)")
        }
        assertionFailure()
        return ""
      case .indirect:
        preconditionFailure("Have not yet resolved an indirect parent reference")
      }
    }
  }

  /// Changes indirect diff encodings to direct diff encodings using `chunkForId` to supply the mapping of parent IDs to parents.
  internal func resolveIndirectEncoding(
    with chunkForId: [String: TextSnippet]
  ) throws {
    try encodingQueue.sync(flags: DispatchWorkItemFlags.barrier) {
      encoding = try encoding.resolvingIndirect(with: chunkForId)
    }
  }

  /// Changes the encoding of a snippet to be as a diff based on another snippet,
  /// assuming that encoding actually saves space.
  public func encodeAsDiff(from other: TextSnippet?) {
    if let parent = other {
      // Make sure we are not creating a cycle. Every digest in the parent chain should show up once.
      var parentChain = parent.parentChain
      parentChain.insert(sha1Digest, at: 0)
      let snippetCounts = parentChain.reduce([String: Int]()) { (snippetCounts, digest) -> [String: Int] in
        var snippetCounts = snippetCounts
        let currentValue = snippetCounts[digest, default: 0]
        snippetCounts[digest] = currentValue + 1
        return snippetCounts
      }
      assert(
        snippetCounts.allSatisfy { $0.value == 1 },
        "Cycle in parent chain: \(parentChain)\n\(snippetCounts)"
      )

      // Construct the patch.
      let dmp = DiffMatchPatch()
      let parentText = parent.text
      let diff = dmp.diff_main(ofOldString: parentText, andNewString: text)
      dmp.diff_cleanupSemantic(diff)
      let patch = dmp.patch_make(fromOldString: parentText, andDiffs: diff)
      let patchText = dmp.patch_(toText: patch)!

      // Only use the patch encoding if it's smaller than the text, including the header
      // space we need for storing an extra digest
      if patchText.count + 41 < text.count {
        encodingQueue.sync(flags: .barrier) {
          encoding = .direct(parent: parent, diff: patchText)
          lineCount = patchText.count(of: "\n")
        }
      }
    } else {
      let text = self.text
      let lineCount = text.count(of: "\n")
      encodingQueue.sync(flags: .barrier) {
        encoding = .raw(text: text)
        self.lineCount = lineCount
      }
    }
  }
}

/// Serialization / deserialization of the chunk.
public extension TextSnippet {
  enum SerializationError: Error {
    case excessInput
    case expectedDigest
    case expectedInteger
    case invalidHash
    case invalidHeader
    case invalidPatch(patch: String)
    case invalidPrefix(expected: String)
    case noChunk(withDigest: String)
    case wrongNumberOfLines(expected: Int, actual: Int)
  }

  /// Parses a single snippet.
  convenience init<S: StringProtocol>(
    textSerialization: S
  ) throws where S.SubSequence == Substring {
    let (chunk, remainder) = try TextSnippet.parse(
      textSerialization[textSerialization.startIndex...]
    )
    if !remainder.isEmpty {
      throw SerializationError.excessInput
    }
    if chunk.sha1Digest != chunk.text.sha1Digest() {
      throw SerializationError.invalidHash
    }
    self.init(encoding: chunk.encoding, sha1Digest: chunk.sha1Digest, lineCount: chunk.lineCount)
  }

  /// Returns plain-text serialization of this chunk.
  func textSerialized() -> String {
    switch encoding {
    case .raw(text: let text):
      return "+++ \(sha1Digest) \(lineCount)\n\(text)"
    case .direct(parent: let parent, diff: let diff):
      return "+++ \(sha1Digest) \(parent.sha1Digest) \(lineCount)\n\(diff)"
    case .indirect(parentSha1Digest: let parentDigest, diff: let diff):
      return "+++ \(sha1Digest) \(parentDigest) \(lineCount)\n\(diff)"
    }
  }

  /// Top-level parser.
  /// - returns: A tuple of (parsed header, remainder)
  internal static func parse(_ input: Substring) throws -> (TextSnippet, Substring) {
    if let (chunk, remainder) = parseChunkWithoutParent(from: input) {
      return (chunk, remainder)
    } else if let (chunk, remainder) = parseChunkWithParent(from: input) {
      return (chunk, remainder)
    }
    throw SerializationError.invalidHeader
  }
}

extension TextSnippet: Equatable {
  public static func == (lhs: TextSnippet, rhs: TextSnippet) -> Bool {
    // don't have to compare text if the digests match!
    return lhs.sha1Digest == rhs.sha1Digest &&
      lhs.lineCount == rhs.lineCount
  }
}

/// Implementation details.
private extension TextSnippet {
  /// How Text is represented in memory.
  enum TextSnippetEncoding {
    /// We have the plain-ol-text of the snippet
    case raw(text: String)

    /// The text is a diff off of a parent that is loaded in memory
    case direct(parent: TextSnippet, diff: String)

    /// The text is a diff off of a parent that's not yet loaded, but we have the parent ID
    case indirect(parentSha1Digest: String, diff: String)

    /// Turns `.indirect` encodings into `.direct` encodings, leaving other encodings unchanged.
    func resolvingIndirect(with snippets: [String: TextSnippet]) throws -> TextSnippetEncoding {
      switch self {
      case .indirect(parentSha1Digest: let sha1Digest, diff: let diff):
        guard let snippet = snippets[sha1Digest] else {
          throw SerializationError.noChunk(withDigest: sha1Digest)
        }
        return .direct(parent: snippet, diff: diff)
      default:
        return self
      }
    }
  }

  /// Optional: A parent TextChunk. If present, `text` is a diff operation that, when applied
  /// to the ...
  var parent: TextSnippet? {
    return encodingQueue.sync {
      if case TextSnippetEncoding.direct(parent: let parent, diff: _) = encoding {
        return parent
      } else {
        return nil
      }
    }
  }

  /// The list of all sha1 digests needed to construct this snippet through delta encoding,
  /// including this one.
  var parentChain: [String] {
    var results: [String] = []
    enumerateParentChain { snippet in
      results.append(snippet.sha1Digest)
    }
    return results
  }

  func enumerateParentChain(block: (TextSnippet) -> Void) {
    block(self)
    if let parent = parent {
      parent.enumerateParentChain(block: block)
    }
  }

  enum HeaderExpressions {
    /// What the header looks like for a raw-encoded snippet (no parent, no delta)
    // swiftlint:disable:next force_try
    static let noParentChunk = try! NSRegularExpression(
      pattern: "^\\+\\+\\+ ([0-9a-f]{40}) (\\d+)$",
      options: []
    )

    /// What the header looks like for a delta-encoded snippet
    // swiftlint:disable:next force_try
    static let parentChunk = try! NSRegularExpression(
      pattern: "^\\+\\+\\+ ([0-9a-f]{40}) ([0-9a-f]{40}) (\\d+)$",
      options: []
    )
  }

  /// Parses a raw-encoded snippet (no parent, no delta)
  /// - returns: If parsing succeeds, a tuple of (parsed snippet, remainder). If parsing fails, nil.
  static func parseChunkWithoutParent(
    from input: Substring
  ) -> (TextSnippet, Substring)? {
    guard
      let index = input.firstIndex(of: "\n").flatMap({ input.index(after: $0) })
    else {
      return nil
    }
    let header = String(input[input.startIndex ..< index])
    guard
      let match = HeaderExpressions.noParentChunk.matches(
        in: header,
        options: [],
        range: header.completeRange
      ).first,
      match.numberOfRanges == 3,
      let lineCount = header.int(at: match.range(at: 2)),
      let splitIndex = input[index...].index(after: lineCount, character: "\n")
    else {
      return nil
    }
    let digest = header.string(at: match.range(at: 1))
    return (
      TextSnippet(
        encoding: .raw(text: String(input[index ..< splitIndex])),
        sha1Digest: digest,
        lineCount: lineCount
      ),
      input[splitIndex...]
    )
  }

  /// Parses a delta-encoded snippet
  /// - returns: If parsing succeeds, a tuple of (parsed snippet, remainder). If parsing fails, nil.
  static func parseChunkWithParent(
    from input: Substring
  ) -> (TextSnippet, Substring)? {
    guard
      let index = input.firstIndex(of: "\n").flatMap({ input.index(after: $0) })
    else {
      return nil
    }
    let header = String(input[input.startIndex ..< index])
    guard
      let match = HeaderExpressions.parentChunk.matches(
        in: header,
        options: [],
        range: header.completeRange
      ).first,
      match.numberOfRanges == 4,
      let lineCount = header.int(at: match.range(at: 3)),
      let splitIndex = input[index...].index(after: lineCount, character: "\n")
    else {
      return nil
    }
    let digest = header.string(at: match.range(at: 1))
    let parentReference = header.string(at: match.range(at: 2))
    return (
      TextSnippet(
        encoding: .indirect(parentSha1Digest: parentReference, diff: String(input[index ..< splitIndex])),
        sha1Digest: digest,
        lineCount: lineCount
      ),
      input[splitIndex...]
    )
  }
}
