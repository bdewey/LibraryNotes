// Copyright © 2018 Brian's Brain. All rights reserved.

import AVFoundation
import CommonplaceBook
import MaterialComponents
import MiniMarkdown
import SnapKit
import TextBundleKit
import UIKit

// TODO: Find commmon code with VocabularyAssociationCardView and create a single reusable class?

final class ClozeCardView: CardView {
  init(card: ClozeCard, parseableDocument: ParseableDocument, stylesheet: Stylesheet) {
    self.card = card
    self.parseableDocument = parseableDocument
    let nodes = parseableDocument.parsingRules.parse(card.markdown)
    assert(nodes.count == 1)
    self.node = nodes[0]
    self.stylesheet = stylesheet
    super.init(frame: .zero)
    self.addSubview(columnStack)
    columnStack.snp.makeConstraints { (make) in
      make.edges.equalToSuperview().inset(16)
    }

    self.addTarget(self, action: #selector(revealAnswer), for: .touchUpInside)

    contextLabel.attributedText = context
    frontLabel.attributedText = cardFront
    backLabel.attributedText = cardBack
    setAnswerVisible(false, animated: false)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let card: ClozeCard
  private let node: Node
  private let parseableDocument: ParseableDocument
  private let stylesheet: Stylesheet

  private func setAnswerVisible(_ answerVisible: Bool, animated: Bool) {
    let animations = {
      UIView.performWithoutAnimation {
        self.frontLabel.isHidden = answerVisible
      }
      self.backLabel.isHidden = !answerVisible
      self.gotItButton.isHidden = !answerVisible
      self.buttonRow.isHidden = !answerVisible
      self.studyMoreButton.isHidden = !answerVisible
      self.columnStack.isUserInteractionEnabled = answerVisible
      self.setNeedsLayout()
      if animated { self.layoutIfNeeded() }
    }
    if animated {
      UIView.animate(withDuration: 0.2, animations: animations, completion: { (_) in
        self.didTapPronounce()
      })
    } else {
      animations()
    }
  }

  private lazy var columnStack: UIStackView = {
    let columnStack = UIStackView(
      arrangedSubviews: [contextLabel, frontLabel, backLabel, buttonRow]
    )
    columnStack.axis = .vertical
    columnStack.alignment = .leading
    columnStack.spacing = 8
    return columnStack
  }()

  private lazy var buttonRow: UIStackView = {
    let buttonRow = UIStackView(arrangedSubviews: [gotItButton, studyMoreButton])
    buttonRow.axis = .horizontal
    buttonRow.spacing = 8
    return buttonRow
  }()

  private let contextLabel: UILabel = {
    let contextLabel = UILabel(frame: .zero)
    contextLabel.numberOfLines = 0
    contextLabel.textAlignment = .center
    contextLabel.isUserInteractionEnabled = false
    return contextLabel
  }()

  private let frontLabel: UILabel = {
    let frontLabel = UILabel(frame: .zero)
    frontLabel.numberOfLines = 0
    frontLabel.textAlignment = .center
    frontLabel.isUserInteractionEnabled = false
    return frontLabel
  }()

  private let backLabel: UILabel = {
    let backLabel = UILabel(frame: .zero)
    backLabel.numberOfLines = 0
    backLabel.textAlignment = .center
    backLabel.isUserInteractionEnabled = false
    return backLabel
  }()

  private lazy var gotItButton: MDCButton = {
    let button = MDCButton(frame: .zero)
    MDCContainedButtonThemer.applyScheme(stylesheet.buttonScheme, to: button)
    button.setTitle("Got it", for: .normal)
    button.addTarget(self, action: #selector(didTapGotIt), for: .touchUpInside)
    return button
  }()

  private lazy var studyMoreButton: MDCButton = {
    let button = MDCButton(frame: .zero)
    MDCTextButtonThemer.applyScheme(stylesheet.buttonScheme, to: button)
    button.setTitle("Study More", for: .normal)
    button.addTarget(self, action: #selector(didTapStudyMore), for: .touchUpInside)
    return button
  }()

  private lazy var prounounceSpanishButton: MDCButton = {
    let button = MDCButton(frame: .zero)
    MDCTextButtonThemer.applyScheme(stylesheet.buttonScheme, to: button)
    button.setTitle("Say it", for: .normal)
    button.addTarget(self, action: #selector(didTapPronounce), for: .touchUpInside)
    return button
  }()

  @objc private func revealAnswer() {
    setAnswerVisible(true, animated: true)
  }

  @objc private func didTapGotIt() {
    delegate?.cardView(self, didAnswerCorrectly: true)
  }

  @objc private func didTapStudyMore() {
    delegate?.cardView(self, didAnswerCorrectly: false)
  }

  /// Returns the language we should use for utterances from this cloze.
  /// TODO: Make this a real property of the document.
  private var language: String? {
    if parseableDocument.document is TextBundleDocument {
      return "es-MX"
    } else {
      return nil
    }
  }

  @objc private func didTapPronounce() {
    if let language = language {
      delegate?.cardView(self, didRequestSpeech: utterance, language: language)
    }
  }
}

extension ClozeCardView {
  var utterance: AVSpeechUtterance {
    let phrase = clozeRenderer.render(node: node)
    let utterance = AVSpeechUtterance(string: phrase)
    utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
    return utterance
  }

  var context: NSAttributedString {
    let font = stylesheet.typographyScheme.overline
    let contextString = "Fill in the blank"
    return NSAttributedString(
      string: contextString.localizedUppercase,
      attributes: [.font: font, .kern: 2.0, .foregroundColor: UIColor(white: 0, alpha: 0.6)]
    )
  }

  var cardFront: NSAttributedString {
    let cardFrontRenderer = MarkdownAttributedStringRenderer.cardFront(
      stylesheet: stylesheet,
      hideClozeAt: card.clozeIndex
    )
    return cardFrontRenderer.render(node: node)
  }

  var cardBack: NSAttributedString {
    return MarkdownAttributedStringRenderer
      .cardBackRenderer(stylesheet: stylesheet, revealingClozeAt: card.clozeIndex)
      .render(node: node)
  }
}

private let clozeRenderer: MarkdownStringRenderer = {
  var renderer = MarkdownStringRenderer()
  renderer.renderFunctions[.text] = { return String($0.slice.substring) }
  renderer.renderFunctions[.cloze] = { (node) in
    guard let cloze = node as? Cloze else { return "" }
    return String(cloze.hiddenText)
  }
  return renderer
}()

private let defaultParagraphStyle: NSParagraphStyle = {
  let paragraphStyle = NSMutableParagraphStyle()
  paragraphStyle.alignment = .left
  return paragraphStyle
}()

extension Stylesheet {

  var textAttributes: [NSAttributedString.Key: Any] {
    return [
      .font: typographyScheme.body2,
      .foregroundColor: colors.onSurfaceColor.withAlphaComponent(alpha[.darkTextHighEmphasis] ?? 1),
      .paragraphStyle: defaultParagraphStyle,
    ]
  }

  var clozeAttributes: [NSAttributedString.Key: Any] {
    return [
      .font: typographyScheme.body2,
      .foregroundColor: colors.onSurfaceColor
        .withAlphaComponent(alpha[.darkTextMediumEmphasis] ?? 0.5),
      .backgroundColor: UIColor(rgb: 0xf6e6f0),
      .paragraphStyle: defaultParagraphStyle,
    ]
  }

  var captionAttributes: [NSAttributedString.Key: Any] {
    return [
      .font: typographyScheme.caption,
      .foregroundColor: colors.onSurfaceColor
        .withAlphaComponent(alpha[.darkTextMediumEmphasis] ?? 0.5),
      .kern: kern[.caption] ?? 1.0,
      .paragraphStyle: defaultParagraphStyle,
    ]
  }
}
