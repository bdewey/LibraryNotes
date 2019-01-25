// Copyright © 2018-present Brian's Brain. All rights reserved.

import AVFoundation
import CommonplaceBook
import MaterialComponents
import MiniMarkdown
import SnapKit
import TextBundleKit
import UIKit

/// A generic card with a "front" and a "back" side.
///
/// The view initially shows the card front with no buttons. When you tap the card, it will
/// show the card back and two buttons: "Got it" and "study more."
///
// TODO: What happened to "pronounce"??
public final class TwoSidedCardView: CardView {
  public override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }

  private func commonInit() {
    addSubview(columnStack)
    columnStack.snp.makeConstraints { make in
      make.edges.equalToSuperview().inset(16)
    }
    addTarget(self, action: #selector(revealAnswer), for: .touchUpInside)
    setAnswerVisible(false, animated: false)
  }

  /// Stylesheet for styling buttons.
  public var stylesheet: Stylesheet? {
    didSet {
      guard let stylesheet = stylesheet else { return }
      MDCContainedButtonThemer.applyScheme(stylesheet.buttonScheme, to: gotItButton)
      MDCTextButtonThemer.applyScheme(stylesheet.buttonScheme, to: studyMoreButton)
      MDCTextButtonThemer.applyScheme(stylesheet.buttonScheme, to: prounounceSpanishButton)
    }
  }

  /// A string displayed at the top of the card, both front and back, that gives context
  /// about what to do with the card.
  public var context: NSAttributedString? {
    get { return contextLabel.attributedText }
    set { contextLabel.attributedText = newValue }
  }

  /// The contents of the card front.
  public var front: NSAttributedString? {
    get { return frontLabel.attributedText }
    set { frontLabel.attributedText = newValue?.withTypographySubstitutions }
  }

  /// The contents of the card back.
  public var back: NSAttributedString? {
    get { return backLabel.attributedText }
    set { backLabel.attributedText = newValue?.withTypographySubstitutions }
  }

  /// Something to say upon showing the card back.
  public var utterance: AVSpeechUtterance?

  /// The language of `utterance`
  // TODO: Get rid of this and just carry the language in `utterance`
  public var language: String?

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
    button.setTitle("Got it", for: .normal)
    button.addTarget(self, action: #selector(didTapGotIt), for: .touchUpInside)
    return button
  }()

  private lazy var studyMoreButton: MDCButton = {
    let button = MDCButton(frame: .zero)
    button.setTitle("Study More", for: .normal)
    button.addTarget(self, action: #selector(didTapStudyMore), for: .touchUpInside)
    return button
  }()

  // TODO: Whoa, I don't actually use this?
  private lazy var prounounceSpanishButton: MDCButton = {
    let button = MDCButton(frame: .zero)
    button.setTitle("Say it", for: .normal)
    button.addTarget(self, action: #selector(didTapPronounce), for: .touchUpInside)
    return button
  }()

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
      UIView.animate(withDuration: 0.2, animations: animations, completion: { _ in
        self.didTapPronounce()
      })
    } else {
      animations()
    }
  }

  @objc private func revealAnswer() {
    setAnswerVisible(true, animated: true)
  }

  @objc private func didTapGotIt() {
    delegate?.cardView(self, didAnswerCorrectly: true)
  }

  @objc private func didTapStudyMore() {
    delegate?.cardView(self, didAnswerCorrectly: false)
  }

  @objc private func didTapPronounce() {
    if let language = language, let utterance = utterance {
      delegate?.cardView(self, didRequestSpeech: utterance, language: language)
    }
  }
}
