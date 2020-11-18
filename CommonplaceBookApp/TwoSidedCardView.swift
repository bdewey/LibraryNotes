// Copyright © 2017-present Brian's Brain. All rights reserved.

import AVFoundation
import SnapKit
import UIKit

private extension CGFloat {
  static let padding: CGFloat = 8
}

/// A generic card with a "front" and a "back" side.
///
/// The view initially shows the card front with no buttons. When you tap the card, it will
/// show the card back and two buttons: "Got it" and "study more."
///
public final class TwoSidedCardView: ChallengeView {
  public override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }

  private func commonInit() {
    [background, contextLabel, frontLabel, backLabel].forEach { addSubview($0) }
    backgroundColor = .clear
    createConstraints()
    addTarget(self, action: #selector(revealAnswer), for: .touchUpInside)
    setAnswerVisible(false, animated: false)
  }

  private var frontLabelConstraints: ConstraintMakerEditable?
  private var backLabelConstraints: ConstraintMakerEditable?

  private func createConstraints() {
    background.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    contextLabel.snp.makeConstraints { make in
      make.top.left.right.equalToSuperview().inset(2.0 * CGFloat.padding)
    }
    frontLabel.snp.makeConstraints { make in
      make.top.equalTo(contextLabel.snp.bottom).offset(1.0 * CGFloat.padding)
      make.left.right.equalToSuperview().inset(2.0 * CGFloat.padding)
      self.frontLabelConstraints = make.bottom.equalToSuperview().inset(2.0 * CGFloat.padding)
    }
    backLabel.snp.makeConstraints { make in
      make.top.equalTo(frontLabel.snp.top)
      make.left.right.equalToSuperview().inset(2.0 * CGFloat.padding)
      self.backLabelConstraints = make.bottom.equalToSuperview().inset(2.0 * CGFloat.padding)
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

  private let background: UIView = {
    let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    view.layer.cornerRadius = 8
    view.isUserInteractionEnabled = false
    view.backgroundColor = .grailSecondaryGroupedBackground
    view.clipsToBounds = true
    return view
  }()

  private let contextLabel: UILabel = {
    let contextLabel = UILabel(frame: .zero)
    contextLabel.numberOfLines = 0
    contextLabel.textAlignment = .left
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

  private func setAnswerVisible(_ answerVisible: Bool, animated: Bool) {
    isAnswerVisible = answerVisible
    let animations = {
      self.frontLabel.alpha = answerVisible ? 0 : 1
      self.backLabel.alpha = answerVisible ? 1 : 0
      if answerVisible {
        self.frontLabelConstraints?.constraint.deactivate()
        self.backLabelConstraints?.constraint.activate()
      } else {
        self.frontLabelConstraints?.constraint.activate()
        self.backLabelConstraints?.constraint.deactivate()
      }
      self.setNeedsLayout()
      if animated { self.layoutIfNeeded() }
    }
    if animated {
      UIView.animate(withDuration: 0.2, animations: animations)
    } else {
      animations()
    }
  }

  @objc private func revealAnswer() {
    setAnswerVisible(true, animated: true)
    delegate?.challengeViewDidRevealAnswer(self)
  }
}
