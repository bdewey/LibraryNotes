// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import GrailDiary
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

  func testLocalMetadataForJSON() {
    do {
      let url = directoryURL.appendingPathComponent("testLocalMetadata.json")
      let sampleContent = "Hello world!\n"
      try sampleContent.write(to: url, atomically: true, encoding: .utf8)
      defer { try? FileManager.default.removeItem(at: url) }
      let metadata = try FileMetadata(fileURL: url)
      XCTAssertEqual(metadata.contentType, "public.json")
    } catch {
      XCTFail(String(describing: error))
    }
  }
}
