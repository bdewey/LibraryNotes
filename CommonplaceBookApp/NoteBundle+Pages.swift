// Copyright © 2019 Brian's Brain. All rights reserved.

import CocoaLumberjack
import CommonplaceBook
import FlashcardKit
import Foundation
import MiniMarkdown
import TextBundleKit

/// Methods related to updating the pages in the NoteBundle.
public extension NoteBundle {
  /// Adds challenges from a page to the NoteBundle.
  ///
  /// - parameter fileName: The name of the page.
  /// - parameter pageProperties: Properties of the page (excluding name)
  /// - parameter challengeTemplates: The challenges associated with this page.
  /// - returns: True if the structure changed, false if we already had the information and
  ///            no update was required.
  mutating func addChallengesFromPage(
    named fileName: String,
    pageProperties: NoteBundlePageProperties,
    challengeTemplates: ChallengeTemplateCollection
  ) -> Bool {
    assert(Thread.isMainThread)
    if let existing = self.pageProperties[fileName],
      existing.sha1Digest == pageProperties.sha1Digest {
      DDLogInfo("Skipping \(fileName) -- already have properties for \(pageProperties.sha1Digest)")
      return false
    }
    log.append(
      ChangeRecord(
        timestamp: Date(),
        change: .addedPage(name: fileName, digest: pageProperties.sha1Digest)
      )
    )
    self.pageProperties[fileName] = pageProperties
    let addedTemplateKeys = self.challengeTemplates.merge(challengeTemplates)
    for key in addedTemplateKeys {
      log.append(ChangeRecord(timestamp: Date(), change: .addedChallengeTemplate(id: key)))
    }
    DDLogInfo(
      "Added information about \(addedTemplateKeys.count) challenges"
      + " from \(fileName) (\(pageProperties.sha1Digest))"
    )
    return true
  }

  /// Synchronously extract properties & challenge templates from the contents of a file.
  func extractPropertiesAndTemplates(
    from text: String,
    loadedFrom fileMetadata: FileMetadata
  ) throws -> (NoteBundlePageProperties, ChallengeTemplateCollection) {
    let nodes = parsingRules.parse(text)
    let challengeTemplates = try nodes.challengeTemplates()
    let properties = NoteBundlePageProperties(
      sha1Digest: text.sha1Digest(),
      timestamp: fileMetadata.contentChangeDate,
      hashtags: nodes.hashtags,
      title: String(nodes.title.split(separator: "\n").first ?? ""),
      cardTemplates: challengeTemplates.keys
    )
    return (properties, challengeTemplates)
  }
}
