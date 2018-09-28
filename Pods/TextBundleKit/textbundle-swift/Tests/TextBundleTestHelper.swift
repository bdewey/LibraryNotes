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

final class TextBundleTestHelper {
  static let expectedDocumentContents = """
    # Textbundle Example

    This is a simple example of a textbundle package. The following paragraph contains an example of a referenced image using the embedding code `![](assets/textbundle.png)`.

    ![](assets/textbundle.png)

    """
  
  static var testResources: Bundle {
    let resourceURL = Bundle(for: TextBundleTestHelper.self).url(
      forResource: "TestContent",
      withExtension: "bundle"
    )
    return Bundle(url: resourceURL!)!
  }
  
  static func makeDocument(
    _ identifier: String,
    resource: String = "Textbundle Example"
  ) throws -> TextBundleDocument {
    let url = testResources.url(forResource: resource, withExtension: "textbundle")!
    let pathComponent = identifier + "-" + UUID().uuidString + ".textbundle"
    let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(pathComponent)
    try FileManager.default.copyItem(at: url, to: temporaryURL)
    return TextBundleDocument(fileURL: temporaryURL)
  }
}

protocol TextBundleHelperMethods {
  func assertEditingWorks(for document: TextBundleDocument)
}

extension TextBundleHelperMethods where Self: XCTestCase {
  func assertEditingWorks(for document: TextBundleDocument) {
    let editedText = "This is edited text!\n"
    let didEdit = expectation(description: "did edit")
    document.open { (success) in
      XCTAssertTrue(success)
      let textStorage = document.text
      let text = try! textStorage.currentResult.unwrap()
      XCTAssertEqual(TextBundleTestHelper.expectedDocumentContents, text)
      textStorage.setValue(editedText)
      didEdit.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
    
    XCTAssertTrue(document.hasUnsavedChanges)
    let didClose = expectation(description: "did close")
    document.close { (success) in
      XCTAssertTrue(success)
      didClose.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
    
    let roundTripDocument = TextBundleDocument(fileURL: document.fileURL)
    let didOpen = expectation(description: "did open")
    roundTripDocument.open { (success) in
      XCTAssertTrue(success)
      let newStorage = roundTripDocument.text
      XCTAssertEqual(newStorage.currentResult.value, editedText)
      XCTAssertEqual(roundTripDocument.assetNames, ["textbundle.png"])
      didOpen.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
  }
}
