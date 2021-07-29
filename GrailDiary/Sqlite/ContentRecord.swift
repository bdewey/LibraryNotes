// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import GRDB

enum ContentRole: String, Codable {
  /// The main text that the person has entered as part of the note.
  case primary

  /// An optional "reference" is the material that a note is about (a web page, PDF, book citation, etc)
  case reference

  /// An embedded image
  case embeddedImage
}

/// For rows that contain text, this is the text.
struct ContentRecord: Codable, FetchableRecord, PersistableRecord {
  static let databaseTableName = "content"
  var text: String
  var noteId: String
  var key: String
  var role: String
  var mimeType: String

  enum Columns: String, ColumnExpression {
    case text
    case noteId
    case key
    case role
    case mimeType
  }

  static let promptStatistics = hasMany(PromptRecord.self)
  static let note = belongsTo(NoteRecord.self)

  static func primaryKey(noteId: Note.Identifier, key: String) -> [String: DatabaseValueConvertible] {
    [ContentRecord.Columns.noteId.rawValue: noteId, ContentRecord.Columns.key.rawValue: key]
  }

  static func fetchOne(_ database: Database, key: ContentIdentifier) throws -> ContentRecord? {
    try fetchOne(database, key: key.keyArray)
  }

  @discardableResult
  static func deleteOne(_ database: Database, key: ContentIdentifier) throws -> Bool {
    try deleteOne(database, key: key.keyArray)
  }

  /// Converts the receiver to an object conforming to PromptCollection, if possible.
  func asPromptCollection() throws -> PromptCollection {
    guard let klass = PromptType.classMap[role] else {
      throw NoteDatabaseError.unknownPromptType
    }
    guard let promptCollection = klass.init(rawValue: text) else {
      throw NoteDatabaseError.cannotDecodePromptCollection
    }
    return promptCollection
  }
}
