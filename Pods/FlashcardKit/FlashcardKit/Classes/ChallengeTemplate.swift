// Copyright © 2018-present Brian's Brain. All rights reserved.

import Foundation

/// Extensible enum for the different types of card templates.
/// Also maintains a mapping between each type and the specific CardTemplate class
/// associated with that type.
public struct ChallengeTemplateType: RawRepresentable {
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
  public init(rawValue: String, class templateClass: ChallengeTemplate.Type) {
    self.rawValue = rawValue
    ChallengeTemplateType.classMap[rawValue] = templateClass
  }

  /// Type used for the "abstract" base class.
  internal static let unknown = ChallengeTemplateType(rawValue: "unknown", class: ChallengeTemplate.self)

  /// Mapping between rawValue and CardTemplate classes.
  fileprivate static var classMap = [String: ChallengeTemplate.Type]()
}

/// A ChallengeTemplate is a serializable thing that knows how to generate one or more Challenges.
/// For example, a VocabularyAssociation knows how to generate one card that prompts with
/// the English word and one card that prompts with the Spanish word.
open class ChallengeTemplate: Codable {
  /// Subclasses should override and return their particular type.
  /// This is a computed, rather than a stored, property so it does not get serialized.
  open var type: ChallengeTemplateType { return .unknown }

  /// The specific cards from this template.
  open var challenges: [Challenge] { return [] }

  /// Public initializer so we can subclass this outside of this module.
  public init() {}
}

extension Array where Element: ChallengeTemplate {
  /// Returns the challenges from all of the associations in the array.
  public var cards: [Challenge] {
    return Array<Challenge>(map { $0.challenges }.joined())
  }
}

/// Wraps ChallengeTemplate instances to allow Codable heterogenous collections of ChallengeTemplate objects.
public final class CardTemplateSerializationWrapper: Codable {
  /// The wrapped ChallengeTemplate.
  public let value: ChallengeTemplate

  public init(_ value: ChallengeTemplate) { self.value = value }

  enum CodingKeys: String, CodingKey {
    /// Used to encode `value.type`
    case type = "__type"
  }

  enum Error: Swift.Error {
    /// Thrown when we cannot look up a CardTemplate class for a specific type.
    case noClassForType(type: String)
  }

  public init(from decoder: Decoder) throws {
    // Step 1: Get the encoded type name and look up the corresponding CardTemplate class.
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let typeName = try container.decode(String.self, forKey: .type)
    guard let templateClass = ChallengeTemplateType.classMap[typeName] else {
      throw Error.noClassForType(type: typeName)
    }

    // Step 2: Create an instance of `templateClass` and initialize it.
    //
    // container.decode(templateClass, forKey: .value) does not work. It appears that
    // in this case, templateClass is resolved at compile time, and the compiler knows that
    // templateClass must be a CardTemplate and we create/initialize the base class.
    //
    // templateClass.init, on the other hand, is resolved at run time and we'll create
    // an instance of the subclass.
    self.value = try templateClass.init(from: decoder)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(value.type.rawValue, forKey: .type)
    try value.encode(to: encoder)
  }
}

extension Array where Element == CardTemplateSerializationWrapper {
  /// Convenience: Returns the cards made from all wrapped templates.
  public var cards: [Challenge] {
    return Array<Challenge>(map { $0.value.challenges }.joined())
  }
}
