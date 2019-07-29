// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import CoreServices
import MaterialComponents
import MiniMarkdown
import SnapKit
import UIKit

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

  private lazy var tableView: UITableView = {
    let tableView = UITableView(frame: .zero, style: .plain)
    tableView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    tableView.backgroundColor = stylesheet.colors.surfaceColor
    tableView.accessibilityIdentifier = "document-list"
    tableView.rowHeight = 72
    tableView.delegate = self
    tableView.separatorStyle = .none
    return tableView
  }()

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    dataSource = DocumentDiffableDataSource(
      tableView: tableView,
      notebook: notebook,
      stylesheet: stylesheet
    )
    view.addSubview(tableView)
    view.addSubview(newDocumentButton)
    tableView.snp.makeConstraints { make in
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
    dataSource.startObservingNotebook()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    dataSource.stopObservingNotebook()
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

extension DocumentListViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
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

  func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    var actions = [UIContextualAction]()
    if let properties = dataSource.itemIdentifier(for: indexPath) {
      let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { _, _, completion in
        try? self.notebook.deletePage(pageIdentifier: properties.pageKey)
        completion(true)
      }
      deleteAction.image = UIImage(named: "round_delete_forever_black_24pt")
      actions.append(deleteAction)
      if properties.cardCount > 0 {
        let studyAction = UIContextualAction(style: .normal, title: "Study") { _, _, completion in
          let studySession = self.notebook.studySession(
            filter: { name, _ in name == properties.pageKey }
          )
          self.presentStudySessionViewController(for: studySession)
          completion(true)
        }
        studyAction.image = UIImage(named: "round_school_black_24pt")
        studyAction.backgroundColor = stylesheet.colors.secondaryColor
        actions.append(studyAction)
      }
    }
    return UISwipeActionsConfiguration(actions: actions)
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
