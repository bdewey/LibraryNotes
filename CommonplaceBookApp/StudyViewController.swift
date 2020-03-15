// Copyright © 2017-present Brian's Brain. All rights reserved.

import AVFoundation
import CocoaLumberjack
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
    view.backgroundColor = .clear
    return view
  }()

  /// Holds the description of what the swipe action is doing.
  /// `currentDynamicItem` adjusts its alpha based on how far the swipe is proceeding
  private lazy var swipeDescriptionLabel: UILabel = {
    let label = UILabel(frame: .zero)
    label.font = UIFont.preferredFont(forTextStyle: .headline)
    label.textColor = .label
    return label
  }()

  /// The current text we are showing in the swipe description.
  /// Memoized here to minimize layout calculations while panning.
  private var swipeDescriptionText: String? {
    didSet {
      if oldValue != swipeDescriptionText {
        swipeDescriptionLabel.text = swipeDescriptionText
        swipeDescriptionLabel.sizeToFit()
      }
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
      currentDynamicItem = currentCardView.map { ColorTranslatingDynamicItem(view: $0, colorWashView: colorWashView, swipeDescriptionLabel: swipeDescriptionLabel, centerX: view.center.x) }
      UIView.animate(withDuration: 0.2, animations: {
        self.colorWashView.backgroundColor = self.colorWashView.backgroundColor?.withAlphaComponent(0)
        self.currentCardView?.alpha = 1
      }) { _ in
        if let current = self.currentCardView {
          current.becomeFirstResponder()
          current.accessibilityIdentifier = "current-card"
          // TODO: Refactor so I don't have to force unwrap
          let snapBehavior = UISnapBehavior(item: self.currentDynamicItem!, snapTo: self.view.center)
          self.animator.addBehavior(snapBehavior)
          self.cardSnapBehavior = snapBehavior
        }
      }
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

  public override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(colorWashView)
    view.addSubview(swipeDescriptionLabel)
    view.addSubview(doneImageView)
    view.addSubview(progressView)
    colorWashView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    doneImageView.snp.makeConstraints { make in
      make.right.top.equalTo(view.safeAreaLayoutGuide).inset(16)
    }
    progressView.snp.makeConstraints { make in
      make.left.equalTo(view.safeAreaLayoutGuide).inset(16)
      make.centerY.equalTo(doneImageView.snp.centerY)
      make.right.equalTo(doneImageView.snp.left).offset(-8)
    }
    swipeDescriptionLabel.snp.makeConstraints { make in
      make.centerX.equalToSuperview()
      make.top.equalTo(doneImageView.snp.bottom).offset(16)
    }
    studySession.studySessionStartDate = Date()
    view.backgroundColor = .grailGroupedBackground
    configureUI(animated: false, completion: nil)
    // Assumes we're presented in a navigation controller
    navigationController?.presentationController?.delegate = self
  }

  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    currentDynamicItem?.centerX = view.center.x
  }

  @objc private func didPan(sender: UIPanGestureRecognizer) {
    guard let currentCard = currentDynamicItem, let snap = cardSnapBehavior else { return }
    let translation = sender.translation(in: currentCard.view)
    switch sender.state {
    case .began:
      cardSnapBehavior.map { animator.removeBehavior($0) }
    case .changed:
      currentCard.center = view.center + translation
      if translation.x > 0 {
        swipeDescriptionLabel.text = "I got it right"
      } else {
        swipeDescriptionLabel.text = "Need to review"
      }
    case .ended:
      var correct: Bool?
      if translation.x > 100.0 {
        snap.snapPoint = CGPoint(x: view.center.x + view.frame.width, y: view.center.y)
        correct = true
      } else if translation.x < -100.0 {
        snap.snapPoint = CGPoint(x: view.center.x - view.frame.width, y: view.center.y)
        correct = false
      } else {
        snap.snapPoint = view.center
      }
      cardSnapBehavior.map { animator.addBehavior($0) }
      if let correct = correct {
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
          attributionMarkdown: sessionChallengeIdentifier.noteTitle,
          parsingRules: notebook.parsingRules
        )
      )
      challengeView.delegate = self
      challengeView.backgroundColor = .grailSecondaryGroupedBackground
      view.addSubview(challengeView)
      challengeView.snp.makeConstraints { make in
        make.left.right.equalTo(self.view.readableContentGuide)
        make.centerY.equalToSuperview()
      }
      challengeView.layer.cornerRadius = 8
      completion(challengeView)
    } catch {
      DDLogError("Unexpected error generating challenge view: \(error)")
      completion(nil)
    }
  }
}

extension StudyViewController: UIAdaptivePresentationControllerDelegate {
  public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    DDLogInfo("Dismissing study view controller")
    if !UIApplication.isSimulator {
      studySession.studySessionEndDate = Date()
      delegate?.studyViewController(self, didFinishSession: studySession)
    }
  }
}

/// Changes the color wash of `colorWashView` as the position of `view` changes.
private final class ColorTranslatingDynamicItem: NSObject, UIDynamicItem {
  init(view: UIView, colorWashView: UIView, swipeDescriptionLabel: UILabel, centerX: CGFloat) {
    self.view = view
    self.colorWashView = colorWashView
    self.swipeDescriptionLabel = swipeDescriptionLabel
    self.centerX = centerX
  }

  let view: UIView
  private let colorWashView: UIView
  private let swipeDescriptionLabel: UILabel

  var centerX: CGFloat {
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
    let deltaX = center.x - centerX
    let colorWash = deltaX < 0 ? UIColor.systemRed : UIColor.systemGreen
    let alpha = min(abs(deltaX) / 100.0, 1.0)
    swipeDescriptionLabel.alpha = alpha
    let intensity = alpha * 0.4
    colorWashView.backgroundColor = colorWash.withAlphaComponent(intensity)
  }
}

extension StudyViewController: ChallengeViewDelegate {
  public func challengeViewDidRevealAnswer(_ challengeView: ChallengeView) {
    attachPanGestureRecognizer()
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
