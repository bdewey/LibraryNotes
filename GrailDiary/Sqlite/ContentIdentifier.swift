// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import GRDB

/// A tuple used as a primary key in one of the content tables in the database
public struct ContentIdentifier: Hashable {
  public var noteId: String
  public var promptKey: String

  public var keyArray: [String: DatabaseValueConvertible] {
    [ContentRecord.Columns.noteId.rawValue: noteId, ContentRecord.Columns.key.rawValue: promptKey]
  }
}
