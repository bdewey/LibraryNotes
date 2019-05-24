// Copyright © 2019 Brian's Brain. All rights reserved.

import CocoaLumberjack
import Foundation

/// A chunk of text to store in the archive.
/// Since the archive is line-based, each chunk *must* end with a newline (\n)
/// If you try to create a chunk that does not end with a newline, we add one.
public final class TextSnippet {

  /// Designated initalizer.
  public init(_ text: String) {
    self._text = text.appendingNewlineIfNecessary()
    self.sha1Digest = self._text.sha1Digest()
    self.lineCount = self._text.count(of: "\n")
    self._parent = .none
  }

  /// Changes the encoding of a snippet to be as a diff based on another snippet,
  /// assuming that encoding actually saves space.
  public func encodeAsDiff(from other: TextSnippet?) {
    if let parent = other {
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
          _text = patchText
          lineCount = patchText.count(of: "\n")
          _parent = .direct(parent)
        }
      }
    } else {
      let text = self.text
      let lineCount = text.count(of: "\n")
      encodingQueue.sync(flags: .barrier) {
        _text = text
        self.lineCount = lineCount
        _parent = .none
      }
    }
  }

  private enum ParentChunkReference {
    case none
    case direct(TextSnippet)
    case indirect(String)
  }

  private init(
    text: String,
    sha1Digest: String,
    lineCount: Int,
    parent: ParentChunkReference = .none
  ) {
    self._text = text
    self.sha1Digest = sha1Digest
    self.lineCount = lineCount
    self._parent = parent
  }

  internal func resolveParentReference(using chunkForId: [String: TextSnippet]) throws {
    guard case ParentChunkReference.indirect(let digest) = _parent else { return }
    guard let chunk = chunkForId[digest] else {
      throw SerializationError.noChunk(withDigest: digest)
    }
    encodingQueue.sync(flags: DispatchWorkItemFlags.barrier) {
      _parent = .direct(chunk)
    }
  }

  /// Synchronization for the encoding of this text snippet.
  /// Accessing "parent" and "_text" should happen on this queue.
  private let encodingQueue = DispatchQueue(
    label: "org.brians-brain.encoding",
    qos: .default,
    attributes: [.concurrent]
  )

  private var _text: String

  /// The text in this chunk. Guaranteed to end in a "\n"
  public var text: String {
    return encodingQueue.sync {
      if let parent = parent {
        let dmp = DiffMatchPatch()
        do {
          if let patches = try dmp.patch_(fromText: _text) as? [Any],
            let results = dmp.patch_apply(patches, to: parent.text),
            let result = results[0] as? String {
            return result
          } else {
            throw SerializationError.invalidPatch(patch: _text)
          }
        } catch {
          DDLogError("Unexpected error applying patch: \(error)")
        }
        assertionFailure()
        return ""
      } else {
        return _text
      }
    }
  }

  /// The SHA-1 digest of `text`
  public let sha1Digest: String

  /// How many lines in this chunk.
  public private(set) var lineCount: Int

  private var _parent: ParentChunkReference

  /// Optional: A parent TextChunk. If present, `text` is a diff operation that, when applied
  /// to the ...
  public var parent: TextSnippet? {
    switch _parent {
    case .none:
      return nil
    case .direct(let parent):
      return parent
    case .indirect:
      assertionFailure("Have not yet resolved chunk parent")
      return nil
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
    self.init(text: chunk.text, sha1Digest: chunk.sha1Digest, lineCount: chunk.lineCount)
  }

  /// Returns plain-text serialization of this chunk.
  func textSerialized() -> String {
    if let parent = parent {
      return "+++ \(sha1Digest) \(parent.sha1Digest) \(lineCount)\n\(_text)"
    } else {
      return "+++ \(sha1Digest) \(lineCount)\n\(_text)"
    }
  }

  internal static func parse(_ input: Substring) throws -> (TextSnippet, Substring) {
    if let (chunk, remainder) = parseChunkWithoutParent(from: input) {
      return (chunk, remainder)
    } else if let (chunk, remainder) = parseChunkWithParent(from: input) {
      return (chunk, remainder)
    }
    throw SerializationError.invalidHeader
  }

  // swiftlint:disable:next force_try
  static let noParentChunkHeader = try! NSRegularExpression(
    pattern: "^\\+\\+\\+ ([0-9a-f]{40}) (\\d+)$",
    options: []
  )

  private static func parseChunkWithoutParent(
    from input: Substring
    ) -> (TextSnippet, Substring)? {
    guard
      let index = input.firstIndex(of: "\n").flatMap({ input.index(after: $0) })
      else {
        return nil
    }
    let header = String(input[input.startIndex ..< index])
    guard
      let match = TextSnippet.noParentChunkHeader.matches(
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
        text: String(input[index ..< splitIndex]),
        sha1Digest: digest,
        lineCount: lineCount
      ),
      input[splitIndex...]
    )
  }

  // swiftlint:disable:next force_try
  static let parentChunkHeader = try! NSRegularExpression(
    pattern: "^\\+\\+\\+ ([0-9a-f]{40}) ([0-9a-f]{40}) (\\d+)$",
    options: []
  )

  private static func parseChunkWithParent(
    from input: Substring
    ) -> (TextSnippet, Substring)? {
    guard
      let index = input.firstIndex(of: "\n").flatMap({ input.index(after: $0) })
      else {
        return nil
    }
    let header = String(input[input.startIndex ..< index])
    guard
      let match = TextSnippet.parentChunkHeader.matches(
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
        text: String(input[index ..< splitIndex]),
        sha1Digest: digest,
        lineCount: lineCount,
        parent: .indirect(parentReference)
      ),
      input[splitIndex...]
    )
  }
}

extension TextSnippet: Equatable {
  public static func == (lhs: TextSnippet, rhs: TextSnippet) -> Bool {
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

  func count(of character: Character) -> Int {
    return reduce(0, { (count, stringCharacter) -> Int in
      if stringCharacter == character { return count + 1 }
      return count
    })
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
