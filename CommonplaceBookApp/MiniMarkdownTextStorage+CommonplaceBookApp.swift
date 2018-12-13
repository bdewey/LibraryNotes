// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import CwlSignal
import Foundation
import MiniMarkdown
import TextBundleKit

private var signalKey = "markdownSignal"

extension MiniMarkdownTextStorage {
  internal convenience init(
    parsingRules: ParsingRules,
    formatters: [NodeType: RenderedMarkdown.FormattingFunction],
    renderers: [NodeType: RenderedMarkdown.RenderFunction],
    stylesheet: Stylesheet
  ) {
    self.init(
      parsingRules: parsingRules,
      formatters: formatters,
      renderers: renderers
    )
    defaultAttributes = NSAttributedString.Attributes(
      stylesheet.typographyScheme.body2
    )
    defaultAttributes.kern = stylesheet.kern[.body2] ?? 1.0
    defaultAttributes.color = stylesheet.colors
      .onSurfaceColor
      .withAlphaComponent(stylesheet.alpha[.darkTextHighEmphasis] ?? 1.0)
  }

  internal var markdownSignal: Signal<[Node]> {
    if let bridge = objc_getAssociatedObject(self, &signalKey) as? StorageSignalBridge {
      return bridge.signal
    }
    let bridge = StorageSignalBridge(storage: self)
    objc_setAssociatedObject(self, &signalKey, bridge, .OBJC_ASSOCIATION_RETAIN)
    return bridge.signal
  }
}

private final class StorageSignalBridge {
  init(storage: MiniMarkdownTextStorage) {
    self.storage = storage

    let (input, signal) = Signal<[Node]>.create()
    self.input = input
    self.signal = signal.continuous()
    input.send(value: storage.nodes)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(storageDidChange(notification:)),
      name: .miniMarkdownTextStorageNodesDidChange,
      object: storage
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  private let storage: MiniMarkdownTextStorage
  private let input: SignalInput<[Node]>
  public let signal: Signal<[Node]>

  @objc private func storageDidChange(notification: Notification) {
    guard let nodes = notification.userInfo?["nodes"] as? [Node] else {
      assertionFailure("Expected nodes")
      return
    }
    input.send(value: nodes)
  }
}
