// Copyright © 2017-present Brian's Brain. All rights reserved.

import AVFoundation
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
    documentCache: DocumentCache,
    delegate: StudyViewControllerDelegate
  ) {
    self.studySession = studySession
    self.documentCache = documentCache
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

  private lazy var progressView: UIProgressView = {
    UIProgressView(progressViewStyle: .default)
  }()

  private lazy var doneImageView: UIImageView = {
    let check = UIImage(systemName: "checkmark.seal")
    let view = UIImageView(image: check)
    view.tintColor = .systemGray2
    return view
  }()

  public override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(doneImageView)
    view.addSubview(progressView)
    doneImageView.snp.makeConstraints { make in
      make.right.top.equalTo(view.safeAreaLayoutGuide).inset(16)
    }
    progressView.snp.makeConstraints { make in
      make.left.equalTo(view.safeAreaLayoutGuide).inset(16)
      make.centerY.equalTo(doneImageView.snp.centerY)
      make.right.equalTo(doneImageView.snp.left).offset(-8)
    }
    studySession.studySessionStartDate = Date()
    view.backgroundColor = UIColor.systemGroupedBackground
    configureUI(animated: false, completion: nil)
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(didTapDone))
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
      UIView.animate(withDuration: 0.2, animations: progressUpdates) { (_) in
        completion?()
      }
    } else {
      progressUpdates()
      completion?()
    }
  }

  @objc private func didTapDone() {
    studySession.studySessionEndDate = Date()
    delegate?.studyViewController(self, didFinishSession: studySession)
  }

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
      cardView.snp.makeConstraints { make in
        make.left.right.equalTo(self.view.readableContentGuide)
        make.centerY.equalToSuperview()
      }
      cardView.layer.cornerRadius = 8
      completion(cardView)
    }
  }
}

extension StudyViewController: ChallengeViewDelegate {
  public func challengeView(_ cardView: ChallengeView, didRespondCorrectly: Bool) {
    studySession.recordAnswer(correct: didRespondCorrectly)
    configureUI(animated: true) {
      if self.studySession.remainingCards == 0 {
        self.studySession.studySessionEndDate = Date()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
          self.delegate?.studyViewController(self, didFinishSession: self.studySession)
        }
      }
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
