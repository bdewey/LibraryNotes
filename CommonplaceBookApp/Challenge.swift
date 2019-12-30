// Copyright © 2017-present Brian's Brain. All rights reserved.

import AVFoundation
import Foundation
import UIKit

/// Uniquely identifies a challenge.
public struct ChallengeIdentifier: Hashable {
  /// The SHA1 digest of the template that created this challenge.
  public let templateDigest: String?

  /// The index of this challenge in the template's challenges array.
  public let index: Int

  /// Public initializer.
  public init(templateDigest: String?, index: Int) {
    self.templateDigest = templateDigest
    self.index = index
  }
}

/// A specific thing to recall.
public protocol Challenge {
  /// Every challenge needs a unique identifier. This serves as an key to associate this card
  /// with statistics describing how well the person handles the challenge over time.
  var challengeIdentifier: ChallengeIdentifier { get }

  /// Returns a view that can quiz a person about the thing to remember.
  ///
  /// - parameter document: The document the card came from. Can be used for things like
  ///                       loading images.
  /// - parameter properties: Relevant properties of `document`
  func challengeView(
    document: NoteStorage,
    properties: CardDocumentProperties
  ) -> ChallengeView
}
