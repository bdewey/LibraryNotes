// Copyright © 2017-present Brian's Brain. All rights reserved.

import CommonplaceBookApp
import FlashcardKit
import MiniMarkdown
import XCTest

final class PagePropertiesTests: XCTestCase {
  var metadataProvider: TestMetadataProvider!

  override func setUp() {
    metadataProvider = TestMetadataProvider(
      fileInfo: [
        TestMetadataProvider.FileInfo(fileName: "page1.txt", contents: "Sample #hashtag #test1"),
        TestMetadataProvider.FileInfo(fileName: "page2.txt", contents: "Sample #hashtag #test2"),
      ],
      parsingRules: parsingRules
    )
  }

  let parsingRules: ParsingRules = {
    var parsingRules = ParsingRules()
    parsingRules.inlineParsers.parsers.insert(Cloze.nodeParser, at: 0)
    return parsingRules
  }()

  func testDesiredFilenameWithEmoji() {
    let existingName = "syntax playground.txt"
    metadataProvider.addFileInfo(TestMetadataProvider.FileInfo(
      fileName: existingName,
      contents: "☠️"
    ))

    let didLoad = expectation(description: "did load properties")
    PageProperties.loadProperties(
      from: metadataProvider.fileNameToMetadata[existingName]!,
      in: metadataProvider,
      parsingRules: parsingRules
    ) { results in
      switch results {
      case .failure(let error):
        XCTFail("Unexpected error: \(error)")
      case .success(let properties):
        XCTAssertNil(properties.desiredBaseFileName)
        XCTAssertTrue(properties.hasDesiredBaseFileName)
      }
      didLoad.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
  }

  func testFormattedTitle() {
    let existingName = "test.txt"
    metadataProvider.addFileInfo(TestMetadataProvider.FileInfo(
      fileName: existingName,
      contents: "# *Emma*, Jane Austen"
    ))

    let didLoad = expectation(description: "did load properties")
    PageProperties.loadProperties(
      from: metadataProvider.fileNameToMetadata[existingName]!,
      in: metadataProvider,
      parsingRules: parsingRules
    ) { results in
      switch results {
      case .failure(let error):
        XCTFail("Unexpected error: \(error)")
      case .success(let properties):
        XCTAssertEqual("emma-jane-austen", properties.desiredBaseFileName)
        XCTAssertEqual("*Emma*, Jane Austen", properties.title)
      }
      didLoad.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
  }
}
