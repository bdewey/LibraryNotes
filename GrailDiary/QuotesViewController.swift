//
//  QuotesViewController.swift
//  GrailDiary
//
//  Created by Brian Dewey on 5/15/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import SnapKit
import UIKit

/// Displays a list of quotes.
final class QuotesViewController: UIViewController {
  public var quotes: [ContentFromNote] = [] {
    didSet {
      var snapshot = NSDiffableDataSourceSnapshot<Int, ContentFromNote>()
      snapshot.appendSections([0])
      snapshot.appendItems(quotes)
      dataSource.apply(snapshot)
    }
  }

  private lazy var layout: UICollectionViewLayout = {
    var config = UICollectionLayoutListConfiguration(appearance:
      .insetGrouped)
    config.backgroundColor = .grailBackground
    return UICollectionViewCompositionalLayout.list(using: config)
  }()

  private lazy var collectionView: UICollectionView = {
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    return collectionView
  }()

  private lazy var dataSource: UICollectionViewDiffableDataSource<Int, ContentFromNote> = {
    let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, ContentFromNote> { cell, _, quote in
      var configuration = cell.defaultContentConfiguration()
      let attributedQuote = ParsedAttributedString(string: quote.text, settings: .plainText(textStyle: .body))
      configuration.attributedText = attributedQuote
      cell.contentConfiguration = configuration

      var background = UIBackgroundConfiguration.listPlainCell()
      background.backgroundColor = .grailBackground
      cell.backgroundConfiguration = background
    }
    let dataSource = UICollectionViewDiffableDataSource<Int, ContentFromNote>(collectionView: collectionView) { collectionView, indexPath, quote in
      collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: quote)
    }
    return dataSource
  }()

  // MARK: - View lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .grailBackground

    [
      collectionView,
    ].forEach(view.addSubview)

    collectionView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
  }
}
