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
    }

    private init(text: String, sha1Digest: String, lineCount: Int) {
      self.text = text
      self.sha1Digest = sha1Digest
      self.lineCount = lineCount
    }

    /// The text in this chunk. Guaranteed to end in a "\n"
    public let text: String

    /// The SHA-1 digest of `text`
    public let sha1Digest: String

    /// How many lines in this chunk.
    public let lineCount: Int
  }
}

extension TextArchive {
  public enum SerializationError: Error {
    case excessInput
    case expectedDigest
    case expectedInteger
    case invalidHash
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
    return "+++ \(sha1Digest) \(lineCount)\n\(text)"
  }

  internal static func parse(_ input: Substring) throws -> (TextArchive.Chunk, Substring) {
    let afterPrefix = try parsePrefix("+++ ", in: input)
    let (hash, afterHash) = try parseHash(in: afterPrefix)
    let afterSpace = try parsePrefix(" ", in: afterHash)
    let (lineCount, afterLineCount) = try parseInt(in: afterSpace)
    let afterNewline = try parsePrefix("\n", in: afterLineCount)
    let (text, remainder) = try parse(lineCount: lineCount, in: afterNewline)
    let chunk = TextArchive.Chunk(text: text, sha1Digest: hash, lineCount: lineCount)
    return (chunk, remainder)
  }

  private static func parseHash(in substring: Substring) throws -> (String, Substring) {
    let hashPrefix = substring.prefix(40)
    if hashPrefix.count != 40 {
      throw TextArchive.SerializationError.expectedDigest
    }
    return (String(hashPrefix), substring[hashPrefix.endIndex...])
  }

  private static func parseInt(in substring: Substring) throws -> (Int, Substring) {
    let (prefix, suffix) = substring.prefixAndSuffix(where: { $0.isHexDigit })
    if prefix.isEmpty {
      throw TextArchive.SerializationError.expectedInteger
    }
    if let value = Int(String(prefix)) {
      return (value, suffix)
    } else {
      throw TextArchive.SerializationError.expectedInteger
    }
  }

  private static func parse(lineCount: Int, in substring: Substring) throws -> (String, Substring) {
    var newlineCount = 0
    var index = substring.startIndex
    while index != substring.endIndex {
      if substring[index] == "\n" { newlineCount += 1 }
      index = substring.index(after: index)
      if newlineCount == lineCount {
        return (String(substring[substring.startIndex ..< index]), substring[index...])
      }
    }
    throw TextArchive.SerializationError.wrongNumberOfLines(expected: lineCount, actual: newlineCount)
  }

  private static func parsePrefix(_ text: String, in substring: Substring) throws -> Substring {
    var textIndex = text.startIndex
    var substringIndex = substring.startIndex
    while textIndex != text.endIndex, substringIndex != substring.endIndex {
      if text[textIndex] != substring[substringIndex] {
        throw TextArchive.SerializationError.invalidPrefix(expected: text)
      }
      textIndex = text.index(after: textIndex)
      substringIndex = substring.index(after: substringIndex)
    }
    // We didn't consume the whole prefix
    if textIndex != text.endIndex {
      throw TextArchive.SerializationError.invalidPrefix(expected: text)
    }
    return substring[substringIndex...]
  }
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
}
