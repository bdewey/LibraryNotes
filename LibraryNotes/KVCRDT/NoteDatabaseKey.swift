// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import KeyValueCRDT
import UniformTypeIdentifiers

/// Represents a valid key for the key-value note database.
///
/// These keys are scoped to individual notes, so there can be multiple instances if the same key in the database. As an escape hatch,
/// any string can be cast to a `NoteDatabaseKey`, but you are strongly encouraged to use one of the static factory methods.
public struct NoteDatabaseKey: RawRepresentable, Hashable, ExpressibleByStringLiteral {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(stringLiteral: String) {
    self.rawValue = stringLiteral
  }

  // MARK: - Well-known keys
  //
  // These are keys that are present for all notes.

  /// Contains the metadata for this note (associated type: JSON)
  public static let metadata: NoteDatabaseKey = ".metadata"

  /// The cover image for the note (associated type: blob)
  public static let coverImage: NoteDatabaseKey = ".coverImage"

  /// The actual note contents (associated type: text)
  public static let noteText: NoteDatabaseKey = ".noteText"

  /// Text values extracted from `metadata` that we want in the full-text index (associated type: text)
  public static let bookIndex: NoteDatabaseKey = ".bookIndex"

  /// True if this key is one of the well-known keys.
  public var isWellKnown: Bool {
    [".metadata", ".coverImage", ".noteText", ".bookIndex"].contains(rawValue)
  }

  // MARK: - Prompt collections

  /// A key that represents a prompt collection of a specific type.
  /// - parameter promptType: The type of the prompt collection.
  /// - parameter count: How many prompts are in the collection.
  /// - parameter id: A unique ID for this prompt collection.
  public static func promptCollection(promptType: PromptType, count: Int, id: String) -> NoteDatabaseKey {
    NoteDatabaseKey(rawValue: "\(promptType.rawValue);count=\(count);id=\(id)")
  }

  /// The prefix for all keys for prompt collections of type `promptType`
  public static func promptPrefix(for promptType: PromptType) -> String {
    "\(promptType.rawValue);"
  }

  /// True if this key represents a prompt collection.
  public var isPrompt: Bool {
    rawValue.hasPrefix("prompt=")
  }

  // MARK: - Binary assets

  public static func asset(assetKey: String, assetType: UTType) -> NoteDatabaseKey {
    let filename = [assetKey, assetType.preferredFilenameExtension].compactMap { $0 }.joined(separator: ".")
    return NoteDatabaseKey(rawValue: "assets/\(filename)")
  }

  // MARK: - Study log entries

  public static func studyLogEntry(date: Date, promptIdentifier: PromptIdentifier, instanceID: UUID) -> NoteDatabaseKey {
    let formattedTime = ISO8601DateFormatter().string(from: date)
    // Each key is globally unique so there should never be collisions.
    let key = "\(formattedTime);note=\(promptIdentifier.noteId);promptId=\(promptIdentifier.promptKey);author=\(instanceID.uuidString)"
    return NoteDatabaseKey(rawValue: key)
  }

}
