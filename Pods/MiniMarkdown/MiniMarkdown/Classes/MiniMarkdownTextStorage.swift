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

import CocoaLumberjack
import UIKit

private let debugLogging = false

extension NSNotification.Name {
  public static let miniMarkdownTextStorageNodesDidChange = NSNotification.Name(
    rawValue: "miniMarkdownTextStorageNodesDidChange"
  )
}

/// Text storage with syntax highlighting.
public final class MiniMarkdownTextStorage: NSTextStorage {

  public init(
    parsingRules: ParsingRules,
    formatters: [NodeType: RenderedMarkdown.FormattingFunction],
    renderers: [NodeType: RenderedMarkdown.RenderFunction]
  ) {
    self.storage = RenderedMarkdown(
      parsingRules: parsingRules,
      formatters: formatters,
      renderers: renderers
    )
    super.init()
  }

  /// Do not use -- just here to make paste work
  @available(*, deprecated)
  public override init() {
    self.storage = RenderedMarkdown(parsingRules: ParsingRules(), formatters: [:], renderers: [:])
    super.init()
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// The core storage
  private let storage: RenderedMarkdown

  /// Default text attributes
  public var defaultAttributes: NSAttributedString.Attributes {
    get {
      return storage.defaultAttributes
    }
    set {
      storage.defaultAttributes = newValue
    }
  }

  public func expectedAttributes(for nodeType: NodeType) -> [NSAttributedString.Key: Any] {
    var attributes = defaultAttributes
    storage.formatters[nodeType]?(Node(type: nodeType, slice: StringSlice("")), &attributes)
    return attributes.attributes
  }

  // MARK: - Required overrides

  private var memoizedAttributedString: NSMutableAttributedString?

  private func getAttributedString() -> NSMutableAttributedString {
    if let memoizedString = self.memoizedAttributedString {
      return memoizedString
    }
    let memoizedString = NSMutableAttributedString(attributedString: storage.attributedString)
    self.memoizedAttributedString = memoizedString
    return memoizedString
  }

  override public var string: String {
    return getAttributedString().string
  }

  public var markdown: String {
    get {
      return storage.markdown
    }
    set {
      let attributedString = storage.attributedString
      replaceCharacters(in: NSRange(location: 0, length: attributedString.length), with: newValue)
    }
  }

  public var nodes: [Node] { return storage.nodes }

  override public func attributes(
    at location: Int,
    effectiveRange range: NSRangePointer?
  ) -> [NSAttributedString.Key: Any] {
    return getAttributedString().attributes(at: location, effectiveRange: range)
  }

  override public func replaceCharacters(in range: NSRange, with str: String) {
    if debugLogging {
      DDLogDebug(
        "MiniMarkdownTextStorage.replaceCharacters " +
          "length = \(String(describing: memoizedAttributedString?.length)) " +
          "range = \(range) replacement = " + str.debugDescription
      )
    }
    memoizedAttributedString = nil
    let change = storage.replaceCharacters(in: range, with: str)
    if debugLogging {
      DDLogDebug("Change = \(change)")
    }
    self.edited(
      NSTextStorage.EditActions.editedCharacters,
      range: change.changedCharacterRange,
      changeInLength: change.sizeChange
    )
    if change.changedAttributesRange.length > 0 {
      self.edited(
        NSTextStorage.EditActions.editedAttributes,
        range: change.changedAttributesRange,
        changeInLength: 0
      )
    }
    NotificationCenter.default.post(
      name: .miniMarkdownTextStorageNodesDidChange,
      object: self,
      userInfo: ["nodes": storage.nodes]
    )
  }

  public func node(at location: Int) -> Node? {
    return storage.findNode(containing: location)
  }

  override public func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
    guard let attrs = attrs, attrs.count > 0 else {
      if debugLogging {
        DDLogDebug("Ignoring call to clear attributes at range \(range)")
      }
      return
    }
    getAttributedString().setAttributes(attrs, range: range)
  }
}
