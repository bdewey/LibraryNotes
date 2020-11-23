// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation

public extension Note {
  /// Creates a new Note from the contents of a parsed text buffer.
  init(parsedString: ParsedString) {
    var challengeTemplates = [ChallengeTemplate]()
    challengeTemplates.append(contentsOf: ClozeTemplate.extract(from: parsedString))
    challengeTemplates.append(contentsOf: QuoteTemplate.extract(from: parsedString))
    challengeTemplates.append(contentsOf: QuestionAndAnswerTemplate.extract(from: parsedString))
    self.init(
      metadata: Note.Metadata(
        timestamp: Date(),
        hashtags: parsedString.hashtags,
        title: String(parsedString.title.split(separator: "\n").first ?? ""),
        containsText: true
      ),
      text: parsedString.string,
      challengeTemplates: challengeTemplates
    )
  }

  init(markdown: String) {
    let buffer = ParsedString(markdown, grammar: MiniMarkdownGrammar.shared)
    self.init(parsedString: buffer)
  }

  mutating func updateMarkdown(_ markdown: String) {
    let newNote = Note(markdown: markdown)
    ChallengeTemplate.assignMatchingTemplateIdentifiers(from: challengeTemplates, to: newNote.challengeTemplates)
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
