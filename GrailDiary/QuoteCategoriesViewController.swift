// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import SnapKit
import UIKit

final class QuoteCategoriesViewController: UIViewController {
  init(database: NoteDatabase) {
    self.database = database
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let database: NoteDatabase

  private lazy var collectionView: UICollectionView = {
    let layout = UICollectionViewCompositionalLayout { _, layoutEnvironment in
      var config = UICollectionLayoutListConfiguration(appearance: .plain)
      config.backgroundColor = .grailBackground
      let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
      return section
    }
    let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
    view.delegate = self
    return view
  }()

  private lazy var dataSource: UICollectionViewDiffableDataSource<Int, String> = {
    let labelRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, String> { cell, _, item in
      var contentConfiguration = cell.defaultContentConfiguration()
      contentConfiguration.text = item
      contentConfiguration.textProperties.color = .label
      var backgroundConfiguration = UIBackgroundConfiguration.listPlainCell()
      backgroundConfiguration.backgroundColor = .grailBackground
      cell.backgroundConfiguration = backgroundConfiguration
      cell.contentConfiguration = contentConfiguration
    }
    let dataSource = UICollectionViewDiffableDataSource<Int, String>(collectionView: collectionView) { collectionView, indexPath, item in
      collectionView.dequeueConfiguredReusableCell(using: labelRegistration, for: indexPath, item: item)
    }
    return dataSource
  }()

  // MARK: - View lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(collectionView)
    collectionView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    updateSnapshot()
  }
}

// MARK: - UICollectionViewDelegate

extension QuoteCategoriesViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    splitViewController?.show(.secondary)
  }
}

// MARK: - Private

private extension QuoteCategoriesViewController {
  func updateSnapshot() {
    var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
    snapshot.appendSections([0])
    snapshot.appendItems(["All Quotes"])
    dataSource.apply(snapshot)
  }
}
