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
