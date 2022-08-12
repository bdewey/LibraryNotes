// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import AVFoundation
import Logging
import SnapKit
import UIKit

// swiftlint:disable file_length

public protocol StudyViewControllerDelegate: AnyObject {
  func studyViewController(_ studyViewController: StudyViewController, didFinishSession: StudySession)
}

extension NSUserActivity {
  static let studySessionActivityType = "org.brians-brain.LibraryNotes.StudySession"
  static let databaseFileKey = "org.brians-brain.LibraryNotes.DatabaseURL"
  static let focusStructureKey = "org.brians-brain.LibraryNotes.FocusStructure"

  static func studySession(databaseURL: URL, focusStructure: NotebookStructureViewController.StructureIdentifier) -> NSUserActivity {
    let activity = NSUserActivity(activityType: studySessionActivityType)
    activity.requiredUserInfoKeys = [databaseFileKey, focusStructureKey]
    activity.addUserInfoEntries(from: [
      databaseFileKey: databaseURL.absoluteString,
      focusStructureKey: focusStructure.rawValue,
    ])
    return activity
  }
}

/// Presents a stack of cards for studying.
// TODO: Refactor
// swiftlint:disable:next type_body_length
public final class StudyViewController: UIViewController {
  /// Designated initializer.
  ///
  /// - parameter studySession: The stack of cards to present for studying.
  /// - parameter documentCache: A properly configured cache for retreiving documents given a
  ///                            file name.
  /// - parameter delegate: TSIA.
  public init(
    studySession: StudySession,
    database: NoteDatabase,
    delegate: StudyViewControllerDelegate
  ) {
    self.studySession = studySession
    self.database = database
    self.delegate = delegate
    super.init(nibName: nil, bundle: nil)
  }

  @objc private func finishStudySession() {
    studySession.studySessionEndDate = Date()
    delegate?.studyViewController(self, didFinishSession: studySession)
    dismiss(animated: true, completion: nil)
  }

  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// The current study session
  private var studySession: StudySession

  /// The document we are studying from
  let database: NoteDatabase

  private weak var delegate: StudyViewControllerDelegate?

  /// Just holds the "correct" versus "incorrect" color whilst swiping
  private lazy var colorWashView: UIView = {
    let view = UIView(frame: .zero)
    return view
  }()

  private var shouldChangeColor = false

  private lazy var blurView: UIVisualEffectView = {
    let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    return view
  }()

  private lazy var gotItRightButton: UIButton = {
    let button = UIButton(type: .roundedRect, primaryAction: UIAction(handler: { [weak self] _ in
      Logger.shared.info("Got it right!")
      self?.markCurrentCardCorrect(true, currentTranslation: .zero)
    }))
    button.setTitle("Got it right", for: .normal)
    button.setTitleColor(.systemGreen, for: .normal)
    button.setTitleColor(.systemGray, for: .disabled)
    button.isEnabled = false
    return button
  }()

  @objc private func handleGotItRightCommand() {
    guard gotItRightButton.isEnabled else { return }
    markCurrentCardCorrect(true, currentTranslation: .zero)
  }

  private lazy var needsReviewButton: UIButton = {
    let button = UIButton(type: .roundedRect, primaryAction: UIAction(handler: { [weak self] _ in
      Logger.shared.info("Needs review")
      self?.markCurrentCardCorrect(false, currentTranslation: .zero)
    }))
    button.setTitle("Needs review", for: .normal)
    button.setTitleColor(.systemRed, for: .normal)
    button.setTitleColor(.systemGray, for: .disabled)
    button.isEnabled = false
    return button
  }()

  @objc private func handleNeedsReviewCommand() {
    guard needsReviewButton.isEnabled else { return }
    markCurrentCardCorrect(false, currentTranslation: .zero)
  }

  private lazy var closeButton: UIButton = {
    let button = UIButton(type: .roundedRect, primaryAction: UIAction(handler: { [weak self] _ in
      Logger.shared.info("Needs review")
      self?.finishStudySession()
    }))
    button.setImage(UIImage(systemName: "xmark"), for: .normal)
    button.setTitleColor(.systemGray, for: .normal)
    return button
  }()

  private struct Swipe: Identifiable {
    var id: CGVector.Direction { classifier.direction }
    let classifier: PanTranslationClassifier
    let message: String
    let color: UIColor
    let requiresVisibleAnswer: Bool
    let correct: Bool?
    let shouldDismiss: Bool
    let snapPoint: (UIView) -> CGPoint

    func makeLabel() -> UILabel {
      let label = UILabel(frame: .zero)
      label.font = UIFont.preferredFont(forTextStyle: .headline)
      label.textColor = .label
      label.text = message
      label.sizeToFit()
      return label
    }
  }

  private let swipeClassifiers: [Swipe] = [
    Swipe(
      classifier: SimpleSwipeClassifier(direction: .down),
      message: "Dismiss",
      color: .systemGray,
      requiresVisibleAnswer: false,
      correct: nil,
      shouldDismiss: true,
      snapPoint: { CGPoint(x: $0.center.x, y: $0.center.y + $0.frame.height) }
    ),
    Swipe(
      classifier: SimpleSwipeClassifier(direction: .right),
      message: "I got it right",
      color: .systemGreen,
      requiresVisibleAnswer: true,
      correct: true,
      shouldDismiss: false,
      snapPoint: { CGPoint(x: $0.center.x + $0.frame.width, y: $0.center.y) }
    ),
    Swipe(
      classifier: SimpleSwipeClassifier(direction: .left),
      message: "Need to review",
      color: .systemRed,
      requiresVisibleAnswer: true,
      correct: false,
      shouldDismiss: false,
      snapPoint: { CGPoint(x: $0.center.x - $0.frame.width, y: $0.center.y) }
    ),
  ]

  /// Given a pan gesture in the view and whether or not the answer is currently visible, returns the best Swipe
  /// corresponding to that gesture and a mesure of how strongly we match.
  private func bestSwipe(for vector: CGVector, answerVisible: Bool) -> (Swipe, CGFloat)? {
    swipeClassifiers
      .compactMap { swipe -> (Swipe, CGFloat)? in
        if swipe.requiresVisibleAnswer, !answerVisible {
          return nil
        }
        return (swipe, swipe.classifier.matchStrength(vector: vector))
      }
      .reduce(nil) { (priorResult, tuple) -> (Swipe, CGFloat)? in
        guard let result = priorResult else {
          return tuple
        }
        if tuple.1 > result.1 {
          return tuple
        } else {
          return result
        }
      }
  }

  /// Sets the alpha for all swipe messages to 0.
  private func hideAllSwipeMessages() {
    gotItRightButton.isEnabled = false
    needsReviewButton.isEnabled = false
  }

  /// The view displaying the current card.
  /// - note: Changing this value will animate away the old card view and animate in the new.
  private var currentCardView: PromptView? {
    didSet {
      currentCardView?.alpha = 0
      oldValue?.accessibilityIdentifier = nil
      oldValue?.alpha = 0
      oldValue?.removeFromSuperview()
      attachPanGestureRecognizer()
      UIView.animate(
        withDuration: 0.2,
        animations: {
          self.colorWashView.backgroundColor = self.colorWashView.backgroundColor?.withAlphaComponent(0)
          self.hideAllSwipeMessages()
          self.currentCardView?.alpha = 1
        },
        completion: { finished in
          Logger.shared.info("Animation finished = \(finished)")
          if let current = self.currentCardView {
            current.becomeFirstResponder()
            current.accessibilityIdentifier = "current-card"
          }
        }
      )
    }
  }

  private func attachPanGestureRecognizer() {
    guard let current = currentCardView else { return }
    let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(StudyViewController.didPan(sender:)))
    current.addGestureRecognizer(panGestureRecognizer)
  }

  private lazy var progressView: UIProgressView = {
    UIProgressView(progressViewStyle: .default)
  }()

  private lazy var doneImageView: UIImageView = {
    let check = UIImage(systemName: "checkmark.seal")
    let view = UIImageView(image: check)
    view.tintColor = .systemGray2
    return view
  }()

  private lazy var animator = UIDynamicAnimator(referenceView: view)

  override public func viewDidLoad() {
    super.viewDidLoad()
    [colorWashView, blurView, doneImageView, progressView, needsReviewButton, gotItRightButton, closeButton].forEach(view.addSubview)
    colorWashView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    closeButton.snp.makeConstraints { make in
      make.top.right.equalTo(view.safeAreaLayoutGuide).inset(16)
    }
    blurView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    doneImageView.snp.makeConstraints { make in
      make.right.bottom.equalTo(view.safeAreaLayoutGuide).inset(16)
    }
    progressView.snp.makeConstraints { make in
      make.left.equalTo(view.safeAreaLayoutGuide).inset(16)
      make.centerY.equalTo(doneImageView.snp.centerY)
      make.right.equalTo(doneImageView.snp.left).offset(-8)
    }
    needsReviewButton.snp.makeConstraints { make in
      make.lastBaseline.equalTo(progressView.snp.top).offset(-16)
      make.left.equalToSuperview().offset(16)
    }
    gotItRightButton.snp.makeConstraints { make in
      make.lastBaseline.equalTo(progressView.snp.top).offset(-16)
      make.right.equalToSuperview().offset(-16)
    }
    studySession.studySessionStartDate = Date()
    configureUI(animated: false, completion: nil)
    // Assumes we're presented in a navigation controller
    navigationController?.presentationController?.delegate = self

    let gotItRightCommand = UIKeyCommand(action: #selector(handleGotItRightCommand), input: UIKeyCommand.inputRightArrow, modifierFlags: .command)
    let needsReviewCommand = UIKeyCommand(action: #selector(handleNeedsReviewCommand), input: UIKeyCommand.inputLeftArrow, modifierFlags: .command)
    let closeSessionCommand = UIKeyCommand(action: #selector(finishStudySession), input: UIKeyCommand.inputEscape)
    let revealAnswerCommand = UIKeyCommand(action: #selector(PromptViewActions.revealAnswer), input: UIKeyCommand.inputUpArrow, modifierFlags: .command)

    for command in [gotItRightCommand, needsReviewCommand, closeSessionCommand, revealAnswerCommand] {
      addKeyCommand(command)
    }
  }

  /// How to transform the image while swiping.
  /// The idea comes from https://github.com/cwRichardKim/RKSwipeCards/blob/master/RKSwipeCards/DraggableView.m
  struct RotationParameters {
    /// Affects the amount of rotation based on lateral movement. Higher number == slower rotation
    var rotationDenominator: CGFloat

    /// Maximum amount of rotation (radians)
    var rotationAngle: CGFloat

    /// Affects the amount of scaling based on lateral movement. Higher number == slower scaling
    var scaleDenominator: CGFloat

    /// The smallest we will scale the image.
    var scaleMin: CGFloat

    static let `default` = RotationParameters(
      rotationDenominator: 320,
      rotationAngle: .pi / 8,
      scaleDenominator: 4,
      scaleMin: 0.93
    )

    func transform(for xTranslation: CGFloat) -> CGAffineTransform {
      let strength = min(xTranslation / rotationDenominator, 1)
      let angle = rotationAngle * strength
      let scale = max(1 - abs(strength) / scaleDenominator, scaleMin)
      return CGAffineTransform(rotationAngle: angle).scaledBy(x: scale, y: scale)
    }
  }

  @objc private func didPan(sender: UIPanGestureRecognizer) {
    guard
      let currentCard = currentCardView
    else {
      return
    }
    let translation = sender.translation(in: currentCard)
    switch sender.state {
    case .began:
      break
    case .changed:
      currentCard.transform = RotationParameters.default.transform(for: translation.x)
      currentCard.center = view.center + translation
      if let (swipe, strength) = bestSwipe(for: CGVector(destination: translation), answerVisible: currentCard.isAnswerVisible), strength > 0 {
        colorWashView.backgroundColor = swipe.color
        colorWashView.alpha = 0.4 * strength
        if let correct = swipe.correct {
          gotItRightButton.alpha = correct ? 1.0 : 1.0 - strength
          needsReviewButton.alpha = !correct ? 1.0 : 1.0 - strength
        } else {
          gotItRightButton.alpha = 1.0 - strength
          needsReviewButton.alpha = 1.0 - strength
        }
      } else {
        colorWashView.backgroundColor = .clear
        gotItRightButton.alpha = 1
        needsReviewButton.alpha = 1
      }
    case .ended:
      var correct: Bool?
      var shouldDismiss = false
      if let (swipe, strength) = bestSwipe(for: CGVector(destination: translation), answerVisible: currentCard.isAnswerVisible), strength >= 1 {
        correct = swipe.correct
        shouldDismiss = swipe.shouldDismiss
      }
      if shouldDismiss {
        let finalCenter = CGPoint(x: view.center.x + 2 * translation.x, y: view.bounds.height + currentCard.frame.height)
        let finalRotationStrength = min((finalCenter.x - view.center.x) / 320, 1)
        let finalRotationAngle = (CGFloat.pi / 8) * finalRotationStrength
        UIView.animate(withDuration: 0.3) {
          currentCard.center = finalCenter
          currentCard.transform = CGAffineTransform(rotationAngle: finalRotationAngle)
        } completion: { _ in
          self.finishStudySession()
        }
      } else if let correct = correct {
        markCurrentCardCorrect(correct, currentTranslation: translation)
      } else {
        // Need to return
        sender.isEnabled = false
        UIView.animate(withDuration: 0.7, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.7, options: .curveEaseInOut) {
          currentCard.center = self.view.center
          currentCard.transform = .identity
          self.gotItRightButton.alpha = 1
          self.needsReviewButton.alpha = 1
        } completion: { _ in
          sender.isEnabled = true
        }
      }
    case .cancelled, .failed:
      // Need to return
      break
    default:
      break
    }
  }

  private func markCurrentCardCorrect(_ correct: Bool, currentTranslation: CGPoint) {
    guard
      let currentCard = currentCardView
    else {
      return
    }
    let horizontalTranslation = correct ? view.bounds.width : -1 * view.bounds.width
    let finalCenter = CGPoint(x: view.center.x + horizontalTranslation, y: view.center.y + 2 * currentTranslation.y)
    UIView.animate(withDuration: 0.3) {
      currentCard.center = finalCenter
      currentCard.transform = RotationParameters.default.transform(for: horizontalTranslation)
      self.gotItRightButton.alpha = 1
      self.needsReviewButton.alpha = 1
    } completion: { _ in
      self.userDidRespond(correct: correct)
    }
  }

  // TODO: Move out of here
  private func userDidRespond(correct: Bool) {
    studySession.recordAnswer(correct: correct)
    configureUI(animated: true) {
      if self.studySession.remainingPrompts == 0 {
        self.studySession.studySessionEndDate = Date()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
          self.delegate?.studyViewController(self, didFinishSession: self.studySession)
          self.dismiss(animated: true, completion: nil)
        }
      }
    }
  }

  private func configureUI(animated: Bool, completion: (() -> Void)?) {
    guard isViewLoaded else { return }
    makePromptView(for: studySession.currentPrompt) { cardView in
      self.currentCardView = cardView
    }
    let progressUpdates = { [progressView, studySession, doneImageView] in
      progressView.setProgress(Float(studySession.count - studySession.remainingPrompts) / Float(studySession.count), animated: animated)
      if studySession.remainingPrompts == 0 {
        progressView.tintColor = .systemGreen
        doneImageView.image = UIImage(systemName: "checkmark.seal.fill")
        doneImageView.tintColor = .systemGreen
      }
    }
    if animated {
      UIView.animate(withDuration: 0.2, animations: progressUpdates) { _ in
        completion?()
      }
    } else {
      progressUpdates()
      completion?()
    }
  }

  /// Creates a card view for a card.
  private func makePromptView(
    for sessionPromptIdentifier: StudySession.SessionPromptIdentifier?,
    completion: @escaping (PromptView?) -> Void
  ) {
    guard let sessionPromptIdentifier = sessionPromptIdentifier else {
      completion(nil)
      return
    }
    do {
      let prompt = try database.prompt(
        promptIdentifier: sessionPromptIdentifier.promptIdentifier
      )
      let promptView = prompt.promptView(
        database: database,
        properties: CardDocumentProperties(
          documentName: sessionPromptIdentifier.noteIdentifier,
          attributionMarkdown: sessionPromptIdentifier.noteTitle
        )
      )
      promptView.delegate = self
      view.addSubview(promptView)
      promptView.becomeFirstResponder()
      completion(promptView)
    } catch {
      Logger.shared.error("Unexpected error generating prompt view: \(error)")
      completion(nil)
    }
  }

  public override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    guard let currentCardView = currentCardView, currentCardView.transform == .identity else {
      return
    }
    var layoutFrame = view.safeAreaLayoutGuide.layoutFrame
    layoutFrame.origin.y = closeButton.frame.maxY + 10
    layoutFrame.size.height = (needsReviewButton.frame.minY - layoutFrame.origin.y) - 10
    let readableWidth = view.readableContentGuide.layoutFrame.width
    let desiredSize = currentCardView.sizeThatFits(CGSize(width: readableWidth, height: .greatestFiniteMagnitude))
    currentCardView.frame = CGRect(origin: .zero, size: CGSize(width: readableWidth, height: min(desiredSize.height, layoutFrame.height)))
    currentCardView.center = CGPoint(x: layoutFrame.midX, y: layoutFrame.midY)
  }
}

extension StudyViewController: UIAdaptivePresentationControllerDelegate {
  public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    Logger.shared.info("Dismissing study view controller")
    if !UIApplication.isSimulator {
      studySession.studySessionEndDate = Date()
      delegate?.studyViewController(self, didFinishSession: studySession)
    }
  }
}

extension StudyViewController: PromptViewDelegate {
  public func promptViewDidRevealAnswer(_ promptView: PromptView) {
    gotItRightButton.isEnabled = true
    needsReviewButton.isEnabled = true
  }
}

extension CGPoint {
  static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
  }

  static func += (lhs: inout CGPoint, rhs: CGPoint) {
    lhs = CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
  }
}

extension CGFloat {
  func plusOrMinus(_ delta: CGFloat) -> Range<CGFloat> {
    return (self - delta) ..< (self + delta)
  }
}
