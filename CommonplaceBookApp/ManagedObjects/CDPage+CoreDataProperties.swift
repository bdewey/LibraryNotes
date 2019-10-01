// Copyright © 2017-present Brian's Brain. All rights reserved.

import CoreData
import Foundation

extension CDPage {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<CDPage> {
    return NSFetchRequest<CDPage>(entityName: "CDPage")
  }

  @NSManaged public var title: String?
  @NSManaged public var timestamp: Date?
  @NSManaged public var uuid: UUID?
  @NSManaged public var hashtags: NSSet?
  @NSManaged public var challengeTemplates: NSSet?
  @NSManaged public var contents: CDPageContents?
}

// MARK: Generated accessors for hashtags

extension CDPage {
  @objc(addHashtagsObject:)
  @NSManaged public func addToHashtags(_ value: CDHashtag)

  @objc(removeHashtagsObject:)
  @NSManaged public func removeFromHashtags(_ value: CDHashtag)

  @objc(addHashtags:)
  @NSManaged public func addToHashtags(_ values: NSSet)

  @objc(removeHashtags:)
  @NSManaged public func removeFromHashtags(_ values: NSSet)
}

// MARK: Generated accessors for challengeTemplates

extension CDPage {
  @objc(addChallengeTemplatesObject:)
  @NSManaged public func addToChallengeTemplates(_ value: CDChallengeTemplate)

  @objc(removeChallengeTemplatesObject:)
  @NSManaged public func removeFromChallengeTemplates(_ value: CDChallengeTemplate)

  @objc(addChallengeTemplates:)
  @NSManaged public func addToChallengeTemplates(_ values: NSSet)

  @objc(removeChallengeTemplates:)
  @NSManaged public func removeFromChallengeTemplates(_ values: NSSet)
}
