// Copyright © 2017-present Brian's Brain. All rights reserved.

import CommonCrypto
import Foundation
import MiniMarkdown

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
  public private(set) static var classMap = [String: ChallengeTemplate.Type]()
}

public protocol MarkdownParseable {
  init(markdown: String, parsingRules: ParsingRules) throws
  var asMarkdown: String { get }
}

/// A ChallengeTemplate is a serializable thing that knows how to generate one or more Challenges.
/// For example, a VocabularyAssociation knows how to generate one card that prompts with
/// the English word and one card that prompts with the Spanish word.
open class ChallengeTemplate: Codable, MarkdownParseable {
  public required init(markdown: String, parsingRules: ParsingRules) throws {}

  open var asMarkdown: String {
    assertionFailure("subclasses should implement")
    return ""
  }

  /// Unique identifier for this template. Must by set by whatever data structure "owns"
  /// the template before creating any challenges from it.
  ///
  /// Can only be set from nil to non-nil once; immutable once set.
  public var templateIdentifier: String? {
    willSet {
      precondition(templateIdentifier == nil)
    }
  }

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
    return [Challenge](map { $0.challenges }.joined())
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
    case value
  }

  enum Error: Swift.Error {
    /// Thrown when we cannot look up a CardTemplate class for a specific type.
    case noClassForType(type: String)
    case couldNotDecodeValue
    case noParsingRules
  }

  public init(from decoder: Decoder) throws {
    // Step 1: Get the encoded type name and look up the corresponding CardTemplate class.
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let typeName = try container.decode(String.self, forKey: .type)
    guard let templateClass = ChallengeTemplateType.classMap[typeName] else {
      throw Error.noClassForType(type: typeName)
    }
    guard let parsingRules = decoder.userInfo[.markdownParsingRules] as? ParsingRules else {
      throw Error.noParsingRules
    }

    let description = try container.decode(String.self, forKey: .value)
    self.value = try templateClass.init(markdown: description, parsingRules: parsingRules)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(value.type.rawValue, forKey: .type)
    try container.encode(value.asMarkdown, forKey: .value)
  }
}

extension Array where Element == CardTemplateSerializationWrapper {
  /// Convenience: Returns the cards made from all wrapped templates.
  public var cards: [Challenge] {
    return [Challenge](map { $0.value.challenges }.joined())
  }
}
