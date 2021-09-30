// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import CodableCSV
import Combine
import CoreServices
import CoreSpotlight
import Logging
import MessageUI
import SafariServices
import SnapKit
import UIKit
import UniformTypeIdentifiers

/// Implements a filterable list of documents in an interactive notebook.
final class DocumentListViewController: UIViewController {
  /// Designated initializer.
  init(
    database: NoteDatabase,
    coverImageCache: CoverImageCache
  ) {
    self.database = database
    self.coverImageCache = coverImageCache
    super.init(nibName: nil, bundle: nil)
    // assume we are showing "all notes" initially.
    navigationItem.title = NotebookStructureViewController.StructureIdentifier.read.description
  }

  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public let database: NoteDatabase
  private let coverImageCache: CoverImageCache

  public var focusedStructure: NotebookStructureViewController.StructureIdentifier = .read {
    didSet {
      monitorDatabaseForFocusedStructure()
    }
  }

  var currentSortOrder = NoteIdentifierRecord.SortOrder.creationTimestamp {
    didSet {
      monitorDatabaseForFocusedStructure()
    }
  }

  var currentSearchTerm: String? {
    didSet {
      monitorDatabaseForFocusedStructure()
    }
  }

  private var metadataPipeline: AnyCancellable?

  private func monitorDatabaseForFocusedStructure() {
    title = focusedStructure.longDescription
    metadataPipeline = database.noteIdentifiersPublisher(
      structureIdentifier: focusedStructure,
      sortOrder: currentSortOrder,
      searchTerm: currentSearchTerm
    )
      .catch { error -> Just<[NoteIdentifierRecord]> in
        Logger.shared.error("Error getting note identifiers: \(error)")
        return Just([])
      }
      .sink(receiveValue: { [weak self] noteIdentifiers in
        self?.dataSource.noteIdentifiers = noteIdentifiers
        self?.updateStudySession()
        self?.updateQuoteList()
      })
  }

  private lazy var dataSource: DocumentTableController = {
    DocumentTableController(
      collectionView: collectionView,
      database: database,
      coverImageCache: coverImageCache,
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
    var listConfiguration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
    listConfiguration.backgroundColor = .grailSecondaryBackground
    listConfiguration.headerMode = .firstItemInSection
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
    self.studySession = try? database.studySession(date: Date())
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
    Logger.shared.info("Search should be active")
  }

  private var updateDueDatePipeline: AnyCancellable?

  private func makeForegroundDatePublisher() -> AnyPublisher<Date, Never> {
    NotificationCenter.default
      .publisher(for: UIApplication.willEnterForegroundNotification)
      .map { _ in Date() }
      .eraseToAnyPublisher()
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    updateToolbarAndMenu()
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
      updateToolbarAndMenu()
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
    studySession = try? database.studySession(
      noteIdentifiers: Set(dataSource.noteIdentifiers.map({ $0.noteIdentifier })),
      date: dueDate
    )
  }

  private var quotesSubscription: AnyCancellable?
  private var quoteIdentifiers: [ContentIdentifier] = [] {
    didSet {
      updateToolbarAndMenu()
    }
  }

  public var quotesPublisher: AnyPublisher<[ContentIdentifier], Error>? {
    willSet {
      quotesSubscription?.cancel()
      quotesSubscription = nil
    }
    didSet {
      quotesSubscription = quotesPublisher?.sink(receiveCompletion: { error in
        Logger.shared.error("Unexpected error getting quotes: \(error)")
      }, receiveValue: { [weak self] quoteIdentifiers in
        self?.quoteIdentifiers = quoteIdentifiers
        Logger.shared.debug("Got \(quoteIdentifiers.count) quotes")
      })
    }
  }

  private func updateQuoteList() {
    Logger.shared.info("Updating quote list for hashtag \(focusedStructure.hashtag ?? "nil")")
    quotesPublisher = database.promptCollectionPublisher(promptType: .quote, tagged: focusedStructure.hashtag)
  }

  private var progressView: UIProgressView? {
    didSet {
      updateToolbarAndMenu()
    }
  }

  /// A `UIBarButtonItem` to display at the bottom of the list view.
  ///
  /// If `progressView` is non-nil (indicating a long-running task is happening), this will be a `UIBarButtonItem` wrapping the progress view.
  /// Otherwise, it will be a `UIBarButtonItem` wrapping a count of the number of books.
  private var displayBarButtonItem: UIBarButtonItem {
    if let progressView = progressView {
      return UIBarButtonItem(customView: progressView)
    } else {
      let countLabel = UILabel(frame: .zero)
      let bookCount = dataSource.bookCount
      countLabel.text = bookCount == 1 ? "1 book" : "\(bookCount) books"
      countLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
      countLabel.sizeToFit()
      return UIBarButtonItem(customView: countLabel)
    }
  }

  private func updateToolbarAndMenu() {
    var toolbarItems = [
      UIBarButtonItem.flexibleSpace(),
      displayBarButtonItem,
      UIBarButtonItem.flexibleSpace(),
    ]
    if splitViewController?.isCollapsed ?? false, let newNoteButton = notebookViewController?.makeNewNoteButtonItem() {
      toolbarItems.append(newNoteButton)
    }
    self.toolbarItems = toolbarItems

    let navButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: UIMenu(children: [
      actionsMenu,
      sortMenu,
    ]))
    navigationItem.rightBarButtonItem = navButton
  }

  /// Exports the selection of books in a CSV format that roughly matches the Goodreads CSV format. Opens the share sheet to determine the final disposition of the file.
  @objc private func exportAndShare() {
    let noteIdentifiers = dataSource.noteIdentifiers
    Logger.shared.info("Exporting and sharing \(noteIdentifiers.count) books...")
    let listFormatter = ListFormatter()
    do {
      let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(title ?? "export").csv")
      let writer = try CSVWriter(fileURL: exportURL) {
        $0.headers = ["Title", "Authors", "ISBN", "ISBN13", "My Rating", "Number of Pages", "Year Published", "Original Publication Year", "Date Added", "Publisher", "Private Notes"]
      }
      for noteIdentifier in noteIdentifiers {
        let note = try database.note(noteIdentifier: noteIdentifier.noteIdentifier)
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
      popover?.barButtonItem = navigationItem.rightBarButtonItem
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

// MARK: - Menus

extension DocumentListViewController {
  /// A menu that shows all of the available actions.
  private var actionsMenu: UIMenu {
    UIMenu(title: "", options: .displayInline, children: [
      openCommand,
      reviewAction,
      quotesAction,
      shareAction,
      importLibraryThingAction,
      sendFeedbackAction,
    ].compactMap { $0 })
  }

  private var openCommand: UICommand {
    UICommand(title: "Open", image: UIImage(systemName: "doc"), action: #selector(AppCommands.openNewFile))
  }

  /// A `UIAction` for importing books from LibraryThing or Goodreads
  private var importLibraryThingAction: UIAction {
    UIAction(title: "Bulk Import", image: UIImage(systemName: "arrow.down.doc")) { [weak self] _ in
      guard let self = self else { return }
      Logger.shared.info("Importing from LibraryThing")
      let bookImporterViewController = BookImporterViewController(database: self.database)
      bookImporterViewController.delegate = self
      self.present(bookImporterViewController, animated: true)
    }
  }

  /// A `UIAction` for showing randomly selected quotes.
  private var quotesAction: UIAction {
    UIAction(title: "Random Quotes", image: UIImage(systemName: "text.quote")) { [weak self] _ in
      guard let self = self else { return }
      self.showQuotes(quotes: self.quoteIdentifiers, shiftFocus: true)
    }
  }

  /// A `UIAction` for reviewing items in the library.
  private var reviewAction: UIAction {
    let itemsToReview = studySession?.count ?? 0
    let reviewAction = UIAction(title: "Review (\(itemsToReview))", image: UIImage(systemName: "sparkles.rectangle.stack")) { [weak self] _ in
      self?.performReview()
    }
    if itemsToReview == 0 {
      reviewAction.attributes.insert(.disabled)
    }
    return reviewAction
  }

  /// A `UIAction` for exporting the current view of the library.
  private var shareAction: UIAction {
    UIAction(title: "Export", image: UIImage(systemName: "arrow.up.forward.app")) { [weak self] _ in
      self?.exportAndShare()
    }
  }

  private var sendFeedbackAction: UIAction? {
    guard MFMailComposeViewController.canSendMail() else {
      return nil
    }
    return UIAction(title: "Send Feedback", image: UIImage(systemName: "envelope.open")) { [weak self] _ in
      guard let self = self else { return }
      Logger.shared.info("Sending feedback")
      let mailComposer = MFMailComposeViewController()
      mailComposer.setSubject("\(AppDelegate.appName) Feedback")
      mailComposer.setToRecipients(["librarynotesapp@gmail.com"])
      mailComposer.setMessageBody("Version \(UIApplication.versionString)", isHTML: false)
      if UIApplication.isTestFlight, let zippedData = try? LogFileDirectory.shared.makeZippedLog() {
        mailComposer.addAttachmentData(zippedData, mimeType: UTType.zip.preferredMIMEType ?? "application/zip", fileName: "log.zip")
      }
      mailComposer.mailComposeDelegate = self
      self.present(mailComposer, animated: true)
    }
  }

  private var sortMenu: UIMenu {
    let sortActions = NoteIdentifierRecord.SortOrder.allCases.map { sortOrder -> UIAction in
      UIAction(title: sortOrder.rawValue, state: sortOrder == currentSortOrder ? .on : .off) { [weak self] _ in
        self?.currentSortOrder = sortOrder
      }
    }
    return UIMenu(title: "Sort", image: UIImage(systemName: "arrow.up.arrow.down.circle"), children: sortActions)
  }
}

extension DocumentListViewController: MFMailComposeViewControllerDelegate {
  func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
    Logger.shared.info("Mail composer finished with result \(result)")
    controller.dismiss(animated: true)
  }
}

extension MFMailComposeResult: CustomStringConvertible {
  public var description: String {
    switch self {
    case .cancelled:
      return "cancelled"
    case .saved:
      return "saved"
    case .sent:
      return "sent"
    case .failed:
      return "failed"
    @unknown default:
      return "unknown"
    }
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
    updateToolbarAndMenu()
  }
}

// MARK: - Search

/// Everything needed for search.
/// This is a bunch of little protocols and it's clearer to declare conformance in a single extension.
extension DocumentListViewController: UISearchResultsUpdating, UISearchBarDelegate {
  func updateSearchResults(for searchController: UISearchController) {
    guard searchController.isActive else {
      currentSearchTerm = nil
      updateStudySession()
      return
    }
    currentSearchTerm = searchController.searchBar.text
  }

  func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
    Logger.shared.info("searchBarTextDidEndEditing")
  }

  func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
    currentSearchTerm = nil
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

extension DocumentListViewController: BookImporterViewControllerDelegate {
  func bookImporter(_ bookImporter: BookImporterViewController, didStartImporting count: Int) {
    let progressView = UIProgressView(progressViewStyle: .bar)
    progressView.trackTintColor = .grailGroupedBackground
    progressView.progress = 0
    self.progressView = progressView
  }

  func bookImporter(_ bookImporter: BookImporterViewController, didProcess partialCount: Int, of totalCount: Int) {
    let newProgress = Float(partialCount) / Float(totalCount)
    progressView?.progress = newProgress
    Logger.shared.debug("toolbar progress = \(newProgress)")
  }

  func bookImporterDidFinishImporting(_ bookImporter: BookImporterViewController) {
    progressView = nil
  }
}
