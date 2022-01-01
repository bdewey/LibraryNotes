// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import TextMarkupKit
import UIKit

final class BookCollectionViewDataSource: UICollectionViewDiffableDataSource<BookSection, BookCollectionViewItem> {
  init(
    collectionView: UICollectionView,
    coverImageCache: CoverImageCache,
    database: NoteDatabase
  ) {
    let bookRegistration = Registration.makeBookRegistration(coverImageCache: coverImageCache, database: database)
    let notebookPageRegistration = Registration.makePageRegistration(coverImageCache: coverImageCache, database: database)
    let headerRegistration = Registration.makeHeaderRegistration()

    super.init(collectionView: collectionView) { (collectionView, indexPath, item) -> UICollectionViewCell? in
      switch item {
      case .book(let noteIdentifier, _):
        let metadata = database.bookMetadata(identifier: noteIdentifier)
        if metadata?.book != nil {
          return collectionView.dequeueConfiguredReusableCell(using: bookRegistration, for: indexPath, item: item)
        } else {
          return collectionView.dequeueConfiguredReusableCell(using: notebookPageRegistration, for: indexPath, item: item)
        }
      case .header, .yearReadHeader:
        return collectionView.dequeueConfiguredReusableCell(using: headerRegistration, for: indexPath, item: item)
      }
    }
  }
}

private enum Registration {
  static func makeBookRegistration(
    coverImageCache: CoverImageCache,
    database: NoteDatabase
  ) -> UICollectionView.CellRegistration<ClearBackgroundCell, BookCollectionViewItem> {
    UICollectionView.CellRegistration<ClearBackgroundCell, BookCollectionViewItem> { cell, _, item in
      guard
        case .book(let noteIdentifier, _) = item,
        let metadata = database.bookMetadata(identifier: noteIdentifier),
        let book = metadata.book
      else {
        return
      }
      let coverImage = coverImageCache.coverImage(bookID: noteIdentifier, maxSize: 300)
      let configuration = BookViewContentConfiguration(book: book, coverImage: coverImage)
      cell.contentConfiguration = configuration
    }
  }

  static func makePageRegistration(
    coverImageCache: CoverImageCache,
    database: NoteDatabase
  ) -> UICollectionView.CellRegistration<ClearBackgroundCell, BookCollectionViewItem> {
    UICollectionView.CellRegistration<ClearBackgroundCell, BookCollectionViewItem> { cell, _, item in
      guard
        case .book(let noteIdentifier, _) = item,
        let metadata = database.bookMetadata(identifier: noteIdentifier)
      else {
        return
      }
      var configuration = cell.defaultContentConfiguration()
      let title = ParsedAttributedString(string: metadata.title, style: .plainText(textStyle: .headline))
      configuration.attributedText = title
      let secondaryComponents: [String?] = [
        metadata.summary,
        metadata.tags.joined(separator: ", "),
      ]
      configuration.secondaryText = secondaryComponents.compactMap { $0 }.joined(separator: " ")
      configuration.secondaryTextProperties.color = .secondaryLabel
      configuration.image = coverImageCache.coverImage(bookID: noteIdentifier, maxSize: 300)

      let headlineFont = UIFont.preferredFont(forTextStyle: .headline)
      let verticalMargin = max(20, 1.5 * headlineFont.lineHeight.roundedToScreenScale())
      configuration.directionalLayoutMargins = .init(top: verticalMargin, leading: 0, bottom: verticalMargin, trailing: 0)
      cell.contentConfiguration = configuration
    }
  }

  static func makeHeaderRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, BookCollectionViewItem> {
    UICollectionView.CellRegistration<UICollectionViewListCell, BookCollectionViewItem> { cell, _, item in
      guard let headerText = item.headerText else { return }
      var configuration = UIListContentConfiguration.extraProminentInsetGroupedHeader()
      configuration.prefersSideBySideTextAndSecondaryText = true
      configuration.text = headerText.primaryHeaderText
      configuration.secondaryText = headerText.secondaryHeaderText
      cell.contentConfiguration = configuration
      cell.accessories = [.outlineDisclosure()]
      cell.backgroundConfiguration?.backgroundColor = .grailSecondaryBackground
    }
  }
}
