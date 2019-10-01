// Copyright © 2017-present Brian's Brain. All rights reserved.

import CoreData
import Foundation

extension CDPageContents {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<CDPageContents> {
    return NSFetchRequest<CDPageContents>(entityName: "CDPageContents")
  }

  @NSManaged public var contents: String?
  @NSManaged public var page: CDPage?
}
