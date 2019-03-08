// Copyright © 2018-present Brian's Brain. All rights reserved.

import AVFoundation
import CommonplaceBook
import Foundation
import MaterialComponents
import TextBundleKit

/// A specific thing to recall.
public protocol Challenge {
  /// Every challenge needs a unique identifier. This serves as an key to associate this card
  /// with statistics describing how well the person handles the challenge over time.
  var identifier: String { get }

  /// Returns a view that can quiz a person about the thing to remember.
  ///
  /// - parameter document: The document the card came from. Can be used for things like
  ///                       loading images.
  /// - parameter properties: Relevant properties of `document`
  /// - parameter stylesheet: Stylesheet to use when rendering the view.
  func challengeView(
    document: UIDocument,
    properties: CardDocumentProperties,
    stylesheet: Stylesheet
  ) -> ChallengeView
}
