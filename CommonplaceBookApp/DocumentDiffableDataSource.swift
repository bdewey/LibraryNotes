// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import MiniMarkdown
import UIKit

/// Given a NoteArchiveDocument, manages a collection of cells representing the pages in that document.
public final class DocumentDiffableDataSource: UITableViewDiffableDataSource<DocumentDiffableDataSource.DocumentSection, DocumentDiffableDataSource.Item> {
  public typealias Snapshot = NSDiffableDataSourceSnapshot<DocumentSection, Item>

  public let notebook: NoteArchiveDocument
  private var cardsPerDocument = [String: Int]()

  // TODO: Get rid of this; just here to make things compile
  public var filteredHashtag: String? {
    didSet {
      performUpdates(animated: true)
    }
  }

  /// If true, show a list of hashtags as a section in the table.
  public var showHashtags: Bool = false

  /// If non-nil, only pages with these identifiers will be shown.
  public var filteredPageIdentifiers: Set<String>? {
    didSet {
      performUpdates(animated: true)
    }
  }

  public enum Item: Hashable {
    case hashtag(String)
    case page(ViewProperties)
  }

  /// All properties needed to display a document cell.
  public struct ViewProperties: Hashable {
    /// UUID for this page
    let pageKey: String
    /// Page properties (serialized into the document)
    let pageProperties: PageProperties
    /// How many cards are eligible for study in this page (dynamic and not serialized)
    var cardCount: Int
  }

  /// Designated initializer.
  public init(
    tableView: UITableView,
    notebook: NoteArchiveDocument
  ) {
    self.notebook = notebook
    tableView.register(DocumentTableViewCell.self, forCellReuseIdentifier: ReuseIdentifiers.documentCell)
    let titleRenderer = RenderedMarkdown.makeTitleRenderer()
    super.init(tableView: tableView) { (tableView, indexPath, item) -> UITableViewCell? in
      switch item {
      case .page(let viewProperties):
        return DocumentDiffableDataSource.cell(
          tableView: tableView,
          indexPath: indexPath,
          viewProperties: viewProperties,
          titleRenderer: titleRenderer
        )
      case .hashtag:
        return nil
      }
    }
    updateCardsPerDocument()
  }

  public func startObservingNotebook() {
    notebook.addObserver(self)
    updateCardsPerDocument()
    performUpdates(animated: true)
  }

  public func stopObservingNotebook() {
    notebook.removeObserver(self)
  }

  public func performUpdates(animated: Bool) {
    let snapshot = DocumentDiffableDataSource.snapshot(
      for: notebook,
      cardsPerDocument: cardsPerDocument,
      filteredPageIdentifiers: filteredPageIdentifiers
    )
    let reallyAnimate = animated && DocumentDiffableDataSource.majorSnapshotDifferences(between: self.snapshot(), and: snapshot)
    apply(snapshot, animatingDifferences: reallyAnimate)
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

  /// Sections of the collection view
  public enum DocumentSection {
    /// List of available hashtags
    case hashtags
    /// List of documents.
    case documents
  }
}

// MARK: - NoteArchiveDocumentObserver

extension DocumentDiffableDataSource: NoteArchiveDocumentObserver {
  public func noteArchiveDocument(
    _ document: NoteArchiveDocument,
    didUpdatePageProperties properties: [String: PageProperties]
  ) {
    updateCardsPerDocument()
    performUpdates(animated: true)
  }
}

// MARK: - Private

private extension DocumentDiffableDataSource {
  enum ReuseIdentifiers {
    static let documentCell = "DocumentCollectionViewCell"
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
    let studySession = notebook.studySession()
    cardsPerDocument = studySession
      .reduce(into: [String: Int]()) { cardsPerDocument, card in
        cardsPerDocument[card.properties.documentName] = cardsPerDocument[card.properties.documentName, default: 0] + 1
      }
    DDLogInfo(
      "studySession.count = \(studySession.count). " +
        "cardsPerDocument has \(cardsPerDocument.count) entries"
    )
  }

  static func snapshot(
    for notebook: NoteArchiveDocument,
    cardsPerDocument: [String: Int],
    filteredPageIdentifiers: Set<String>?
  ) -> Snapshot {
    let snapshot = Snapshot()
    snapshot.appendSections([.documents])

    let propertiesFilteredByHashtag = notebook.pageProperties
      .filter {
        guard let filteredPageIdentifiers = filteredPageIdentifiers else { return true }
        return filteredPageIdentifiers.contains($0.key)
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
    return snapshot
  }
}
