// Copyright © 2018 Brian's Brain. All rights reserved.

import AVFoundation
import CommonplaceBook
import Foundation
import MaterialComponents
import SnapKit
import UIKit

final class VocabularyAssociationSpellingCardView: CardView {
  init(
    card: VocabularyAssociationSpellingCard,
    document: UIDocument,
    parseableDocument: CardDocumentProperties,
    stylesheet: Stylesheet
  ) {
    self.card = card
    self.document = document
    self.parseableDocument = parseableDocument
    self.stylesheet = stylesheet
    super.init(frame: .zero)
    addSubview(controlStack)
    controlStack.snp.makeConstraints { (make) in
      make.edges.equalToSuperview().inset(8)
    }
    spellCheckField.field.snp.makeConstraints { (make) in
      make.leading.equalToSuperview()
      make.trailing.equalToSuperview()
    }
    controlStack.setArrangedSubviews([contextLabel, imageView, spellCheckField.field, buttonStack], animated: false)
    buttonStack.setArrangedSubviews([doneButton, sayAgainButton], animated: false)
    if imageView.image != nil {
      imageView.snp.makeConstraints { (make) in
        make.height.equalTo(100)
        make.width.equalTo(100)
      }
    }
    correctSpellingLabel.text = card.spanish
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let card: VocabularyAssociationSpellingCard
  private let document: UIDocument
  private let parseableDocument: CardDocumentProperties
  private let stylesheet: Stylesheet

  override var introductoryUtterances: [AVSpeechUtterance]? {
    return [
      AVSpeechUtterance(string: "Por favor, deltrea:"),
      AVSpeechUtterance(string: card.spanish),
    ]
  }

  override func becomeFirstResponder() -> Bool {
    return spellCheckField.field.becomeFirstResponder()
  }

  private lazy var contextLabel: UILabel = {
    let contextLabel = UILabel(frame: .zero)
    let attributedString = NSAttributedString(
      string: "Deltrea esta palabra...",
      attributes: [
        .font: stylesheet.typographyScheme.overline,
        .kern: 2.0,
        .foregroundColor: UIColor(white: 0, alpha: 0.6),
      ])
    contextLabel.attributedText = attributedString
    return contextLabel
  }()

  private lazy var imageView: UIImageView = {
    let imageView = UIImageView()
    if let image = card.image(document: document, parseableDocument: parseableDocument) {
      imageView.image = image
      imageView.contentMode = .scaleAspectFit
    }
    return imageView
  }()

  private lazy var spellCheckField: TextFieldAndController = {
    let spellCheckField = TextFieldAndController(placeholder: "Spell", stylesheet: stylesheet)
    spellCheckField.field.autocorrectionType = .no
    spellCheckField.field.autocapitalizationType = .none
    spellCheckField.field.delegate = self
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(textDidChange),
      name: UITextField.textDidChangeNotification,
      object: spellCheckField.field
    )
    return spellCheckField
  }()

  private lazy var correctSpellingLabel: UILabel = {
    let correctSpellingLabel = UILabel(frame: .zero)
    correctSpellingLabel.font = stylesheet.typographyScheme.subtitle1
    return correctSpellingLabel
  }()

  private lazy var sayAgainButton: MDCButton = {
    let button = MDCButton(frame: .zero)
    MDCTextButtonThemer.applyScheme(stylesheet.buttonScheme, to: button)
    button.setTitle("Repeat", for: .normal)
    button.addTarget(self, action: #selector(didTapRepeat), for: .touchUpInside)
    button.setContentHuggingPriority(.required, for: .horizontal)
    return button
  }()

  private lazy var doneButton: MDCButton = {
    let button = MDCButton(frame: .zero)
    MDCContainedButtonThemer.applyScheme(stylesheet.buttonScheme, to: button)
    button.setTitle("Done", for: .normal)
    button.addTarget(self, action: #selector(didTapDone), for: .touchUpInside)
    button.setContentHuggingPriority(.required, for: .horizontal)
    return button
  }()

  private lazy var nextButton: MDCButton = {
    let button = MDCButton(frame: .zero)
    MDCContainedButtonThemer.applyScheme(stylesheet.buttonScheme, to: button)
    button.setTitle("Next", for: .normal)
    button.addTarget(self, action: #selector(didTapNext), for: .touchUpInside)
    button.setContentHuggingPriority(.required, for: .horizontal)
    return button
  }()

  private lazy var controlStack: UIStackView = {
    let controlStack = UIStackView(
      arrangedSubviews: [contextLabel, spellCheckField.field, imageView, correctSpellingLabel, buttonStack]
    )
    controlStack.axis = .vertical
    controlStack.alignment = .leading
    controlStack.spacing = 8
    return controlStack
  }()

  private lazy var buttonStack: UIStackView = {
    let buttonStack = UIStackView(arrangedSubviews: [doneButton, nextButton, sayAgainButton])
    buttonStack.axis = .horizontal
    buttonStack.spacing = 8
    return buttonStack
  }()

  private func checkAnswer(spelling: String) {
    spellCheckField.field.resignFirstResponder()
    spellCheckField.field.isEnabled = false
    let spelling = spelling.trimmingCharacters(in: CharacterSet.whitespaces)
    let correct = spelling.localizedCaseInsensitiveCompare(card.spanish) == .orderedSame
    if correct {
      delegate?.cardView(self, didRequestSpeech: AVSpeechUtterance(string: "correcto"), language: "es-MX")
      delegate?.cardView(self, didAnswerCorrectly: true)
    } else {
      delegate?.cardView(self, didRequestSpeech: AVSpeechUtterance(string: "Eso no está bien. Por favor, estudia la ortografía correcta."), language: "es-MX")
      showAnswer()
    }
  }

  private func configureUI() {
    doneButton.isEnabled = !spellCheckField.field.text.isEmpty
  }

  private func showAnswer() {
    controlStack.setArrangedSubviews([contextLabel, imageView, correctSpellingLabel, buttonStack], animated: true)
    buttonStack.setArrangedSubviews([nextButton, sayAgainButton], animated: true)
  }

  @objc private func textDidChange() {
    configureUI()
  }

  @objc private func didTapDone() {
    checkAnswer(spelling: spellCheckField.field.text ?? "")
  }

  @objc private func didTapNext() {
    delegate?.cardView(self, didAnswerCorrectly: false)
  }

  @objc private func didTapRepeat() {
    delegate?.cardView(self, didRequestSpeech: AVSpeechUtterance(string: card.spanish), language: "es-MX")
  }
}

extension VocabularyAssociationSpellingCardView: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    checkAnswer(spelling: textField.text ?? "")
    return true
  }
}
