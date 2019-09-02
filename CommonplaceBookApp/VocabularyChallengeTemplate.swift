// Copyright © 2017-present Brian's Brain. All rights reserved.

import Combine
import MiniMarkdown
import UIKit

extension ChallengeTemplateType {
  public static let vocabulary = ChallengeTemplateType(rawValue: "vocab", class: VocabularyChallengeTemplate.self)
}

public final class VocabularyChallengeTemplate: ChallengeTemplate, ObservableObject {
  public override var type: ChallengeTemplateType { return .vocabulary }

  /// Holds a vocabulary word -- a pairing of the word and language
  public struct Word: Codable, Hashable {
    public var text: String
    public let language: String

    public init(text: String, language: String) {
      self.text = text
      self.language = language
    }
  }

  @Published public var front: Word
  @Published public var back: Word
  public let parsingRules: ParsingRules

  public init(front: Word, back: Word, parsingRules: ParsingRules) {
    self.front = front
    self.back = back
    self.parsingRules = parsingRules
    super.init()
  }

  public func trimText() {
    front.text = front.text.trimmingCharacters(in: .whitespacesAndNewlines)
    back.text = back.text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  public var isValid: Bool {
    !front.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !back.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  public override var challenges: [CommonplaceBookApp.Challenge] {
    // TODO: It's awful that I'm hard-coding the prefixes here. There's got to be a better way
    // to manage these identifiers.
    return [
      Challenge(challengeIdentifier: ChallengeIdentifier(templateDigest: templateIdentifier, index: 0), front: front, back: back, parsingRules: parsingRules),
      Challenge(challengeIdentifier: ChallengeIdentifier(templateDigest: templateIdentifier, index: 1), front: back, back: front, parsingRules: parsingRules),
    ]
  }

  // MARK: - Codable

  enum CodingKeys: String, CodingKey {
    case front
    case back
  }

  required init(from decoder: Decoder) throws {
    guard let parsingRules = decoder.userInfo[.markdownParsingRules] as? ParsingRules else {
      // TODO: Move this error somewhere else
      throw ClozeTemplate.Error.noParsingRules
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.front = try container.decode(Word.self, forKey: .front)
    self.back = try container.decode(Word.self, forKey: .back)
    self.parsingRules = parsingRules
    try super.init(from: decoder)
  }

  public override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(front, forKey: .front)
    try container.encode(back, forKey: .back)
  }
}

extension VocabularyChallengeTemplate: Hashable {
  public static func == (lhs: VocabularyChallengeTemplate, rhs: VocabularyChallengeTemplate) -> Bool {
    return lhs.front == rhs.front &&
      lhs.back == rhs.back
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(front)
    hasher.combine(back)
  }
}

extension VocabularyChallengeTemplate {
  public struct Challenge: CommonplaceBookApp.Challenge {
    public let challengeIdentifier: ChallengeIdentifier
    public let front: Word
    public let back: Word
    public let parsingRules: ParsingRules

    public func challengeView(
      document: UIDocument,
      properties: CardDocumentProperties
    ) -> ChallengeView {
      let view = TwoSidedCardView(frame: .zero)
      view.context = context()
      let renderer = RenderedMarkdown(textStyle: .headline, parsingRules: parsingRules)
      renderer.markdown = front.text
      view.front = renderer.attributedString
      renderer.markdown = back.text
      view.back = renderer.attributedString
      return view
    }

    private func context() -> NSAttributedString {
      let font = UIFont.preferredFont(forTextStyle: .subheadline)
      let contextString: String
      if let languageName = languageName(for: back.language) {
        contextString = "Say this in \(languageName)"
      } else {
        contextString = "Translate"
      }
      return NSAttributedString(
        string: contextString.localizedUppercase,
        attributes: [.font: font, .kern: 2.0, .foregroundColor: UIColor.secondaryLabel]
      )
    }

    private func languageName(for language: String) -> String? {
      switch language.lowercased() {
      case "en":
        return "English"
      case "es":
        return "Spanish"
      default:
        return nil
      }
    }
  }
}
