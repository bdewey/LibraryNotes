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
    self.navigationItem.title = "Interactive Notebook"
    self.navigationItem.rightBarButtonItem = studyButton
    self.notebookSubscription = notebook.pagePropertiesDidChange
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.updateStudySession()
      }
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public let notebook: NoteStorage
  public var didTapFilesAction: (() -> Void)?
  private var dataSource: DocumentTableController?
  private var currentSpotlightQuery: CSSearchQuery?
  private var notebookSubscription: AnyCancellable?

  private lazy var documentBrowserButton: UIBarButtonItem = {
    let icon = UIImage(systemName: "folder")
    let button = UIBarButtonItem(image: icon, style: .plain, target: self, action: #selector(didTapFiles))
    button.accessibilityIdentifier = "open-files"
    return button
  }()

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

  private lazy var tableView: UITableView = DocumentTableController.makeTableView()

  internal func showPage(with pageIdentifier: String) {
    let markdown: String
    do {
      markdown = try notebook.currentTextContents(for: pageIdentifier)
    } catch {
      DDLogError("Unexpected error loading page: \(error)")
      return
    }
    let textEditViewController = TextEditViewController(
      notebook: notebook
    )
    textEditViewController.pageIdentifier = pageIdentifier
    textEditViewController.markdown = markdown
    textEditViewController.delegate = notebook
    showDetailViewController(textEditViewController)
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    let dataSource = DocumentTableController(
      tableView: tableView,
      notebook: notebook
    )
    dataSource.delegate = self
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

    navigationItem.leftBarButtonItem = documentBrowserButton
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

  @objc private func didTapFiles() {
    didTapFilesAction?()
  }

  private func makeBlankTextDocument() {
    let viewController = TextEditViewController.makeBlankDocument(
      notebook: notebook,
      currentHashtag: currentHashtag,
      autoFirstResponder: true
    )
    showDetailViewController(viewController)
  }

  private func makeBlankVocabularyPage() {
    let viewController = VocabularyViewController(notebook: notebook)
    viewController.properties.title = "Test Vocabulary"
    splitViewController?.showDetailViewController(
      UINavigationController(rootViewController: viewController),
      sender: nil
    )
  }

  @objc private func didTapNewDocument() {
    let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
    let textAction = UIAlertAction(title: "Text", style: .default) { [weak self] _ in
      self?.makeBlankTextDocument()
    }
    alertController.addAction(textAction)
    let vocabularyAction = UIAlertAction(title: "Vocabulary", style: .default) { [weak self] _ in
      self?.makeBlankVocabularyPage()
    }
    alertController.addAction(vocabularyAction)
    alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    alertController.popoverPresentationController?.barButtonItem = newDocumentButton
    present(alertController, animated: true)
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
    let filter: (String, PageProperties) -> Bool = (currentHashtag == nil)
      ? { _, _ in true }
      : { _, properties in properties.hashtags.contains(self.currentHashtag!) }
    let hashtag = currentHashtag
    notebook.studySession(filter: filter, date: Date()) {
      guard self.currentHashtag == hashtag else { return }
      self.studySession = $0
    }
  }
}

// MARK: - DocumentTableControllerDelegate

extension DocumentListViewController: DocumentTableControllerDelegate {
  func showDetailViewController(_ detailViewController: UIViewController) {
    if let splitViewController = splitViewController {
      splitViewController.showDetailViewController(
        UINavigationController(rootViewController: detailViewController),
        sender: self
      )
    } else if let navigationController = navigationController {
      navigationController.pushViewController(detailViewController, animated: true)
    }
  }

  func presentStudySessionViewController(for studySession: StudySession) {
    let studyVC = StudyViewController(
      studySession: studySession.limiting(to: 20),
      notebook: notebook,
      delegate: self
    )
    studyVC.title = navigationItem.title
    present(
      UINavigationController(rootViewController: studyVC),
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

  func documentTableDidDeleteDocument(with pageIdentifier: String) {
    guard
      let splitViewController = self.splitViewController,
      splitViewController.viewControllers.count > 1,
      let navigationController = splitViewController.viewControllers.last as? UINavigationController,
      let detailViewController = navigationController.viewControllers.first as? TextEditViewController
    else {
      return
    }
    if detailViewController.pageIdentifier == pageIdentifier {
      // We just deleted the current page. Show a blank document.
      showDetailViewController(
        TextEditViewController.makeBlankDocument(
          notebook: notebook,
          currentHashtag: currentHashtag,
          autoFirstResponder: false
        )
      )
    }
  }
}

// MARK: - Private

private extension DocumentListViewController {
  /// If there is currently a hashtag active in the search bar, return it.
  var currentHashtag: String? {
    return navigationItem.searchController?.searchBar.searchTextField.tokens.first?.representedObject as? String
  }
}

// MARK: - Search

/// Everything needed for search.
/// This is a bunch of little protocols and it's clearer to declare conformance in a single extension.
extension DocumentListViewController: UISearchResultsUpdating, UISearchBarDelegate {
  func updateSearchResults(for searchController: UISearchController) {
    guard searchController.isActive else {
      dataSource?.hashtags = []
      dataSource?.filteredPageIdentifiers = nil
      currentSpotlightQuery = nil
      updateStudySession()
      return
    }
    let pattern = searchController.searchBar.text ?? ""
    var queryString = """
    contentDescription == "*\(pattern)*"dc
    """
    if let selectedHashtag = searchController.searchBar.searchTextField.tokens.first?.representedObject as? String {
      queryString.append(" && keywords == \"\(selectedHashtag)\"dc")
      dataSource?.hashtags = []
      dataSource?.filteredHashtag = selectedHashtag
    } else {
      DDLogInfo("No selected hashtag. isActive = \(searchController.isActive)")
      dataSource?.hashtags = notebook.hashtags
        .filter { $0.fuzzyMatch(pattern: pattern) }
      dataSource?.filteredHashtag = nil
    }
    DDLogInfo("Issuing query: \(queryString)")
    currentSpotlightQuery?.cancel()
    let query = CSSearchQuery(queryString: queryString, attributes: nil)
    var allIdentifiers: [String] = []
    query.foundItemsHandler = { items in
      allIdentifiers.append(contentsOf: items.map { $0.uniqueIdentifier })
    }
    query.completionHandler = { _ in
      DDLogInfo("Found identifiers: \(allIdentifiers)")
      DispatchQueue.main.async {
        if searchController.isActive, self.currentSpotlightQuery == query {
          self.dataSource?.filteredPageIdentifiers = Set(allIdentifiers)
        }
      }
    }
    query.start()
    currentSpotlightQuery = query
  }

  func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
    DDLogInfo("searchBarTextDidEndEditing")
    dataSource?.hashtags = []
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
    notebook.updateStudySessionResults(session, on: Date())
    updateStudySession()
  }

  func studyViewControllerDidCancel(_ studyViewController: StudyViewController) {
    dismiss(animated: true, completion: nil)
  }
}
