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
import Logging
import UIKit

public extension ChallengeTemplateType {
  static let cloze = ChallengeTemplateType(rawValue: "cloze", class: ClozeTemplate.self)
}

/// A template for creating ClozeCards from a markdown block that contains one or more clozes.
public final class ClozeTemplate: ChallengeTemplate {
  override public var type: ChallengeTemplateType { return .cloze }

  public required init?(rawValue: String) {
    self.markdown = rawValue
    let memoizationTable = MemoizationTable(grammar: MiniMarkdownGrammar.shared)
    guard let node = try? memoizationTable.parseBuffer(rawValue) else {
      return nil
    }
    self.node = node
    super.init()
  }

  override public var rawValue: String { markdown }
  private let markdown: String
  private let node: SyntaxTreeNode

  // MARK: - CardTemplate conformance

  override public var challenges: [Challenge] {
    let clozeCount = node.findNodes(where: { $0.type == .cloze }).count
    return (0 ..< clozeCount).map { ClozeCard(template: self, markdown: markdown, clozeIndex: $0) }
  }

  public static func extract(from parsedString: ParsedString) -> [ClozeTemplate] {
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
    return clozeSet.compactMap { wrappedNode -> ClozeTemplate? in
      let node = wrappedNode.value
      let chars = parsedString[node.range]
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
