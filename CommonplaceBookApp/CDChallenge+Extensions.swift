// Copyright © 2019 Brian's Brain. All rights reserved.

import CoreData
import Foundation

extension CDChallenge {
  /// Gets the challenge associated with an identifier.
  static func fetch(
    identifier: ChallengeIdentifier
  ) throws -> CDChallenge? {
    guard let templateDigest = identifier.templateDigest else {
      return nil
    }
    let request: NSFetchRequest<CDChallenge> = CDChallenge.fetchRequest()
    let matchTemplate = NSPredicate(format: "challengeTemplate.legacyIdentifier == %@", templateDigest)
    let matchIndex = NSPredicate(format: "key == %@", String(describing: identifier.index))
    request.predicate = NSCompoundPredicate(
      andPredicateWithSubpredicates: [matchTemplate, matchIndex]
    )
    let results = try request.execute()
    switch results.count {
    case 0:
      return nil
    case 1:
      return results[0]
    default:
      assertionFailure("Unexpected number of challenges: \(results.count)")
      return results.first
    }
  }
}
