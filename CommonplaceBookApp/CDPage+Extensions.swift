// Copyright © 2019 Brian's Brain. All rights reserved.

import CoreData
import Foundation

extension CDPage {
  static func getOrCreate(uuid: UUID, context: NSManagedObjectContext) -> CDPage {
    let request: NSFetchRequest<CDPage> = CDPage.fetchRequest()
    request.predicate = NSPredicate(format: "uuid == %@", uuid as CVarArg)
    if let existingRecords = try? request.execute() {
      assert(existingRecords.count == 1)
      return existingRecords.first!
    }
    let page = CDPage(context: context)
    page.uuid = uuid
    return page
  }
}
