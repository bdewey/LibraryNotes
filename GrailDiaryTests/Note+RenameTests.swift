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

final class NoteRenameTests: NoteSqliteStorageTestBase {
  func testRenamePreservesPromptHistory() {
    makeAndOpenEmptyDatabase { database in
      do {
        let identifier = try database.createNote(.withChallenges)
        XCTAssertTrue(try database.note(noteIdentifier: identifier).metadata.hashtags.contains("#test"))
        XCTAssertFalse(try database.note(noteIdentifier: identifier).metadata.hashtags.contains("#testing"))
        let promptIdentifiers = Set(try database.eligiblePromptIdentifiers(before: Date().addingTimeInterval(7 * .day), limitedTo: identifier))
        try database.replaceText("#test", with: "#testing")
        XCTAssertTrue(try database.note(noteIdentifier: identifier).metadata.hashtags.contains("#testing"))
        XCTAssertFalse(try database.note(noteIdentifier: identifier).metadata.hashtags.contains("#test"))
        let newPromptIdentifiers = Set(try database.eligiblePromptIdentifiers(before: Date().addingTimeInterval(7 * .day), limitedTo: identifier))
        XCTAssertEqual(promptIdentifiers, newPromptIdentifiers)
      } catch {
        XCTFail("Unexpected error: \(error)")
      }
    }
  }

  func testRenameHashtagAsAtomicToken() {
    makeAndOpenEmptyDatabase { database in
      do {
        let note1 = try database.createNote(Note(markdown: "First note #book"))
        let note2 = try database.createNote(Note(markdown: "Second note #books"))
        XCTAssertTrue(try database.note(noteIdentifier: note2).metadata.hashtags.contains("#books"))
        try database.renameHashtag("#book", to: "#books")
        XCTAssertFalse(try database.note(noteIdentifier: note1).metadata.hashtags.contains("#book"))
        XCTAssertTrue(try database.note(noteIdentifier: note1).metadata.hashtags.contains("#books"))
        XCTAssertTrue(try database.note(noteIdentifier: note2).metadata.hashtags.contains("#books"))
      } catch {
        XCTFail("Unexpected error: \(error)")
      }
    }
  }
}
