// Copyright © 2017-present Brian's Brain. All rights reserved.

import CoreData
import Foundation

extension CDHashtag {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<CDHashtag> {
    return NSFetchRequest<CDHashtag>(entityName: "CDHashtag")
  }

  @NSManaged public var name: String?
  @NSManaged public var pages: NSSet?
}

// MARK: Generated accessors for pages

extension CDHashtag {
  @objc(addPagesObject:)
  @NSManaged public func addToPages(_ value: CDPage)

  @objc(removePagesObject:)
  @NSManaged public func removeFromPages(_ value: CDPage)

  @objc(addPages:)
  @NSManaged public func addToPages(_ values: NSSet)

  @objc(removePages:)
  @NSManaged public func removeFromPages(_ values: NSSet)
}
