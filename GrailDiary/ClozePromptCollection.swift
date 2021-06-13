// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import Logging
import TextMarkupKit
import UIKit

public extension PromptType {
  static let cloze = PromptType(rawValue: "prompt=cloze", class: ClozePromptCollection.self)
}

/// A template for creating ClozeCards from a markdown block that contains one or more clozes.
public struct ClozePromptCollection: PromptCollection {
  public var type: PromptType { return .cloze }

  public init?(rawValue: String) {
    self.markdown = rawValue
    let memoizationTable = MemoizationTable(grammar: MiniMarkdownGrammar.shared)
    guard let node = try? memoizationTable.parseBuffer(rawValue) else {
      return nil
    }
    self.node = node
  }

  public var rawValue: String { markdown }
  private let markdown: String
  private let node: SyntaxTreeNode

  // MARK: - CardTemplate conformance

  public var prompts: [Prompt] {
    let clozeCount = node.findNodes(where: { $0.type == .cloze }).count
    return (0 ..< clozeCount).map { ClozePrompt(template: self, markdown: markdown, clozeIndex: $0) }
  }

  public static func extract(from parsedString: ParsedString) -> [ClozePromptCollection] {
    guard let root = try? parsedString.result.get() else {
      return []
    }
    var clozeParents = [AnchoredNode]()
    let anchoredRoot = AnchoredNode(node: root, startIndex: 0)
    anchoredRoot.forEachPath { path, _ in
      guard path.last?.node.type == .cloze else { return }
      if let parent = path.reversed().first(where: { $0.node.type == .paragraph || $0.node.type == .listItem }) {
        clozeParents.append(parent)
      }
    }
    // A paragraph or list item that contains more than one cloze will appear more than
    // one time in `clozes`. Deduplicate using pointer identity.
    let clozeSet = Set<ObjectIdentityHashable>(clozeParents.map { ObjectIdentityHashable($0) })
    Logger.shared.debug("Found \(clozeSet.count) clozes")
    return clozeSet.compactMap { wrappedNode -> ClozePromptCollection? in
      let node = wrappedNode.value
      let chars = parsedString[node.range]
      return ClozePromptCollection(rawValue: String(utf16CodeUnits: chars, count: chars.count))
    }
  }
}

/// Wraps an object to allow hashing based on ObjectIdentifier.
struct ObjectIdentityHashable<T: AnyObject>: Hashable {
  let value: T
  init(_ value: T) { self.value = value }

  func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(value))
  }

  static func == (lhs: ObjectIdentityHashable<T>, rhs: ObjectIdentityHashable<T>) -> Bool {
    return lhs.value === rhs.value
  }
}
