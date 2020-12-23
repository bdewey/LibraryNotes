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

import CommonCrypto
import Foundation

/// Extensible enum for the different types of card templates.
/// Also maintains a mapping between each type and the specific CardTemplate class
/// associated with that type.
public struct PromptType: RawRepresentable, Hashable {
  public let rawValue: String

  /// While required by the RawRepresentable protocol, this is not the preferred way
  /// to create CardTemplateTypes because it will not create an association with the
  /// corresponding CardTemplate classes.
  @available(*, deprecated)
  public init(rawValue: String) { self.rawValue = rawValue }

  /// Designated initializer.
  ///
  /// - parameter rawValue: The string name for the type.
  /// - parameter templateClass: The CardTemplate associated with this type.
  public init(rawValue: String, class templateClass: PromptCollection.Type) {
    self.rawValue = rawValue
    PromptType.classMap[rawValue] = templateClass
  }

  /// Mapping between rawValue and CardTemplate classes.
  public private(set) static var classMap = [String: PromptCollection.Type]()
}

public struct ChallengeTemplateIdentifier: Hashable {
  public var noteId: String
  public var promptKey: String
}

/// A ChallengeTemplate is a serializable thing that knows how to generate one or more Challenges.
/// For example, a VocabularyAssociation knows how to generate one card that prompts with
/// the English word and one card that prompts with the Spanish word.
public protocol PromptCollection {
  init?(rawValue: String)
  
  var rawValue: String { get }

  /// Subclasses should override and return their particular type.
  /// This is a computed, rather than a stored, property so it does not get serialized.
  var type: PromptType { get }

  /// The specific cards from this template.
  var challenges: [Prompt] { get }
}

public extension Array where Element: PromptCollection {
  /// Returns the challenges from all of the associations in the array.
  var cards: [Prompt] {
    return [Prompt](map { $0.challenges }.joined())
  }
}
