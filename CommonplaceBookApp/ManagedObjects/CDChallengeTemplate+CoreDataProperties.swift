// Copyright © 2017-present Brian's Brain. All rights reserved.

import CoreData
import Foundation

extension CDChallengeTemplate {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<CDChallengeTemplate> {
    return NSFetchRequest<CDChallengeTemplate>(entityName: "CDChallengeTemplate")
  }

  @NSManaged public var type: String?
  @NSManaged public var serialized: String?
  @NSManaged public var page: CDPage?
  @NSManaged public var studyLogEntries: NSSet?
}

// MARK: Generated accessors for studyLogEntries

extension CDChallengeTemplate {
  @objc(addStudyLogEntriesObject:)
  @NSManaged public func addToStudyLogEntries(_ value: CDStudyLogEntry)

  @objc(removeStudyLogEntriesObject:)
  @NSManaged public func removeFromStudyLogEntries(_ value: CDStudyLogEntry)

  @objc(addStudyLogEntries:)
  @NSManaged public func addToStudyLogEntries(_ values: NSSet)

  @objc(removeStudyLogEntries:)
  @NSManaged public func removeFromStudyLogEntries(_ values: NSSet)
}
