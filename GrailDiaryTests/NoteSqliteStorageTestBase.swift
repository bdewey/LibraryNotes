//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

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
