//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import CommonplaceBookApp
import Foundation

extension Note {
  static let simpleTest = Note(
    metadata: Note.Metadata(
      creationTimestamp: Date(),
      timestamp: Date(),
      hashtags: [],
      title: "Testing"
    ),
    text: "This is a test",
    promptCollections: [:]
  )

  static let withHashtags = Note(
    metadata: Note.Metadata(
      creationTimestamp: Date(),
      timestamp: Date(),
      hashtags: ["#ashtag"],
      title: "Testing"
    ),
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
    metadata: Metadata(
      creationTimestamp: Date(),
      timestamp: Date(),
      hashtags: ["#test"],
      title: "The Onion"
    ),
    text: nil,
    reference: .webPage(URL(string: "https://www.theonion.com")!),
    promptCollections: [:]
  )
}
