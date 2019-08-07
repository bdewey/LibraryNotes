// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import MiniMarkdown
import UIKit

/// Given a NoteArchiveDocument, manages a collection of cells representing the pages in that document.
public final class DocumentDiffableDataSource: UITableViewDiffableDataSource<DocumentDiffableDataSource.DocumentSection, DocumentDiffableDataSource.ViewProperties> {
  public typealias Snapshot = NSDiffableDataSourceSnapshot<DocumentSection, ViewProperties>

  public let notebook: NoteArchiveDocument
  private var cardsPerDocument = [String: Int]()

  // TODO: Get rid of this; just here to make things compile
  public var filteredHashtag: String? {
    didSet {
      performUpdates(animated: true)
    }
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
    super.init(tableView: tableView) { (tableView, indexPath, viewProperties) -> UITableViewCell? in
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
        string: DocumentDiffableDataSource.ageFormatter.string(from: dateDelta) ?? "",
        attributes: [
          .font: UIFont.preferredFont(forTextStyle: .caption1),
          .foregroundColor: UIColor.secondaryLabel,
        ]
      )
      cell.setNeedsLayout()
      return cell
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
      hashtag: filteredHashtag
    )
    let reallyAnimate = animated && DocumentDiffableDataSource.majorSnapshotDifferences(between: self.snapshot(), and: snapshot)
    apply(snapshot, animatingDifferences: reallyAnimate)
  }

  /// Compares lhs & rhs to see if the differences are worth animating.
  private static func majorSnapshotDifferences(between lhs: Snapshot, and rhs: Snapshot) -> Bool {
    if lhs.numberOfItems != rhs.numberOfItems {
      return true
    }
    for (lhsItem, rhsItem) in zip(lhs.itemIdentifiers, rhs.itemIdentifiers) {
      if lhsItem.pageKey != rhsItem.pageKey { return true }
    }
    return false
  }

  private static func snapshot(
    for notebook: NoteArchiveDocument,
    cardsPerDocument: [String: Int],
    hashtag: String?
  ) -> Snapshot {
    let snapshot = Snapshot()
    snapshot.appendSections([.documents])

    let propertiesFilteredByHashtag = notebook.pageProperties
      .filter {
        guard let hashtag = hashtag else { return true }
        return $0.value.hashtags.contains(hashtag)
      }
    let objects = propertiesFilteredByHashtag
      .compactMap { tuple in
        ViewProperties(pageKey: tuple.key, pageProperties: tuple.value, cardCount: cardsPerDocument[tuple.key, default: 0])
      }
      .sorted(
        by: { $0.pageProperties.timestamp > $1.pageProperties.timestamp }
      )
    snapshot.appendItems(objects)
    return snapshot
  }

  /// Sections of the collection view
  public enum DocumentSection {
    /// List of documents.
    case documents
  }
}

extension DocumentDiffableDataSource: NoteArchiveDocumentObserver {
  public func noteArchiveDocument(
    _ document: NoteArchiveDocument,
    didUpdatePageProperties properties: [String: PageProperties]
  ) {
    updateCardsPerDocument()
    performUpdates(animated: true)
  }
}

private extension RenderedMarkdown {
  static func makeTitleRenderer() -> RenderedMarkdown {
    var formatters: [NodeType: RenderedMarkdown.FormattingFunction] = [:]
    formatters[.emphasis] = { $1.italic = true }
    var renderers: [NodeType: RenderedMarkdown.RenderFunction] = [:]
    renderers[.delimiter] = { _, _ in NSAttributedString() }
    let renderer = RenderedMarkdown(
      parsingRules: ParsingRules(),
      formatters: formatters,
      renderers: renderers
    )
    renderer.defaultAttributes = [
      .font: UIFont.preferredFont(forTextStyle: .headline),
      .foregroundColor: UIColor.label,
    ]
    return renderer
  }
}

private extension DocumentDiffableDataSource {
  enum ReuseIdentifiers {
    static let documentCell = "DocumentCollectionViewCell"
  }

  static let ageFormatter: DateComponentsFormatter = {
    let ageFormatter = DateComponentsFormatter()
    ageFormatter.maximumUnitCount = 1
    ageFormatter.unitsStyle = .abbreviated
    ageFormatter.allowsFractionalUnits = false
    ageFormatter.allowedUnits = [.day, .hour, .minute]
    return ageFormatter
  }()

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
}
