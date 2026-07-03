// Copyright (c) 2018-2025  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import Library_Notes
import LibraryNotesCore

extension Note {
  nonisolated(unsafe) static let simpleTest = Note(
    creationTimestamp: Date(),
    timestamp: Date(),
    hashtags: [],
    referencedImageKeys: [],
    title: "Testing",
    text: "This is a test",
    promptCollections: [:]
  )

  nonisolated(unsafe) static let withHashtags = Note(
    creationTimestamp: Date(),
    timestamp: Date(),
    hashtags: ["#ashtag"],
    referencedImageKeys: [],
    title: "Testing",
    text: "This is a test",
    promptCollections: [:]
  )

  nonisolated(unsafe) static let withChallenges = Note(markdown: """
  # Shakespeare quotes

  > To be, or not to be, that is the question. (Hamlet)

  * Let's make sure we can encode a ?[](cloze).

  Q: What is the name of this format?
  A: Question and answer.

  #test

  """)

  nonisolated(unsafe) static let multipleClozes = Note(markdown: "* This ?[](challenge) has multiple ?[](clozes).")

  nonisolated(unsafe) static let withReferenceWebPage = Note(
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
