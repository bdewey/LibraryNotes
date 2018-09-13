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

import XCTest
import TextBundleKit

final class TextBundleSnapshotTests: XCTestCase {

  func testSimpleSnapshot() {
    let editedText = "updated text"
    let document = try! TextBundleTestHelper.makeDocument("testSimpleSnapshot")
    let didOpen = expectation(description: "did open")
    document.open { (success) in
      XCTAssert(success)
      didOpen.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
    let now = Date()
    let textStorage = TextStorage(document: document)
    try! textStorage.makeSnapshot(at: now)
    textStorage.text.setValue(editedText)
    let didClose = expectation(description: "did close")
    document.close { (success) in
      XCTAssert(success)
      didClose.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
    
    let roundTripDocument = TextBundleDocument(fileURL: document.fileURL)
    let didRead = expectation(description: "did read")
    roundTripDocument.open { (_) in
      let newStorage = TextStorage(document: roundTripDocument)
      let text = try! newStorage.text.currentResult.unwrap()
      XCTAssertEqual(text, editedText)
      XCTAssertEqual(try? newStorage.snapshot(at: now), TextBundleTestHelper.expectedDocumentContents)
      didRead.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
  }
}
