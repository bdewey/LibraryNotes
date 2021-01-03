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
import Logging

public protocol FileMetadataProviderDelegate: class {
  /// Sent when there are new FileMetadata items in the provider.
  ///
  /// - parameter provider: The file metadata provider
  /// - parameter metadata: The updated copy of the FileMetadata array.
  func fileMetadataProvider(_ provider: FileMetadataProvider, didUpdate metadata: [FileMetadata])
}

/// A FileMetadataProvider knows how to obtain all of the FileMetadata structures corresponding
/// to a single container (e.g., iCloud container or documents folder)
public protocol FileMetadataProvider: class {
  var container: URL { get }

  /// The current array of metadata.
  var fileMetadata: [FileMetadata] { get }

  func queryForCurrentFileMetadata(completion: @escaping ([FileMetadata]) -> Void)

  /// Delegate that can receive notifications when `fileMetadata` changes.
  var delegate: FileMetadataProviderDelegate? { get set }

  /// Gets the contents of `fileMetadata` as a UTF-8 encoded string.
  func text(for fileMetadata: FileMetadata) throws -> String

  /// Gets the data backed by this `fileMetadata`
  func data(for fileMetadata: FileMetadata) throws -> Data

  /// Delete an item.
  func delete(_ metadata: FileMetadata) throws

  /// Tests if there is currently an item with a given path component in this container.
  func itemExists(with pathComponent: String) throws -> Bool

  /// Renames an item associated with metadata.
  func renameMetadata(_ metadata: FileMetadata, to name: String) throws
}

enum FileMetadataProviderError: Error {
  case cannotGetDocument
  case cannotOpenDocument
}

/// I/O routines that work for all implementations of FileMetadataProvider
public extension FileMetadataProvider {
  func data(for fileMetadata: FileMetadata) throws -> Data {
    let url = container.appendingPathComponent(fileMetadata.fileName)
    return try Data(contentsOf: url)
  }

  func text(for fileMetadata: FileMetadata) throws -> String {
    let fileData = try data(for: fileMetadata)
    return String(data: fileData, encoding: .utf8)!
  }
}
