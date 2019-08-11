// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
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
    notebook: NoteArchiveDocument
  ) {
    self.notebook = notebook
    super.init(nibName: nil, bundle: nil)
    self.navigationItem.title = "Interactive Notebook"
    self.navigationItem.rightBarButtonItem = studyButton
    notebook.addObserver(self)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let notebook: NoteArchiveDocument
  private var dataSource: DocumentDiffableDataSource?
  private var currentSpotlightQuery: CSSearchQuery?

  private lazy var newDocumentButton: UIBarButtonItem = {
    let icon = UIImage(systemName: "plus.circle")
    let button = UIBarButtonItem(image: icon, style: .plain, target: self, action: #selector(didTapNewDocument))
    button.accessibilityIdentifier = "new-document"
    return button
  }()

  private lazy var studyButton: UIBarButtonItem = {
    let icon = UIImage(systemName: "rectangle.stack")
    let button = UIBarButtonItem(
      image: icon,
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
    tableView.backgroundColor = UIColor.systemBackground
    tableView.accessibilityIdentifier = "document-list"
    tableView.estimatedRowHeight = 72
    tableView.delegate = self
    tableView.separatorStyle = .none
    return tableView
  }()

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    let dataSource = DocumentDiffableDataSource(
      tableView: tableView,
      notebook: notebook
    )
    self.dataSource = dataSource
    view.addSubview(tableView)
    tableView.snp.makeConstraints { make in
      make.top.bottom.left.right.equalToSuperview()
    }
    studySession = notebook.studySession()
    dataSource.performUpdates(animated: false)

    let resultsViewController = DocumentSearchResultsViewController()
    resultsViewController.delegate = self
    let searchController = UISearchController(searchResultsController: resultsViewController)
    searchController.searchResultsUpdater = self
    searchController.searchBar.delegate = self
    searchController.showsSearchResultsController = true
    navigationItem.searchController = searchController

    navigationItem.rightBarButtonItems = [newDocumentButton, studyButton]
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    dataSource?.startObservingNotebook()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    dataSource?.stopObservingNotebook()
  }

  @objc private func didTapNewDocument() {
    var initialText = "# "
    let initialOffset = initialText.count
    initialText += "\n"
    if let hashtag = self.dataSource?.filteredHashtag {
      initialText += hashtag
      initialText += "\n"
    }
    let viewController = TextEditViewController(
      parsingRules: notebook.parsingRules
    )
    viewController.markdown = initialText
    viewController.selectedRange = NSRange(location: initialOffset, length: 0)
    viewController.autoFirstResponder = true
    viewController.delegate = notebook
    showTextEditViewController(viewController)
  }

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

  @objc private func startStudySession() {
    guard let studySession = studySession else { return }
    presentStudySessionViewController(for: studySession)
  }

  private func updateStudySession() {
    let filter: (String, PageProperties) -> Bool = (dataSource?.filteredHashtag == nil)
      ? { _, _ in true }
      : { _, properties in properties.hashtags.contains(self.dataSource!.filteredHashtag!) }
    studySession = notebook.studySession(filter: filter)
  }

  public func presentStudySessionViewController(for studySession: StudySession) {
    let studyVC = StudyViewController(
      studySession: studySession.limiting(to: 20),
      documentCache: ReadOnlyDocumentCache(delegate: self),
      delegate: self
    )
    studyVC.maximumCardWidth = 440
    studyVC.title = navigationItem.title
    present(
      UINavigationController(rootViewController: studyVC),
      animated: true,
      completion: nil
    )
  }
}

// MARK: - Private

private extension DocumentListViewController {
  func showPage(with pageIdentifier: String) {
    let markdown: String
    do {
      markdown = try notebook.currentTextContents(for: pageIdentifier)
    } catch {
      DDLogError("Unexpected error loading page: \(error)")
      return
    }
    let textEditViewController = TextEditViewController(
      parsingRules: notebook.parsingRules
    )
    textEditViewController.pageIdentifier = pageIdentifier
    textEditViewController.markdown = markdown
    textEditViewController.delegate = notebook
    showTextEditViewController(textEditViewController)
  }

  func showTextEditViewController(_ textEditViewController: TextEditViewController) {
    if let splitViewController = splitViewController {
      splitViewController.showDetailViewController(
        UINavigationController(rootViewController: textEditViewController),
        sender: self
      )
    } else if let navigationController = navigationController {
      navigationController.pushViewController(textEditViewController, animated: true)
    }
  }
}

// MARK: - Search

/// Everything needed for search.
/// This is a bunch of little protocols and it's clearer to declare conformance in a single extension.
extension DocumentListViewController: UISearchResultsUpdating, DocumentSearchResultsViewControllerDelegate, UISearchBarDelegate {
  func documentSearchResultsDidSelectHashtag(_ hashtag: String) {
    dataSource?.filteredHashtag = hashtag
    navigationItem.searchController?.searchBar.text = hashtag
    navigationItem.searchController?.dismiss(animated: true, completion: nil)
  }

  func documentSearchResultsDidSelectPageIdentifier(_ pageIdentifier: String) {
    showPage(with: pageIdentifier)
  }

  func documentSearchResultsPageProperties(for pageIdentifier: String) -> PageProperties? {
    notebook.pageProperties[pageIdentifier]
  }

  func updateSearchResults(for searchController: UISearchController) {
    guard let resultsViewController = searchController.searchResultsController as? DocumentSearchResultsViewController else {
      assertionFailure()
      return
    }
    let pattern = searchController.searchBar.text ?? ""
    resultsViewController.hashtags = notebook.hashtags
      .filter { $0.fuzzyMatch(pattern: pattern) }
    let queryString = """
    contentDescription == "*\(pattern)*"dc
    """
    let query = CSSearchQuery(queryString: queryString, attributes: nil)
    var allIdentifiers: [String] = []
    query.foundItemsHandler = { items in
      allIdentifiers.append(contentsOf: items.map { $0.uniqueIdentifier })
    }
    query.completionHandler = { _ in
      DDLogInfo("Found identifiers: \(allIdentifiers)")
      DispatchQueue.main.async {
        resultsViewController.pageIdentifiers = allIdentifiers
      }
    }
    query.start()
    currentSpotlightQuery = query
  }

  func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
    dataSource?.filteredHashtag = nil
  }

  func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
    if searchBar.text.isEmpty, dataSource?.filteredHashtag != nil {
      // Allow single-click clear of the filtered hashtag
      dataSource?.filteredHashtag = nil
      return false
    }
    return true
  }
}

extension DocumentListViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let viewProperties = dataSource?.itemIdentifier(for: indexPath) else { return }
    let markdown: String
    do {
      markdown = try notebook.currentTextContents(for: viewProperties.pageKey)
    } catch {
      DDLogError("Unexpected error loading page: \(error)")
      return
    }
    let textEditViewController = TextEditViewController(
      parsingRules: notebook.parsingRules
    )
    textEditViewController.pageIdentifier = viewProperties.pageKey
    textEditViewController.markdown = markdown
    textEditViewController.delegate = notebook
    showTextEditViewController(textEditViewController)
  }

  func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    var actions = [UIContextualAction]()
    if let properties = dataSource?.itemIdentifier(for: indexPath) {
      let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { _, _, completion in
        try? self.notebook.deletePage(pageIdentifier: properties.pageKey)
        completion(true)
      }
      deleteAction.image = UIImage(systemName: "trash")
      actions.append(deleteAction)
      if properties.cardCount > 0 {
        let studyAction = UIContextualAction(style: .normal, title: "Study") { _, _, completion in
          let studySession = self.notebook.studySession(
            filter: { name, _ in name == properties.pageKey }
          )
          self.presentStudySessionViewController(for: studySession)
          completion(true)
        }
        studyAction.image = UIImage(systemName: "rectangle.stack")
        studyAction.backgroundColor = UIColor.systemBlue
        actions.append(studyAction)
      }
    }
    return UISwipeActionsConfiguration(actions: actions)
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
