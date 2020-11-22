// Copyright © 2017-present Brian's Brain. All rights reserved.

import AVFoundation
import CocoaLumberjack
import Logging
import SnapKit
import UIKit

public protocol StudyViewControllerDelegate: class {
  func studyViewController(_ studyViewController: StudyViewController, didFinishSession: StudySession)
  func studyViewControllerDidCancel(_ studyViewController: StudyViewController)
}

/// Presents a stack of cards for studying.
public final class StudyViewController: UIViewController {
  /// Designated initializer.
  ///
  /// - parameter studySession: The stack of cards to present for studying.
  /// - parameter documentCache: A properly configured cache for retreiving documents given a
  ///                            file name.
  /// - parameter delegate: TSIA.
  public init(
    studySession: StudySession,
    notebook: NoteStorage,
    delegate: StudyViewControllerDelegate
  ) {
    self.studySession = studySession
    self.notebook = notebook
    self.delegate = delegate
    super.init(nibName: nil, bundle: nil)
  }

  private func finishStudySession() {
    studySession.studySessionEndDate = Date()
    delegate?.studyViewController(self, didFinishSession: studySession)
    dismiss(animated: true, completion: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// The current study session
  private var studySession: StudySession

  /// The document we are studying from
  private let notebook: NoteStorage

  private weak var delegate: StudyViewControllerDelegate?

  /// UIKitDynamics behavior used to put the card in ts desired resting position
  private var cardSnapBehavior: UISnapBehavior?

  /// Just holds the "correct" versus "incorrect" color whilst swiping
  private lazy var colorWashView: UIView = {
    let view = UIView(frame: .zero)
    return view
  }()

  private lazy var blurView: UIVisualEffectView = {
    let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    return view
  }()

  private struct Swipe: Identifiable {
    var id: CGVector.Direction { classifier.direction }
    let classifier: LinearPanTranslationClassifier
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
      classifier: LinearPanTranslationClassifier(direction: .down),
      message: "Dismiss",
      color: .clear,
      requiresVisibleAnswer: false,
      correct: nil,
      shouldDismiss: true,
      snapPoint: { CGPoint(x: $0.center.x, y: $0.center.y + $0.frame.height) }
    ),
    Swipe(
      classifier: LinearPanTranslationClassifier(direction: .right),
      message: "I got it right",
      color: .systemGreen,
      requiresVisibleAnswer: true,
      correct: true,
      shouldDismiss: false,
      snapPoint: { CGPoint(x: $0.center.x + $0.frame.width, y: $0.center.y) }
    ),
    Swipe(
      classifier: LinearPanTranslationClassifier(direction: .left),
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

  /// Mapping of possible swipe gestures with labels that tell the person we are going to match that swipe.
  private var statusMessageLabels: [Swipe.ID: UILabel] = [:]

  /// Sets the alpha of a particular swipe label to `alpha` and all other labels to zero.
  private func setAlpha(_ alpha: CGFloat, for swipe: Swipe) {
    for (swipeID, label) in statusMessageLabels {
      label.alpha = (swipeID == swipe.id) ? alpha : 0
    }
  }

  /// Sets the alpha for all swipe messages to 0.
  private func hideAllSwipeMessages() {
    for (_, label) in statusMessageLabels {
      label.alpha = 0
    }
  }

  /// Encapsulates the current swipe state. As this item moves, either because of panning or
  /// because of animations, it also changes the color/alpha of `colorWashView` and the alpha of `swipeDescriptionLabel`
  private var currentDynamicItem: ColorTranslatingDynamicItem?

  /// The view displaying the current card.
  /// - note: Changing this value will animate away the old card view and animate in the new.
  private var currentCardView: ChallengeView? {
    didSet {
      currentCardView?.alpha = 0
      oldValue?.accessibilityIdentifier = nil
      oldValue?.alpha = 0
      oldValue?.removeFromSuperview()
      cardSnapBehavior.map { animator.removeBehavior($0) }
      currentDynamicItem = currentCardView.map { ColorTranslatingDynamicItem(view: $0, origin: view.center, viewController: self) }
      attachPanGestureRecognizer()
      UIView.animate(withDuration: 0.2, animations: {
        self.colorWashView.backgroundColor = self.colorWashView.backgroundColor?.withAlphaComponent(0)
        self.hideAllSwipeMessages()
        self.currentCardView?.alpha = 1
      }) { finished in
        Logger.shared.info("Animation finished = \(finished)")
        if let current = self.currentCardView {
          current.becomeFirstResponder()
          current.accessibilityIdentifier = "current-card"
          self.attachSnapBehavior()
        }
      }
    }
  }

  private func attachSnapBehavior() {
    // TODO: Refactor so I don't have to force unwrap
    guard let dynamicItem = currentDynamicItem, dynamicItem.bounds.size != .zero else {
      return
    }
    let snapBehavior = UISnapBehavior(item: dynamicItem, snapTo: view.center)
    animator.addBehavior(snapBehavior)
    cardSnapBehavior = snapBehavior
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

  public override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(colorWashView)
    view.addSubview(blurView)
    makeStatusLabels()
    view.addSubview(doneImageView)
    view.addSubview(progressView)
    colorWashView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
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
    for (_, label) in statusMessageLabels {
      label.snp.makeConstraints { make in
        make.centerX.equalToSuperview()
        make.top.equalTo(doneImageView).offset(-16)
      }
    }
    studySession.studySessionStartDate = Date()
    configureUI(animated: false, completion: nil)
    // Assumes we're presented in a navigation controller
    navigationController?.presentationController?.delegate = self
  }

  private func makeStatusLabels() {
    for swipe in swipeClassifiers {
      let label = swipe.makeLabel()
      statusMessageLabels[swipe.id] = label
      view.addSubview(label)
    }
  }

  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    attachSnapBehavior()
  }

  @objc private func didPan(sender: UIPanGestureRecognizer) {
    guard
      let currentCard = currentDynamicItem,
      let isAnswerVisible = currentCardView?.isAnswerVisible,
      let snap = cardSnapBehavior
    else {
      return
    }
    let translation = sender.translation(in: currentCard.view)
    switch sender.state {
    case .began:
      cardSnapBehavior.map { animator.removeBehavior($0) }
    case .changed:
      currentCard.center = view.center + translation
    case .ended:
      var correct: Bool?
      var shouldDismiss = false
      if let (swipe, strength) = bestSwipe(for: CGVector(destination: translation), answerVisible: isAnswerVisible), strength >= 1 {
        correct = swipe.correct
        shouldDismiss = swipe.shouldDismiss
        snap.snapPoint = swipe.snapPoint(view)
      }
      cardSnapBehavior.map { animator.addBehavior($0) }
      if shouldDismiss {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
          self.finishStudySession()
        }
      } else if let correct = correct {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
          // TODO: Get rid of force unwrap
          self.userDidRespond(correct: correct)
        }
      }
    case .cancelled, .failed:
      cardSnapBehavior.map { animator.addBehavior($0) }
    default:
      break
    }
  }

  // TODO: Move out of here
  private func userDidRespond(correct: Bool) {
    studySession.recordAnswer(correct: correct)
    configureUI(animated: true) {
      if self.studySession.remainingCards == 0 {
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
    makeCardView(for: studySession.currentCard) { cardView in
      self.currentCardView = cardView
    }
    let progressUpdates = { [progressView, studySession, doneImageView] in
      progressView.setProgress(Float(studySession.count - studySession.remainingCards) / Float(studySession.count), animated: animated)
      if studySession.remainingCards == 0 {
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
  private func makeCardView(
    for sessionChallengeIdentifier: StudySession.SessionChallengeIdentifier?,
    completion: @escaping (ChallengeView?) -> Void
  ) {
    guard let sessionChallengeIdentifier = sessionChallengeIdentifier else {
      completion(nil)
      return
    }
    do {
      let challenge = try notebook.challenge(
        noteIdentifier: sessionChallengeIdentifier.noteIdentifier,
        challengeIdentifier: sessionChallengeIdentifier.challengeIdentifier
      )
      let challengeView = challenge.challengeView(
        document: notebook,
        properties: CardDocumentProperties(
          documentName: sessionChallengeIdentifier.noteIdentifier,
          attributionMarkdown: sessionChallengeIdentifier.noteTitle
        )
      )
      challengeView.delegate = self
      view.addSubview(challengeView)
      challengeView.snp.makeConstraints { make in
        make.left.right.equalTo(self.view.readableContentGuide)
        make.centerY.equalToSuperview()
      }
      completion(challengeView)
    } catch {
      DDLogError("Unexpected error generating challenge view: \(error)")
      completion(nil)
    }
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

private extension StudyViewController {
  /// Changes the color wash of `colorWashView` as the position of `view` changes.
  final class ColorTranslatingDynamicItem: NSObject, UIDynamicItem {
    init(view: UIView, origin: CGPoint, viewController: StudyViewController) {
      self.view = view
      self.origin = origin
      self.viewController = viewController
    }

    let view: UIView
    weak var viewController: StudyViewController?
    var shouldChangeColor = false

    var origin: CGPoint {
      didSet {
        configureUI()
      }
    }

    var center: CGPoint {
      get { view.center }
      set {
        view.center = newValue
        configureUI()
      }
    }

    var bounds: CGRect {
      get { view.bounds }
      set { view.bounds = newValue }
    }

    var transform: CGAffineTransform {
      get { view.transform }
      set { view.transform = newValue }
    }

    private func configureUI() {
      let vector = CGVector(origin: origin, destination: center)
      if let (swipe, alpha) = viewController?.bestSwipe(for: vector, answerVisible: shouldChangeColor) {
        let intensity = alpha * 0.4
        viewController?.setAlpha(alpha, for: swipe)
        viewController?.colorWashView.backgroundColor = swipe.color.withAlphaComponent(intensity)
      } else {
        viewController?.hideAllSwipeMessages()
        viewController?.colorWashView.backgroundColor = .clear
      }
    }
  }
}

extension StudyViewController: ChallengeViewDelegate {
  public func challengeViewDidRevealAnswer(_ challengeView: ChallengeView) {
    currentDynamicItem?.shouldChangeColor = true
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
