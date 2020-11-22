// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import Foundation
import Logging
import UIKit

extension ChallengeTemplateType {
  public static let cloze = ChallengeTemplateType(rawValue: "cloze", class: ClozeTemplate.self)
}

/// A template for creating ClozeCards from a markdown block that contains one or more clozes.
public final class ClozeTemplate: ChallengeTemplate {
  public override var type: ChallengeTemplateType { return .cloze }

  public required init?(rawValue: String) {
    self.markdown = rawValue
    let memoizationTable = MemoizationTable(grammar: MiniMarkdownGrammar.shared)
    guard let node = try? memoizationTable.parseBuffer(rawValue) else {
      return nil
    }
    self.node = node
    super.init()
  }

  public override var rawValue: String { markdown }
  private let markdown: String
  private let node: NewNode

  // MARK: - CardTemplate conformance

  public override var challenges: [Challenge] {
    let clozeCount = node.findNodes(where: { $0.type == .cloze }).count
    return (0 ..< clozeCount).map { ClozeCard(template: self, markdown: markdown, clozeIndex: $0) }
  }

  public static func extract(from buffer: IncrementalParsingBuffer) -> [ClozeTemplate] {
    guard let root = try? buffer.result.get() else {
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
    return clozeSet.compactMap { wrappedNode -> ClozeTemplate? in
      let node = wrappedNode.value
      let chars = buffer[node.range]
      return ClozeTemplate(rawValue: String(utf16CodeUnits: chars, count: chars.count))
    }
  }
}

/// Wraps an object to allow hashing based on ObjectIdentifier.
struct ObjectIdentityHashable<T: AnyObject>: Hashable {
  let value: T
  init(_ value: T) { self.value = value }

  var hashValue: Int {
    return ObjectIdentifier(value).hashValue
  }

  static func == (lhs: ObjectIdentityHashable<T>, rhs: ObjectIdentityHashable<T>) -> Bool {
    return lhs.value === rhs.value
  }
}
