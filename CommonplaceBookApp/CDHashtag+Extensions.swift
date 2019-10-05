// Copyright © 2017-present Brian's Brain. All rights reserved.

import CoreData
import Foundation

extension CDHashtag {
  static func getOrCreate(name: String, context: NSManagedObjectContext) -> CDHashtag {
    let request: NSFetchRequest<CDHashtag> = CDHashtag.fetchRequest()
    request.predicate = NSPredicate(format: "name == %@", name)
    if let existingRecord = try? request.execute().first {
      return existingRecord
    }
    let hashtag = CDHashtag(context: context)
    hashtag.name = name
    return hashtag
  }
}
