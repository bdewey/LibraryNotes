// Copyright © 2017-present Brian's Brain. All rights reserved.

import CommonplaceBookApp
import Foundation
import MiniMarkdown

extension Note {
  static let simpleTest = Note(
    metadata: Note.Metadata(
      timestamp: Date(),
      hashtags: [],
      title: "Testing",
      containsText: true
    ),
    text: "This is a test",
    challengeTemplates: []
  )

  static let withHashtags = Note(
    metadata: Note.Metadata(
      timestamp: Date(),
      hashtags: ["#ashtag"],
      title: "Testing",
      containsText: true
    ),
    text: "This is a test",
    challengeTemplates: []
  )

  static let withChallenges = Note(markdown: """
  # Shakespeare quotes

  > To be, or not to be, that is the question. (Hamlet)

  * Let's make sure we can encode a ?[](cloze).

  Q: What is the name of this format?
  A: Question and answer.

  """, parsingRules: ParsingRules.commonplace)

  static let multipleClozes = Note(markdown: "* This ?[](challenge) has multiple ?[](clozes).", parsingRules: ParsingRules.commonplace)
}
