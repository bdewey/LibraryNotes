//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import AVFoundation
import Foundation
import UIKit

/// Uniquely identifies a challenge.
public struct ChallengeIdentifier: Hashable {
  /// The SHA1 digest of the template that created this challenge.
  public var challengeTemplateID: FlakeID?

  /// The index of this challenge in the template's challenges array.
  public let index: Int

  /// Public initializer.
  public init(templateDigest: FlakeID?, index: Int) {
    self.challengeTemplateID = templateDigest
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
    document: NoteSqliteStorage,
    properties: CardDocumentProperties
  ) -> ChallengeView
}
