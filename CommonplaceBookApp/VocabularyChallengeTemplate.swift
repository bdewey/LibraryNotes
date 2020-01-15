// Copyright © 2017-present Brian's Brain. All rights reserved.

import AVFoundation
import CocoaLumberjack
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

  /// Used to serialize internal state.
  private struct State: Codable {
    var front: Word
    var back: Word
    var imageAsset: String?
  }

  @Published public var front: Word { didSet { memoizedRawValue = nil } }
  @Published public var back: Word { didSet { memoizedRawValue = nil } }
  @Published public var imageAsset: String? { didSet { memoizedRawValue = nil } }

  public init(front: Word, back: Word) {
    self.front = front
    self.back = back
    super.init()
  }

  public required init?(rawValue: String) {
    do {
      let data = rawValue.data(using: .utf8)!
      let state = try JSONDecoder().decode(State.self, from: data)
      self.front = state.front
      self.back = state.back
      self.imageAsset = state.imageAsset
      super.init()
    } catch {
      DDLogError("Error decoding \(rawValue.debugDescription): \(error)")
      return nil
    }
  }

  private var memoizedRawValue: String?

  public override var rawValue: String {
    if let memoizedRawValue = memoizedRawValue {
      return memoizedRawValue
    }
    let state = State(front: front, back: back, imageAsset: imageAsset)
    let encoder = JSONEncoder()
    do {
      let data = try encoder.encode(state)
      memoizedRawValue = String(data: data, encoding: .utf8)
      return memoizedRawValue ?? ""
    } catch {
      DDLogError("Unexpected error serializing template: \(error)")
      return ""
    }
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
      Challenge(challengeIdentifier: ChallengeIdentifier(templateDigest: templateIdentifier!, index: 0), front: front, back: back, imageAsset: imageAsset),
      Challenge(challengeIdentifier: ChallengeIdentifier(templateDigest: templateIdentifier!, index: 1), front: back, back: front, imageAsset: imageAsset),
    ]
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
    public let imageAsset: String?

    public func challengeView(
      document: NoteStorage,
      properties: CardDocumentProperties
    ) -> ChallengeView {
      var image: UIImage?
      if let notebook = document as? NoteStorage,
        let assetKey = imageAsset,
        let data = try? notebook.data(for: assetKey),
        let documentImage = UIImage(data: data) {
        image = documentImage
      }
      let view = VocabularyChallengeView(promptWord: front, answerWord: back, image: image)
      if let languageName = languageName(for: back.language) {
        view.context = "Say this in \(languageName)"
      } else {
        view.context = "Translate"
      }
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

extension VocabularyChallengeTemplate {
  /// A specialized ChallengeView for vocabulary. It's got room for images, and it will speak words.
  /// - The assumption is the viewer knows English and wants to learn something else.
  /// - When the non-English word is revealed, it's also spoken.
  /// - If there is an image, it will be revealed when the English word is revealed.
  private final class VocabularyChallengeView: ChallengeView {
    init(promptWord: Word, answerWord: Word, image: UIImage?) {
      self.promptWord = promptWord
      self.answerWord = answerWord
      super.init(frame: .zero)
      promptLabel.text = promptWord.text
      answerLabel.text = answerWord.text
      addSubview(stackView)
      stackView.snp.makeConstraints { make in
        make.edges.equalToSuperview().inset(16)
      }
      if let image = image {
        imageView.image = image
        imageView.snp.makeConstraints { make in
          make.width.equalToSuperview()
          // This needs to be less-than-required, otherwise when the image is hidden it will force
          // its width to 0, which forces the stack width to 0...
          make.height.equalTo(imageView.snp.width).multipliedBy(image.size.height / image.size.width).priority(999)
        }
      } else {
        imageView.isHidden = true
      }
      // The image starts hidden if the prompt language is anything other than english
      // TODO: "english" should be an environment variable of "language you already know"
      imageView.isHidden = promptWord.language != "en"
      addTarget(self, action: #selector(revealAnswer), for: .touchUpInside)
      layoutIfNeeded()
    }

    /// What are we prompting for? (text & language)
    let promptWord: Word

    /// What's the expected response? (text & language)
    let answerWord: Word

    let speechSynthesizer = AVSpeechSynthesizer()

    public required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToSuperview() {
      super.didMoveToSuperview()
      if superview != nil, promptWord.language != "en" {
        LoggingSpeechSynthesizer.shared.speakWord(promptWord)
      }
    }

    /// Holds the vertical stack of controls.
    private lazy var stackView: UIStackView = {
      let stack = UIStackView(arrangedSubviews: [contextLabel, imageView, promptLabel, answerLabel])
      stack.axis = .vertical
      stack.alignment = .leading
      stack.spacing = 8
      stack.isUserInteractionEnabled = false
      return stack
    }()

    var context: String? {
      get { contextLabel.attributedText?.string }
      set {
        contextLabel.attributedText = NSAttributedString(
          string: (newValue ?? "").localizedUppercase,
          attributes: [
            .font: UIFont.preferredFont(forTextStyle: .subheadline),
            .kern: 2.0,
            .foregroundColor: UIColor.secondaryLabel,
          ]
        )
      }
    }

    /// The "context" at the top of the view, letting the viewer know what's expected.
    private lazy var contextLabel: UILabel = {
      let label = UILabel(frame: .zero)
      label.font = .preferredFont(forTextStyle: .subheadline)
      label.textColor = .secondaryLabel
      return label
    }()

    /// The prompt for a word.
    private lazy var promptLabel: UILabel = {
      let label = UILabel(frame: .zero)
      label.font = .preferredFont(forTextStyle: .headline)
      label.textColor = .label
      return label
    }()

    /// The optional image.
    private lazy var imageView: UIImageView = {
      let imageView = UIImageView(frame: .zero)
      imageView.contentMode = .scaleAspectFit
      return imageView
    }()

    /// The expected response, given the prompt.
    private lazy var answerLabel: UILabel = {
      let label = UILabel(frame: .zero)
      label.font = .preferredFont(forTextStyle: .body)
      label.textColor = .label
      label.isHidden = true
      return label
    }()

    /// Reveals the answer.
    @objc private func revealAnswer() {
      UIView.animate(
        withDuration: 0.2,
        animations: {
          self.answerLabel.isHidden = false
          self.imageView.isHidden = false
          self.setNeedsLayout()
          self.layoutIfNeeded()
        },
        completion: { _ in
          if self.answerWord.language != "en" {
            LoggingSpeechSynthesizer.shared.speakWord(self.answerWord)
          }
        }
      )
      delegate?.challengeViewDidRevealAnswer(self)
    }
  }
}
