//
//  PromptCollectionInfo.swift
//  PromptCollectionInfo
//
//  Created by Brian Dewey on 8/1/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import Foundation

/// This is an experimental struct to encode information currently stored in a ContentRecord (the `PromptCollection`) and in related `PromptRecords`
/// (stats on individual prompts).
public struct PromptCollectionInfo: Codable {
  public init(type: String, rawValue: String, promptStatistics: [PromptStatistics]) {
    self.type = type
    self.rawValue = rawValue
    self.promptStatistics = promptStatistics
  }

  public var type: String
  public var rawValue: String
  public var promptStatistics: [PromptStatistics]
}

public extension PromptCollectionInfo {
  /// Initialize a new ``PromptCollectionInfo`` from a ``PromptCollection``
  init(_ promptCollection: PromptCollection) {
    self.type = promptCollection.type.rawValue
    self.rawValue = promptCollection.rawValue
    self.promptStatistics = Array(repeating: PromptStatistics(), count: promptCollection.prompts.count)
  }

  func asPromptCollection() throws -> PromptCollection {
    guard let klass = PromptType.classMap[type], let collection = klass.init(rawValue: rawValue) else {
      throw NoteDatabaseError.unknownPromptType
    }
    return collection
  }
}

extension PromptCollectionInfo {
  init(contentRecord: ContentRecord, promptRecords: [PromptRecord]) {
    self.type = contentRecord.role
    self.rawValue = contentRecord.text
    let sortedRecords = promptRecords.sorted(by: { $0.promptIndex < $1.promptIndex })
    for index in sortedRecords.indices {
      assert(sortedRecords[index].promptIndex == index)
    }
    self.promptStatistics = sortedRecords.map(PromptStatistics.init)
  }
}
