// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import KeyValueCRDT
import UniformTypeIdentifiers

public struct NoteDatabaseKey: RawRepresentable, Hashable, ExpressibleByStringLiteral {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(stringLiteral: String) {
    self.rawValue = stringLiteral
  }

  public static let metadata: NoteDatabaseKey = ".metadata"
  public static let coverImage: NoteDatabaseKey = ".coverImage"
  public static let noteText: NoteDatabaseKey = ".noteText"
  public static let bookIndex: NoteDatabaseKey = ".bookIndex"
  public static func promptCollection(promptType: PromptType, count: Int, id: String) -> NoteDatabaseKey {
    NoteDatabaseKey(rawValue: "\(promptType.rawValue);count=\(count);id=\(id)")
  }

  public static func promptPrefix(for promptType: PromptType) -> String {
    "\(promptType.rawValue);"
  }

  public static func asset(assetKey: String, assetType: UTType) -> NoteDatabaseKey {
    let filename = [assetKey, assetType.preferredFilenameExtension].compactMap { $0 }.joined(separator: ".")
    return NoteDatabaseKey(rawValue: "assets/\(filename)")
  }

  public static func studyLogEntry(date: Date, promptIdentifier: PromptIdentifier, author: Author) -> NoteDatabaseKey {
    let formattedTime = ISO8601DateFormatter().string(from: date)
    // Each key is globally unique so there should never be collisions.
    let key = "\(formattedTime);note=\(promptIdentifier.noteId);promptId=\(promptIdentifier.promptKey);author=\(author.id.uuidString)"
    return NoteDatabaseKey(rawValue: key)
  }

  public var isPrompt: Bool {
    rawValue.hasPrefix("prompt=")
  }

  public var isWellKnown: Bool {
    [".metadata", ".coverImage", ".noteText", ".bookIndex"].contains(rawValue)
  }
}
