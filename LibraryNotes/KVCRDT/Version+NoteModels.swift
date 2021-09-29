// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import KeyValueCRDT

enum VersionError: String, Error {
  case unexpectedVersionConflict = "Detected a version conflict on a key/value entry that should never conflict"
}

extension Array where Element == Version {
  var metadata: BookNoteMetadata? {
    guard let json = resolved(with: .lastWriterWins)?.json else { return nil }
    return try? JSONDecoder.databaseDecoder.decode(BookNoteMetadata.self, from: json.data(using: .utf8)!)
  }

  var promptCollectionInfo: PromptCollectionInfo? {
    guard let json = resolved(with: .lastWriterWins)?.json else { return nil }
    return try? JSONDecoder.databaseDecoder.decode(PromptCollectionInfo.self, from: json.data(using: .utf8)!)
  }

  /// Gets the corresponding `StudyLog.Entry` for the version array.
  ///
  /// `StudyLog.Entry` should never conflict in a key-value database (keys are unique per author / instance), and this will raise an error if there are multiple versions
  /// for the entry.
  var studyLogEntry: StudyLog.Entry? {
    get throws {
      switch self.count {
      case 0:
        return nil
      case 1:
        return self[0].value.studyLogEntry
      default:
        throw VersionError.unexpectedVersionConflict
      }
    }
  }

  var internalMetadata: InternalMetadata? {
    get throws {
      // If there are conflicting version updates, we take the *max* of all versions.
      try compactMap {
        guard let json = $0.value.json else { return nil }
        return try JSONDecoder.databaseDecoder.decode(InternalMetadata.self, from: json.data(using: .utf8)!)
      }
      .max()
    }
  }
}
