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

public struct Note: Equatable {
  /// Identifies a note.
  public typealias Identifier = String

  /// Identifies content within a note (currently, just prompts, but can be extended to other things)
  public typealias ContentKey = String

  public struct Metadata: Hashable {
    /// Last modified time of the page.
    public var timestamp: Date

    /// Hashtags present in the page.
    /// - note: Need to keep sorted to make comparisons canonical. Can't be a Set or serialization isn't canonical :-(
    public var hashtags: [String]

    /// Title of the page. May include Markdown formatting.
    public var title: String

    public init(
      timestamp: Date = Date(),
      hashtags: [String] = [],
      title: String = ""
    ) {
      self.timestamp = timestamp
      self.hashtags = hashtags
      self.title = title
    }

    public static func == (lhs: Metadata, rhs: Metadata) -> Bool {
      return
        abs(lhs.timestamp.timeIntervalSince1970 - rhs.timestamp.timeIntervalSince1970) < 0.001 &&
        lhs.hashtags == rhs.hashtags &&
        lhs.title == rhs.title
    }
  }

  public var metadata: Metadata
  public var text: String?
  public var promptCollections: [ContentKey: PromptCollection]

  public init(
    metadata: Metadata = Metadata(),
    text: String? = nil,
    promptCollections: [ContentKey: PromptCollection] = [:]
  ) {
    self.metadata = metadata
    self.text = text
    self.promptCollections = promptCollections
  }

  public static func == (lhs: Note, rhs: Note) -> Bool {
    if lhs.metadata != rhs.metadata || lhs.text != rhs.text {
      return false
    }
    let lhsIdentifiers = Set(lhs.promptCollections.keys)
    let rhsIdentifiers = Set(rhs.promptCollections.keys)
    return lhsIdentifiers == rhsIdentifiers
  }
}
