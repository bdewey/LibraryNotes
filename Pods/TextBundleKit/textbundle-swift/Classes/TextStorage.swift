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
public final class TextStorage: WrappingDocument {
  
  public init(document: TextBundleDocument) {
    self.document = document
    document.addListener(self)
    text.storage = self
  }
  
  public let document: TextBundleDocument
  public var text = DocumentProperty<TextStorage>()
  
  var key: String {
    return document.bundle.fileWrappers?.keys.first(where: { $0.hasPrefix("text.") })
      ?? "text.markdown"
  }
  
  func writeValue(_ value: String) throws {
    guard let data = value.data(using: .utf8) else {
      throw NSError.fileWriteInapplicableStringEncoding
    }
    let wrapper = FileWrapper(regularFileWithContents: data)
    document.bundle.replaceFileWrapper(wrapper, key: key)
  }
}

extension TextStorage: TextBundleDocumentSaveListener {
  public func textBundleDocumentWillSave(_ textBundleDocument: TextBundleDocument) throws {
    if let value = text.clean() {
      try writeValue(value)
    }
  }
  
  public func textBundleDocumentDidLoad(_ textBundleDocument: TextBundleDocument) {
    text.invalidate()
  }
}

extension TextStorage: StableStorage {
  
  public func documentPropertyInitialValue() throws -> String {
    guard let data = try? document.data(for: key) else { return "" }
    guard let string = String(data: data, encoding: .utf8) else {
      throw NSError(
        domain: NSCocoaErrorDomain,
        code: NSFileReadInapplicableStringEncodingError,
        userInfo: nil
      )
    }
    return string
  }
  
  public func documentPropertyDidChange() {
    document.updateChangeCount(.done)
  }
}
