// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import Combine
import MiniMarkdown
import UIKit

/// Knows how to perform key actions with the document
public protocol DocumentTableControllerDelegate: AnyObject {
  /// Shows a TextEditViewController in the detail view.
  func showDetailViewController(_ detailViewController: UIViewController)
  /// Initiates studying.
  func presentStudySessionViewController(for studySession: StudySession)
  func documentSearchResultsDidSelectHashtag(_ hashtag: String)
  func documentTableDidDeleteDocument(with noteIdentifier: Note.Identifier)
  func showAlert(_ alertMessage: String)
  func showPage(with noteIdentifier: Note.Identifier)
  func documentTableDidRequestReview()
  func documentTableController(_ documentTableController: DocumentTableController, didUpdateWithNoteCount noteCount: Int)
}

/// Given a notebook, this class can manage a table that displays the hashtags and pages of that notebook.
public final class DocumentTableController: NSObject {
  /// Designated initializer.
  public init(
    tableView: UITableView,
    notebook: NoteStorage,
    delegate: DocumentTableControllerDelegate
  ) {
    self.notebook = notebook
    self.delegate = delegate
    tableView.register(DocumentTableViewCell.self, forCellReuseIdentifier: ReuseIdentifiers.documentCell)
    tableView.register(ButtonCell.self, forCellReuseIdentifier: ReuseIdentifiers.review)
    let titleRenderer = RenderedMarkdown.makeTitleRenderer()
    self.dataSource = DataSource(tableView: tableView) { (tableView, indexPath, item) -> UITableViewCell? in
      switch item {
      case .page(let viewProperties):
        return DocumentTableController.cell(
          tableView: tableView,
          indexPath: indexPath,
          viewProperties: viewProperties,
          titleRenderer: titleRenderer
        )
      case .hashtag(let hashtag):
        var cell: UITableViewCell! = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifiers.hashtag)
        if cell == nil {
          cell = UITableViewCell(style: .default, reuseIdentifier: ReuseIdentifiers.hashtag)
        }
        cell.backgroundColor = .secondarySystemBackground
        cell.textLabel?.text = hashtag
        return cell
      case .review(let count):
        // swiftlint:disable:next force_cast
        let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifiers.review, for: indexPath) as! ButtonCell
        cell.backgroundColor = .grailBackground
        cell.button.setTitle("Review (\(count))", for: .normal)
        cell.button.contentHorizontalAlignment = .left
        cell.button.isEnabled = (count > 0) // swiftlint:disable:this empty_count
        cell.button.accessibilityIdentifier = "study-button"
        cell.tapHandler = { [weak delegate] in
          delegate?.documentTableDidRequestReview()
        }
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

  @objc private func didTapReview() {
    delegate?.documentTableDidRequestReview()
  }

  public var challengeDueDate = Date() {
    didSet {
      updateCardsPerDocument()
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

  /// The number of items that the learner can review.
  public var reviewItemCount: Int = 0 {
    didSet {
      needsPerformUpdates = true
    }
  }

  /// Delegate.
  private(set) weak var delegate: DocumentTableControllerDelegate?

  private let notebook: NoteStorage
  private var cardsPerDocument = [Note.Identifier: Int]() {
    didSet {
      needsPerformUpdates = true
    }
  }

  private let dataSource: DataSource

  private var notebookSubscription: AnyCancellable?

  public func startObservingNotebook() {
    notebookSubscription = notebook.notesDidChange
      .receive(on: DispatchQueue.main)
      .sink { [weak self] in
        self?.updateCardsPerDocument()
      }
    updateCardsPerDocument()
  }

  public func stopObservingNotebook() {
    notebookSubscription?.cancel()
    notebookSubscription = nil
  }

  public func performUpdates(animated: Bool) {
    let snapshot = DocumentTableController.snapshot(
      for: notebook,
      cardsPerDocument: cardsPerDocument,
      filteredHashtag: filteredHashtag,
      filteredPageIdentifiers: filteredPageIdentifiers,
      reviewItemCount: reviewItemCount
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
    // side and the right hand side, in order, have matching hashtags or page identifiers.
    // In that case, whatever difference that exists between the snapshots is "minor"
    let itemsToCompare = zip(lhs.itemIdentifiers, rhs.itemIdentifiers)
    for (lhsItem, rhsItem) in itemsToCompare {
      switch (lhsItem, rhsItem) {
      case (.page(let lhsPage), .page(let rhsPage)):
        if lhsPage.pageKey != rhsPage.pageKey {
          return true
        }
      case (.hashtag(let lhsHashtag), .hashtag(let rhsHashtag)):
        if lhsHashtag != rhsHashtag {
          return true
        }
      case (.review, .review):
        // These items do nothing to affect "major differences"
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
    case .hashtag(let hashtag):
      delegate?.documentSearchResultsDidSelectHashtag(hashtag)
    case .review:
      delegate?.documentTableDidRequestReview()
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
        try? self.notebook.deleteNote(noteIdentifier: properties.pageKey)
        try? self.notebook.flush()
        self.delegate?.documentTableDidDeleteDocument(with: properties.pageKey)
        completion(true)
      }
      deleteAction.image = UIImage(systemName: "trash")
      actions.append(deleteAction)
      if properties.cardCount > 0 {
        let studyAction = UIContextualAction(style: .normal, title: "Study") { _, _, completion in
          self.notebook.studySession(filter: { name, _ in name == properties.pageKey }, date: Date(), completion: {
            self.delegate?.presentStudySessionViewController(for: $0)
            completion(true)
          })
        }
        studyAction.image = UIImage(systemName: "rectangle.stack")
        studyAction.backgroundColor = UIColor.systemBlue
        actions.append(studyAction)
      }
    case .hashtag, .review:
      // NOTHING
      break
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
    /// Buttons to quiz/review on notebook contents
    case review
    /// List of documents.
    case documents
  }

  enum Item: Hashable, CustomStringConvertible {
    case hashtag(String)
    case review(Int)
    case page(ViewProperties)

    var description: String {
      switch self {
      case .hashtag(let hashtag):
        return hashtag
      case .review:
        return "Review"
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
    static let review = "ReviewCell"
  }

  static func cell(
    tableView: UITableView,
    indexPath: IndexPath,
    viewProperties: ViewProperties,
    titleRenderer: RenderedMarkdown
  ) -> UITableViewCell? {
    guard
      let cell = tableView.dequeueReusableCell(
        withIdentifier: ReuseIdentifiers.documentCell,
        for: indexPath
      ) as? DocumentTableViewCell
    else {
      preconditionFailure("Forgot to register the right kind of cell")
    }
    titleRenderer.markdown = viewProperties.noteProperties.title
    cell.titleLabel.attributedText = titleRenderer.attributedString
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
    if let font = titleRenderer.defaultAttributes[.font] as? UIFont {
      cell.verticalPadding = max(20, font.lineHeight.roundedToScreenScale() * 1.5)
    }
    return cell
  }

  @objc func handleRefreshControl() {
    notebook.refresh { _ in
      self.refreshControl.endRefreshing()
    }
  }

  func updateCardsPerDocument() {
    notebook.studySession(filter: nil, date: challengeDueDate) { studySession in
      self.cardsPerDocument = studySession
        .reduce(into: [Note.Identifier: Int]()) { cardsPerDocument, card in
          cardsPerDocument[card.noteIdentifier] = cardsPerDocument[card.noteIdentifier, default: 0] + 1
        }
      DDLogInfo(
        "studySession.count = \(studySession.count). " +
          "cardsPerDocument has \(self.cardsPerDocument.count) entries"
      )
    }
  }

  static func snapshot(
    for notebook: NoteStorage,
    cardsPerDocument: [Note.Identifier: Int],
    filteredHashtag: String?,
    filteredPageIdentifiers: Set<Note.Identifier>?,
    reviewItemCount: Int
  ) -> Snapshot {
    var snapshot = Snapshot()
    snapshot.appendSections([.review])
    snapshot.appendItems([.review(reviewItemCount)])
    snapshot.appendSections([.documents])

    let propertiesFilteredByHashtag = notebook.allMetadata
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
    DDLogDebug("Generating snapshot with \(objects.count) entries: \(objects)")
    return snapshot
  }
}

private extension CGFloat {
  func roundedToScreenScale(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> CGFloat {
    let scale: CGFloat = 1.0 / UIScreen.main.scale
    return scale * (self / scale).rounded(rule)
  }
}
