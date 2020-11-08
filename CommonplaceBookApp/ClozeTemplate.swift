// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import Foundation
import MiniMarkdown
import UIKit

extension ChallengeTemplateType {
  public static let cloze = ChallengeTemplateType(rawValue: "cloze", class: ClozeTemplate.self)
}

extension CodingUserInfoKey {
  /// Used to associate a set of ParsingRules with a decoder. These parsing rules are used
  /// to parse encoded Markdown into specific nodes.
  public static let markdownParsingRules = CodingUserInfoKey(rawValue: "markdownParsingRules")!
}

/// A template for creating ClozeCards from a markdown block that contains one or more clozes.
public final class ClozeTemplate: ChallengeTemplate {
  public override var type: ChallengeTemplateType { return .cloze }

  /// Designated initializer.
  /// - parameter node: MiniMarkdown node that contains at least one cloze.
  public init(node: Node) {
    self.node = node
    super.init()
  }

  public required convenience init?(rawValue: String) {
    let nodes = ParsingRules.commonplace.parse(rawValue)
    guard nodes.count == 1 else { return nil }
    self.init(node: nodes[0])
  }

  public let node: Node
  public override var rawValue: String {
    return node.allMarkdown
  }

  // MARK: - CardTemplate conformance

  public override var challenges: [Challenge] {
    let clozeCount = node.findNodes(where: { $0.type == .cloze }).count
    let markdown = node.allMarkdown
    return (0 ..< clozeCount).map { ClozeCard(template: self, markdown: markdown, clozeIndex: $0) }
  }

  /// Extracts all cloze templates from a parsed markdown document.
  /// - parameter markdown: The parsed markdown document.
  /// - returns: An array of all ClozeTemplates found in the document.
  public static func extract(from markdown: [Node]) -> [ClozeTemplate] {
    // Find all paragraphs or list items that contain at least one cloze.
    let clozes = markdown
      .map { $0.findNodes(where: { $0.type == .cloze }) }
      .joined()
      .compactMap { $0.findFirstAncestor(where: { $0.type == .paragraph || $0.type == .listItem }) }

    // A paragraph or list item that contains more than one cloze will appear more than
    // one time in `clozes`. Deduplicate using pointer identity.
    let clozeSet = Set<ObjectIdentityHashable>(clozes.map { ObjectIdentityHashable($0) })
    DDLogDebug("Found \(clozeSet.count) clozes")
    return clozeSet.compactMap { ClozeTemplate(node: $0.value) }
  }

  public static func extract(from buffer: IncrementalParsingBuffer) -> [ClozeTemplate] {
    guard let root = try? buffer.result.get() else {
      return []
    }
    return []
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
