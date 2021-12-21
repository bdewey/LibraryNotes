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

typealias BookCollectionViewSnapshot = NSDiffableDataSourceSnapshot<BookSection, BookCollectionViewItem>

/// Given a notebook, this class can manage a table that displays the hashtags and pages of that notebook.
@MainActor
public final class DocumentTableController: NSObject {
  /// Designated initializer.
  public init(
    collectionView: UICollectionView,
    database: NoteDatabase,
    coverImageCache: CoverImageCache,
    delegate: DocumentTableControllerDelegate
  ) {
    self.collectionView = collectionView
    self.database = database
    let coverImageCache = coverImageCache
    self.coverImageCache = coverImageCache
    self.delegate = delegate

    self.dataSource = BookCollectionViewDataSource(collectionView: collectionView, coverImageCache: coverImageCache, database: database)

    super.init()
    collectionView.delegate = self
    if FileManager.default.isUbiquitousItem(at: database.fileURL) {
      collectionView.refreshControl = refreshControl
    }
    changedNoteSubscription = database.updatedValuesPublisher
      .filter({ $0.0.key == NoteDatabaseKey.metadata.rawValue })
      .map({ $0.0.scope })
      .receive(on: DispatchQueue.main)
      .sink { [weak self] noteIdentifier in
        guard let self = self else { return }
        var snapshot = self.dataSource.snapshot()
        if snapshot.indexOfItem(.book(noteIdentifier)) != nil {
          snapshot.reconfigureItems([.book(noteIdentifier)])
          self.dataSource.apply(snapshot, animatingDifferences: false)
        }
      }
  }

  public var dueDate = Date()

  public var bookCount: Int {
    var total = 0
    for section in BookSection.bookSections {
      total += dataSource.snapshot(for: section).bookCount
    }
    return total
  }

  private lazy var refreshControl: UIRefreshControl = {
    let control = UIRefreshControl()
    control.addTarget(self, action: #selector(handleRefreshControl), for: .valueChanged)
    return control
  }()

  public var noteIdentifiers: [NoteIdentifierRecord] = [] {
    didSet {
      performUpdates(animated: true)
    }
  }

  /// Delegate.
  private(set) weak var delegate: DocumentTableControllerDelegate?

  private let collectionView: UICollectionView
  private let database: NoteDatabase
  private let coverImageCache: CoverImageCache

  private let dataSource: BookCollectionViewDataSource

  private var changedNoteSubscription: AnyCancellable?

  @MainActor
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

    let partitions = noteIdentifiers.bookSectionPartitions
    for section in BookSection.bookSections {
      if var sectionSnapshot = sectionSnapshot(for: section, partitions: partitions, identifiers: noteIdentifiers) {
        sectionSnapshot.collapseSections(in: collapsedSections)
        dataSource.apply(sectionSnapshot, to: section, animatingDifferences: animated)
      } else {
        dataSource.apply(.init(), to: section, animatingDifferences: animated)
      }
    }
    if let otherItems = sectionSnapshot(for: .other, partitions: partitions, identifiers: noteIdentifiers) {
      dataSource.apply(otherItems, to: .other, animatingDifferences: animated)
    } else {
      dataSource.apply(.init(), to: .other, animatingDifferences: animated)
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
      .studyItem(noteIdentifier, database: database, delegate: delegate),
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
      try? await Task.sleep(nanoseconds: 1_000_000_000)
      refreshControl.endRefreshing()
    }
  }
}
