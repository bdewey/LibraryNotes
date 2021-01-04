// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import CommonplaceBookApp
import XCTest

/// Base class for tests that work with the note database -- provides key helper routines.
class NoteSqliteStorageTestBase: XCTestCase {
  func makeAndOpenEmptyDatabase(completion: @escaping (NoteDatabase) throws -> Void) {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let database = NoteDatabase(fileURL: fileURL)
    let completionExpectation = expectation(description: "Expected to call completion routine")
    database.open { success in
      if success {
        do {
          try completion(database)
        } catch {
          XCTFail("Unexpected error: \(error)")
        }
      } else {
        XCTFail("Could not open database")
      }
      completionExpectation.fulfill()
    }
    waitForExpectations(timeout: 5, handler: nil)
    let closedExpectation = expectation(description: "Can close")
    database.close { _ in
      try? FileManager.default.removeItem(at: database.fileURL)
      closedExpectation.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
  }
}
