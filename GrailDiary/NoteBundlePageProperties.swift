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
import IGListKit

/// Metadata about pages in a NoteBundle.
public struct PageProperties: Codable, Equatable {
  /// SHA-1 digest of the contents of the page.
  public let sha1Digest: String

  /// Last modified time of the page.
  public let timestamp: Date

  /// Hashtags present in the page.
  public let hashtags: [String]

  /// Title of the page. May include Markdown formatting.
  public let title: String

  /// IDs of all card templates in the page.
  public let cardTemplates: [String]
}

/// Wrapper around PageProperties for IGListKit.
public final class NoteBundlePagePropertiesListDiffable: ListDiffable {
  public let fileMetadata: FileMetadata

  /// The wrapped PageProperties.
  public private(set) var properties: PageProperties

  /// How many cards are eligible for study in this page.
  public private(set) var cardCount: Int

  /// Designated initializer.
  public init(fileMetadata: FileMetadata, properties: PageProperties, cardCount: Int) {
    self.fileMetadata = fileMetadata
    self.properties = properties
    self.cardCount = cardCount
  }

  public func diffIdentifier() -> NSObjectProtocol {
    return fileMetadata.fileName as NSString
  }

  public func isEqual(toDiffableObject object: ListDiffable?) -> Bool {
    guard let otherWrapper = object as? NoteBundlePagePropertiesListDiffable else { return false }
    return properties == otherWrapper.properties &&
      cardCount == otherWrapper.cardCount &&
      fileMetadata == otherWrapper.fileMetadata
  }
}

/// Debuggability extensions for PagePropertiesListDiffable.
extension NoteBundlePagePropertiesListDiffable: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String { return String(describing: properties) }
  public var debugDescription: String {
    return "DocumentPropertiesListDiffable \(Unmanaged.passUnretained(self).toOpaque()) "
      + String(describing: properties)
  }
}
