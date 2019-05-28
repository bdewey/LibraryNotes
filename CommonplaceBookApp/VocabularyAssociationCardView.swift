// Copyright © 2018-present Brian's Brain. All rights reserved.

import AVFoundation
import MaterialComponents
import SnapKit
import TextBundleKit
import UIKit

final class VocabularyAssociationCardView: ChallengeView {
  let card: VocabularyAssociationCard
  let document: UIDocument
  let properties: CardDocumentProperties
  let stylesheet: Stylesheet

  init(
    card: VocabularyAssociationCard,
    document: UIDocument,
    properties: CardDocumentProperties,
    stylesheet: Stylesheet
  ) {
    self.card = card
    self.document = document
    self.properties = properties
    self.stylesheet = stylesheet
    super.init(frame: .zero)
    self.addSubview(columnStack)
    columnStack.snp.makeConstraints { make in
      make.edges.equalToSuperview().inset(16)
    }

    self.addTarget(self, action: #selector(revealAnswer), for: .touchUpInside)

    contextLabel.attributedText = card.context(stylesheet: stylesheet)
    frontLabel.attributedText = card.prompt(
      document: document,
      properties: properties,
      stylesheet: stylesheet
    )
    backLabel.attributedText = card.answer(
      document: document,
      properties: properties,
      stylesheet: stylesheet
    )
    setAnswerVisible(false, animated: false)
  }

  private func setAnswerVisible(_ answerVisible: Bool, animated: Bool) {
    let animations = {
      self.backLabel.isHidden = !answerVisible
      self.gotItButton.isHidden = !answerVisible
      self.buttonRow.isHidden = !answerVisible
      self.studyMoreButton.isHidden = !answerVisible
      self.columnStack.isUserInteractionEnabled = answerVisible
      self.setNeedsLayout()
      if animated { self.layoutIfNeeded() }
    }
    if animated {
      UIView.animate(withDuration: 0.2, animations: animations, completion: { _ in
        self.didTapPronounce()
      })
    } else {
      animations()
    }
  }

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
    button.setTitle("Pronounce", for: .normal)
    button.addTarget(self, action: #selector(didTapPronounce), for: .touchUpInside)
    return button
  }()

  private lazy var columnStack: UIStackView = {
    let columnStack = UIStackView(arrangedSubviews: [contextLabel, frontLabel, backLabel, buttonRow])
    columnStack.axis = .vertical
    columnStack.alignment = .leading
    columnStack.spacing = 8
    return columnStack
  }()

  private lazy var buttonRow: UIStackView = {
    let buttonRow = UIStackView(arrangedSubviews: [gotItButton, prounounceSpanishButton, studyMoreButton])
    buttonRow.axis = .horizontal
    buttonRow.spacing = 8
    return buttonRow
  }()

  @objc private func revealAnswer() {
    setAnswerVisible(true, animated: true)
  }

  @objc private func didTapGotIt() {
    delegate?.challengeView(self, didRespondCorrectly: true)
  }

  @objc private func didTapStudyMore() {
    delegate?.challengeView(self, didRespondCorrectly: false)
  }

  @objc private func didTapPronounce() {
    let utterance = AVSpeechUtterance(string: card.pronunciation)
    delegate?.challengeView(self, didRequestSpeech: utterance, language: "es-MX")
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var intrinsicContentSize: CGSize {
    return columnStack.systemLayoutSizeFitting(CGSize(width: bounds.width, height: CGFloat.nan))
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let desiredSize = columnStack.systemLayoutSizeFitting(CGSize(width: bounds.width, height: CGFloat.nan))
    let intrinsicSize = columnStack.intrinsicContentSize
    print("in layout. desired size = \(desiredSize), intrinsic size = \(intrinsicSize)")
  }
}
