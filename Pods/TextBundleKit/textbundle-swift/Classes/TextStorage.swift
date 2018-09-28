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

import Foundation

/// Reads and writes data to text.*
public enum TextStorage {

  private static func key(for document: TextBundleDocument) -> String {
    return document.bundle.fileWrappers?.keys.first(where: { $0.hasPrefix("text.") })
      ?? "text.markdown"
  }

  public static func writeValue(_ text: String, to document: TextBundleDocument) throws {
    guard let data = text.data(using: .utf8) else {
      throw NSError.fileWriteInapplicableStringEncoding
    }
    let wrapper = FileWrapper(regularFileWithContents: data)
    document.bundle.replaceFileWrapper(
      wrapper,
      key: key(for: document)
    )
  }

  public static func read(from document: TextBundleDocument) throws -> String {
    guard let data = try? document.data(for: key(for: document)) else {
      return ""
    }
    guard let string = String(data: data, encoding: .utf8) else {
      throw NSError(
        domain: NSCocoaErrorDomain,
        code: NSFileReadInapplicableStringEncodingError,
        userInfo: nil
      )
    }
    return string
  }

  fileprivate static func makeProperty(for document: TextBundleDocument) -> DocumentProperty<String> {
    return DocumentProperty(document: document, readFunction: read, writeFunction: writeValue)
  }
}

extension TextBundleDocument {
  public var text: DocumentProperty<String> {
    return listener(for: "text", constructor: TextStorage.makeProperty)
  }
}
