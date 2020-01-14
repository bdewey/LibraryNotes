// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown

public extension Note {
  /// Creates a new Note from markdown and parsing rules.
  init(markdown: String, parsingRules: ParsingRules) {
    let nodes = parsingRules.parse(markdown)
    self.init(
      metadata: Note.Metadata(
        timestamp: Date(),
        hashtags: nodes.hashtags,
        title: String(nodes.title.split(separator: "\n").first ?? ""),
        containsText: true
      ),
      text: markdown,
      challengeTemplates: nodes.makeChallengeTemplates()
    )
  }

  mutating func updateMarkdown(_ markdown: String, parsingRules: ParsingRules) {
    let newNote = Note(markdown: markdown, parsingRules: parsingRules)
    ChallengeTemplate.assignMatchingTemplateIdentifiers(from: challengeTemplates, to: newNote.challengeTemplates)
    self = newNote
  }
}
