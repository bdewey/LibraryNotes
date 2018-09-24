// Copyright © 2018 Brian's Brain. All rights reserved.

import AVFoundation
import CommonplaceBook
import Foundation
import MaterialComponents

/// A specific thing to recall.
/// TODO: Extend this so prompts and answers can be more than just strings. Pictures? Sounds?
protocol Card {

  var identifier: String { get }

  func cardView(with stylesheet: Stylesheet) -> CardView
}
