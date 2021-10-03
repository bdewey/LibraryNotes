// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import KeyValueCRDT

extension Value {
  init(_ promptCollectionInfo: PromptCollectionInfo) throws {
    let jsonData = try JSONEncoder.databaseEncoder.encode(promptCollectionInfo)
    self = .json(String(data: jsonData, encoding: .utf8)!)
  }

  init(_ metadata: BookNoteMetadata) throws {
    let encodedMetadata = try JSONEncoder.databaseEncoder.encode(metadata)
    self = .json(String(data: encodedMetadata, encoding: .utf8)!)
  }

  init(_ studyLogEntry: StudyLog.Entry) throws {
    let jsonData = try JSONEncoder.databaseEncoder.encode(studyLogEntry)
    self = .json(String(data: jsonData, encoding: .utf8)!)
  }

  init(_ text: String?) {
    if let text = text {
      self = .text(text)
    } else {
      self = .null
    }
  }

  var bookNoteMetadata: BookNoteMetadata? {
    decodeJSON(BookNoteMetadata.self)
  }

  var promptCollectionInfo: PromptCollectionInfo? {
    decodeJSON(PromptCollectionInfo.self)
  }

  var studyLogEntry: StudyLog.Entry? {
    decodeJSON(StudyLog.Entry.self)
  }

  func decodeJSON<T: Decodable>(_ type: T.Type) -> T? {
    guard
      let json = self.json,
      let data = json.data(using: .utf8),
      let decodedItem = try? JSONDecoder.databaseDecoder.decode(type, from: data)
    else {
      return nil
    }
    return decodedItem
  }
}
