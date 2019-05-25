// Copyright © 2019 Brian's Brain. All rights reserved.

import FlashcardKit
import Foundation
import MiniMarkdown

extension Array where Element == Node {
  /// For an array of Nodes, return all VocabularyAssociations and ClozeTemplates found in
  /// the nodes.
  // TODO: Make this extensible for other card template types.
  func cardTemplates() -> [CardTemplateSerializationWrapper] {
    var results = [CardTemplateSerializationWrapper]()
    results.append(
      contentsOf: VocabularyAssociation.makeAssociations(from: self).0
        .map { CardTemplateSerializationWrapper($0) }
    )
    results.append(
      contentsOf: ClozeTemplate.extract(from: self)
        .map { CardTemplateSerializationWrapper($0) }
    )
    results.append(
      contentsOf: QuoteTemplate.extract(from: self)
        .map { CardTemplateSerializationWrapper($0) }
    )
    return results
  }

  func challengeTemplates() throws -> ChallengeTemplateCollection {
    var challengeTemplates = ChallengeTemplateCollection()
    try challengeTemplates.insert(contentsOf: VocabularyAssociation.makeAssociations(from: self).0)
    try challengeTemplates.insert(contentsOf: ClozeTemplate.extract(from: self))
    try challengeTemplates.insert(contentsOf: QuoteTemplate.extract(from: self))
    return challengeTemplates
  }

  func archiveChallengeTemplates(
    to archive: inout TextSnippetArchive
  ) -> [ChallengeTemplateArchiveKey] {
    return Swift.Array([
      archive.insert(contentsOf: VocabularyAssociation.makeAssociations(from: self).0),
      archive.insert(contentsOf: ClozeTemplate.extract(from: self)),
      archive.insert(contentsOf: QuoteTemplate.extract(from: self)),
    ].joined())
  }

  /// Extracts the title from an array of nodes.
  ///
  /// - note: If there is a heading anywhere in the nodes, the contents of the first heading
  ///         is the title. Otherwise, the contents of the first non-blank line is the title.
  var title: String {
    if let heading = self.lazy.compactMap(
      { $0.first(where: { $0.type == .heading }) }
      ).first as? Heading {
      return String(heading.inlineSlice.substring)
    } else if let notBlank = self.lazy.compactMap({
      $0.first(where: { $0.type != .blank })
    }).first {
      return notBlank.allMarkdown
    } else {
      return ""
    }
  }

  /// Extracts all hashtags from nodes.
  var hashtags: [String] {
    let hashtagSet = self
      .map { $0.findNodes(where: { $0.type == .hashtag }) }
      .joined()
      .reduce(into: Set<String>()) { $0.insert(String($1.slice.substring)) }
    return [String](hashtagSet)
  }
}
