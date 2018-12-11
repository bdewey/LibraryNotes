// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import CwlSignal
import MiniMarkdown
import TextBundleKit
import enum TextBundleKit.Result
import UIKit

public protocol EditableDocument: class {
  var currentTextResult: Result<Tagged<String>> { get }
  var textSignal: Signal<Tagged<String>> { get }
  func applyTaggedModification(tag: Tag, modification: (String) -> String)
  func open(completionHandler: ((Bool) -> Void)?)
  func openOrCreate(completionHandler: ((Bool) -> Void)?)
  func close()
  var previousError: Swift.Error? { get }
}

public protocol ConfiguresRenderers {
  func configureRenderers(_ renderers: inout [NodeType: RenderedMarkdown.RenderFunction])
}

extension UIDocument {
  /// Any UIDocument now has `openOrCreate` functionality.
  /// If opening the document doesn't succeed, try saving it with mode `.forCreating`.
  /// - parameter completionHandler: Optional handler to be called with a Bool indicating success.
  public func openOrCreate(completionHandler: ((Bool) -> Void)?) {
    self.open { (success) in
      if success {
        completionHandler?(success)
      } else {
        self.save(to: self.fileURL, for: .forCreating, completionHandler: { (success) in
          completionHandler?(success)
        })
      }
    }
  }
}
