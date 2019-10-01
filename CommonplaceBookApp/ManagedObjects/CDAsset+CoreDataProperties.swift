// Copyright © 2017-present Brian's Brain. All rights reserved.

import CoreData
import Foundation

extension CDAsset {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<CDAsset> {
    return NSFetchRequest<CDAsset>(entityName: "CDAsset")
  }

  @NSManaged public var data: Data?
  @NSManaged public var shaHash: String?
}
