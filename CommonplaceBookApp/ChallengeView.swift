// Copyright © 2017-present Brian's Brain. All rights reserved.

import AVFoundation
import Foundation
import UIKit

public protocol ChallengeViewDelegate: class {
  func challengeViewDidRevealAnswer(_ challengeView: ChallengeView)
}

open class ChallengeView: UIControl {
  public weak var delegate: ChallengeViewDelegate?

  public override init(frame: CGRect) {
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
