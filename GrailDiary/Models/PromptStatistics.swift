//
//  PromptStatistics.swift
//  PromptStatistics
//
//  Created by Brian Dewey on 8/1/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import Foundation

public struct PromptStatistics: Codable {
  public init(reviewCount: Int = 0, lapseCount: Int = 0, totalCorrect: Int = 0, totalIncorrect: Int = 0, lastReview: Date? = nil, idealInterval: Double? = nil, due: Date? = nil, spacedRepetitionFactor: Double = 2.5) {
    self.reviewCount = reviewCount
    self.lapseCount = lapseCount
    self.totalCorrect = totalCorrect
    self.totalIncorrect = totalIncorrect
    self.lastReview = lastReview
    self.idealInterval = idealInterval
    self.due = due
    self.spacedRepetitionFactor = spacedRepetitionFactor
  }

  public var reviewCount: Int = 0
  public var lapseCount: Int = 0
  public var totalCorrect: Int = 0
  public var totalIncorrect: Int = 0
  public var lastReview: Date?
  public var idealInterval: Double?
  public var due: Date?
  public var spacedRepetitionFactor: Double = 2.5
}

extension PromptStatistics {
  internal init(_ promptRecord: PromptRecord) {
    self.reviewCount = promptRecord.reviewCount
    self.lapseCount = promptRecord.lapseCount
    self.totalCorrect = promptRecord.totalCorrect
    self.totalIncorrect = promptRecord.totalIncorrect
    self.lastReview = promptRecord.lastReview
    self.idealInterval = promptRecord.idealInterval
    self.due = promptRecord.due
    self.spacedRepetitionFactor = promptRecord.spacedRepetitionFactor
  }
}
