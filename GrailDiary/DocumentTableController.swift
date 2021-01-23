// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Combine
import Logging
import UIKit

/// Knows how to perform key actions with the document
public protocol DocumentTableControllerDelegate: AnyObject {
  /// Initiates studying.
  func presentStudySessionViewController(for studySession: StudySession)
  func documentTableDidDeleteDocument(with noteIdentifier: Note.Identifier)
  func showAlert(_ alertMessage: String)
  func showPage(with noteIdentifier: Note.Identifier, shiftFocus: Bool)
  func showWebPage(url: URL, shiftFocus: Bool)
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

    let notebookPageRegistration = UICollectionView.CellRegistration<ClearBackgroundCell, Item> { cell, _, item in
      guard case .page(let viewProperties) = item else { return }
      var configuration = cell.defaultContentConfiguration()
      let title = ParsedAttributedString(string: viewProperties.noteProperties.title, settings: .plainText(textStyle: .headline))
      configuration.attributedText = title
      configuration.secondaryText = viewProperties.noteProperties.noteLinks.map { $0.targetTitle }.joined(separator: ", ")
      configuration.secondaryTextProperties.color = .secondaryLabel
      if viewProperties.hasLink {
        configuration.image = UIImage(systemName: "link")
      }

      let headlineFont = UIFont.preferredFont(forTextStyle: .headline)
      let verticalMargin = max(20, 1.5 * headlineFont.lineHeight.roundedToScreenScale())
      configuration.directionalLayoutMargins = .init(top: verticalMargin, leading: 0, bottom: verticalMargin, trailing: 0)
      cell.contentConfiguration = configuration
    }

    self.dataSource = UICollectionViewDiffableDataSource<DocumentSection, Item>(
      collectionView: collectionView,
      cellProvider: { (collectionView, indexPath, item) -> UICollectionViewCell? in
        switch item {
        case .webPage:
          return collectionView.dequeueConfiguredReusableCell(using: openWebPageRegistration, for: indexPath, item: item)
        case .page:
          return collectionView.dequeueConfiguredReusableCell(using: notebookPageRegistration, for: indexPath, item: item)
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
  public var filteredPageIdentifiers: Set<Note.Identifier>? {
    didSet {
      needsPerformUpdates = true
    }
  }

  /// If set, only show pages that contain this hashtag.
  public var filteredHashtag: String? {
    didSet {
      needsPerformUpdates = true
    }
  }

  /// If non-nil, the table view should show a cell representing this web page at the top of the table.
  public var webURL: URL? {
    didSet {
      needsPerformUpdates = true
    }
  }

  public func trailingSwipeActionsConfiguration(forRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    guard let item = dataSource.itemIdentifier(for: indexPath) else {
      return nil
    }
    var actions = [UIContextualAction]()
    switch item {
    case .page(let properties):
      let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { _, _, completion in
        try? self.database.deleteNote(noteIdentifier: properties.pageKey)
        try? self.database.flush()
        self.delegate?.documentTableDidDeleteDocument(with: properties.pageKey)
        completion(true)
      }
      deleteAction.image = UIImage(systemName: "trash")
      actions.append(deleteAction)
      if properties.cardCount > 0 {
        let studyAction = UIContextualAction(style: .normal, title: "Study") { _, _, completion in
          self.database.studySession(filter: { name, _ in name == properties.pageKey }, date: Date(), completion: {
            self.delegate?.presentStudySessionViewController(for: $0)
            completion(true)
          })
        }
        studyAction.image = UIImage(systemName: "rectangle.stack")
        studyAction.backgroundColor = UIColor.systemBlue
        actions.append(studyAction)
      }
    case .webPage:
      return nil
    }
    return UISwipeActionsConfiguration(actions: actions)
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

  private var databaseSubscription: AnyCancellable?

  public func startObservingDatabase() {
    databaseSubscription = database.notesDidChange
      .receive(on: DispatchQueue.main)
      .sink { [weak self] in
        self?.updateCardsPerDocument()
      }
    updateCardsPerDocument()
  }

  public func stopObservingDatabase() {
    databaseSubscription?.cancel()
    databaseSubscription = nil
  }

  public func performUpdates(animated: Bool) {
    let snapshot = DocumentTableController.snapshot(
      for: database,
      cardsPerDocument: cardsPerDocument,
      filteredHashtag: filteredHashtag,
      filteredPageIdentifiers: filteredPageIdentifiers,
      webURL: webURL
    )
    let reallyAnimate = animated && DocumentTableController.majorSnapshotDifferences(between: dataSource.snapshot(), and: snapshot)

    isPerformingUpdates = true
    dataSource.apply(snapshot, animatingDifferences: reallyAnimate) {
      self.isPerformingUpdates = false
    }
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
      case (.webPage, .webPage):
        continue
      default:
        return true
      }
    }
    return false
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

// MARK: - UITableViewDelegate

extension DocumentTableController: UICollectionViewDelegate {
  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
    switch item {
    case .page(let viewProperties):
      delegate?.showPage(with: viewProperties.pageKey, shiftFocus: true)
    case .webPage(let url):
      delegate?.showWebPage(url: url, shiftFocus: true)
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
    /// List of documents.
    case documents
  }

  enum Item: Hashable, CustomStringConvertible {
    case webPage(URL)
    case page(ViewProperties)

    var description: String {
      switch self {
      case .webPage(let url):
        return "Web page: \(url)"
      case .page(let viewProperties):
        return "Page \(viewProperties.pageKey)"
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

    // "Identity" for hashing & equality is just the pageKey

    func hash(into hasher: inout Hasher) {
      hasher.combine(pageKey)
    }

    static func == (lhs: ViewProperties, rhs: ViewProperties) -> Bool {
      lhs.pageKey == rhs.pageKey
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
      Logger.shared.info(
        "studySession.count = \(studySession.count). cardsPerDocument has \(self.cardsPerDocument.count) entries"
      )
    }
  }

  static func snapshot(
    for database: NoteDatabase,
    cardsPerDocument: [Note.Identifier: Int],
    filteredHashtag: String?,
    filteredPageIdentifiers: Set<Note.Identifier>?,
    webURL: URL?
  ) -> Snapshot {
    var snapshot = Snapshot()

    if let webURL = webURL {
      snapshot.appendSections([.webNavigation])
      snapshot.appendItems([.webPage(webURL)])
    }

    snapshot.appendSections([.documents])

    let propertiesFilteredByHashtag = database.allMetadata
      .filter {
        guard let filteredPageIdentifiers = filteredPageIdentifiers else { return true }
        return filteredPageIdentifiers.contains($0.key)
      }
      .filter {
        guard let hashtag = filteredHashtag else { return true }
        return $0.value.noteLinks.anySatisfy { hashtag.isPathPrefix(of: $0.targetTitle) }
      }

    let objects = propertiesFilteredByHashtag
      .compactMap { tuple in
        ViewProperties(pageKey: tuple.key, noteProperties: tuple.value, cardCount: cardsPerDocument[tuple.key, default: 0], hasLink: !tuple.value.contents.isEmpty)
      }
      .sorted(
        by: { $0.noteProperties.modifiedTimestamp > $1.noteProperties.modifiedTimestamp }
      )
      .map {
        Item.page($0)
      }
    snapshot.appendItems(objects)
    Logger.shared.debug("Generating snapshot with \(objects.count) entries")
    return snapshot
  }
}

private extension CGFloat {
  func roundedToScreenScale(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> CGFloat {
    let scale: CGFloat = 1.0 / UIScreen.main.scale
    return scale * (self / scale).rounded(rule)
  }
}
