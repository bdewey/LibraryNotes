// Copyright © 2017-present Brian's Brain. All rights reserved.

import CoreData
import CryptoKit
import Foundation

extension CDAsset {
  static func asset(digest: String) -> CDAsset? {
    let request: NSFetchRequest<CDAsset> = CDAsset.fetchRequest()
    request.predicate = NSPredicate(format: "digest == %@", digest)
    return try? request.execute().first
  }

  static func asset(data: Data, context: NSManagedObjectContext) -> CDAsset {
    let digest = SHA256.hash(data: data)
    let digestString = Data(digest).base64EncodedString()
    if let asset = self.asset(digest: digestString) {
      return asset
    }
    let assetObject = CDAsset(context: context)
    assetObject.digest = digestString
    assetObject.data = data
    return assetObject
  }
}
