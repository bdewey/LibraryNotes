// Copyright © 2018 Brian's Brain. All rights reserved.

import AVFoundation
import CommonplaceBook
import Foundation
import MaterialComponents
import TextBundleKit

/// A specific thing to recall.
protocol Card: Codable {

  var identifier: String { get }

  func cardView(parseableDocument: ParseableDocument, stylesheet: Stylesheet) -> CardView
}
