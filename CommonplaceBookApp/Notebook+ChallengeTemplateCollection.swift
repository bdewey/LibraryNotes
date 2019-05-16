// Copyright © 2019 Brian's Brain. All rights reserved.

import CocoaLumberjack
import CwlSignal
import Foundation

extension Notebook.Key {
  public static let challengeTemplates = Notebook.Key(rawValue: "challenge-templates.json")
}

extension Notebook {
  public var challengeTemplateDocument: ChallengeTemplateDocument? {
    return openMetadocuments[.challengeTemplates] as? ChallengeTemplateDocument
  }

  @discardableResult
  public func loadChallengeTemplates() -> Notebook {
    let fileURL = metadataProvider.container.appendingPathComponent(Key.challengeTemplates.rawValue)
    let document = ChallengeTemplateDocument(fileURL: fileURL)
    openMetadocuments[.challengeTemplates] = document
    document.openOrCreate { success in
      precondition(success)
    }
    return self
  }
}
