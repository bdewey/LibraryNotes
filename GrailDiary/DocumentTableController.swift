// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Combine
import GRDB
import GRDBCombine
import Logging
import TextMarkupKit
import UIKit

/// Knows how to perform key actions with the document
public protocol DocumentTableControllerDelegate: AnyObject {
  /// Initiates studying.
  func presentStudySessionViewController(for studySession: StudySession)
  func documentTableDidDeleteDocument(with noteIdentifier: Note.Identifier)
  func showAlert(_ alertMessage: String)
  func showPage(with noteIdentifier: Note.Identifier, shiftFocus: Bool)
  func showWebPage(url: URL, shiftFocus: Bool)
  func showQuotes(quotes: [ContentIdentifier], shiftFocus: Bool)
  func documentTableController(_ documentTableController: DocumentTableController, didUpdateWithNoteCount noteCount: Int)
}

/// A list cell that is clear by default, with tint background color when selected.
private final class ClearBackgroundCell: UICollectionViewListCell {
  override func updateConfiguration(using state: UICellConfigurationState) {
    var backgroundConfiguration = UIBackgroundConfiguration.clear()
    if state.isSelected {
      backgroundConfiguration.backgroundColor = nil
      backgroundConfiguration.backgroundColorTransformer = .init { $0.withAlphaComponent(0.5) }
    }
    self.backgroundConfiguration = backgroundConfiguration
  }
}

/// Given a notebook, this class can manage a table that displays the hashtags and pages of that notebook.
public final class DocumentTableController: NSObject {
  /// Designated initializer.
  public init(
    collectionView: UICollectionView,
    database: NoteDatabase,
    delegate: DocumentTableControllerDelegate
  ) {
    self.database = database
    self.delegate = delegate

    let openWebPageRegistration = UICollectionView.CellRegistration<ClearBackgroundCell, Item> { cell, _, item in
      guard case .webPage(let url) = item else { return }
      var configuration = cell.defaultContentConfiguration()
      configuration.text = "Open \(url)"
      cell.contentConfiguration = configuration
    }

    let viewQuotesRegistration = UICollectionView.CellRegistration<ClearBackgroundCell, Item> { cell, _, _ in
      var configuration = cell.defaultContentConfiguration()
      configuration.text = "Random Quotes"
      configuration.image = UIImage(systemName: "text.quote")
      cell.contentConfiguration = configuration
      cell.accessories = [.disclosureIndicator()]
    }

    let notebookPageRegistration = UICollectionView.CellRegistration<ClearBackgroundCell, Item> { cell, _, item in
      guard case .page(let viewProperties) = item else { return }
      var configuration = cell.defaultContentConfiguration()
      let title = ParsedAttributedString(string: viewProperties.noteProperties.title, style: .plainText(textStyle: .headline))
      configuration.attributedText = title
      let secondaryComponents: [String?] = [
        viewProperties.noteProperties.summary,
        viewProperties.noteProperties.noteLinks.map { $0.targetTitle }.joined(separator: ", "),
      ]
      configuration.secondaryText = secondaryComponents.compactMap { $0 }.joined(separator: " ")
      configuration.secondaryTextProperties.color = .secondaryLabel
      if viewProperties.hasLink {
        configuration.image = UIImage(systemName: "link")
      }
      if let imageData = viewProperties.noteProperties.thumbnailImage.first {
        configuration.image = imageData.blob.image(maxSize: 100)
      }

      let headlineFont = UIFont.preferredFont(forTextStyle: .headline)
      let verticalMargin = max(20, 1.5 * headlineFont.lineHeight.roundedToScreenScale())
      configuration.directionalLayoutMargins = .init(top: verticalMargin, leading: 0, bottom: verticalMargin, trailing: 0)
      cell.contentConfiguration = configuration
    }

    let bookCategoryRegistration = UICollectionView.CellRegistration<ClearBackgroundCell, Item> { cell, _, item in
      guard case .bookCategory(let category) = item else { return }
      var configuration = cell.defaultContentConfiguration()
      switch category {
      case .wantToRead:
        configuration.text = "Want to read"
      case .currentlyReading:
        configuration.text = "Currently reading"
      case .read:
        configuration.text = "Read"
      }
      cell.contentConfiguration = configuration
      cell.accessories = [.outlineDisclosure()]
    }

    self.dataSource = UICollectionViewDiffableDataSource<DocumentSection, Item>(
      collectionView: collectionView,
      cellProvider: { (collectionView, indexPath, item) -> UICollectionViewCell? in
        switch item {
        case .webPage:
          return collectionView.dequeueConfiguredReusableCell(using: openWebPageRegistration, for: indexPath, item: item)
        case .reviewQuotes:
          return collectionView.dequeueConfiguredReusableCell(using: viewQuotesRegistration, for: indexPath, item: item)
        case .page:
          return collectionView.dequeueConfiguredReusableCell(using: notebookPageRegistration, for: indexPath, item: item)
        case .bookCategory:
          return collectionView.dequeueConfiguredReusableCell(using: bookCategoryRegistration, for: indexPath, item: item)
        }
      }
    )

    super.init()
    collectionView.delegate = self
    collectionView.refreshControl = refreshControl
    let needsPerformUpdatesObserver = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.beforeWaiting.rawValue, true, 0) { [weak self] _, _ in
      self?.updateDataSourceIfNeeded()
    }
    CFRunLoopAddObserver(CFRunLoopGetMain(), needsPerformUpdatesObserver, CFRunLoopMode.commonModes)
    updateCardsPerDocument()
  }

  public var dueDate = Date() {
    didSet {
      updateCardsPerDocument()
    }
  }

  public var noteCount: Int {
    let snapshot = dataSource.snapshot()
    if snapshot.indexOfSection(.documents) != nil {
      return snapshot.numberOfItems(inSection: .documents)
    } else {
      return 0
    }
  }

  /// All note identifiers currently displayed in the table.
  public var noteIdentifiers: [Note.Identifier] {
    dataSource.snapshot().itemIdentifiers.compactMap { $0.noteIdentifier }
  }

  private var needsPerformUpdates = false
  private var isPerformingUpdates = false

  private func updateDataSourceIfNeeded() {
    if needsPerformUpdates, !isPerformingUpdates {
      performUpdates(animated: true)
      needsPerformUpdates = false
    }
  }

  private lazy var refreshControl: UIRefreshControl = {
    let control = UIRefreshControl()
    control.addTarget(self, action: #selector(handleRefreshControl), for: .valueChanged)
    return control
  }()

  /// If non-nil, only pages with these identifiers will be shown.
  // TODO: Incorporate this into the query
  public var filteredPageIdentifiers: Set<Note.Identifier>? {
    didSet {
      needsPerformUpdates = true
    }
  }

  public var observableRecords: NoteDatabase.ObservableRecords? {
    willSet {
      recordsSubscription?.cancel()
      recordsSubscription = nil
    }
    didSet {
      guard let observableRecords = observableRecords else { return }
      recordsSubscription = observableRecords.recordsDidChange
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in
          self?.updateCardsPerDocument()
        }
      updateCardsPerDocument()
      needsPerformUpdates = true
    }
  }

  private var quotesSubscription: AnyCancellable?
  private var quoteIdentifiers: [ContentIdentifier] = [] {
    didSet {
      needsPerformUpdates = true
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

  /// If non-nil, the table view should show a cell representing this web page at the top of the table.
  public var webURL: URL? {
    didSet {
      needsPerformUpdates = true
    }
  }

  /// Delegate.
  private(set) weak var delegate: DocumentTableControllerDelegate?

  private let database: NoteDatabase
  private var cardsPerDocument = [Note.Identifier: Int]() {
    didSet {
      needsPerformUpdates = true
    }
  }

  private let dataSource: UICollectionViewDiffableDataSource<DocumentSection, Item>

  private var recordsSubscription: AnyCancellable?

  var currentSortOrder = SortOrder.creationTimestamp {
    didSet {
      needsPerformUpdates = true
    }
  }

  enum SortOrder: String, CaseIterable {
    case author = "Author"
    case title = "Title"
    case creationTimestamp = "Created Date"
    case modificationTimestap = "Modified Date"

    fileprivate var sortFunction: (ViewProperties, ViewProperties) -> Bool {
      switch self {
      case .author:
        return ViewProperties.lessThanPriorityAuthor
      case .title:
        return ViewProperties.lessThanPriorityTitle
      case .creationTimestamp:
        return { ViewProperties.lessThanPriorityCreation(lhs: $1, rhs: $0) }
      case .modificationTimestap:
        return { ViewProperties.lessThanPriorityModified(lhs: $1, rhs: $0) }
      }
    }
  }

  public func performUpdates(animated: Bool) {
    let (snapshot, bookSection) = DocumentTableController.snapshot(
      for: observableRecords?.records ?? [:],
      cardsPerDocument: cardsPerDocument,
      filteredPageIdentifiers: filteredPageIdentifiers,
      webURL: webURL,
      quoteCount: quoteIdentifiers.count,
      sortOrder: currentSortOrder
    )
    let reallyAnimate = animated && DocumentTableController.majorSnapshotDifferences(between: dataSource.snapshot(), and: snapshot)

    isPerformingUpdates = true
    dataSource.apply(snapshot, animatingDifferences: reallyAnimate) {
      self.isPerformingUpdates = false
    }
    dataSource.apply(bookSection, to: .documents)
    delegate?.documentTableController(self, didUpdateWithNoteCount: snapshot.numberOfItems(inSection: .documents))
  }

  /// Compares lhs & rhs to see if the differences are worth animating.
  private static func majorSnapshotDifferences(between lhs: Snapshot, and rhs: Snapshot) -> Bool {
    if lhs.numberOfItems != rhs.numberOfItems {
      return true
    }
    // The only way to get through this loop and return false is if every item in the left hand
    // side and the right hand side, in order, have matching page identifiers.
    // In that case, whatever difference that exists between the snapshots is "minor"
    // (e.g., other page properties differ)
    let itemsToCompare = zip(lhs.itemIdentifiers, rhs.itemIdentifiers)
    for (lhsItem, rhsItem) in itemsToCompare {
      switch (lhsItem, rhsItem) {
      case (.page(let lhsPage), .page(let rhsPage)):
        if lhsPage.pageKey != rhsPage.pageKey {
          return true
        }
        // If the page transitions from image to non image, or vice versa, animate the change.
        if lhsPage.noteProperties.thumbnailImage.isEmpty != rhsPage.noteProperties.thumbnailImage.isEmpty {
          return true
        }
      case (.webPage, .webPage):
        continue
      case (.reviewQuotes, .reviewQuotes):
        continue
      default:
        return true
      }
    }
    return false
  }
}

// MARK: - Swipe & context menu actions

extension DocumentTableController {
  public func trailingSwipeActionsConfiguration(forRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    guard let item = dataSource.itemIdentifier(for: indexPath) else {
      return nil
    }
    switch item {
    case .page(let properties):
      let actions = availableItemActionConfigurations(properties).reversed().map { $0.asContextualAction() }
      return UISwipeActionsConfiguration(actions: actions)
    case .webPage, .reviewQuotes, .bookCategory:
      return nil
    }
  }

  fileprivate func availableItemActionConfigurations(_ viewProperties: ViewProperties) -> [ActionConfiguration] {
    let actions: [ActionConfiguration?] = [
      .studyItem(viewProperties, in: database, delegate: delegate),
      .moveItemToWantToRead(viewProperties, in: database),
      .moveItemToCurrentlyReading(viewProperties, in: database),
      .moveItemToRead(viewProperties, in: database),
      .deleteItem(viewProperties, in: database),
    ]
    return actions.compactMap { $0 }
  }

  fileprivate struct ActionConfiguration {
    var title: String?
    var image: UIImage?
    var backgroundColor: UIColor?
    var destructive: Bool = false
    var handler: () throws -> Void

    func asContextualAction() -> UIContextualAction {
      let action = UIContextualAction(style: destructive ? .destructive : .normal, title: title) { _, _, completion in
        do {
          try handler()
          completion(true)
        } catch {
          Logger.shared.error("Unexpected error executing action \(String(describing: title)): \(error)")
          completion(false)
        }
      }
      action.image = image
      action.backgroundColor = backgroundColor
      return action
    }

    func asAction() -> UIAction {
      UIAction(title: title ?? "", image: image, attributes: destructive ? [.destructive] : []) { _ in
        do {
          try handler()
        } catch {
          Logger.shared.error("Unexpected error executing action \(String(describing: title)): \(error)")
        }
      }
    }

    static func deleteItem(_ viewProperties: ViewProperties, in database: NoteDatabase) -> ActionConfiguration? {
      return ActionConfiguration(title: "Delete", image: UIImage(systemName: "trash"), destructive: true) {
        if viewProperties.noteProperties.folder == PredefinedFolder.recentlyDeleted.rawValue {
          try database.deleteNote(noteIdentifier: viewProperties.pageKey)
        } else {
          try database.updateNote(noteIdentifier: viewProperties.pageKey, updateBlock: { note in
            var note = note
            note.folder = PredefinedFolder.recentlyDeleted.rawValue
            return note
          })
        }
      }
    }

    static func moveItemToRead(_ viewProperties: ViewProperties, in database: NoteDatabase) -> ActionConfiguration? {
      if viewProperties.noteProperties.folder == nil { return nil }
      return ActionConfiguration(title: "Read", image: UIImage(systemName: "books.vertical"), backgroundColor: .grailTint) {
        try database.updateNote(noteIdentifier: viewProperties.pageKey, updateBlock: { note -> Note in
          var note = note
          note.folder = nil
          return note
        })
        Logger.shared.info("Moved \(viewProperties.pageKey) to 'read'")
      }
    }

    static func moveItemToCurrentlyReading(_ viewProperties: ViewProperties, in database: NoteDatabase) -> ActionConfiguration? {
      if viewProperties.noteProperties.folder == PredefinedFolder.currentlyReading.rawValue { return nil }
      return ActionConfiguration(title: "Currently Reading", image: UIImage(systemName: "book"), backgroundColor: .grailTint) {
        try database.updateNote(noteIdentifier: viewProperties.pageKey, updateBlock: { note -> Note in
          var note = note
          note.folder = PredefinedFolder.currentlyReading.rawValue
          return note
        })
        Logger.shared.info("Moved \(viewProperties.pageKey) to 'read'")
      }
    }

    static func moveItemToWantToRead(_ viewProperties: ViewProperties, in database: NoteDatabase) -> ActionConfiguration? {
      if viewProperties.noteProperties.folder == PredefinedFolder.wantToRead.rawValue { return nil }
      return ActionConfiguration(title: "Want to Read", image: UIImage(systemName: "list.star"), backgroundColor: .systemIndigo) {
        try database.updateNote(noteIdentifier: viewProperties.pageKey, updateBlock: { note -> Note in
          var note = note
          note.folder = PredefinedFolder.wantToRead.rawValue
          return note
        })
        Logger.shared.info("Moved \(viewProperties.pageKey) to 'want to read'")
      }
    }

    static func studyItem(
      _ viewProperties: ViewProperties,
      in database: NoteDatabase,
      delegate: DocumentTableControllerDelegate?
    ) -> ActionConfiguration? {
      if viewProperties.cardCount == 0 { return nil }
      return ActionConfiguration(title: "Study", image: UIImage(systemName: "rectangle.stack"), backgroundColor: .systemBlue) {
        database.studySession(filter: { name, _ in name == viewProperties.pageKey }, date: Date(), completion: {
          delegate?.presentStudySessionViewController(for: $0)
        })
      }
    }
  }
}

// MARK: - Manage selection / keyboard

public extension DocumentTableController {
  func selectItemAtIndexPath(_ indexPath: IndexPath, shiftFocus: Bool) {
    guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
    switch item {
    case .page(let viewProperties):
      delegate?.showPage(with: viewProperties.pageKey, shiftFocus: shiftFocus)
    case .webPage(let url):
      delegate?.showWebPage(url: url, shiftFocus: shiftFocus)
    case .reviewQuotes:
      delegate?.showQuotes(quotes: quoteIdentifiers, shiftFocus: shiftFocus)
    case .bookCategory:
      assertionFailure()
    }
  }

  func indexPath(noteIdentifier: Note.Identifier) -> IndexPath? {
    let item = dataSource.snapshot().itemIdentifiers.first { item in
      if case .page(let viewProperties) = item {
        return viewProperties.pageKey == noteIdentifier
      } else {
        return false
      }
    }
    guard let item = item else { return nil }
    return dataSource.indexPath(for: item)
  }

  func selectFirstNote() {
    let notes = dataSource.snapshot().itemIdentifiers(inSection: .documents)
    if let firstNote = notes.first, case .page(let viewProperties) = firstNote {
      delegate?.showPage(with: viewProperties.pageKey, shiftFocus: false)
    }
  }

  func moveSelectionDown(in collectionView: UICollectionView) {
    let snapshot = dataSource.snapshot()
    guard snapshot.numberOfItems > 0 else { return }
    let nextItemIndex: Int
    if let indexPath = collectionView.indexPathsForSelectedItems?.first,
       let item = dataSource.itemIdentifier(for: indexPath),
       let itemIndex = snapshot.indexOfItem(item)
    {
      nextItemIndex = min(itemIndex + 1, snapshot.numberOfItems - 1)
    } else {
      nextItemIndex = 0
    }
    if let nextIndexPath = dataSource.indexPath(for: snapshot.itemIdentifiers[nextItemIndex]) {
      collectionView.selectItem(at: nextIndexPath, animated: true, scrollPosition: [])
      if let cell = collectionView.cellForItem(at: nextIndexPath) {
        collectionView.scrollRectToVisible(cell.frame, animated: true)
      }
      selectItemAtIndexPath(nextIndexPath, shiftFocus: false)
    }
  }

  func moveSelectionUp(in collectionView: UICollectionView) {
    let snapshot = dataSource.snapshot()
    guard snapshot.numberOfItems > 0 else { return }
    let previousItemIndex: Int
    if let indexPath = collectionView.indexPathsForSelectedItems?.first,
       let item = dataSource.itemIdentifier(for: indexPath),
       let itemIndex = snapshot.indexOfItem(item)
    {
      previousItemIndex = max(itemIndex - 1, 0)
    } else {
      previousItemIndex = snapshot.numberOfItems - 1
    }
    if let previousIndexPath = dataSource.indexPath(for: snapshot.itemIdentifiers[previousItemIndex]) {
      collectionView.selectItem(at: previousIndexPath, animated: true, scrollPosition: [])
      if let cell = collectionView.cellForItem(at: previousIndexPath) {
        collectionView.scrollRectToVisible(cell.frame, animated: true)
      }
      selectItemAtIndexPath(previousIndexPath, shiftFocus: false)
    }
  }
}

// MARK: - UICollectionViewDelegate

extension DocumentTableController: UICollectionViewDelegate {
  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    selectItemAtIndexPath(indexPath, shiftFocus: true)
  }

  public func collectionView(
    _ collectionView: UICollectionView,
    contextMenuConfigurationForItemAt indexPath: IndexPath,
    point: CGPoint
  ) -> UIContextMenuConfiguration? {
    guard
      let item = dataSource.itemIdentifier(for: indexPath),
      case .page(let itemProperties) = item
    else {
      return nil
    }
    return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
      guard let self = self else { return nil }
      let menuActions = self.availableItemActionConfigurations(itemProperties).map { $0.asAction() }
      return UIMenu(title: "", children: menuActions)
    }
  }
}

// MARK: - Private

private extension DocumentTableController {
  typealias Snapshot = NSDiffableDataSourceSnapshot<DocumentSection, Item>

  private final class DataSource: UITableViewDiffableDataSource<DocumentSection, Item> {
    // New behavior in Beta 6: The built-in data source defaults to "not editable" which
    // disables the swipe actions.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
      return true
    }
  }

  /// Sections of the collection view
  enum DocumentSection {
    /// A section with cells that represent navigation to other pages.
    case webNavigation
    /// A section with cells that represent review actions
    case actions
    /// List of documents.
    case documents
  }

  enum BookCategory {
    case wantToRead
    case currentlyReading
    case read
  }

  enum Item: Hashable, CustomStringConvertible {
    case webPage(URL)
    case page(ViewProperties)
    case reviewQuotes(count: Int)
    case bookCategory(BookCategory)

    var description: String {
      switch self {
      case .webPage(let url):
        return "Web page: \(url)"
      case .page(let viewProperties):
        return "Page \(viewProperties.pageKey)"
      case .reviewQuotes(count: let count):
        return "Quotes: \(count)"
      case .bookCategory(let category):
        return "\(category)"
      }
    }

    /// The note identifier for the item, if it exists.
    var noteIdentifier: Note.Identifier? {
      if case .page(let viewProperties) = self {
        return viewProperties.pageKey
      } else {
        return nil
      }
    }

    /// If the receiver is a page, returns the category for that page, else nil.
    var bookCategory: BookCategory? {
      if case .page(let properties) = self {
        return properties.bookCategory
      } else {
        return nil
      }
    }
  }

  /// All properties needed to display a document cell.
  struct ViewProperties: Hashable {
    /// UUID for this page
    let pageKey: Note.Identifier
    /// Page properties (serialized into the document)
    let noteProperties: NoteMetadataRecord
    /// How many cards are eligible for study in this page (dynamic and not serialized)
    var cardCount: Int
    /// Does this note have an associated link?
    let hasLink: Bool

    let author: PersonNameComponents?

    let bookCategory: BookCategory?

    init(pageKey: Note.Identifier, noteProperties: NoteMetadataRecord, cardCount: Int, hasLink: Bool) {
      self.pageKey = pageKey
      self.noteProperties = noteProperties
      self.cardCount = cardCount
      self.hasLink = hasLink

      if let book = noteProperties.book {
        if let readingHistory = book.readingHistory {
          if readingHistory.isCurrentlyReading {
            self.bookCategory = .currentlyReading
          } else {
            self.bookCategory = .read
          }
        } else {
          self.bookCategory = .wantToRead
        }
      } else {
        self.bookCategory = nil
      }

      if let book = noteProperties.book, let rawAuthorString = book.authors.first {
        let splitRawAuthor = rawAuthorString.split(separator: " ")
        var nameComponents = PersonNameComponents()
        if let last = splitRawAuthor.last {
          let first = splitRawAuthor.dropLast()
          nameComponents.familyName = String(last)
          nameComponents.givenName = first.joined(separator: " ")
        }
        self.author = nameComponents
      } else {
        self.author = nil
      }
    }

    // "Identity" for hashing & equality is just the pageKey

    func hash(into hasher: inout Hasher) {
      hasher.combine(pageKey)
    }

    static func == (lhs: ViewProperties, rhs: ViewProperties) -> Bool {
      lhs.pageKey == rhs.pageKey
    }

    static func lessThanPriorityAuthor(lhs: ViewProperties, rhs: ViewProperties) -> Bool {
      return
        (lhs.author, lhs.noteProperties.title, lhs.noteProperties.creationTimestamp, lhs.noteProperties.modifiedTimestamp) <
        (rhs.author, rhs.noteProperties.title, rhs.noteProperties.creationTimestamp, rhs.noteProperties.modifiedTimestamp)
    }

    static func lessThanPriorityTitle(lhs: ViewProperties, rhs: ViewProperties) -> Bool {
      return
        (lhs.noteProperties.title, lhs.author, lhs.noteProperties.creationTimestamp, lhs.noteProperties.modifiedTimestamp) <
        (rhs.noteProperties.title, rhs.author, rhs.noteProperties.creationTimestamp, rhs.noteProperties.modifiedTimestamp)
    }

    static func lessThanPriorityCreation(lhs: ViewProperties, rhs: ViewProperties) -> Bool {
      return
        (lhs.noteProperties.creationTimestamp, lhs.author, lhs.noteProperties.title, lhs.noteProperties.modifiedTimestamp) <
        (rhs.noteProperties.creationTimestamp, rhs.author, rhs.noteProperties.title, rhs.noteProperties.modifiedTimestamp)
    }

    static func lessThanPriorityModified(lhs: ViewProperties, rhs: ViewProperties) -> Bool {
      return
        (lhs.noteProperties.modifiedTimestamp, lhs.author, lhs.noteProperties.title, lhs.noteProperties.creationTimestamp) <
        (rhs.noteProperties.modifiedTimestamp, rhs.author, rhs.noteProperties.title, rhs.noteProperties.creationTimestamp)
    }
  }

  @objc func handleRefreshControl() {
    database.refresh { _ in
      self.refreshControl.endRefreshing()
    }
  }

  func updateCardsPerDocument() {
    database.studySession(filter: nil, date: dueDate) { studySession in
      self.cardsPerDocument = studySession
        .reduce(into: [Note.Identifier: Int]()) { cardsPerDocument, card in
          cardsPerDocument[card.noteIdentifier] = cardsPerDocument[card.noteIdentifier, default: 0] + 1
        }
      Logger.shared.debug(
        "studySession.count = \(studySession.count). cardsPerDocument has \(self.cardsPerDocument.count) entries"
      )
    }
  }

  static func snapshot(
    for records: [Note.Identifier: NoteMetadataRecord],
    cardsPerDocument: [Note.Identifier: Int],
    filteredPageIdentifiers: Set<Note.Identifier>?,
    webURL: URL?,
    quoteCount: Int,
    sortOrder: SortOrder = .author
  ) -> (Snapshot, NSDiffableDataSourceSectionSnapshot<Item>) {
    var snapshot = Snapshot()

    if let webURL = webURL {
      snapshot.appendSections([.webNavigation])
      snapshot.appendItems([.webPage(webURL)])
    }

    if quoteCount > 0 {
      snapshot.appendSections([.actions])
      snapshot.appendItems([.reviewQuotes(count: quoteCount)])
    }

    snapshot.appendSections([.documents])

    var bookSection = NSDiffableDataSourceSectionSnapshot<Item>()

    let viewProperties = records
      .filter {
        guard let filteredPageIdentifiers = filteredPageIdentifiers else { return true }
        return filteredPageIdentifiers.contains($0.key)
      }
      .compactMap { tuple in
        ViewProperties(
          pageKey: tuple.key,
          noteProperties: tuple.value,
          cardCount: cardsPerDocument[tuple.key, default: 0],
          hasLink: !tuple.value.contents.isEmpty
        )
      }

    let categories: [BookCategory] = [.wantToRead, .currentlyReading, .read]
    bookSection.append(categories.map { Item.bookCategory($0) })

    let items = viewProperties
      .sorted(by: sortOrder.sortFunction)
      .map {
        Item.page($0)
      }
    for item in items {
      bookSection.append([item], to: item.bookCategory.flatMap({ Item.bookCategory($0) }))
    }
    Logger.shared.debug("Generating snapshot with \(items.count) entries")
    return (snapshot, bookSection)
  }
}

private extension CGFloat {
  func roundedToScreenScale(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> CGFloat {
    let scale: CGFloat = 1.0 / UIScreen.main.scale
    return scale * (self / scale).rounded(rule)
  }
}

private extension PersonNameComponents {
  func compare(to other: PersonNameComponents) -> ComparisonResult {
    if let familyName = self.familyName, let otherFamilyName = other.familyName {
      let result = familyName.compare(otherFamilyName, options: [.diacriticInsensitive, .caseInsensitive])
      if result != .orderedSame { return result }
    }
    if let givenName = self.givenName, let otherGivenName = other.givenName {
      return givenName.compare(otherGivenName)
    }
    return .orderedSame
  }
}

extension Optional: Comparable where Wrapped == PersonNameComponents {
  public static func < (lhs: Wrapped?, rhs: Wrapped?) -> Bool {
    switch (lhs, rhs) {
    case (.none, .some):
      // No name before name
      return true
    case (.some, .none):
      return false
    case (.none, .none):
      return false
    case (.some(let lhs), .some(let rhs)):
      return lhs.compare(to: rhs) == .orderedAscending
    }
  }
}
