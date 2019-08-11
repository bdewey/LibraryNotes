// Copyright © 2017-present Brian's Brain. All rights reserved.

import MiniMarkdown
import UIKit

protocol DocumentSearchResultsViewControllerDelegate: AnyObject {
  func documentSearchResultsDidSelectHashtag(_ hashtag: String)
  func documentSearchResultsDidSelectPageIdentifier(_ pageIdentifier: String)
  func documentSearchResultsPageProperties(for pageIdentifier: String) -> PageProperties?
}

/// Shows search results.
final class DocumentSearchResultsViewController: UIViewController {
  private lazy var tableView: UITableView = {
    let tableView = UITableView()
    tableView.register(DocumentTableViewCell.self, forCellReuseIdentifier: ReuseIdentifier.page)
    return tableView
  }()

  public weak var delegate: DocumentSearchResultsViewControllerDelegate?
  private var dataSource: DataSource?
  /// The current set of hashtags to display
  public var hashtags = [String]() { didSet { updateSnapshot() } }
  /// The current set of pages to display
  public var pageIdentifiers = [String]() { didSet { updateSnapshot() } }

  override func loadView() {
    view = tableView
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    let titleRenderer = RenderedMarkdown.makeTitleRenderer()
    let dataSource = DataSource(tableView: tableView) { [weak self] (tableView, indexPath, item) -> UITableViewCell? in
      guard let self = self else { return nil }
      switch item {
      case .hashtag(let hashtag):
        var cell: UITableViewCell! = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifier.hashtag)
        if cell == nil {
          cell = UITableViewCell(style: .default, reuseIdentifier: ReuseIdentifier.hashtag)
        }
        cell.textLabel?.text = hashtag
        return cell
      case .pageIdentifier(let pageIdentifier):
        guard
          let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifier.page, for: indexPath) as? DocumentTableViewCell,
          let pageProperties = self.delegate?.documentSearchResultsPageProperties(for: pageIdentifier)
        else {
          return nil
        }
        titleRenderer.markdown = pageProperties.title
        cell.titleLabel.attributedText = titleRenderer.attributedString
        cell.accessibilityLabel = pageProperties.title
        var detailString = pageProperties.hashtags.joined(separator: ", ")
        // TODO: Get the card count for the pages.
//        if viewProperties.cardCount > 0 {
//          if !detailString.isEmpty { detailString += ". " }
//          if viewProperties.cardCount == 1 {
//            detailString += "1 card."
//          } else {
//            detailString += "\(viewProperties.cardCount) cards."
//          }
//        }
        cell.detailLabel.attributedText = NSAttributedString(
          string: detailString,
          attributes: [
            .font: UIFont.preferredFont(forTextStyle: .subheadline),
            .foregroundColor: UIColor.secondaryLabel,
          ]
        )
        let now = Date()
        let dateDelta = now.timeIntervalSince(pageProperties.timestamp)
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
    }
    self.dataSource = dataSource
    tableView.delegate = self
  }
}

extension DocumentSearchResultsViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    guard let item = dataSource?.itemIdentifier(for: indexPath) else { return }
    switch item {
    case .hashtag(let hashtag):
      delegate?.documentSearchResultsDidSelectHashtag(hashtag)
    case .pageIdentifier(let pageIdentifier):
      delegate?.documentSearchResultsDidSelectPageIdentifier(pageIdentifier)
    }
  }

  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    guard let section = dataSource?.snapshot().sectionIdentifiers[section] else {
      return nil
    }
    let label = UILabel(frame: .zero)
    label.font = UIFont.preferredFont(forTextStyle: .subheadline)
    label.textColor = .secondaryLabel
    switch section {
    case .hashtags:
      label.text = "Hashtag"
    case .pages:
      label.text = "Page"
    }
    return label
  }

  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    let font = UIFont.preferredFont(forTextStyle: .subheadline)
    return font.lineHeight + 8
  }
}

// MARK: - Private

private extension DocumentSearchResultsViewController {
  enum ReuseIdentifier {
    static let hashtag = "HashtagCell"
    static let page = "PageCell"
  }

  typealias DataSource = UITableViewDiffableDataSource<Section, Item>

  /// The sections in the search results
  enum Section: Hashable {
    /// Shows hashtag results
    case hashtags
    /// Shows page results
    case pages
  }

  /// Items in the search results
  enum Item: Hashable {
    /// A hashtag
    case hashtag(String)
    /// A specific page
    case pageIdentifier(String)
  }

  func updateSnapshot() {
    dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
    let snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
    if !hashtags.isEmpty {
      snapshot.appendSections([.hashtags])
      snapshot.appendItems(hashtags.map { Item.hashtag($0) })
    }
    if !pageIdentifiers.isEmpty {
      snapshot.appendSections([.pages])
      snapshot.appendItems(pageIdentifiers.map { Item.pageIdentifier($0) })
    }
    dataSource?.apply(snapshot, animatingDifferences: true)
  }
}
