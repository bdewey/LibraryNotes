// Copyright © 2018 Brian's Brain. All rights reserved.

import AVFoundation
import Foundation
import MaterialComponents

protocol CardViewDelegate: class {
  func cardView(_ cardView: CardView, didAnswerCorrectly: Bool)
  func cardView(_ cardView: CardView, didRequestSpeech: AVSpeechUtterance, language: String)
}

open class CardView: MDCCard {
  weak var delegate: CardViewDelegate?

  var introductoryUtterances: [AVSpeechUtterance]? { return nil }
}
