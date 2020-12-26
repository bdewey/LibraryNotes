//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import Combine
import Logging
import UIKit

/// Knows how to perform key actions with the document
public protocol DocumentTableControllerDelegate: AnyObject {
  /// Shows a TextEditViewController in the detail view.
  func showDetailViewController(_ detailViewController: UIViewController)
  /// Initiates studying.
  func presentStudySessionViewController(for studySession: StudySession)
  func documentTableDidDeleteDocument(with noteIdentifier: Note.Identifier)
  func showAlert(_ alertMessage: String)
  func showPage(with noteIdentifier: Note.Identifier)
  func showWebPage(url: URL)
  func documentTableController(_ documentTableController: DocumentTableController, didUpdateWithNoteCount noteCount: Int)
}

/// Given a notebook, this class can manage a table that displays the hashtags and pages of that notebook.
public final class DocumentTableController: NSObject {
  /// Designated initializer.
  public init(
    tableView: UITableView,
    database: NoteDatabase,
    delegate: DocumentTableControllerDelegate
  ) {
    self.database = database
    self.delegate = delegate
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "web")
    tableView.register(DocumentTableViewCell.self, forCellReuseIdentifier: ReuseIdentifiers.documentCell)
    self.dataSource = DataSource(tableView: tableView) { (tableView, indexPath, item) -> UITableViewCell? in
      switch item {
      case .page(let viewProperties):
        return DocumentTableController.cell(
          tableView: tableView,
          indexPath: indexPath,
          viewProperties: viewProperties
        )
      case .webPage(let url):
        let cell = tableView.dequeueReusableCell(withIdentifier: "web", for: indexPath)
        cell.textLabel?.text = "Open \(url)"
        return cell
      }
    }
    super.init()
    tableView.delegate = self
    tableView.refreshControl = refreshControl
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
    dataSource.snapshot().numberOfItems(inSection: .documents)
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

  /// Convenience to construct an appropriately-configured UITableView to show our data.
  public static func makeTableView() -> UITableView {
    let tableView = UITableView(frame: .zero, style: .plain)
    tableView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    tableView.backgroundColor = .grailBackground
    tableView.accessibilityIdentifier = "document-list"
    tableView.estimatedRowHeight = 72
    tableView.separatorStyle = .none
    return tableView
  }

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

  /// Delegate.
  private(set) weak var delegate: DocumentTableControllerDelegate?

  private let database: NoteDatabase
  private var cardsPerDocument = [Note.Identifier: Int]() {
    didSet {
      needsPerformUpdates = true
    }
  }

  private let dataSource: DataSource

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

// MARK: - UITableViewDelegate

extension DocumentTableController: UITableViewDelegate {
  public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
    switch item {
    case .page(let viewProperties):
      delegate?.showPage(with: viewProperties.pageKey)
    case .webPage(let url):
      delegate?.showWebPage(url: url)
    }
  }

  public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
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
    let noteProperties: Note.Metadata
    /// How many cards are eligible for study in this page (dynamic and not serialized)
    var cardCount: Int
  }

  enum ReuseIdentifiers {
    static let documentCell = "DocumentCollectionViewCell"
    static let hashtag = "HashtagCell"
  }

  static func cell(
    tableView: UITableView,
    indexPath: IndexPath,
    viewProperties: ViewProperties
  ) -> UITableViewCell? {
    guard
      let cell = tableView.dequeueReusableCell(
        withIdentifier: ReuseIdentifiers.documentCell,
        for: indexPath
      ) as? DocumentTableViewCell
    else {
      preconditionFailure("Forgot to register the right kind of cell")
    }
    let title = ParsedAttributedString(string: viewProperties.noteProperties.title, settings: .plainText(textStyle: .headline))
    cell.titleLabel.attributedText = title
    cell.accessibilityLabel = viewProperties.noteProperties.title
    let detailString = viewProperties.noteProperties.hashtags.joined(separator: ", ")
    cell.detailLabel.attributedText = NSAttributedString(
      string: detailString,
      attributes: [
        .font: UIFont.preferredFont(forTextStyle: .subheadline),
        .foregroundColor: UIColor.secondaryLabel,
      ]
    )
    cell.documentModifiedTimestamp = viewProperties.noteProperties.timestamp
    let font = UIFont.preferredFont(forTextStyle: .headline)
    cell.verticalPadding = max(20, font.lineHeight.roundedToScreenScale() * 1.5)
    return cell
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
        return $0.value.hashtags.contains(hashtag)
      }

    let objects = propertiesFilteredByHashtag
      .compactMap { tuple in
        ViewProperties(pageKey: tuple.key, noteProperties: tuple.value, cardCount: cardsPerDocument[tuple.key, default: 0])
      }
      .sorted(
        by: { $0.noteProperties.timestamp > $1.noteProperties.timestamp }
      )
      .map {
        Item.page($0)
      }
    snapshot.appendItems(objects)
    Logger.shared.debug("Generating snapshot with \(objects.count) entries: \(objects)")
    return snapshot
  }
}

private extension CGFloat {
  func roundedToScreenScale(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> CGFloat {
    let scale: CGFloat = 1.0 / UIScreen.main.scale
    return scale * (self / scale).rounded(rule)
  }
}
