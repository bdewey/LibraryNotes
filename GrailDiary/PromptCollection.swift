// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import CommonCrypto
import Foundation

/// Extensible enum for the different types of prompts.
/// Also maintains a mapping between each type and the specific PromptCollection class
/// associated with that type.
public struct PromptType: RawRepresentable, Hashable {
  public let rawValue: String

  /// While required by the RawRepresentable protocol, this is not the preferred way
  /// to create PromptType because it will not create an association with the
  /// corresponding PromptCollection classes.
  @available(*, deprecated)
  public init(rawValue: String) { self.rawValue = rawValue }

  /// Designated initializer.
  ///
  /// - parameter rawValue: The string name for the type.
  /// - parameter templateClass: The PromptCollection associated with this type.
  public init(rawValue: String, class templateClass: PromptCollection.Type) {
    self.rawValue = rawValue
    PromptType.classMap[rawValue] = templateClass
  }

  /// Mapping between rawValue and PromptCollection classes.
  public private(set) static var classMap = [String: PromptCollection.Type]()
}

/// A PromptCollection is a serializable thing that knows how to generate one or more Prompts.
/// For example, a VocabularyAssociation knows how to generate one card that prompts with
/// the English word and one card that prompts with the Spanish word.
public protocol PromptCollection {
  init?(rawValue: String)

  var rawValue: String { get }

  /// Subclasses should override and return their particular type.
  /// This is a computed, rather than a stored, property so it does not get serialized.
  var type: PromptType { get }

  /// The specific prompts contained in this collection.
  var prompts: [Prompt] { get }

  /// When first creating the prompts in this collection, how far in the future should they be scheduled?
  var newPromptDelay: TimeInterval { get }
}

public extension PromptCollection {
  var newPromptDelay: TimeInterval { 4 * .day }
}

public extension Array where Element: PromptCollection {
  /// Returns the prompts from all of the collections in the array.
  var prompts: [Prompt] {
    return [Prompt](map { $0.prompts }.joined())
  }
}
