// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import MiniMarkdown
import UIKit

/// Knows how to perform key actions with the document
protocol DocumentTableControllerDelegate: AnyObject {
  /// Shows a TextEditViewController in the detail view.
  func showDetailViewController(_ detailViewController: UIViewController)
  /// Initiates studying.
  func presentStudySessionViewController(for studySession: StudySession)
  func documentSearchResultsDidSelectHashtag(_ hashtag: String)
  func documentTableDidDeleteDocument(with pageIdentifier: String)
}

/// Given a notebook, this class can manage a table that displays the hashtags and pages of that notebook.
public final class DocumentTableController: NSObject {
  /// Designated initializer.
  public init(
    tableView: UITableView,
    notebook: NoteArchiveDocument
  ) {
    self.notebook = notebook
    tableView.register(DocumentTableViewCell.self, forCellReuseIdentifier: ReuseIdentifiers.documentCell)
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
      }
    }
    super.init()
    tableView.delegate = self
    updateCardsPerDocument()
  }

  /// Convenience to construct an appropriately-configured UITableView to show our data.
  public static func makeTableView() -> UITableView {
    let tableView = UITableView(frame: .zero, style: .plain)
    tableView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    tableView.backgroundColor = UIColor.systemBackground
    tableView.accessibilityIdentifier = "document-list"
    tableView.estimatedRowHeight = 72
    tableView.separatorStyle = .none
    return tableView
  }

  /// If non-nil, only pages with these identifiers will be shown.
  public var filteredPageIdentifiers: Set<String>? {
    didSet {
      performUpdates(animated: true)
    }
  }

  /// If not empty, show a list of hashtags as a section in the table.
  public var hashtags: [String] = [] {
    didSet {
      performUpdates(animated: true)
    }
  }

  /// If set, only show pages that contain this hashtag.
  public var filteredHashtag: String? {
    didSet {
      performUpdates(animated: true)
    }
  }

  /// Delegate.
  internal weak var delegate: DocumentTableControllerDelegate?

  private let notebook: NoteArchiveDocument
  private var cardsPerDocument = [String: Int]() {
    didSet {
      performUpdates(animated: true)
    }
  }
  private let dataSource: DataSource

  public func startObservingNotebook() {
    notebook.addObserver(self)
    updateCardsPerDocument()
  }

  public func stopObservingNotebook() {
    notebook.removeObserver(self)
  }

  public func performUpdates(animated: Bool) {
    let snapshot = DocumentTableController.snapshot(
      for: notebook,
      cardsPerDocument: cardsPerDocument,
      hashtags: hashtags,
      filteredHashtag: filteredHashtag,
      filteredPageIdentifiers: filteredPageIdentifiers
    )
    let reallyAnimate = animated && DocumentTableController.majorSnapshotDifferences(between: dataSource.snapshot(), and: snapshot)
    dataSource.apply(snapshot, animatingDifferences: reallyAnimate)
  }

  /// Compares lhs & rhs to see if the differences are worth animating.
  private static func majorSnapshotDifferences(between lhs: Snapshot, and rhs: Snapshot) -> Bool {
    if lhs.numberOfItems != rhs.numberOfItems {
      return true
    }
    // The only way to get through this loop and return false is if every item in the left hand
    // side and the right hand side, in order, have matching hashtags or page identifiers.
    // In that case, whatever difference that exists between the snapshots is "minor"
    for (lhsItem, rhsItem) in zip(lhs.itemIdentifiers, rhs.itemIdentifiers) {
      switch (lhsItem, rhsItem) {
      case (.page(let lhsPage), .page(let rhsPage)):
        if lhsPage.pageKey != rhsPage.pageKey { return true }
      case (.hashtag(let lhsHashtag), .hashtag(let rhsHashtag)):
        if lhsHashtag != rhsHashtag { return true }
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
    guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
    switch item {
    case .page(let viewProperties):
      if viewProperties.pageProperties.sha1Digest == nil {
        // This is a vocabulary page, not a text page.
        let vc = VocabularyViewController(notebook: notebook)
        vc.pageIdentifier = viewProperties.pageKey
        vc.properties = viewProperties.pageProperties
        delegate?.showDetailViewController(vc)
        return
      }
      let markdown: String
      do {
        markdown = try notebook.currentTextContents(for: viewProperties.pageKey)
      } catch {
        DDLogError("Unexpected error loading page: \(error)")
        return
      }
      let textEditViewController = TextEditViewController(
        notebook: notebook
      )
      textEditViewController.pageIdentifier = viewProperties.pageKey
      textEditViewController.markdown = markdown
      textEditViewController.delegate = notebook
      delegate?.showDetailViewController(textEditViewController)
    case .hashtag(let hashtag):
      delegate?.documentSearchResultsDidSelectHashtag(hashtag)
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
        try? self.notebook.deletePage(pageIdentifier: properties.pageKey)
        self.delegate?.documentTableDidDeleteDocument(with: properties.pageKey)
        completion(true)
      }
      deleteAction.image = UIImage(systemName: "trash")
      actions.append(deleteAction)
      if properties.cardCount > 0 {
        let studyAction = UIContextualAction(style: .normal, title: "Study") { _, _, completion in
          self.notebook.studySession(filter: { name, _ in name == properties.pageKey }, date: Date()) {
            self.delegate?.presentStudySessionViewController(for: $0)
            completion(true)
          }
        }
        studyAction.image = UIImage(systemName: "rectangle.stack")
        studyAction.backgroundColor = UIColor.systemBlue
        actions.append(studyAction)
      }
    case .hashtag:
      // NOTHING
      break
    }
    return UISwipeActionsConfiguration(actions: actions)
  }

  public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    let section = dataSource.snapshot().sectionIdentifiers[section]
    let label = UILabel(frame: .zero)
    label.font = UIFont.preferredFont(forTextStyle: .subheadline)
    label.textColor = .secondaryLabel
    label.backgroundColor = .secondarySystemBackground
    switch section {
    case .hashtags:
      label.text = "Hashtag"
    case .documents:
      return nil
    }
    return label
  }

  public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    let section = dataSource.snapshot().sectionIdentifiers[section]
    switch section {
    case .hashtags:
      let font = UIFont.preferredFont(forTextStyle: .subheadline)
      return font.lineHeight + 8
    case .documents:
      return 0
    }
  }
}

// MARK: - NoteArchiveDocumentObserver

extension DocumentTableController: NoteArchiveDocumentObserver {
  public func noteArchiveDocument(
    _ document: NoteArchiveDocument,
    didUpdatePageProperties properties: [String: PageProperties]
  ) {
    updateCardsPerDocument()
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
    /// List of available hashtags
    case hashtags
    /// List of documents.
    case documents
  }

  enum Item: Hashable, CustomStringConvertible {
    case hashtag(String)
    case page(ViewProperties)

    var description: String {
      switch self {
      case .hashtag(let hashtag):
        return hashtag
      case .page(let viewProperties):
        return "Page \(viewProperties.pageKey)"
      }
    }
  }

  /// All properties needed to display a document cell.
  struct ViewProperties: Hashable {
    /// UUID for this page
    let pageKey: String
    /// Page properties (serialized into the document)
    let pageProperties: PageProperties
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
    titleRenderer.markdown = viewProperties.pageProperties.title
    cell.titleLabel.attributedText = titleRenderer.attributedString
    cell.accessibilityLabel = viewProperties.pageProperties.title
    var detailString = viewProperties.pageProperties.hashtags.joined(separator: ", ")
    if viewProperties.cardCount > 0 {
      if !detailString.isEmpty { detailString += ". " }
      if viewProperties.cardCount == 1 {
        detailString += "1 card."
      } else {
        detailString += "\(viewProperties.cardCount) cards."
      }
    }
    cell.detailLabel.attributedText = NSAttributedString(
      string: detailString,
      attributes: [
        .font: UIFont.preferredFont(forTextStyle: .subheadline),
        .foregroundColor: UIColor.secondaryLabel,
      ]
    )
    let now = Date()
    let dateDelta = now.timeIntervalSince(viewProperties.pageProperties.timestamp)
    cell.ageLabel.attributedText = NSAttributedString(
      string: DateComponentsFormatter.age.string(from: dateDelta) ?? "",
      attributes: [
        .font: UIFont.preferredFont(forTextStyle: .caption1),
        .foregroundColor: UIColor.secondaryLabel,
      ]
    )
    cell.setNeedsLayout()
    return cell
  }

  func updateCardsPerDocument() {
    notebook.studySession(filter: nil, date: Date()) { studySession in
      self.cardsPerDocument = studySession
        .reduce(into: [String: Int]()) { cardsPerDocument, card in
          cardsPerDocument[card.properties.documentName] = cardsPerDocument[card.properties.documentName, default: 0] + 1
        }
      DDLogInfo(
        "studySession.count = \(studySession.count). " +
          "cardsPerDocument has \(self.cardsPerDocument.count) entries"
      )
    }
  }

  static func snapshot(
    for notebook: NoteArchiveDocument,
    cardsPerDocument: [String: Int],
    hashtags: [String],
    filteredHashtag: String?,
    filteredPageIdentifiers: Set<String>?
  ) -> Snapshot {
    var snapshot = Snapshot()
    if !hashtags.isEmpty {
      snapshot.appendSections([.hashtags])
      snapshot.appendItems(hashtags.map { Item.hashtag($0) })
    }
    snapshot.appendSections([.documents])

    let propertiesFilteredByHashtag = notebook.pageProperties
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
        ViewProperties(pageKey: tuple.key, pageProperties: tuple.value, cardCount: cardsPerDocument[tuple.key, default: 0])
      }
      .sorted(
        by: { $0.pageProperties.timestamp > $1.pageProperties.timestamp }
      )
      .map {
        Item.page($0)
      }
    snapshot.appendItems(objects)
    DDLogDebug("Generating snapshot with \(objects.count) entries: \(objects)")
    return snapshot
  }
}
