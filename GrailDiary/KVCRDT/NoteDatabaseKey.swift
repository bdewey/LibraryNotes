import Foundation
import KeyValueCRDT

struct NoteDatabaseKey: RawRepresentable, Hashable, ExpressibleByStringLiteral {
  let rawValue: String

  init(rawValue: String) {
    self.rawValue = rawValue
  }

  init(stringLiteral: String) {
    self.rawValue = stringLiteral
  }

  static let metadata: NoteDatabaseKey = ".metadata"
  static let coverImage: NoteDatabaseKey = "coverImage"
  static let noteText: NoteDatabaseKey = "noteText"
  static func promptCollection(promptType: PromptType, count: Int, id: String) -> NoteDatabaseKey {
    NoteDatabaseKey(rawValue: "prompt=\(promptType.rawValue);count=\(count);id=\(id)")
  }

  static func studyLogEntry(date: Date, promptIdentifier: PromptIdentifier, author: Author) -> NoteDatabaseKey {
    let formattedTime = ISO8601DateFormatter().string(from: date)
    // Each key is globally unique so there should never be collisions.
    let key = "\(formattedTime);note=\(promptIdentifier.noteId);promptId=\(promptIdentifier.promptKey);author=\(author.id.uuidString)"
    return NoteDatabaseKey(rawValue: key)
  }

  var isPrompt: Bool {
    rawValue.hasPrefix("prompt=")
  }

  var isWellKnown: Bool {
    [".metadata", "coverImage", "noteText"].contains(rawValue)
  }
}

