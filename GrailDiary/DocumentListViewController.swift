// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import CodableCSV
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
    navigationItem.title = NotebookStructureViewController.StructureIdentifier.read.description
  }

  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public let database: NoteDatabase

  public var focusedStructure: NotebookStructureViewController.StructureIdentifier = .read {
    didSet {
      monitorDatabaseForFocusedStructure()
    }
  }

  private var metadataPipeline: AnyCancellable?

  private func monitorDatabaseForFocusedStructure() {
    title = focusedStructure.longDescription
    metadataPipeline = database.bookMetadataPublisher()
      .catch { error -> Just<[String: BookNoteMetadata]> in
        Logger.shared.error("Unexpected error getting metadata: \(error)")
        return Just([String: BookNoteMetadata]())
      }
      .map { [focusedStructure] in $0.filter(focusedStructure.filterBookNoteMetadata) }
      .sink(receiveValue: { [weak self] filteredBookMetadata in
        self?.dataSource.bookNoteMetadata = filteredBookMetadata
        self?.updateStudySession()
        self?.updateQuoteList()
      })
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

  internal func showPage(with noteIdentifier: Note.Identifier, shiftFocus: Bool) {
    do {
      let note = try database.note(noteIdentifier: noteIdentifier)
      notebookViewController?.showNoteEditor(noteIdentifier: noteIdentifier, note: note, shiftFocus: shiftFocus)
    } catch {
      Logger.shared.error("Unexpected error loading page: \(error)")
    }
  }

  func selectPage(with noteIdentifier: Note.Identifier) {
    guard let indexPath = dataSource.indexPath(noteIdentifier: noteIdentifier) else {
      return
    }
    collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .top)
  }

  internal func selectFirstNote() {
    dataSource.selectFirstNote()
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
    monitorDatabaseForFocusedStructure()
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

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    updateToolbar()
  }

  // MARK: - Keyboard support

  override var canBecomeFirstResponder: Bool { true }

  @discardableResult
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
          notebookViewController?.documentListViewControllerDidRequestChangeFocus(self)
          didHandleEvent = true
        }
      case "\r":
        splitViewController?.show(.secondary)
        didHandleEvent = true
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

  private var studySessionGeneration = 0

  private func updateStudySession() {
    let records = dataSource.bookNoteMetadata
    let filter: (Note.Identifier, BookNoteMetadata) -> Bool = { identifier, _ in records[identifier] != nil }
    studySessionGeneration += 1
    let currentStudySessionGeneration = studySessionGeneration
    database.studySession(filter: filter, date: dueDate) {
      guard currentStudySessionGeneration == self.studySessionGeneration else { return }
      self.studySession = $0
    }
  }

  private func updateQuoteList() {
    dataSource.quotesPublisher = database.promptCollectionPublisher(promptType: .quote, tagged: focusedStructure.hashtag)
  }

  private func updateToolbar() {
    let countLabel = UILabel(frame: .zero)
    let bookCount = dataSource.bookCount
    countLabel.text = bookCount == 1 ? "1 book" : "\(bookCount) books"
    countLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
    countLabel.sizeToFit()

    let itemsToReview = studySession?.count ?? 0
    let reviewButton = UIBarButtonItem(title: "Review (\(itemsToReview))", style: .plain, target: self, action: #selector(performReview))
    reviewButton.accessibilityIdentifier = "study-button"
    reviewButton.isEnabled = itemsToReview > 0

    let exportMenuItem = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(exportAndShare))

    let sortActions = DocumentTableController.SortOrder.allCases.map { sortOrder -> UIAction in
      UIAction(title: sortOrder.rawValue, state: sortOrder == dataSource.currentSortOrder ? .on : .off) { [weak self] _ in
        self?.dataSource.currentSortOrder = sortOrder
      }
    }
    let sortMenuItem = UIBarButtonItem(image: UIImage(systemName: "arrow.up.arrow.down.circle"), menu: UIMenu(children: sortActions))

    let countItem = UIBarButtonItem(customView: countLabel)
    var toolbarItems = [
      reviewButton,
      UIBarButtonItem.flexibleSpace(),
      countItem,
      UIBarButtonItem.flexibleSpace(),
      exportMenuItem,
      sortMenuItem,
    ]
    if splitViewController?.isCollapsed ?? false, let newNoteButton = notebookViewController?.makeNewNoteButtonItem() {
      toolbarItems.append(newNoteButton)
    }
    self.toolbarItems = toolbarItems
  }

  /// Exports the selection of books in a CSV format that roughly matches the Goodreads CSV format. Opens the share sheet to determine the final disposition of the file.
  @objc private func exportAndShare(sender: UIBarButtonItem) {
    let noteIdentifiers = dataSource.noteIdentifiers
    Logger.shared.info("Exporting and sharing \(noteIdentifiers.count) books...")
    let listFormatter = ListFormatter()
    do {
      let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(title ?? "export").csv")
      let writer = try CSVWriter(fileURL: exportURL) {
        $0.headers = ["Title", "Authors", "ISBN", "ISBN13", "My Rating", "Number of Pages", "Year Published", "Original Publication Year", "Date Added", "Publisher", "Private Notes"]
      }
      for noteIdentifier in noteIdentifiers {
        let note = try database.note(noteIdentifier: noteIdentifier)
        guard let book = note.book else { continue }
        try writer.write(field: book.title)
        try listFormatter.string(from: book.authors).flatMap { try writer.write(field: $0) }
        try writer.write(field: book.isbn ?? "")
        try writer.write(field: book.isbn13 ?? "")
        try writer.write(field: note.rating?.description ?? "")
        try writer.write(field: book.numberOfPages?.description ?? "")
        try writer.write(field: book.yearPublished?.description ?? "")
        try writer.write(field: book.originalYearPublished?.description ?? "")
        try writer.write(field: DayComponents(note.metadata.creationTimestamp).description)
        try writer.write(field: book.publisher ?? "")
        try writer.write(field: note.text ?? "")
        try writer.endRow()
      }
      try writer.endEncoding()
      let activityViewController = UIActivityViewController(activityItems: [exportURL], applicationActivities: nil)
      let popover = activityViewController.popoverPresentationController
      popover?.barButtonItem = sender
      present(activityViewController, animated: true)
    } catch {
      Logger.shared.error("Error exporting to CSV: \(error)")
    }
  }

  @objc private func performReview() {
    guard let studySession = studySession else { return }
    presentStudySessionViewController(for: studySession)
  }
}

// MARK: - DocumentTableControllerDelegate

extension DocumentListViewController: DocumentTableControllerDelegate {
  func showQuotes(quotes: [ContentIdentifier], shiftFocus: Bool) {
    let quotesVC = QuotesViewController(database: database)
    quotesVC.quoteIdentifiers = quotes
    quotesVC.title = "Random Quotes"
    notebookViewController?.setSecondaryViewController(quotesVC, pushIfCollapsed: shiftFocus)
  }

  func presentStudySessionViewController(for studySession: StudySession) {
    let studyVC = StudyViewController(
      studySession: studySession.shuffling().ensuringUniquePromptCollections().limiting(to: 20),
      database: database,
      delegate: self
    )
    studyVC.title = navigationItem.title
    studyVC.view.tintColor = .grailTint
    studyVC.modalTransitionStyle = .crossDissolve
    studyVC.modalPresentationStyle = .overFullScreen
    present(
      studyVC,
      animated: true,
      completion: nil
    )
  }

  // TODO: This isn't actually called :-(
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
      let hashtag: String?
      if case .hashtag(let filteredHashtag) = focusedStructure {
        hashtag = filteredHashtag
      } else {
        hashtag = nil
      }
      let (blankText, _) = Note.makeBlankNoteText(hashtag: hashtag)
      let note = Note(markdown: blankText)
      notebookViewController?.showNoteEditor(noteIdentifier: nil, note: note, shiftFocus: false)
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

private extension Note {
  var book: AugmentedBook? {
    return metadata.book
  }

  var rating: Int? {
    for hashtag in metadata.tags where hashtag.hasPrefix("#rating/") {
      return hashtag.count - 8
    }
    return 0
  }
}
