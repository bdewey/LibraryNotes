// Copyright © 2017-present Brian's Brain. All rights reserved.

import AVFoundation
import MaterialComponents
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
    documentCache: DocumentCache,
    stylesheet: Stylesheet,
    delegate: StudyViewControllerDelegate
  ) {
    self.studySession = studySession
    self.documentCache = documentCache
    self.stylesheet = stylesheet
    self.delegate = delegate
    super.init(nibName: nil, bundle: nil)
    self.tabBarItem.title = "STUDY"
    self.title = "¡Habla Español!"
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// The current study session
  private var studySession: StudySession

  private let documentCache: DocumentCache
  private let stylesheet: Stylesheet

  private weak var delegate: StudyViewControllerDelegate?

  /// The view displaying the current card.
  /// - note: Changing this value will animate away the old card view and animate in the new.
  private var currentCardView: ChallengeView? {
    didSet {
      currentCardView?.alpha = 0
      oldValue?.accessibilityIdentifier = nil
      UIView.animate(withDuration: 0.2, animations: {
        self.currentCardView?.alpha = 1
        oldValue?.alpha = 0
      }) { _ in
        oldValue?.removeFromSuperview()
        if let utterances = self.currentCardView?.introductoryUtterances {
          for utterance in utterances {
            PersonalitySpeechSynthesizer.spanish.speak(utterance)
          }
        }
        self.currentCardView?.becomeFirstResponder()
        self.currentCardView?.accessibilityIdentifier = "current-card"
      }
    }
  }

  private var cardsRemainingLabel: UILabel!

  public override func viewDidLoad() {
    super.viewDidLoad()
    studySession.studySessionStartDate = Date()
    cardsRemainingLabel = UILabel(frame: .zero)
    view.addSubview(cardsRemainingLabel)
    cardsRemainingLabel.bottomAnchor.constraint(
      lessThanOrEqualToSystemSpacingBelow: view.safeAreaLayoutGuide.bottomAnchor,
      multiplier: -1
    ).isActive = true
    cardsRemainingLabel.leadingAnchor.constraint(
      greaterThanOrEqualToSystemSpacingAfter: view.safeAreaLayoutGuide.leadingAnchor,
      multiplier: 1
    ).isActive = true
    cardsRemainingLabel.trailingAnchor.constraint(
      lessThanOrEqualToSystemSpacingAfter: view.safeAreaLayoutGuide.trailingAnchor,
      multiplier: -1
    ).isActive = true
    cardsRemainingLabel.textAlignment = .center
    cardsRemainingLabel.translatesAutoresizingMaskIntoConstraints = false
    // TODO: this should probably be "caption" -- prototype inside Sketch
    cardsRemainingLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
    view.backgroundColor = UIColor.systemGroupedBackground
    configureUI()
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(didTapDone))
    navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(didTapCancel))
  }

  private func configureUI() {
    guard isViewLoaded else { return }
    makeCardView(for: studySession.currentCard) { cardView in
      self.currentCardView = cardView
    }
    cardsRemainingLabel.text = "Cards remaining: \(studySession.remainingCards)"
  }

  @objc private func didTapDone() {
    studySession.studySessionEndDate = Date()
    delegate?.studyViewController(self, didFinishSession: studySession)
  }

  @objc private func didTapCancel() {
    let alertController = UIAlertController(
      title: "Discard study session?",
      message: "Are you sure you want to discard your study session? " +
        "If you do this, the app will not remember what questions you answered correctly.",
      preferredStyle: .alert
    )
    let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in
      // Nothing
    }
    let discard = UIAlertAction(title: "Discard", style: .destructive) { _ in
      self.studySession.studySessionEndDate = Date()
      self.delegate?.studyViewControllerDidCancel(self)
    }
    alertController.addAction(discard)
    alertController.addAction(cancel)
    present(alertController, animated: true, completion: nil)
  }

  public var maximumCardWidth: CGFloat?

  /// Creates a card view for a card.
  private func makeCardView(
    for cardFromDocument: StudySession.AttributedCard?,
    completion: @escaping (ChallengeView?) -> Void
  ) {
    guard let cardFromDocument = cardFromDocument else { completion(nil); return }
    documentCache.document(for: cardFromDocument.properties.documentName) { document in
      guard let document = document else { completion(nil); return }
      let cardView = cardFromDocument.card.challengeView(
        document: document,
        properties: cardFromDocument.properties
      )
      cardView.delegate = self
      self.view.addSubview(cardView)
      cardView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
      let widthConstraint = cardView.widthAnchor.constraint(
        equalTo: self.view.widthAnchor,
        multiplier: 1,
        constant: -32
      )
      widthConstraint.priority = .defaultHigh
      widthConstraint.isActive = true
      if let maximumCardWidth = self.maximumCardWidth {
        let maximumWidthConstraint = cardView
          .widthAnchor
          .constraint(lessThanOrEqualToConstant: maximumCardWidth)
        maximumWidthConstraint.priority = .required
        maximumWidthConstraint.isActive = true
      }
      cardView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
      cardView.translatesAutoresizingMaskIntoConstraints = false
      completion(cardView)
    }
  }
}

extension StudyViewController: ChallengeViewDelegate {
  public func challengeView(_ cardView: ChallengeView, didRespondCorrectly: Bool) {
    studySession.recordAnswer(correct: didRespondCorrectly)
    configureUI()
    if studySession.remainingCards == 0 {
      studySession.studySessionEndDate = Date()
      delegate?.studyViewController(self, didFinishSession: studySession)
    }
  }

  public func challengeView(
    _ cardView: ChallengeView,
    didRequestSpeech utterance: AVSpeechUtterance,
    language: String
  ) {
    PersonalitySpeechSynthesizer.make(with: language).speak(utterance)
  }
}
