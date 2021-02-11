// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

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
      creationTimestamp: Date(),
      timestamp: Date(),
      hashtags: parsedString.hashtags,
      title: String(parsedString.title.split(separator: "\n").first ?? ""),
      text: parsedString.string,
      summary: parsedString.summary,
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
    newNote.creationTimestamp = creationTimestamp
    newNote.folder = folder
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

  var summary: String? {
    guard
      let anchor = (try? result.get()).flatMap({ AnchoredNode(node: $0, startIndex: 0) }),
      let summaryBody = anchor.first(where: { $0.type == .summaryBody })
    else {
      return nil
    }
    let chars = self[summaryBody.range]
    return String(utf16CodeUnits: chars, count: chars.count)
  }

  var title: String {
    guard let root = try? result.get() else { return "" }
    let anchoredRoot = AnchoredNode(node: root, startIndex: 0)
    if let header = anchoredRoot.first(where: { $0.type == .header }), let tab = header.first(where: { $0.type == .softTab }) {
      var headerRange = header.range
      // Remove everything in the header before the tab.
      headerRange.length -= (tab.range.location - header.range.location + 1)
      headerRange.location = tab.range.location + 1
      let chars = self[headerRange]
      return String(utf16CodeUnits: chars, count: chars.count)
    } else if let nonBlank = anchoredRoot.first(where: { $0.type != .blankLine && $0.type != .document }) {
      let chars = self[nonBlank.range]
      return String(utf16CodeUnits: chars, count: chars.count)
    } else {
      return ""
    }
  }
}
