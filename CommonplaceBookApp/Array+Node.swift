// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown

extension Array where Element == Node {
  func makeChallengeTemplates() -> [ChallengeTemplate] {
    var results: [ChallengeTemplate] = []
    results.append(contentsOf: QuoteTemplate.extract(from: self))
    results.append(contentsOf: QuestionAndAnswerTemplate.extract(from: self))
    return results
  }

  /// Extracts the title from an array of nodes.
  ///
  /// - note: If there is a heading anywhere in the nodes, the contents of the first heading
  ///         is the title. Otherwise, the contents of the first non-blank line is the title.
  var title: String {
    if let heading = self.lazy.compactMap({ $0.first(where: { $0.type == .heading }) }).first as? Heading {
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
    let hashtagSet = map { $0.findNodes(where: { $0.type == .hashtag }) }
      .joined()
      .reduce(into: Set<String>()) { $0.insert(String($1.slice.substring)) }
    return [String](hashtagSet)
  }
}
