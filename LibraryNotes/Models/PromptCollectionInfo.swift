// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

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
