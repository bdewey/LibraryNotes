// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import CoreServices
import MaterialComponents
import MiniMarkdown
import SnapKit
import UIKit

private let reuseIdentifier = "HACKY_document"

extension NSComparisonPredicate {
  fileprivate convenience init(conformingToUTI uti: String) {
    self.init(
      leftExpression: NSExpression(forKeyPath: "kMDItemContentTypeTree"),
      rightExpression: NSExpression(forConstantValue: uti),
      modifier: .any,
      type: .like,
      options: []
    )
  }
}

/// Implements a filterable list of documents in an interactive notebook.
final class DocumentListViewController: UIViewController, StylesheetContaining {
  /// Designated initializer.
  ///
  /// - parameter stylesheet: Controls the styling of UI elements.
  init(
    notebook: NoteArchiveDocument,
    stylesheet: Stylesheet
  ) {
    self.notebook = notebook
    self.stylesheet = stylesheet
    super.init(nibName: nil, bundle: nil)
    self.navigationItem.title = "Interactive Notebook"
    self.navigationItem.leftBarButtonItem = hashtagMenuButton
    self.navigationItem.rightBarButtonItem = studyButton
    notebook.addObserver(self)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let notebook: NoteArchiveDocument
  public let stylesheet: Stylesheet
  private var dataSource: DocumentDiffableDataSource!

  private lazy var hashtagMenuButton: UIBarButtonItem = {
    UIBarButtonItem(
      image: UIImage(named: "round_menu_black_24pt")?.withRenderingMode(.alwaysTemplate),
      style: .plain,
      target: self,
      action: #selector(didTapHashtagMenu)
    )
  }()

  private lazy var newDocumentButton: MDCButton = {
    let icon = UIImage(named: "baseline_add_black_24pt")?.withRenderingMode(.alwaysTemplate)
    let button = MDCFloatingButton(frame: .zero)
    button.setImage(icon, for: .normal)
    button.accessibilityIdentifier = "new-document"
    MDCFloatingActionButtonThemer.applyScheme(stylesheet.buttonScheme, to: button)
    button.addTarget(self, action: #selector(didTapNewDocument), for: .touchUpInside)
    return button
  }()

  private lazy var studyButton: UIBarButtonItem = {
    let button = UIBarButtonItem(
      title: "Study",
      style: .plain,
      target: self,
      action: #selector(startStudySession)
    )
    button.accessibilityIdentifier = "study-button"
    return button
  }()

  private lazy var layout: UICollectionViewFlowLayout = {
    let layout = UICollectionViewFlowLayout()
    layout.scrollDirection = .vertical
    layout.minimumInteritemSpacing = 0
    layout.minimumLineSpacing = 0
    return layout
  }()

  private lazy var documentCollectionView: UICollectionView = {
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: self.layout)
    collectionView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    collectionView.backgroundColor = stylesheet.colors.surfaceColor
    collectionView.accessibilityIdentifier = "document-list"
    collectionView.delegate = self
    return collectionView
  }()

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    self.dataSource = DocumentDiffableDataSource(
      collectionView: documentCollectionView,
      notebook: notebook,
      stylesheet: stylesheet
    )
    view.addSubview(documentCollectionView)
    view.addSubview(newDocumentButton)
    documentCollectionView.snp.makeConstraints { make in
      make.top.bottom.left.right.equalToSuperview()
    }
    newDocumentButton.snp.makeConstraints { make in
      make.trailing.equalToSuperview().offset(-16)
      make.bottom.equalToSuperview().offset(-16)
      make.width.equalTo(56)
      make.height.equalTo(56)
    }
    studySession = notebook.studySession()
    dataSource.performUpdates(animated: false)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    layout.itemSize = CGSize(width: documentCollectionView.bounds.width, height: 72)
    dataSource.startObservingNotebook()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    dataSource.stopObservingNotebook()
  }

  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    layout.itemSize = CGSize(width: size.width, height: 72)
  }

  @objc private func didTapNewDocument() {
    var initialText = "# "
    let initialOffset = initialText.count
    initialText += "\n"
    if let hashtag = self.dataSource.filteredHashtag {
      initialText += hashtag
      initialText += "\n"
    }
    let viewController = TextEditViewController(
      parsingRules: notebook.parsingRules,
      stylesheet: stylesheet
    )
    viewController.markdown = initialText
    viewController.selectedRange = NSRange(location: initialOffset, length: 0)
    viewController.autoFirstResponder = true
    viewController.delegate = notebook
    navigationController?.pushViewController(viewController, animated: true)
  }

  private var hamburgerPresentationController: CoverPartiallyPresentationController?

  /// Stuff we can study based on the current selected documents.
  private var studySession: StudySession? {
    didSet {
      if let studySession = studySession {
        studyButton.isEnabled = !studySession.isEmpty
      } else {
        studyButton.isEnabled = false
      }
    }
  }

  @objc private func didTapHashtagMenu() {
    let hashtagViewController = HashtagViewController(
      index: notebook,
      stylesheet: stylesheet
    )
    hamburgerPresentationController = CoverPartiallyPresentationController(
      presentedViewController: hashtagViewController,
      presenting: self,
      coverDirection: .left
    )
    hashtagViewController.transitioningDelegate = hamburgerPresentationController
    hashtagViewController.modalPresentationStyle = .custom
    hashtagViewController.delegate = self
    present(hashtagViewController, animated: true, completion: nil)
  }

  @objc private func startStudySession() {
    guard let studySession = studySession else { return }
    presentStudySessionViewController(for: studySession)
  }

  private func updateStudySession() {
    let filter: (String, PageProperties) -> Bool = (dataSource.filteredHashtag == nil)
      ? { _, _ in true }
      : { _, properties in properties.hashtags.contains(self.dataSource.filteredHashtag!) }
    studySession = notebook.studySession(filter: filter)
  }

  public func presentStudySessionViewController(for studySession: StudySession) {
    let studyVC = StudyViewController(
      studySession: studySession.limiting(to: 20),
      documentCache: ReadOnlyDocumentCache(delegate: self),
      stylesheet: stylesheet,
      delegate: self
    )
    studyVC.modalTransitionStyle = .crossDissolve
    studyVC.maximumCardWidth = 440
    studyVC.title = navigationItem.title
    studyVC.modalPresentationStyle = .fullScreen
    present(studyVC, animated: true, completion: nil)
  }
}

extension DocumentListViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    guard let viewProperties = dataSource.itemIdentifier(for: indexPath) else { return }
    do {
      let textEditViewController = TextEditViewController(
        parsingRules: notebook.parsingRules,
        stylesheet: stylesheet
      )
      textEditViewController.pageIdentifier = viewProperties.pageKey
      textEditViewController.markdown = try notebook.currentTextContents(for: viewProperties.pageKey)
      textEditViewController.delegate = notebook
      navigationController?
        .pushViewController(textEditViewController, animated: true)
    } catch {
      DDLogError("Unexpected error loading page: \(error)")
    }
  }
}

extension DocumentListViewController: HashtagViewControllerDelegate {
  func hashtagViewControllerDidClearHashtag(_ viewController: HashtagViewController) {
    dataSource.filteredHashtag = nil
    title = "Interactive Notebook"
    updateStudySession()
    dismiss(animated: true, completion: nil)
  }

  func hashtagViewController(_ viewController: HashtagViewController, didTap hashtag: String) {
    print("Tapped " + hashtag)
    dataSource.filteredHashtag = hashtag
    title = hashtag
    updateStudySession()
    dismiss(animated: true, completion: nil)
  }

  func hashtagViewControllerDidCancel(_ viewController: HashtagViewController) {
    dismiss(animated: true, completion: nil)
  }
}

extension DocumentListViewController: ReadOnlyDocumentCacheDelegate {
  func documentCache(_ cache: ReadOnlyDocumentCache, documentFor name: String) -> UIDocument? {
    return notebook
  }
}

extension DocumentListViewController: StudyViewControllerDelegate {
  func studyViewController(
    _ studyViewController: StudyViewController,
    didFinishSession session: StudySession
  ) {
    notebook.updateStudySessionResults(session)
    updateStudySession()
    dismiss(animated: true, completion: nil)
  }

  func studyViewControllerDidCancel(_ studyViewController: StudyViewController) {
    dismiss(animated: true, completion: nil)
  }
}

extension DocumentListViewController: NoteArchiveDocumentObserver {
  func noteArchiveDocument(
    _ document: NoteArchiveDocument,
    didUpdatePageProperties properties: [String: PageProperties]
  ) {
    updateStudySession()
  }
}
