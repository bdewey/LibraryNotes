// Copyright © 2017-present Brian's Brain. All rights reserved.

import SnapKit
import UIKit

/// Allows editing a vocabulary list.
final class VocabularyViewController: UIViewController {
  init(notebook: NoteArchiveDocument) {
    self.notebook = notebook
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// The notebook we write changes back to
  let notebook: NoteArchiveDocument

  /// The page that stores our vocabulary.
  var properties = PageProperties() {
    didSet {
      title = properties.title
      dataSource.apply(makeSnapshot(), animatingDifferences: true)
    }
  }

  /// Identifier of the page. If nil, it means we're working with unsaved content.
  var pageIdentifier: String?

  private lazy var addCardButton: UIBarButtonItem = {
    UIBarButtonItem(image: .add, style: .plain, target: self, action: #selector(didTapAddButton))
  }()

  @objc private func didTapAddButton() {}

  private lazy var tableView: UITableView = {
    let tableView = UITableView(frame: .zero, style: .plain)
    return tableView
  }()

  private lazy var dataSource: DataSource = {
    DataSource(tableView: tableView) { (innerTableView, _, template) -> UITableViewCell? in
      var cell: UITableViewCell! = innerTableView.dequeueReusableCell(withIdentifier: Identifier.cell)
      if cell == nil {
        cell = UITableViewCell(style: .subtitle, reuseIdentifier: Identifier.cell)
      }
      cell.textLabel?.text = template.front.text
      cell.detailTextLabel?.text = template.back.text
      return cell
    }
  }()

  // MARK: - Lifecycle

  override func viewDidLoad() {
    view.backgroundColor = UIColor.systemBackground
    view.addSubview(tableView)
    navigationItem.rightBarButtonItem = addCardButton
    tableView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    dataSource.apply(makeSnapshot())
  }
}

private extension VocabularyViewController {
  typealias DataSource = UITableViewDiffableDataSource<Section, VocabularyChallengeTemplate>
  typealias Snapshot = NSDiffableDataSourceSnapshot<Section, VocabularyChallengeTemplate>

  enum Identifier {
    static let cell = "Cell"
  }

  enum Section: Hashable {
    case vocabularyItems
  }

  func makeSnapshot() -> Snapshot {
    var snapshot = VocabularyViewController.Snapshot()
    snapshot.appendSections([.vocabularyItems])
    let items = properties.cardTemplates
      .compactMap(notebook.challengeTemplate(for:))
      .compactMap { $0 as? VocabularyChallengeTemplate }
    snapshot.appendItems(items)
    return snapshot
  }
}
