// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import AVFoundation
import UIKit

private extension CGFloat {
  static let padding: CGFloat = 10
}

/// A generic card with a "front" and a "back" side.
///
/// The view initially shows the card front with no buttons. When you tap the card, it will
/// show the card back and two buttons: "Got it" and "study more."
///
public final class TwoSidedCardView: PromptView, PromptViewActions {
  override public init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }

  private func commonInit() {
    [background, contentScrollView, contextLabel, frontLabel, backLabel].forEach { addSubview($0) }
    [contextLabel, frontLabel, backLabel].forEach { contentScrollView.addSubview($0) }
    backgroundColor = .clear
    let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(revealAnswer))
    addGestureRecognizer(tapRecognizer)
    addTarget(self, action: #selector(revealAnswer), for: .touchUpInside)
    setAnswerVisible(false, animated: false)
    let revealAnswerCommand = UIKeyCommand(action: #selector(revealAnswer), input: " ", modifierFlags: .command)
  }

  private struct Layout: Equatable {
    var contextLabelFrame: CGRect
    var frontLabelFrame: CGRect
    var backLabelFrame: CGRect
    var isAnswerVisible: Bool

    var desiredHeight: CGFloat {
      isAnswerVisible ? backLabelFrame.maxY : frontLabelFrame.maxY
    }
  }

  private func computeLayout(layoutArea: CGRect) -> Layout {
    let contextLabelSize = contextLabel.sizeThatFits(layoutArea.size)
    var (contextLabelFrame, remainder) = layoutArea.divided(atDistance: contextLabelSize.height, from: .minYEdge)
    (_, remainder) = remainder.divided(atDistance: .padding, from: .minYEdge)
    let frontLabelSize = frontLabel.sizeThatFits(remainder.size)
    let backLabelSize = backLabel.sizeThatFits(remainder.size)
    let frontLabelFrame: CGRect
    let backLabelFrame: CGRect
    (frontLabelFrame, _) = remainder.divided(atDistance: frontLabelSize.height, from: .minYEdge)
    (backLabelFrame, _) = remainder.divided(atDistance: backLabelSize.height, from: .minYEdge)
    return Layout(
      contextLabelFrame: contextLabelFrame,
      frontLabelFrame: frontLabelFrame,
      backLabelFrame: backLabelFrame,
      isAnswerVisible: isAnswerVisible
    )
  }

  override public func sizeThatFits(_ size: CGSize) -> CGSize {
    let layoutArea = CGRect(origin: .zero, size: size).insetBy(dx: .padding * 2, dy: .padding * 2)
    let layout = computeLayout(layoutArea: layoutArea)
    return CGSize(width: size.width, height: layout.desiredHeight + 2 * .padding)
  }

  private var priorLayout: Layout?

  override public func layoutSubviews() {
    background.frame = bounds
    var layoutArea = bounds
    layoutArea.size.height = .greatestFiniteMagnitude
    layoutArea.size.width -= contentScrollView.contentInset.left + contentScrollView.contentInset.right
    let layout = computeLayout(layoutArea: layoutArea)
    if priorLayout == layout {
      // No change needed
      return
    }
    let childContentSize = CGSize(width: layoutArea.width, height: layout.desiredHeight)
    contentScrollView.contentSize = childContentSize
    contentScrollView.frame.size.width = bounds.size.width
    contentScrollView.frame.size.height = min(bounds.size.height, childContentSize.height + 2 * .padding)
    contentScrollView.center = CGPoint(x: bounds.midX, y: bounds.midY)
    contextLabel.frame = layout.contextLabelFrame
    backLabel.frame = layout.backLabelFrame
    frontLabel.frame = layout.frontLabelFrame
    print("childContentSize: \(childContentSize). Layout: \(layout). Bounds = \(bounds)")
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

  private let contentScrollView: UIScrollView = {
    let scrollView = UIScrollView(frame: .zero)
    scrollView.contentInset = UIEdgeInsets(top: .padding, left: .padding, bottom: .padding, right: .padding)
    return scrollView
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
      self.setNeedsLayout()
      self.superview?.setNeedsLayout()
      if animated {
        self.superview?.layoutIfNeeded()
        self.layoutIfNeeded()
      }
    }
    if animated {
      UIView.animate(withDuration: 0.2, animations: animations)
    } else {
      animations()
    }
  }

  override public var canBecomeFirstResponder: Bool { true }

  @objc public func revealAnswer() {
    setAnswerVisible(true, animated: true)
    delegate?.promptViewDidRevealAnswer(self)
  }
}
