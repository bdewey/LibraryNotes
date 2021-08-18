// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import GrailDiary
import KeyValueCRDT
import XCTest

enum TestError: Error {
  case couldNotOpenDatabase
  case couldNotCloseDatabase
}

/// Base class for tests that work with the note database -- provides key helper routines.
class NoteSqliteStorageTestBase: XCTestCase {
  func withEmptyDatabase(testCase: @escaping (NoteDatabase) throws -> Void) async throws {
    let database = try await makeAndOpenEmptyKeyValueDatabase()
    do {
      try testCase(database)
    }
    _ = await database.close()
    try FileManager.default.removeItem(at: database.fileURL)
  }

  func makeAndOpenEmptyKeyValueDatabase() async throws -> NoteDatabase {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let database = try NoteDatabase(fileURL: fileURL, author: Author(id: UUID(), name: "test"))
    let success = await database.open()
    if !success {
      throw TestError.couldNotOpenDatabase
    }
    return database
  }
}
