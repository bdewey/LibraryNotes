// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import AVFoundation
import Foundation
import UIKit

@MainActor
public protocol PromptViewDelegate: AnyObject {
  func promptViewDidRevealAnswer(_ promptView: PromptView)
}

@MainActor
@objc public protocol PromptViewActions {
  func revealAnswer()
}

open class PromptView: UIControl {
  public var isAnswerVisible = false
  public weak var delegate: PromptViewDelegate?

  override public init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }

  public required init?(coder: NSCoder) {
    super.init(coder: coder)
    commonInit()
  }

  private func commonInit() {
    backgroundColor = UIColor.secondarySystemGroupedBackground
  }
}
