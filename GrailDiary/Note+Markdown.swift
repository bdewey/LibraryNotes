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

import Foundation

/// This struct provides a standard string encoding for all keys used for prompts: "prompt-{number}"
public struct PromptCollectionKey: RawRepresentable {
  public let rawValue: Note.ContentKey
  public let numericIndex: Int

  private static let prefix = "prompt-"

  public init?(rawValue: String) {
    guard rawValue.hasPrefix(Self.prefix) else {
      return nil
    }
    let numberPart = rawValue.suffix(rawValue.count - Self.prefix.count)
    guard let numericIndex = Int(numberPart) else {
      return nil
    }
    self.rawValue = rawValue
    self.numericIndex = numericIndex
  }

  public init(numericIndex: Int) {
    self.numericIndex = numericIndex
    self.rawValue = "\(Self.prefix)\(numericIndex)"
  }
}

public extension Note {
  /// Creates a new Note from the contents of a parsed text buffer.
  init(parsedString: ParsedString) {
    var prompts = [PromptCollection]()
    prompts.append(contentsOf: ClozePromptCollection.extract(from: parsedString))
    prompts.append(contentsOf: QuotePrompt.extract(from: parsedString))
    prompts.append(contentsOf: QuestionAndAnswerPrompt.extract(from: parsedString))
    var keyedCollection = [Note.ContentKey: PromptCollection]()
    for (index, promptCollection) in prompts.enumerated() {
      keyedCollection[PromptCollectionKey(numericIndex: index).rawValue] = promptCollection
    }
    self.init(
      metadata: Note.Metadata(
        creationTimestamp: Date(),
        timestamp: Date(),
        hashtags: parsedString.hashtags,
        title: String(parsedString.title.split(separator: "\n").first ?? "")
      ),
      text: parsedString.string,
      promptCollections: keyedCollection
    )
  }

  init(markdown: String) {
    let buffer = ParsedString(markdown, grammar: MiniMarkdownGrammar.shared)
    self.init(parsedString: buffer)
  }

  static func makeBlankNote(hashtag: String? = nil) -> (Note, Int) {
    var initialText = "# "
    let initialOffset = initialText.count
    initialText += "\n"
    if let hashtag = hashtag {
      initialText += hashtag
      initialText += "\n"
    }
    return (Note(markdown: initialText), initialOffset)
  }

  mutating func updateMarkdown(_ markdown: String) {
    var newNote = Note(markdown: markdown)
    newNote.metadata.creationTimestamp = metadata.creationTimestamp
    newNote.copyContentKeysForMatchingContent(from: self)
    self = newNote
  }
}

public extension ParsedString {
  var hashtags: [String] {
    guard let root = try? result.get() else { return [] }
    var results = Set<String>()
    root.forEach { node, startIndex, _ in
      guard node.type == .hashtag else { return }
      let chars = self[NSRange(location: startIndex, length: node.length)]
      results.insert(String(utf16CodeUnits: chars, count: chars.count))
    }
    return [String](results)
  }

  var title: String {
    guard let root = try? result.get() else { return "" }
    let anchoredRoot = AnchoredNode(node: root, startIndex: 0)
    if let header = anchoredRoot.first(where: { $0.type == .header }), let text = header.first(where: { $0.type == .text }) {
      let chars = self[text.range]
      return String(utf16CodeUnits: chars, count: chars.count)
    } else if let nonBlank = anchoredRoot.first(where: { $0.type != .blankLine && $0.type != .document }) {
      let chars = self[nonBlank.range]
      return String(utf16CodeUnits: chars, count: chars.count)
    } else {
      return ""
    }
  }
}
