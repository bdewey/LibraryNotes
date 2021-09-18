// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import LibraryNotes

extension Note {
  static let simpleTest = Note(
    creationTimestamp: Date(),
    timestamp: Date(),
    hashtags: [],
    referencedImageKeys: [],
    title: "Testing",
    text: "This is a test",
    promptCollections: [:]
  )

  static let withHashtags = Note(
    creationTimestamp: Date(),
    timestamp: Date(),
    hashtags: ["#ashtag"],
    referencedImageKeys: [],
    title: "Testing",
    text: "This is a test",
    promptCollections: [:]
  )

  static let withChallenges = Note(markdown: """
  # Shakespeare quotes

  > To be, or not to be, that is the question. (Hamlet)

  * Let's make sure we can encode a ?[](cloze).

  Q: What is the name of this format?
  A: Question and answer.

  #test

  """)

  static let multipleClozes = Note(markdown: "* This ?[](challenge) has multiple ?[](clozes).")

  static let withReferenceWebPage = Note(
    creationTimestamp: Date(),
    timestamp: Date(),
    hashtags: ["#test"],
    referencedImageKeys: [],
    title: "The Onion",
    text: nil,
    reference: .webPage(URL(string: "https://www.theonion.com")!),
    promptCollections: [:]
  )
}
