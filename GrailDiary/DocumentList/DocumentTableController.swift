// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Combine
import Logging
import TextMarkupKit
import UIKit

/// Knows how to perform key actions with the document
@MainActor
public protocol DocumentTableControllerDelegate: AnyObject {
  /// Initiates studying.
  func presentStudySessionViewController(for studySession: StudySession)
  func documentTableDidDeleteDocument(with noteIdentifier: Note.Identifier)
  func showAlert(_ alertMessage: String)
  func showPage(with noteIdentifier: Note.Identifier, shiftFocus: Bool)
  func showQuotes(quotes: [ContentIdentifier], shiftFocus: Bool)
  func documentTableController(_ documentTableController: DocumentTableController, didUpdateWithNoteCount noteCount: Int)
}

/// Given a notebook, this class can manage a table that displays the hashtags and pages of that notebook.
@MainActor
public final class DocumentTableController: NSObject {
  /// Designated initializer.
  public init(
    collectionView: UICollectionView,
    database: NoteDatabase,
    coverImageCache: CoverImageCache,
    sessionGenerator: SessionGenerator,
    delegate: DocumentTableControllerDelegate
  ) {
    self.collectionView = collectionView
    self.database = database
    let coverImageCache = coverImageCache
    self.coverImageCache = coverImageCache
    self.sessionGenerator = sessionGenerator
    self.delegate = delegate

    self.dataSource = BookCollectionViewDataSource(collectionView: collectionView, coverImageCache: coverImageCache)

    super.init()
    collectionView.delegate = self
    if FileManager.default.isUbiquitousItem(at: database.fileURL) {
      collectionView.refreshControl = refreshControl
    }
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

  public var bookCount: Int {
    var total = 0
    for section in BookSection.bookSections {
      total += dataSource.snapshot(for: section).bookCount
    }
    return total
  }

  /// All note identifiers currently displayed in the table.
  public var noteIdentifiers: [Note.Identifier] {
    dataSource.snapshot().itemIdentifiers.compactMap { $0.noteIdentifier }
  }

  private var needsPerformUpdates = false
  private var isPerformingUpdates = false

  @MainActor
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

  public var bookNoteMetadata: [String: BookNoteMetadata] = [:] {
    didSet {
      updateCardsPerDocument()
      needsPerformUpdates = true
    }
  }

  /// Delegate.
  private(set) weak var delegate: DocumentTableControllerDelegate?

  private let collectionView: UICollectionView
  private let database: NoteDatabase
  private let coverImageCache: CoverImageCache
  private let sessionGenerator: SessionGenerator
  private var cardsPerDocument = [Note.Identifier: Int]() {
    didSet {
      needsPerformUpdates = true
    }
  }

  private let dataSource: BookCollectionViewDataSource

  var currentSortOrder = BookCollectionViewSnapshotBuilder.SortOrder.creationTimestamp {
    didSet {
      needsPerformUpdates = true
    }
  }

  private var snapshotParameters: BookCollectionViewSnapshotBuilder?

  @MainActor
  public func performUpdates(animated: Bool) {
    let filteredRecordIdentifiers = bookNoteMetadata
      .map { $0.key }
      .filter { filteredPageIdentifiers?.contains($0) ?? true }
    let newSnapshotBuilder = BookCollectionViewSnapshotBuilder(
      records: Set(filteredRecordIdentifiers),
      cardsPerDocument: cardsPerDocument,
      sortOrder: currentSortOrder
    )
    let selectedItems = collectionView.indexPathsForSelectedItems?.compactMap { dataSource.itemIdentifier(for: $0) }
    let reallyAnimate = animated && (newSnapshotBuilder != snapshotParameters)
    var collapsedSections = Set<BookSection>()
    for section in BookSection.bookSections {
      let sectionSnapshot = dataSource.snapshot(for: section)
      if let firstItem = sectionSnapshot.rootItems.first, !sectionSnapshot.isExpanded(firstItem) {
        collapsedSections.insert(section)
      }
    }

    isPerformingUpdates = true
    dataSource.apply(BookCollectionViewSnapshot(), animatingDifferences: reallyAnimate) {
      self.isPerformingUpdates = false
    }
    let categorizedItems = newSnapshotBuilder.categorizeMetadataRecords(bookNoteMetadata)
    for section in BookSection.bookSections {
      if var sectionSnapshot = newSnapshotBuilder.sectionSnapshot(for: section, categorizedItems: categorizedItems) {
        sectionSnapshot.collapseSections(in: collapsedSections)
        dataSource.apply(sectionSnapshot, to: section, animatingDifferences: reallyAnimate)
      }
    }
    if let otherItems = newSnapshotBuilder.sectionSnapshot(for: .other, categorizedItems: categorizedItems) {
      dataSource.apply(otherItems, to: .other, animatingDifferences: reallyAnimate)
    }
    selectedItems?.forEach { item in
      guard let indexPath = dataSource.indexPath(for: item) else { return }
      collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
    }
    delegate?.documentTableController(self, didUpdateWithNoteCount: filteredRecordIdentifiers.count)
    snapshotParameters = newSnapshotBuilder
  }
}

// MARK: - Swipe & context menu actions

extension DocumentTableController {
  public func trailingSwipeActionsConfiguration(forRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    guard let item = dataSource.itemIdentifier(for: indexPath) else {
      return nil
    }
    switch item {
    case .book(let properties):
      let actions = availableItemActionConfigurations(properties).reversed().compactMap { $0.asContextualAction() }
      return UISwipeActionsConfiguration(actions: actions)
    case .header:
      return nil
    }
  }

  fileprivate func availableItemActionConfigurations(_ viewProperties: BookViewProperties) -> [ActionConfiguration] {
    let actions: [ActionConfiguration?] = [
      .studyItem(viewProperties, sessionGenerator: sessionGenerator, delegate: delegate),
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
    var availableAsSwipeAction = true
    var handler: () throws -> Void

    func asContextualAction() -> UIContextualAction? {
      guard availableAsSwipeAction else { return nil }
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

    static func deleteItem(_ viewProperties: BookViewProperties, in database: NoteDatabase) -> ActionConfiguration? {
      return ActionConfiguration(title: "Delete", image: UIImage(systemName: "trash"), destructive: true) {
        if viewProperties.noteProperties.folder == PredefinedFolder.recentlyDeleted.rawValue {
          try database.deleteNote(noteIdentifier: viewProperties.pageKey)
        } else {
          try database.updateNote(noteIdentifier: viewProperties.pageKey, updateBlock: { note in
            var note = note
            note.metadata.folder = PredefinedFolder.recentlyDeleted.rawValue
            return note
          })
        }
      }
    }

    static func moveItemToRead(_ viewProperties: BookViewProperties, in database: NoteDatabase) -> ActionConfiguration? {
      guard viewProperties.bookCategory != .read else {
        return nil
      }
      return ActionConfiguration(title: "Read", image: UIImage(systemName: "books.vertical"), backgroundColor: .grailTint, availableAsSwipeAction: false) {
        try database.updateNote(noteIdentifier: viewProperties.pageKey, updateBlock: { note -> Note in
          var note = note
          if var book = note.metadata.book {
            let today = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            if book.readingHistory == nil {
              book.readingHistory = ReadingHistory()
            }
            book.readingHistory!.finishReading(finishDate: today)
            note.metadata.book = book
          }
          return note
        })
        Logger.shared.info("Moved \(viewProperties.pageKey) to 'read'")
      }
    }

    static func moveItemToCurrentlyReading(_ viewProperties: BookViewProperties, in database: NoteDatabase) -> ActionConfiguration? {
      guard viewProperties.bookCategory != .currentlyReading else {
        return nil
      }
      return ActionConfiguration(title: "Currently Reading", image: UIImage(systemName: "book"), backgroundColor: .grailTint, availableAsSwipeAction: false) {
        try database.updateNote(noteIdentifier: viewProperties.pageKey, updateBlock: { note -> Note in
          var note = note
          if var book = note.metadata.book {
            let today = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            if book.readingHistory == nil {
              book.readingHistory = ReadingHistory()
            }
            book.readingHistory!.startReading(startDate: today)
            note.metadata.book = book
          }
          return note
        })
        Logger.shared.info("Moved \(viewProperties.pageKey) to 'read'")
      }
    }

    static func moveItemToWantToRead(_ viewProperties: BookViewProperties, in database: NoteDatabase) -> ActionConfiguration? {
      guard viewProperties.bookCategory != .wantToRead else {
        return nil
      }
      return ActionConfiguration(title: "Want to Read", image: UIImage(systemName: "list.star"), backgroundColor: .systemIndigo, availableAsSwipeAction: false) {
        try database.updateNote(noteIdentifier: viewProperties.pageKey, updateBlock: { note -> Note in
          var note = note
          if var book = note.metadata.book {
            book.readingHistory = nil
            note.metadata.book = book
          }
          return note
        })
        Logger.shared.info("Moved \(viewProperties.pageKey) to 'want to read'")
      }
    }

    static func studyItem(
      _ viewProperties: BookViewProperties,
      sessionGenerator: SessionGenerator,
      delegate: DocumentTableControllerDelegate?
    ) -> ActionConfiguration? {
      if viewProperties.cardCount == 0 { return nil }
      return ActionConfiguration(title: "Study", image: UIImage(systemName: "rectangle.stack"), backgroundColor: .systemBlue) {
        Task {
          let studySession = try await sessionGenerator.studySession(filter: { name, _ in name == viewProperties.pageKey }, date: Date())
          await delegate?.presentStudySessionViewController(for: studySession)
        }
      }
    }
  }
}

// MARK: - Manage selection / keyboard

public extension DocumentTableController {
  func selectItemAtIndexPath(_ indexPath: IndexPath, shiftFocus: Bool) -> Bool {
    guard
      let item = dataSource.itemIdentifier(for: indexPath),
      let section = dataSource.sectionIdentifier(for: indexPath.section)
    else {
      return false
    }
    switch item {
    case .book(let viewProperties):
      delegate?.showPage(with: viewProperties.pageKey, shiftFocus: shiftFocus)
      return true
    case .header:
      var bookSection = dataSource.snapshot(for: section)
      if bookSection.isExpanded(item) {
        bookSection.collapse([item])
      } else {
        bookSection.expand([item])
      }
      dataSource.apply(bookSection, to: section)
      return false
    }
  }

  func indexPath(noteIdentifier: Note.Identifier) -> IndexPath? {
    let item = dataSource.snapshot().itemIdentifiers.first { item in
      if case .book(let viewProperties) = item {
        return viewProperties.pageKey == noteIdentifier
      } else {
        return false
      }
    }
    guard let item = item else { return nil }
    return dataSource.indexPath(for: item)
  }

  func selectFirstNote() {
    let firstNote = dataSource.snapshot().itemIdentifiers.first(where: { $0.bookCategory != nil })
    if let firstNote = firstNote, case .book(let viewProperties) = firstNote {
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
      _ = selectItemAtIndexPath(nextIndexPath, shiftFocus: false)
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
      _ = selectItemAtIndexPath(previousIndexPath, shiftFocus: false)
    }
  }
}

// MARK: - UICollectionViewDelegate

extension DocumentTableController: UICollectionViewDelegate {
  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    if !selectItemAtIndexPath(indexPath, shiftFocus: true) {
      collectionView.deselectItem(at: indexPath, animated: false)
    }
  }

  public func collectionView(
    _ collectionView: UICollectionView,
    contextMenuConfigurationForItemAt indexPath: IndexPath,
    point: CGPoint
  ) -> UIContextMenuConfiguration? {
    guard
      let item = dataSource.itemIdentifier(for: indexPath),
      case .book(let itemProperties) = item
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
  @objc func handleRefreshControl() {
    do {
      try database.refresh()
    } catch {
      Logger.shared.error("Unexpected error refreshing file: \(error)")
    }
    Task {
      await Task.sleep(1000000000)
      await refreshControl.endRefreshing()
    }
  }

  func updateCardsPerDocument() {
    Task {
      let studySession = try await sessionGenerator.studySession(filter: nil, date: dueDate)
      cardsPerDocument = studySession
        .reduce(into: [Note.Identifier: Int]()) { cardsPerDocument, card in
          cardsPerDocument[card.noteIdentifier] = cardsPerDocument[card.noteIdentifier, default: 0] + 1
        }
      Logger.shared.debug(
        "studySession.count = \(studySession.count). cardsPerDocument has \(self.cardsPerDocument.count) entries"
      )
    }
  }
}
