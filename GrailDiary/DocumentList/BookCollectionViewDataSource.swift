//
//  DocumentListViewDataSource.swift
//  DocumentListViewDataSource
//
//  Created by Brian Dewey on 8/29/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import Foundation
import TextMarkupKit
import UIKit

final class BookCollectionViewDataSource: UICollectionViewDiffableDataSource<BookSection, BookCollectionViewItem> {
  init(
    collectionView: UICollectionView,
    coverImageCache: CoverImageCache
  ) {
    let bookRegistration = Registration.makeBookRegistration(coverImageCache: coverImageCache)
    let notebookPageRegistration = Registration.makePageRegistration(coverImageCache: coverImageCache)
    let headerRegistration = Registration.makeHeaderRegistration()

    super.init(collectionView: collectionView) { (collectionView, indexPath, item) -> UICollectionViewCell? in
      switch item {
      case .book(let viewProperties):
        if viewProperties.noteProperties.book != nil {
          return collectionView.dequeueConfiguredReusableCell(using: bookRegistration, for: indexPath, item: item)
        } else {
          return collectionView.dequeueConfiguredReusableCell(using: notebookPageRegistration, for: indexPath, item: item)
        }
      case .header:
        return collectionView.dequeueConfiguredReusableCell(using: headerRegistration, for: indexPath, item: item)
      }
    }
  }
}

private enum Registration {
  static func makeBookRegistration(
    coverImageCache: CoverImageCache
  ) -> UICollectionView.CellRegistration<ClearBackgroundCell, BookCollectionViewItem> {
    UICollectionView.CellRegistration<ClearBackgroundCell, BookCollectionViewItem> { cell, _, item in
      guard case .book(let viewProperties) = item, let book = viewProperties.noteProperties.book else { return }
      let coverImage = coverImageCache.coverImage(bookID: viewProperties.pageKey, maxSize: 300)
      let configuration = BookViewContentConfiguration(book: book, coverImage: coverImage)
      cell.contentConfiguration = configuration
    }
  }

  static func makePageRegistration(
    coverImageCache: CoverImageCache
  ) -> UICollectionView.CellRegistration<ClearBackgroundCell, BookCollectionViewItem> {
    UICollectionView.CellRegistration<ClearBackgroundCell, BookCollectionViewItem> { cell, _, item in
      guard case .book(let viewProperties) = item else { return }
      var configuration = cell.defaultContentConfiguration()
      let title = ParsedAttributedString(string: viewProperties.noteProperties.title, style: .plainText(textStyle: .headline))
      configuration.attributedText = title
      let secondaryComponents: [String?] = [
        viewProperties.noteProperties.summary,
        viewProperties.noteProperties.tags.joined(separator: ", "),
      ]
      configuration.secondaryText = secondaryComponents.compactMap { $0 }.joined(separator: " ")
      configuration.secondaryTextProperties.color = .secondaryLabel
      configuration.image = coverImageCache.coverImage(bookID: viewProperties.pageKey, maxSize: 300)

      let headlineFont = UIFont.preferredFont(forTextStyle: .headline)
      let verticalMargin = max(20, 1.5 * headlineFont.lineHeight.roundedToScreenScale())
      configuration.directionalLayoutMargins = .init(top: verticalMargin, leading: 0, bottom: verticalMargin, trailing: 0)
      cell.contentConfiguration = configuration
    }
  }

  static func makeHeaderRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, BookCollectionViewItem> {
    UICollectionView.CellRegistration<UICollectionViewListCell, BookCollectionViewItem> { cell, _, item in
      guard case .header(let category, let count) = item else { return }
      var configuration = UIListContentConfiguration.extraProminentInsetGroupedHeader()
      configuration.prefersSideBySideTextAndSecondaryText = true
      switch category {
      case .wantToRead:
        configuration.text = "Want to read"
      case .currentlyReading:
        configuration.text = "Currently reading"
      case .read:
        configuration.text = "Read"
      case .other:
        configuration.text = "Other"
      }
      configuration.secondaryText = "\(count)"
      cell.contentConfiguration = configuration
      cell.accessories = [.outlineDisclosure()]
      cell.backgroundConfiguration?.backgroundColor = .grailSecondaryBackground
    }
  }
}
