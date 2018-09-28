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

fileprivate let key = "info.json"

public enum MetadataStorage {

  /// Reads and writes metadata to info.json
  private static func read(from document: TextBundleDocument) throws -> MetadataStorage.Metadata {
    guard let data = try? document.data(for: key) else { return Metadata() }
    return try Metadata(from: data)
  }

  private static func writeValue(_ metadata: MetadataStorage.Metadata, to document: TextBundleDocument) throws {
    let data = try metadata.makeData()
    let wrapper = FileWrapper(regularFileWithContents: data)
    document.bundle.replaceFileWrapper(wrapper, key: key)
  }

  fileprivate static func makeProperty(
    for document: TextBundleDocument
  ) -> DocumentProperty<MetadataStorage.Metadata> {
    return DocumentProperty(document: document, readFunction: read, writeFunction: writeValue)
  }
}

extension TextBundleDocument {
  public var metadata: DocumentProperty<MetadataStorage.Metadata> {
    return listener(for: key, constructor: MetadataStorage.makeProperty)
  }
}
