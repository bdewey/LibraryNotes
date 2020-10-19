// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import Combine
import CoreServices
import CoreSpotlight
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
final class DocumentListViewController: UIViewController {
  /// Designated initializer.
  ///
  /// - parameter stylesheet: Controls the styling of UI elements.
  init(
    notebook: NoteStorage
  ) {
    self.notebook = notebook
    super.init(nibName: nil, bundle: nil)
    self.navigationItem.title = AppDelegate.appName
    self.notebookSubscription = notebook.notesDidChange
      .receive(on: DispatchQueue.main)
      .sink { [weak self] in
        self?.updateStudySession()
      }
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public let notebook: NoteStorage
  public var didTapFilesAction: (() -> Void)?
  private var dataSource: DocumentTableController?
  private var notebookSubscription: AnyCancellable?
  private var challengeDueDate: Date {
    get {
      return dataSource?.challengeDueDate ?? Date()
    }
    set {
      dataSource?.challengeDueDate = newValue
      updateStudySession()
    }
  }

  private lazy var newDocumentButton: UIBarButtonItem = {
    let button = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(makeBlankTextDocument))
    button.accessibilityIdentifier = "new-document"
    return button
  }()

  private lazy var advanceTimeButton: UIBarButtonItem = {
    let icon = UIImage(systemName: "clock")
    let button = UIBarButtonItem(
      image: icon,
      style: .plain,
      target: self,
      action: #selector(advanceTime)
    )
    button.accessibilityIdentifier = "advance-time-button"
    return button
  }()

  private lazy var tableView: UITableView = DocumentTableController.makeTableView()

  internal func showPage(with noteIdentifier: Note.Identifier) {
    let note: Note
    do {
      note = try notebook.note(noteIdentifier: noteIdentifier)
    } catch {
      DDLogError("Unexpected error loading page: \(error)")
      return
    }
    let textEditViewController = TextEditViewController(
      notebook: notebook
    )
    textEditViewController.noteIdentifier = noteIdentifier
    textEditViewController.markdown = note.text ?? ""
    let savingWrapper = SavingTextEditViewController(textEditViewController, noteIdentifier: noteIdentifier, parsingRules: notebook.parsingRules, noteStorage: notebook)
    savingWrapper.setTitleMarkdown(note.metadata.title)
    showDetailViewController(savingWrapper)
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    let dataSource = DocumentTableController(
      tableView: tableView,
      notebook: notebook,
      delegate: self
    )
    self.dataSource = dataSource
    view.addSubview(tableView)
    tableView.snp.makeConstraints { make in
      make.top.bottom.left.right.equalToSuperview()
    }
    notebook.studySession(filter: nil, date: Date()) { [weak self] in
      self?.studySession = $0
    }
    dataSource.performUpdates(animated: false)

    let searchController = UISearchController(searchResultsController: nil)
    searchController.searchResultsUpdater = self
    searchController.searchBar.delegate = self
    searchController.showsSearchResultsController = true
    searchController.searchBar.searchTextField.clearButtonMode = .whileEditing
    searchController.obscuresBackgroundDuringPresentation = false
    navigationItem.searchController = searchController

    /// Update the challenge due date as time passes, app foregrounds, etc.
    updateChallengeDueDatePipeline = Just(Date())
      .merge(with: makeForegroundDatePublisher(), Timer.publish(every: .hour, on: .main, in: .common).autoconnect())
      .map { Calendar.current.startOfDay(for: $0.addingTimeInterval(.day)) }
      .assign(to: \.challengeDueDate, on: self)
    navigationController?.setToolbarHidden(false, animated: false)
    if AppDelegate.isUITesting {
      navigationItem.rightBarButtonItems?.append(advanceTimeButton)
    }
  }

  private var updateChallengeDueDatePipeline: AnyCancellable?

  private func makeForegroundDatePublisher() -> AnyPublisher<Date, Never> {
    NotificationCenter.default
      .publisher(for: UIApplication.willEnterForegroundNotification)
      .map { _ in Date() }
      .eraseToAnyPublisher()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    dataSource?.startObservingNotebook()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    dataSource?.stopObservingNotebook()
  }

  @objc private func makeBlankTextDocument() {
    let viewController = TextEditViewController.makeBlankDocument(
      notebook: notebook,
      currentHashtag: dataSource?.filteredHashtag,
      autoFirstResponder: true
    )
    showDetailViewController(viewController)
  }

  /// Stuff we can study based on the current selected documents.
  private var studySession: StudySession? {
    didSet {
      updateToolbar()
    }
  }

  @objc private func startStudySession() {
    guard let studySession = studySession else { return }
    presentStudySessionViewController(for: studySession)
  }

  @objc private func advanceTime() {
    challengeDueDate = challengeDueDate.addingTimeInterval(7 * .day)
  }

  private func updateStudySession() {
    let currentHashtag = dataSource?.filteredHashtag
    let filter: (Note.Identifier, Note.Metadata) -> Bool = (currentHashtag == nil)
      ? { _, _ in true }
      : { [currentHashtag] _, properties in properties.hashtags.contains(currentHashtag!) }
    let hashtag = currentHashtag
    notebook.studySession(filter: filter, date: challengeDueDate) {
      guard currentHashtag == hashtag else { return }
      self.studySession = $0
    }
  }

  private func updateToolbar() {
    let countLabel = UILabel(frame: .zero)
    let noteCount = dataSource?.noteCount ?? 0
    countLabel.text = noteCount == 1 ? "1 note" : "\(noteCount) notes"
    countLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
    countLabel.sizeToFit()

    let itemsToReview = studySession?.count ?? 0
    let reviewButton = UIBarButtonItem(title: "Review (\(itemsToReview))", style: .plain, target: self, action: #selector(performReview))
    reviewButton.isEnabled = itemsToReview > 0

    let countItem = UIBarButtonItem(customView: countLabel)
    toolbarItems = [
      reviewButton,
      UIBarButtonItem.flexibleSpace(),
      countItem,
      UIBarButtonItem.flexibleSpace(),
      newDocumentButton,
    ]
  }

  @objc private func performReview() {
    guard let studySession = studySession else { return }
    presentStudySessionViewController(for: studySession)
  }
}

// MARK: - DocumentTableControllerDelegate

extension DocumentListViewController: DocumentTableControllerDelegate {
  func showDetailViewController(_ detailViewController: UIViewController) {
    if let splitViewController = splitViewController {
      let navigationController = UINavigationController(rootViewController: detailViewController)
      navigationController.navigationBar.barTintColor = .grailBackground
      splitViewController.showDetailViewController(
        navigationController,
        sender: self
      )
    } else if let navigationController = navigationController {
      navigationController.pushViewController(detailViewController, animated: true)
    }
  }

  func presentStudySessionViewController(for studySession: StudySession) {
    let studyVC = StudyViewController(
      studySession: studySession.shuffling().ensuringUniqueChallengeTemplates().limiting(to: 20),
      notebook: notebook,
      delegate: self
    )
    studyVC.title = navigationItem.title
    studyVC.modalTransitionStyle = .crossDissolve
    studyVC.modalPresentationStyle = .overFullScreen
    present(
      studyVC,
      animated: true,
      completion: nil
    )
  }

  func documentSearchResultsDidSelectHashtag(_ hashtag: String) {
    guard let searchController = navigationItem.searchController else { return }
    let token = UISearchToken(icon: nil, text: hashtag)
    token.representedObject = hashtag
    searchController.searchBar.searchTextField.tokens = [token]
    searchController.searchBar.searchTextField.text = ""
    searchController.dismiss(animated: true, completion: nil)
  }

  func documentTableDidDeleteDocument(with noteIdentifier: Note.Identifier) {
    guard
      let splitViewController = self.splitViewController,
      splitViewController.viewControllers.count > 1,
      let navigationController = splitViewController.viewControllers.last as? UINavigationController,
      let detailViewController = navigationController.viewControllers.first as? SavingTextEditViewController
    else {
      return
    }
    if detailViewController.noteIdentifier == noteIdentifier {
      // We just deleted the current page. Show a blank document.
      showDetailViewController(
        TextEditViewController.makeBlankDocument(
          notebook: notebook,
          currentHashtag: dataSource?.filteredHashtag,
          autoFirstResponder: false
        )
      )
    }
  }

  func showAlert(_ alertMessage: String) {
    let alert = UIAlertController(title: "Oops", message: alertMessage, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
    present(alert, animated: true, completion: nil)
  }

  func documentTableController(_ documentTableController: DocumentTableController, didUpdateWithNoteCount noteCount: Int) {
    updateToolbar()
  }
}

extension DocumentListViewController: NotebookStructureViewControllerDelegate {
  func notebookStructureViewController(_ viewController: NotebookStructureViewController, didSelect structure: NotebookStructureViewController.StructureIdentifier) {
    let hashtag: String?
    switch structure {
    case .allNotes:
      hashtag = nil
      title = "All Notes"
    case .hashtag(let selectedHashtag):
      hashtag = selectedHashtag
      title = selectedHashtag
    }
    dataSource?.filteredHashtag = hashtag
    updateStudySession()
  }
}

// MARK: - Search

/// Everything needed for search.
/// This is a bunch of little protocols and it's clearer to declare conformance in a single extension.
extension DocumentListViewController: UISearchResultsUpdating, UISearchBarDelegate {
  func updateSearchResults(for searchController: UISearchController) {
    guard searchController.isActive else {
      dataSource?.filteredPageIdentifiers = nil
      updateStudySession()
      return
    }
    let pattern = searchController.searchBar.text ?? ""
    if let selectedHashtag = searchController.searchBar.searchTextField.tokens.first?.representedObject as? String {
      dataSource?.filteredHashtag = selectedHashtag
    } else {
      DDLogInfo("No selected hashtag. isActive = \(searchController.isActive)")
      dataSource?.filteredHashtag = nil
    }
    DDLogInfo("Issuing query: \(pattern)")
    do {
      let allIdentifiers = try notebook.search(for: pattern)
      dataSource?.filteredPageIdentifiers = Set(allIdentifiers)
    } catch {
      DDLogError("Error issuing full text query: \(error)")
    }
  }

  func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
    DDLogInfo("searchBarTextDidEndEditing")
  }

  func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
    dataSource?.filteredPageIdentifiers = nil
  }
}

extension DocumentListViewController: StudyViewControllerDelegate {
  func studyViewController(
    _ studyViewController: StudyViewController,
    didFinishSession session: StudySession
  ) {
    do {
      try notebook.updateStudySessionResults(session, on: challengeDueDate, buryRelatedChallenges: true)
      updateStudySession()
    } catch {
      DDLogError("Unexpected error recording study session results: \(error)")
    }
  }

  func studyViewControllerDidCancel(_ studyViewController: StudyViewController) {
    dismiss(animated: true, completion: nil)
  }
}
