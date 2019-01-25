// Copyright © 2018 Brian's Brain. All rights reserved.

import AVFoundation
import CommonplaceBook
import Foundation
import MaterialComponents
import TextBundleKit

/// A specific thing to recall.
public protocol Card {

  /// Every card needs a unique identifier. This serves as an key to associate this card
  /// with statistics describing how well the person remembers the information associated
  /// with this card over time.
  var identifier: String { get }

  /// Returns a view that can quiz a person about the thing to remember.
  ///
  /// - parameter document: The document the card came from. Can be used for things like
  ///                       loading images.
  /// - parameter properties: Relevant properties of `document`
  /// - parameter stylesheet: Stylesheet to use when rendering the view.
  func cardView(
    document: UIDocument,
    properties: CardDocumentProperties,
    stylesheet: Stylesheet
  ) -> CardView
}
