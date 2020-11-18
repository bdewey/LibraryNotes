// Copyright © 2017-present Brian's Brain. All rights reserved.

import CommonCrypto
import Foundation

/// Extensible enum for the different types of card templates.
/// Also maintains a mapping between each type and the specific CardTemplate class
/// associated with that type.
public struct ChallengeTemplateType: RawRepresentable, Hashable {
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

/// A ChallengeTemplate is a serializable thing that knows how to generate one or more Challenges.
/// For example, a VocabularyAssociation knows how to generate one card that prompts with
/// the English word and one card that prompts with the Spanish word.
open class ChallengeTemplate: RawRepresentable {
  public var rawValue: String {
    assertionFailure("Subclasses should override")
    return ""
  }

  public init() {}

  public required init?(rawValue: String) {
    assertionFailure("Subclasses should call the designated initializer instead.")
  }

  /// Unique identifier for this template. Must by set by whatever data structure "owns"
  /// the template before creating any challenges from it.
  ///
  /// Can only be set from nil to non-nil once; immutable once set.
  public var templateIdentifier: FlakeID?

  /// Subclasses should override and return their particular type.
  /// This is a computed, rather than a stored, property so it does not get serialized.
  open var type: ChallengeTemplateType { return .unknown }

  /// The specific cards from this template.
  open var challenges: [Challenge] { return [] }

  public enum CommonErrors: Error {
    /// Thrown when encoded template markdown does not decode to exactly one Node.
    case markdownParseError
  }
}

extension Array where Element: ChallengeTemplate {
  /// Returns the challenges from all of the associations in the array.
  public var cards: [Challenge] {
    return [Challenge](map { $0.challenges }.joined())
  }
}
