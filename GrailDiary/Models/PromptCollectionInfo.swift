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
