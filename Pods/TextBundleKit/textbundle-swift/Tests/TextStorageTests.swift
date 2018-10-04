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

import TextBundleKit
import XCTest

let expectedMarkdown = """
# Textbundle Example

This is a simple example of a textbundle package. The following paragraph contains an example of a referenced image using the embedding code `![](assets/textbundle.png)`.

![](assets/textbundle.png)

"""

final class TextStorageTests: XCTestCase {

  func testCanLoadMarkdown() {
    let document = try! TextBundleTestHelper.makeDocument("testCanLoadMarkdown")
    let didOpen = expectation(description: "did open")
    document.open { (success) in
      XCTAssert(success)
      XCTAssertEqual(document.text.taggedResult.value?.value, expectedMarkdown)
      didOpen.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
  }
  
  func testConcurrentEdits() {
    let editedText = "# Edited!\n\nThis is my edited text."
    let activeDocument = try! TextBundleTestHelper.makeDocument("testConcurrentEdits")
    let passiveDocument = TextBundleDocument(fileURL: activeDocument.fileURL)
    let didOpenPassive = expectation(description: "did open passive")
    passiveDocument.open { (success) in
      XCTAssert(success)
      didOpenPassive.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
    let didOpenActive = expectation(description: "did open active")
    activeDocument.open { (success) in
      XCTAssert(success)
      didOpenActive.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
    var textHistory: [Result<Tagged<String>>] = []
    let passiveDidGetEditedText = expectation(description: "passive document got the edited text")
    var subscription: AnySubscription? = passiveDocument.text.subscribe { (result) in
      textHistory.append(result)
      _ = result.flatMap({ (valueDescription) -> Void in
        if valueDescription.value == editedText {
          passiveDidGetEditedText.fulfill()
        }
      })
    }
    defer {
      subscription = nil
    }
    activeDocument.text.setValue(editedText)
    activeDocument.autosave(completionHandler: nil)
    waitForExpectations(timeout: 3, handler: nil)
    XCTAssertEqual(textHistory.count, 2)
  }
}
