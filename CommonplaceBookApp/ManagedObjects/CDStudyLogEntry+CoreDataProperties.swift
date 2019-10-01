// Copyright © 2017-present Brian's Brain. All rights reserved.

import CoreData
import Foundation

extension CDStudyLogEntry {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<CDStudyLogEntry> {
    return NSFetchRequest<CDStudyLogEntry>(entityName: "CDStudyLogEntry")
  }

  @NSManaged public var timestamp: Date?
  @NSManaged public var challengeIndex: Int16
  @NSManaged public var correct: Int16
  @NSManaged public var incorrect: Int16
  @NSManaged public var challengeTemplate: CDChallengeTemplate?
}
