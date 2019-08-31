// Copyright © 2017-present Brian's Brain. All rights reserved.

import MiniMarkdown
import UIKit

extension ChallengeTemplateType {
  public static let vocabulary = ChallengeTemplateType(rawValue: "vocab", class: VocabularyChallengeTemplate.self)
}

public final class VocabularyChallengeTemplate: ChallengeTemplate {
  public override var type: ChallengeTemplateType { return .vocabulary }

  /// Holds a vocabulary word -- a pairing of the word and language
  public struct Word: Codable {
    public let text: String
    public let language: String

    public init(text: String, language: String) {
      self.text = text
      self.language = language
    }
  }

  public let front: Word
  public let back: Word

  public init(front: Word, back: Word) {
    self.front = front
    self.back = back
    super.init()
  }

  public override var challenges: [CommonplaceBookApp.Challenge] {
    // TODO: It's awful that I'm hard-coding the prefixes here. There's got to be a better way
    // to manage these identifiers.
    return [
      Challenge(challengeIdentifier: ChallengeIdentifier(templateDigest: templateIdentifier, index: 0), front: front, back: back),
      Challenge(challengeIdentifier: ChallengeIdentifier(templateDigest: templateIdentifier, index: 1), front: back, back: front),
    ]
  }

  // MARK: - Codable

  enum CodingKeys: String, CodingKey {
    case front
    case back
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.front = try container.decode(Word.self, forKey: .front)
    self.back = try container.decode(Word.self, forKey: .back)
    try super.init(from: decoder)
  }

  public override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(front, forKey: .front)
    try container.encode(back, forKey: .back)
  }
}

extension VocabularyChallengeTemplate {
  public struct Challenge: CommonplaceBookApp.Challenge {
    public let challengeIdentifier: ChallengeIdentifier
    public let front: Word
    public let back: Word

    public func challengeView(
      document: UIDocument,
      properties: CardDocumentProperties
    ) -> ChallengeView {
      let view = TwoSidedCardView(frame: .zero)
      return view
    }
  }
}
