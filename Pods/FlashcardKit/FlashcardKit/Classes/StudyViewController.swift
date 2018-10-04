// Copyright © 2018 Brian's Brain. All rights reserved.

import AVFoundation
import CommonplaceBook
import MaterialComponents
import TextBundleKit
import UIKit

protocol StudyViewControllerDelegate: class {
  func studyViewController(_ studyViewController: StudyViewController, didFinishSession: StudySession)
  func studyViewControllerDidCancel(_ studyViewController: StudyViewController)
}

/// Presents a stack of cards for studying.
final class StudyViewController: UIViewController {

  /// The current study session
  private var studySession: StudySession

  private weak var delegate: StudyViewControllerDelegate?

  /// The view displaying the current card.
  /// - note: Changing this value will animate away the old card view and animate in the new.
  private var currentCardView: CardView? {
    didSet {
      currentCardView?.alpha = 0
      UIView.animate(withDuration: 0.2, animations: {
        self.currentCardView?.alpha = 1
        oldValue?.alpha = 0
      }) { (_) in
        oldValue?.removeFromSuperview()
        if let utterances = self.currentCardView?.introductoryUtterances {
          for utterance in utterances {
            PersonalitySpeechSynthesizer.spanish.speak(utterance)
          }
        }
        self.currentCardView?.becomeFirstResponder()
      }
    }
  }

  /// Designated initializer.
  init(studySession: StudySession, delegate: StudyViewControllerDelegate) {
    self.studySession = studySession
    self.delegate = delegate
    super.init(nibName: nil, bundle: nil)
    addChild(appBar.headerViewController)
    self.tabBarItem.title = "STUDY"
    self.title = "¡Habla Español!"
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let appBar: MDCAppBar = {
    let appBar = MDCAppBar()
    MDCAppBarColorThemer.applySemanticColorScheme(Stylesheet.hablaEspanol.colorScheme, to: appBar)
    MDCAppBarTypographyThemer.applyTypographyScheme(Stylesheet.hablaEspanol.typographyScheme, to: appBar)
    return appBar
  }()

  override var childForStatusBarStyle: UIViewController? {
    return appBar.headerViewController
  }

  private var cardsRemainingLabel: UILabel!

  override func viewDidLoad() {
    super.viewDidLoad()
    studySession.studySessionStartDate = Date()
    cardsRemainingLabel = UILabel(frame: .zero)
    view.addSubview(cardsRemainingLabel)
    cardsRemainingLabel.bottomAnchor.constraint(lessThanOrEqualToSystemSpacingBelow: view.safeAreaLayoutGuide.bottomAnchor, multiplier: -1).isActive = true
    cardsRemainingLabel.leadingAnchor.constraint(greaterThanOrEqualToSystemSpacingAfter: view.safeAreaLayoutGuide.leadingAnchor, multiplier: 1).isActive = true
    cardsRemainingLabel.trailingAnchor.constraint(lessThanOrEqualToSystemSpacingAfter: view.safeAreaLayoutGuide.trailingAnchor, multiplier: -1).isActive = true
    cardsRemainingLabel.textAlignment = .center
    cardsRemainingLabel.translatesAutoresizingMaskIntoConstraints = false
    // TODO: this should probably be "caption" -- prototype inside Sketch
    cardsRemainingLabel.font = Stylesheet.hablaEspanol.typographyScheme.body2
    appBar.addSubviewsToParent()
    view.backgroundColor = Stylesheet.hablaEspanol.colorScheme.darkSurfaceColor
    configureUI()
    appBar.navigationBar.trailingBarButtonItem = UIBarButtonItem(title: "DONE", style: .plain, target: self, action: #selector(didTapDone))

    // TODO: Get rid of the option to cancel once I have multi-document support
    appBar.navigationBar.leadingBarButtonItem = UIBarButtonItem(title: "Discard", style: .plain, target: self, action: #selector(didTapCancel))
  }

  private func configureUI() {
    guard isViewLoaded else { return }
    currentCardView = makeCardView(for: studySession.currentCard)
    cardsRemainingLabel.text = "Cards remaining: \(studySession.remainingCards)"
  }

  @objc private func didTapDone() {
    studySession.studySessionEndDate = Date()
    delegate?.studyViewController(self, didFinishSession: studySession)
  }

  @objc private func didTapCancel() {
    let alertController = MDCAlertController(title: "Discard study session?", message: "Are you sure you want to discard your study session? If you do this, the app will not remember what questions you answered correctly.")
    let cancel = MDCAlertAction(title: "Cancel") { (_) in
      // Nothing
    }
    let discard = MDCAlertAction(title: "Discard") { (_) in
      self.studySession.studySessionEndDate = Date()
      self.delegate?.studyViewControllerDidCancel(self)
    }
    alertController.addAction(discard)
    alertController.addAction(cancel)
    MDCAlertColorThemer.applySemanticColorScheme(Stylesheet.hablaEspanol.colorScheme, to: alertController)
    MDCAlertTypographyThemer.applyTypographyScheme(Stylesheet.hablaEspanol.typographyScheme, to: alertController)
    present(alertController, animated: true, completion: nil)
  }

  /// Creates a card view for a card.
  private func makeCardView(for card: Card?) -> CardView? {
    guard let card = card else { return nil }
    let cardView = card.cardView(with: Stylesheet.hablaEspanol)
    cardView.delegate = self
    view.addSubview(cardView)
    cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
    cardView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1, constant: -32).isActive = true
    cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    cardView.translatesAutoresizingMaskIntoConstraints = false
    return cardView
  }
}

extension StudyViewController: CardViewDelegate {
  func cardView(_ cardView: CardView, didAnswerCorrectly: Bool) {
    studySession.recordAnswer(correct: didAnswerCorrectly)
    configureUI()
    if studySession.remainingCards == 0 {
      studySession.studySessionEndDate = Date()
      delegate?.studyViewController(self, didFinishSession: studySession)
    }
  }

  func cardView(_ cardView: CardView, didRequestSpeech utterance: AVSpeechUtterance) {
    PersonalitySpeechSynthesizer.spanish.speak(utterance)
  }
}
