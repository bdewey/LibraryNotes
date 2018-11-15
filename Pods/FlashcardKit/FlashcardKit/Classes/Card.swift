// Copyright © 2018 Brian's Brain. All rights reserved.

import AVFoundation
import CommonplaceBook
import Foundation
import MaterialComponents
import TextBundleKit

/// A specific thing to recall.
public protocol Card: Codable {

  /// Every card needs a unique identifier. This serves as an key to associate this card
  /// with statistics describing how well the person remembers the information associated
  /// with this card over time.
  var identifier: String { get }

  /// Returns a view that can quiz a person about the thing to remember.
  func cardView(parseableDocument: ParseableDocument, stylesheet: Stylesheet) -> CardView
}
