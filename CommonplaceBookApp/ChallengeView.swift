// Copyright © 2018-present Brian's Brain. All rights reserved.

import AVFoundation
import Foundation
import MaterialComponents

public protocol ChallengeViewDelegate: class {
  func challengeView(_ cardView: ChallengeView, didRespondCorrectly: Bool)
  func challengeView(_ cardView: ChallengeView, didRequestSpeech: AVSpeechUtterance, language: String)
}

open class ChallengeView: MDCCard {
  public weak var delegate: ChallengeViewDelegate?

  var introductoryUtterances: [AVSpeechUtterance]? { return nil }
}
