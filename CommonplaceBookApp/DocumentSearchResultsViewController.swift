// Copyright © 2019 Brian's Brain. All rights reserved.

import UIKit

protocol DocumentSearchResultsViewControllerDelegate: AnyObject {
  func documentSearchResultsDidSelectHashtag(_ hashtag: String)
}

final class DocumentSearchResultsViewController: UIViewController {
  private lazy var tableView: UITableView = {
    let tableView = UITableView()
    return tableView
  }()

  public weak var delegate: DocumentSearchResultsViewControllerDelegate?
  private var dataSource: DataSource?

  func setHashtags(_ hashtags: [String]) {
    let snapshot = NSDiffableDataSourceSnapshot<Section, String>()
    snapshot.appendSections([.hashtags])
    snapshot.appendItems(hashtags)
    dataSource?.apply(snapshot, animatingDifferences: true)
  }

  override func loadView() {
    self.view = tableView
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    let dataSource = DataSource(tableView: tableView) { (tableView, indexPath, hashtag) -> UITableViewCell? in
      var cell: UITableViewCell! = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifier.hashtag)
      if cell == nil {
        cell = UITableViewCell(style: .default, reuseIdentifier: ReuseIdentifier.hashtag)
      }
      cell.textLabel?.text = hashtag
      return cell
    }
    self.dataSource = dataSource
    tableView.delegate = self
  }
}

extension DocumentSearchResultsViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    guard let hashtag = dataSource?.itemIdentifier(for: indexPath) else { return }
    delegate?.documentSearchResultsDidSelectHashtag(hashtag)
  }
}

private extension DocumentSearchResultsViewController {
  enum ReuseIdentifier {
    static let hashtag = "HashtagCell"
  }

  typealias DataSource = UITableViewDiffableDataSource<Section, String>

  enum Section: Hashable {
    case hashtags
  }
}
