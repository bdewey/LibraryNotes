// Copyright © 2019 Brian's Brain. All rights reserved.

import CommonplaceBookApp
import XCTest

final class StudyLogTests: XCTestCase {
  func testMerge() {
    var studyLog = StudyLog()
    var dateComponents = DateComponents()
    dateComponents.month = 3
    dateComponents.day = 19
    dateComponents.year = 2006
    let now = Calendar.current.date(from: dateComponents)!
    let identifier = ChallengeIdentifier(templateDigest: "test", index: 0)
    for delta in 0 ..< 10 {
      studyLog.appendEntry(
        challengeIdentifier: identifier,
        timestamp: now.addingTimeInterval(TimeInterval(delta))
      )
    }
    var branchedLog = studyLog
    let otherIdentifier = ChallengeIdentifier(templateDigest: "test", index: 1)
    for delta in 10 ..< 20 {
      branchedLog.appendEntry(
        challengeIdentifier: identifier,
        timestamp: now.addingTimeInterval(TimeInterval(delta))
      )
      studyLog.appendEntry(
        challengeIdentifier: otherIdentifier,
        timestamp: now.addingTimeInterval(TimeInterval(delta))
      )
    }

    studyLog.merge(other: branchedLog)
    XCTAssertEqual(30, studyLog.count)
    print(studyLog.description)
    XCTAssertEqual(studyLog.description, expectedLog)
  }
}

private let expectedLog = """
2006-03-19T08:00:00Z test 0 correct 1 incorrect 0
2006-03-19T08:00:01Z test 0 correct 1 incorrect 0
2006-03-19T08:00:02Z test 0 correct 1 incorrect 0
2006-03-19T08:00:03Z test 0 correct 1 incorrect 0
2006-03-19T08:00:04Z test 0 correct 1 incorrect 0
2006-03-19T08:00:05Z test 0 correct 1 incorrect 0
2006-03-19T08:00:06Z test 0 correct 1 incorrect 0
2006-03-19T08:00:07Z test 0 correct 1 incorrect 0
2006-03-19T08:00:08Z test 0 correct 1 incorrect 0
2006-03-19T08:00:09Z test 0 correct 1 incorrect 0
2006-03-19T08:00:10Z test 0 correct 1 incorrect 0
2006-03-19T08:00:10Z test 1 correct 1 incorrect 0
2006-03-19T08:00:11Z test 0 correct 1 incorrect 0
2006-03-19T08:00:11Z test 1 correct 1 incorrect 0
2006-03-19T08:00:12Z test 0 correct 1 incorrect 0
2006-03-19T08:00:12Z test 1 correct 1 incorrect 0
2006-03-19T08:00:13Z test 0 correct 1 incorrect 0
2006-03-19T08:00:13Z test 1 correct 1 incorrect 0
2006-03-19T08:00:14Z test 0 correct 1 incorrect 0
2006-03-19T08:00:14Z test 1 correct 1 incorrect 0
2006-03-19T08:00:15Z test 0 correct 1 incorrect 0
2006-03-19T08:00:15Z test 1 correct 1 incorrect 0
2006-03-19T08:00:16Z test 0 correct 1 incorrect 0
2006-03-19T08:00:16Z test 1 correct 1 incorrect 0
2006-03-19T08:00:17Z test 0 correct 1 incorrect 0
2006-03-19T08:00:17Z test 1 correct 1 incorrect 0
2006-03-19T08:00:18Z test 0 correct 1 incorrect 0
2006-03-19T08:00:18Z test 1 correct 1 incorrect 0
2006-03-19T08:00:19Z test 0 correct 1 incorrect 0
2006-03-19T08:00:19Z test 1 correct 1 incorrect 0

"""
