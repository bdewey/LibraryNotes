// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Combine
import CoreServices
import CoreSpotlight
import Logging
import SafariServices
import SnapKit
import UIKit

private extension NSComparisonPredicate {
  convenience init(conformingToUTI uti: String) {
    self.init(
      leftExpression: NSExpression(forKeyPath: "kMDItemContentTypeTree"),
      rightExpression: NSExpression(forConstantValue: uti),
      modifier: .any,
      type: .like,
      options: []
    )
  }
}

extension UIResponder {
  func printResponderChain() {
    var responder: UIResponder? = self
    while let currentResponder = responder {
      print(currentResponder)
      responder = currentResponder.next
    }
  }

  func responderChain() -> String {
    var responderStrings = [String]()
    var responder: UIResponder? = self
    while let currentResponder = responder {
      responderStrings.append(String(describing: currentResponder))
      responder = currentResponder.next
    }
    return responderStrings.joined(separator: "\n")
  }
}

protocol DocumentListViewControllerDelegate: AnyObject {
  func documentListViewController(
    _ viewController: DocumentListViewController,
    didRequestShowNote note: Note,
    noteIdentifier: Note.Identifier?
  )

  func documentListViewControllerDidRequestChangeFocus(_ viewController: DocumentListViewController)
}

/// Implements a filterable list of documents in an interactive notebook.
final class DocumentListViewController: UIViewController {
  /// Designated initializer.
  ///
  /// - parameter stylesheet: Controls the styling of UI elements.
  init(
    database: NoteDatabase
  ) {
    self.database = database
    super.init(nibName: nil, bundle: nil)
    // assume we are showing "all notes" initially.
    navigationItem.title = NotebookStructureViewController.StructureIdentifier.allNotes.description
    self.databaseSubscription = database.notesDidChange
      .receive(on: DispatchQueue.main)
      .sink { [weak self] in
        self?.updateStudySession()
      }
  }

  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public let database: NoteDatabase
  public weak var delegate: DocumentListViewControllerDelegate?

  public func setFocus(_ focusedStructure: NotebookStructureViewController.StructureIdentifier) {
    let hashtag: String?
    switch focusedStructure {
    case .allNotes:
      hashtag = nil
      title = "All Notes"
    case .hashtag(let selectedHashtag):
      hashtag = selectedHashtag
      title = selectedHashtag
    }
    dataSource.filteredHashtag = hashtag
    updateStudySession()
  }

  private lazy var dataSource: DocumentTableController = {
    DocumentTableController(
      collectionView: collectionView,
      database: database,
      delegate: self
    )
  }()

  private var databaseSubscription: AnyCancellable?
  private var dueDate: Date {
    get {
      return dataSource.dueDate
    }
    set {
      dataSource.dueDate = newValue
      updateStudySession()
    }
  }

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

  private lazy var collectionView: UICollectionView = {
    var listConfiguration = UICollectionLayoutListConfiguration(appearance: .plain)
    listConfiguration.backgroundColor = .grailBackground
    listConfiguration.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath -> UISwipeActionsConfiguration? in
      guard let self = self else { return nil }
      return self.dataSource.trailingSwipeActionsConfiguration(forRowAt: indexPath)
    }
    let layout = UICollectionViewCompositionalLayout.list(using: listConfiguration)
    let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
    view.backgroundColor = .grailBackground
    return view
  }()

  internal func showPage(with noteIdentifier: Note.Identifier) {
    let note: Note
    do {
      note = try database.note(noteIdentifier: noteIdentifier)
    } catch {
      Logger.shared.error("Unexpected error loading page: \(error)")
      return
    }
    delegate?.documentListViewController(self, didRequestShowNote: note, noteIdentifier: noteIdentifier)
  }

  internal func selectFirstNote() {
    dataSource.selectFirstNote(in: collectionView)
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(collectionView)
    collectionView.snp.makeConstraints { make in
      make.top.bottom.left.right.equalToSuperview()
    }
    database.studySession(filter: nil, date: Date()) { [weak self] in
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

    /// Update the due date as time passes, app foregrounds, etc.
    updateDueDatePipeline = Just(Date())
      .merge(with: makeForegroundDatePublisher(), Timer.publish(every: .hour, on: .main, in: .common).autoconnect())
      .map { Calendar.current.startOfDay(for: $0.addingTimeInterval(.day)) }
      .assign(to: \.dueDate, on: self)
    navigationController?.setToolbarHidden(false, animated: false)
    if AppDelegate.isUITesting {
      navigationItem.rightBarButtonItem = advanceTimeButton
    }
  }

  func searchBecomeFirstResponder() {
    navigationItem.searchController?.isActive = true
    navigationItem.searchController?.searchBar.becomeFirstResponder()
    Logger.shared.info("Search should be activeg")
  }

  private var updateDueDatePipeline: AnyCancellable?

  private func makeForegroundDatePublisher() -> AnyPublisher<Date, Never> {
    NotificationCenter.default
      .publisher(for: UIApplication.willEnterForegroundNotification)
      .map { _ in Date() }
      .eraseToAnyPublisher()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    dataSource.startObservingDatabase()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    dataSource.stopObservingDatabase()
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    updateToolbar()
  }

  // MARK: - Keyboard support

  override var canBecomeFirstResponder: Bool { true }

  override func becomeFirstResponder() -> Bool {
    if collectionView.indexPathsForSelectedItems.isEmpty {
      selectFirstNote()
    }
    return super.becomeFirstResponder()
  }

  override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    var didHandleEvent = false
    for press in presses {
      guard let key = press.key else { continue }
      switch key.charactersIgnoringModifiers {
      case UIKeyCommand.inputDownArrow:
        dataSource.moveSelectionDown(in: collectionView)
        didHandleEvent = true
      case UIKeyCommand.inputUpArrow:
        dataSource.moveSelectionUp(in: collectionView)
        didHandleEvent = true
      case "\t":
        if key.modifierFlags.contains(.shift) {
          delegate?.documentListViewControllerDidRequestChangeFocus(self)
          didHandleEvent = true
        }
      default:
        break
      }
    }

    if !didHandleEvent {
      super.pressesBegan(presses, with: event)
    }

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
    dueDate = dueDate.addingTimeInterval(7 * .day)
  }

  private func updateStudySession() {
    let currentHashtag = dataSource.filteredHashtag
    let filter: (Note.Identifier, Note.Metadata) -> Bool = (currentHashtag == nil)
      ? { _, _ in true }
      : { [currentHashtag] _, properties in properties.hashtags.contains(currentHashtag!) }
    let hashtag = currentHashtag
    database.studySession(filter: filter, date: dueDate) {
      guard currentHashtag == hashtag else { return }
      self.studySession = $0
    }
  }

  private func updateToolbar() {
    let countLabel = UILabel(frame: .zero)
    let noteCount = dataSource.noteCount
    countLabel.text = noteCount == 1 ? "1 note" : "\(noteCount) notes"
    countLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
    countLabel.sizeToFit()

    let itemsToReview = studySession?.count ?? 0
    let reviewButton = UIBarButtonItem(title: "Review (\(itemsToReview))", style: .plain, target: self, action: #selector(performReview))
    reviewButton.accessibilityIdentifier = "study-button"
    reviewButton.isEnabled = itemsToReview > 0

    let countItem = UIBarButtonItem(customView: countLabel)
    var toolbarItems = [
      reviewButton,
      UIBarButtonItem.flexibleSpace(),
      countItem,
      UIBarButtonItem.flexibleSpace(),
    ]
    if splitViewController?.isCollapsed ?? false {
      toolbarItems.append(AppCommandsButtonItems.newNote())
    }
    self.toolbarItems = toolbarItems
  }

  @objc private func performReview() {
    guard let studySession = studySession else { return }
    presentStudySessionViewController(for: studySession)
  }
}

// MARK: - DocumentTableControllerDelegate

extension DocumentListViewController: DocumentTableControllerDelegate {
  func showWebPage(url: URL) {
    Logger.shared.info("Will navigate to web page at \(url)")
    let placeholderNote = Note(
      metadata: Note.Metadata(
        creationTimestamp: Date(),
        timestamp: Date(),
        hashtags: [],
        title: ""
      ),
      text: "This is a test note",
      reference: .webPage(url),
      promptCollections: [:]
    )
    delegate?.documentListViewController(self, didRequestShowNote: placeholderNote, noteIdentifier: nil)
  }

  func presentStudySessionViewController(for studySession: StudySession) {
    let studyVC = StudyViewController(
      studySession: studySession.shuffling().ensuringUniquePromptCollections().limiting(to: 20),
      database: database,
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
      let (blankNote, _) = Note.makeBlankNote(hashtag: dataSource.filteredHashtag)
      delegate?.documentListViewController(self, didRequestShowNote: blankNote, noteIdentifier: nil)
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

// MARK: - Search

/// Everything needed for search.
/// This is a bunch of little protocols and it's clearer to declare conformance in a single extension.
extension DocumentListViewController: UISearchResultsUpdating, UISearchBarDelegate {
  func updateSearchResults(for searchController: UISearchController) {
    guard searchController.isActive else {
      dataSource.filteredPageIdentifiers = nil
      updateStudySession()
      return
    }
    let pattern = searchController.searchBar.text ?? ""
    Logger.shared.info("Issuing query: \(pattern)")
    dataSource.webURL = pattern.asWebURL
    do {
      let allIdentifiers = try database.search(for: pattern)
      dataSource.filteredPageIdentifiers = Set(allIdentifiers)
    } catch {
      Logger.shared.error("Error issuing full text query: \(error)")
    }
  }

  func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
    Logger.shared.info("searchBarTextDidEndEditing")
  }

  func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
    dataSource.filteredPageIdentifiers = nil
  }
}

extension DocumentListViewController: StudyViewControllerDelegate {
  func studyViewController(
    _ studyViewController: StudyViewController,
    didFinishSession session: StudySession
  ) {
    do {
      try database.updateStudySessionResults(session, on: dueDate, buryRelatedPrompts: true)
      updateStudySession()
    } catch {
      Logger.shared.error("Unexpected error recording study session results: \(error)")
    }
  }

  func studyViewControllerDidCancel(_ studyViewController: StudyViewController) {
    dismiss(animated: true, completion: nil)
  }
}

private extension String {
  /// Non-nil if this string is a valid web URL.
  var asWebURL: URL? {
    guard let urlDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
      assertionFailure()
      return nil
    }
    let fullStringRange = NSRange(startIndex..., in: self)
    let matches = urlDetector.matches(in: self, options: [], range: fullStringRange)
    for match in matches {
      if match.range(at: 0) == fullStringRange {
        return match.url
      }
    }
    return nil
  }
}
