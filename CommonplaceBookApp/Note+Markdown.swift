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

// MARK: - Using the new parser

public extension Note {
  /// Creates a new Note from the contents of a parsed text buffer.
  init(buffer: IncrementalParsingBuffer) {
    var challengeTemplates = [ChallengeTemplate]()
    challengeTemplates.append(contentsOf: ClozeTemplate.extract(from: buffer))
    challengeTemplates.append(contentsOf: QuoteTemplate.extract(from: buffer))
    self.init(
      metadata: Note.Metadata(
        timestamp: Date(),
        hashtags: buffer.hashtags,
        title: String(buffer.title.split(separator: "\n").first ?? ""),
        containsText: true
      ),
      text: buffer.string,
      challengeTemplates: challengeTemplates
    )
  }
}

public extension IncrementalParsingBuffer {
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
    if let header = anchoredRoot.first(where: { $0.type == .header }) {
      let chars = self[header.range]
      return String(utf16CodeUnits: chars, count: chars.count)
    } else if let nonBlank = anchoredRoot.first(where: { $0.type != .blankLine && $0.type != .document }) {
      let chars = self[nonBlank.range]
      return String(utf16CodeUnits: chars, count: chars.count)
    } else {
      return ""
    }
  }
}
