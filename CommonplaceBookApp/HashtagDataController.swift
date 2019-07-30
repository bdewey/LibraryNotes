// Copyright © 2019 Brian's Brain. All rights reserved.

import UIKit

public protocol HashtagDataControllerDelegate: class {
  func hashtagDataControllerDidClearHashtag()
  func hashtagDataControllerDidSelectHashtag(_ hashtag: String)
}

public final class HashtagDataController: NSObject {
  public init(tableView: UITableView, notebook: NoteArchiveDocument, stylesheet: Stylesheet) {
    self.notebook = notebook
    self.stylesheet = stylesheet
    self.dataSource = UITableViewDiffableDataSource<Section, Item>(tableView: tableView) { (tableView, indexPath, item) -> UITableViewCell? in
      var cell: UITableViewCell! = tableView.dequeueReusableCell(withIdentifier: "HashtagDataController")
      if cell == nil {
        cell = UITableViewCell(style: .default, reuseIdentifier: "HashtagDataController")
      }
      cell.backgroundColor = stylesheet.colors.surfaceColor
      cell.textLabel?.attributedText = item.label(stylesheet: stylesheet)
      return cell
    }
    super.init()
    tableView.delegate = self
  }

  public weak var delegate: HashtagDataControllerDelegate?

  private let notebook: NoteArchiveDocument
  private let stylesheet: Stylesheet
  private let dataSource: UITableViewDiffableDataSource<Section, Item>

  public func performUpdates(animated: Bool) {
    dataSource.apply(makeSnapshot(), animatingDifferences: animated)
  }

  public func startObservingNotebook() {
    notebook.addObserver(self)
  }

  public func stopObservingNotebook() {
    notebook.removeObserver(self)
  }
}

extension HashtagDataController: NoteArchiveDocumentObserver {
  public func noteArchiveDocument(
    _ document: NoteArchiveDocument,
    didUpdatePageProperties properties: [String : PageProperties]
  ) {
    performUpdates(animated: true)
  }
}

extension HashtagDataController: UITableViewDelegate {
  public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
    switch item {
    case .allDocuments:
      delegate?.hashtagDataControllerDidClearHashtag()
    case .hashtag(let hashtag):
      delegate?.hashtagDataControllerDidSelectHashtag(hashtag)
    }
  }
}

private extension HashtagDataController {
  enum Section: Hashable {
    case main
  }

  enum Item: Hashable {
    case allDocuments
    case hashtag(String)

    func label(stylesheet: Stylesheet) -> NSAttributedString {
      switch self {
      case .allDocuments:
        return NSAttributedString(
          string: "All notes",
          attributes: stylesheet.attributes(style: .body2)
        )
      case .hashtag(let hashtag):
        return NSAttributedString(
          string: hashtag,
          attributes: stylesheet.attributes(style: .body2, emphasis: .darkTextHighEmphasis)
        )
      }
    }
  }

  func makeSnapshot() -> NSDiffableDataSourceSnapshot<Section, Item> {
    let snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
    snapshot.appendSections([.main])
    snapshot.appendItems([.allDocuments])
    let hashtags = notebook.pageProperties.values.reduce(into: Set<String>()) { hashtags, props in
      hashtags.formUnion(props.hashtags)
    }
    snapshot.appendItems(
      Array(hashtags).sorted().map({ Item.hashtag($0) })
    )
    return snapshot
  }
}
