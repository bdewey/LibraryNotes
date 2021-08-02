import Foundation

public struct StudyLogEntry: Codable {
  public init(timestamp: Date, correct: Int, incorrect: Int, promptIndex: Int) {
    self.timestamp = timestamp
    self.correct = correct
    self.incorrect = incorrect
    self.promptIndex = promptIndex
  }

  public var timestamp: Date
  public var correct: Int
  public var incorrect: Int
  public var promptIndex: Int
}

extension StudyLogEntry {
  init(_ studyLogEntry: StudyLogEntryRecord) {
    self.timestamp = studyLogEntry.timestamp
    self.correct = studyLogEntry.correct
    self.incorrect = studyLogEntry.incorrect
    self.promptIndex = studyLogEntry.promptIndex
  }
}
