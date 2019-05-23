// Copyright © 2019 Brian's Brain. All rights reserved.

import Foundation

public struct TextArchive: Equatable {

  /// Publically constructable.
  public init() { }

  /// The chunks that make up this archive.
  public var chunks: [Chunk] = []

  public mutating func append(_ text: String) -> Chunk {
    let chunk = Chunk(text)
    chunks.append(chunk)
    return chunk
  }

  public mutating func append(_ text: String, parent: Chunk) -> Chunk {
    let chunk = Chunk(text: text, parent: parent)
    chunks.append(chunk)
    return chunk
  }

  public func textSerialized() -> String {
    return chunks.map { $0.textSerialized() }.joined()
  }

  public init(textSerialization: String) throws {
    var remainder = textSerialization[textSerialization.startIndex...]
    var chunks: [Chunk] = []
    while !remainder.isEmpty {
      let (chunk, nextStep) = try Chunk.parse(remainder)
      chunks.append(chunk)
      remainder = nextStep
    }
    self.chunks = chunks
  }

  /// A chunk of text to store in the archive.
  /// Since the archive is line-based, each chunk *must* end with a newline (\n)
  /// If you try to create a chunk that does not end with a newline, we add one.
  public final class Chunk {

    /// Designated initalizer.
    public init(_ text: String) {
      self.text = text.appendingNewlineIfNecessary()
      self.sha1Digest = self.text.sha1Digest()
      self.lineCount = self.text.reduce(0, { count, character in
        if character == "\n" {
          return count + 1
        } else {
          return count
        }
      })
      self.parent = nil
    }

    public init(text: String, parent: Chunk) {
      let text = text.appendingNewlineIfNecessary()
      let dmp = DiffMatchPatch()
      let diff = dmp.diff_main(ofOldString: parent.text, andNewString: text)
      dmp.diff_cleanupSemantic(diff)
      let patch = dmp.patch_make(fromOldString: parent.text, andDiffs: diff)
      let patchText = dmp.patch_(toText: patch)!

      self.text = patchText
      self.lineCount = patchText.reduce(0, { count, character in
        if character == "\n" {
        return count + 1
        } else {
        return count
        }
      })
      self.parent = parent
      self.sha1Digest = text.sha1Digest()
    }

    private init(text: String, sha1Digest: String, lineCount: Int, parent: Chunk? = nil) {
      self.text = text
      self.sha1Digest = sha1Digest
      self.lineCount = lineCount
      self.parent = parent
    }

    /// The text in this chunk. Guaranteed to end in a "\n"
    public let text: String

    /// The SHA-1 digest of `text`
    public let sha1Digest: String

    /// How many lines in this chunk.
    public let lineCount: Int

    /// Optional: A parent TextChunk. If present, `text` is a diff operation that, when applied
    /// to the ...
    public let parent: Chunk?
  }
}

extension TextArchive {
  public enum SerializationError: Error {
    case excessInput
    case expectedDigest
    case expectedInteger
    case invalidHash
    case invalidHeader
    case invalidPrefix(expected: String)
    case wrongNumberOfLines(expected: Int, actual: Int)
  }
}

/// Serialization / deserialization of the chunk.
public extension TextArchive.Chunk {

  convenience init<S: StringProtocol>(
    textSerialization: S
  ) throws where S.SubSequence == Substring {
    let (chunk, remainder) = try TextArchive.Chunk.parse(
      textSerialization[textSerialization.startIndex...]
    )
    if !remainder.isEmpty {
      throw TextArchive.SerializationError.excessInput
    }
    if chunk.sha1Digest != chunk.text.sha1Digest() {
      throw TextArchive.SerializationError.invalidHash
    }
    self.init(text: chunk.text, sha1Digest: chunk.sha1Digest, lineCount: chunk.lineCount)
  }

  /// Returns plain-text serialization of this chunk.
  func textSerialized() -> String {
    if let parent = parent {
      return "+++ \(sha1Digest) \(parent.sha1Digest) \(lineCount)\n\(text)"
    } else {
      return "+++ \(sha1Digest) \(lineCount)\n\(text)"
    }
  }

  internal static func parse(_ input: Substring) throws -> (TextArchive.Chunk, Substring) {
    guard let (chunk, remainder) = parseChunkWithoutParent(from: input) else {
      throw TextArchive.SerializationError.invalidHeader
    }
    return (chunk, remainder)
  }

  private static func parseChunkWithoutParent(
    from input: Substring
  ) -> (TextArchive.Chunk, Substring)? {
    guard
      let index = input.firstIndex(of: "\n").flatMap({ input.index(after: $0) })
      else {
        return nil
    }
    let header = String(input[input.startIndex ..< index])
    guard
      let match = NSRegularExpression.noParentChunkHeader.matches(in: header, options: [], range: header.completeRange).first,
      match.numberOfRanges == 3,
      let lineCount = header.int(at: match.range(at: 2)),
      let splitIndex = input[index...].index(after: lineCount, character: "\n")
      else {
        return nil
    }
    let digest = header.string(at: match.range(at: 1))
    return (
      TextArchive.Chunk(
        text: String(input[index ..< splitIndex]),
        sha1Digest: digest,
        lineCount: lineCount
      ),
      input[splitIndex...]
    )
  }
}

private extension NSRegularExpression {
  // swiftlint:disable:next force_try
  static let noParentChunkHeader = try! NSRegularExpression(
    pattern: "^\\+\\+\\+ ([0-9a-f]{40}) (\\d+)$",
    options: []
  )
}

extension TextArchive.Chunk: Equatable {
  public static func == (lhs: TextArchive.Chunk, rhs: TextArchive.Chunk) -> Bool {
    // don't have to compare text if the digests match!
    return lhs.sha1Digest == rhs.sha1Digest &&
      lhs.lineCount == rhs.lineCount
  }
}

private extension String {
  func appendingNewlineIfNecessary() -> String {
    if last == "\n" {
      return self
    } else {
      return self.appending("\n")
    }
  }

  func string(at range: NSRange) -> String {
    return String(self[Range(range, in: self)!])
  }

  func int(at range: NSRange) -> Int? {
    return Int(string(at: range))
  }

  var completeRange: NSRange {
    return NSRange(startIndex ..< endIndex, in: self)
  }
}

private extension StringProtocol {
  /// Returns the index that is *after* the `count` occurence of `character` in the receiver.
  func index(after count: Int, character: Character) -> String.Index? {
    var index = startIndex
    var newlineCount = 0
    while index != endIndex {
      if self[index] == character { newlineCount += 1 }
      index = self.index(after: index)
      if newlineCount == count {
        return index
      }
    }
    return nil
  }
}
