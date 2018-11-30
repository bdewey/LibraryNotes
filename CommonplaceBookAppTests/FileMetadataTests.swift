// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBookApp
import XCTest

final class FileMetadataTests: XCTestCase {
  
  let directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!

  func testLocalMetadataForTextFile() {
    do {
      let url = directoryURL.appendingPathComponent("testLocalMetadata.txt")
      let sampleContent = "Hello world!\n"
      try sampleContent.write(to: url, atomically: true, encoding: .utf8)
      defer { try? FileManager.default.removeItem(at: url) }
      let metadata = try FileMetadata(fileURL: url)
      XCTAssertEqual(metadata.contentType, "public.plain-text")
    } catch {
      XCTFail(String(describing: error))
    }
  }

  func testLocalMetadataForDeck() {
    do {
      let url = directoryURL.appendingPathComponent("testLocalMetadata.deck")
      let sampleContent = "Hello world!\n"
      try sampleContent.write(to: url, atomically: true, encoding: .utf8)
      defer { try? FileManager.default.removeItem(at: url) }
      let metadata = try FileMetadata(fileURL: url)
      XCTAssertEqual(metadata.contentType, "org.brians-brain.swiftflash")
    } catch {
      XCTFail(String(describing: error))
    }
  }

  func testLocalMetadataForTextbundle() {
    do {
      let url = directoryURL.appendingPathComponent("testLocalMetadata.textbundle")
      let sampleContent = "Hello world!\n"
      try sampleContent.write(to: url, atomically: true, encoding: .utf8)
      defer { try? FileManager.default.removeItem(at: url) }
      let metadata = try FileMetadata(fileURL: url)
      XCTAssertEqual(metadata.contentType, "org.textbundle.package")
    } catch {
      XCTFail(String(describing: error))
    }
  }
}
