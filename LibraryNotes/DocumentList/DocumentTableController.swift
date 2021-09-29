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

    self.dataSource = BookCollectionViewDataSource(collectionView: collectionView, coverImageCache: coverImageCache, database: database)

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

  public var noteIdentifiers: [NoteIdentifierRecord] = [] {
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

  public func performUpdates(animated: Bool) {
    let filteredRecordIdentifiers = noteIdentifiers
    let selectedItems = collectionView.indexPathsForSelectedItems?.compactMap { dataSource.itemIdentifier(for: $0) }
    var collapsedSections = Set<BookSection>()
    for section in BookSection.bookSections {
      let sectionSnapshot = dataSource.snapshot(for: section)
      if let firstItem = sectionSnapshot.rootItems.first, !sectionSnapshot.isExpanded(firstItem) {
        collapsedSections.insert(section)
      }
    }

    isPerformingUpdates = true
    dataSource.apply(BookCollectionViewSnapshot(), animatingDifferences: animated) {
      self.isPerformingUpdates = false
    }
    let partitions = noteIdentifiers.bookSectionPartitions
    for section in BookSection.bookSections {
      if var sectionSnapshot = sectionSnapshot(for: section, partitions: partitions, identifiers: noteIdentifiers) {
        sectionSnapshot.collapseSections(in: collapsedSections)
        dataSource.apply(sectionSnapshot, to: section, animatingDifferences: animated)
      }
    }
    if let otherItems = sectionSnapshot(for: .other, partitions: partitions, identifiers: noteIdentifiers) {
      dataSource.apply(otherItems, to: .other, animatingDifferences: animated)
    }
    selectedItems?.forEach { item in
      guard let indexPath = dataSource.indexPath(for: item) else { return }
      collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
    }
    delegate?.documentTableController(self, didUpdateWithNoteCount: filteredRecordIdentifiers.count)
  }

  func sectionSnapshot(for section: BookSection, partitions: [BookSection: Range<Int>], identifiers: [NoteIdentifierRecord]) -> NSDiffableDataSourceSectionSnapshot<BookCollectionViewItem>? {
    guard let range = partitions[section], !range.isEmpty else {
      return nil
    }
    var bookSection = NSDiffableDataSourceSectionSnapshot<BookCollectionViewItem>()
    let headerItem = BookCollectionViewItem.header(section, range.count)
    let items: [BookCollectionViewItem] = identifiers[range].map { .book($0.noteIdentifier) }
    bookSection.append([headerItem])
    bookSection.append(items, to: headerItem)
    bookSection.expand([headerItem])
    return bookSection
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

  fileprivate func availableItemActionConfigurations(_ noteIdentifier: Note.Identifier) -> [BookAction] {
    let actions: [BookAction?] = [
      .studyItem(noteIdentifier, sessionGenerator: sessionGenerator, delegate: delegate),
      .moveItemToWantToRead(noteIdentifier, in: database),
      .moveItemToCurrentlyReading(noteIdentifier, in: database),
      .moveItemToRead(noteIdentifier, in: database),
      .deleteItem(noteIdentifier, in: database),
    ]
    return actions.compactMap { $0 }
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
    case .book(let noteIdentifier):
      delegate?.showPage(with: noteIdentifier, shiftFocus: shiftFocus)
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
    return dataSource.indexPath(for: .book(noteIdentifier))
  }

  func selectFirstNote() {
    let firstNote = dataSource.snapshot().itemIdentifiers.first(where: { if case .book = $0 { return true } else { return false } })
    if let firstNote = firstNote, case .book(let noteIdentifier) = firstNote {
      delegate?.showPage(with: noteIdentifier, shiftFocus: false)
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
      refreshControl.endRefreshing()
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
