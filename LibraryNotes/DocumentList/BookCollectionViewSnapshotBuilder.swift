// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import UIKit

typealias BookCollectionViewSnapshot = NSDiffableDataSourceSnapshot<BookSection, BookCollectionViewItem>

struct BookCollectionViewSnapshotBuilder: Equatable {
  var records: Set<Note.Identifier>
  var cardsPerDocument: [Note.Identifier: Int]
  var sortOrder: SortOrder = .author

  enum SortOrder: String, CaseIterable {
    case author = "Author"
    case title = "Title"
    case creationTimestamp = "Created Date"
    case modificationTimestap = "Modified Date"
    case rating = "Rating"

    fileprivate var sortFunction: (BookViewProperties, BookViewProperties) -> Bool {
      switch self {
      case .author:
        return BookViewProperties.lessThanPriorityAuthor
      case .title:
        return BookViewProperties.lessThanPriorityTitle
      case .creationTimestamp:
        return { BookViewProperties.lessThanPriorityCreation(lhs: $1, rhs: $0) }
      case .modificationTimestap:
        return { BookViewProperties.lessThanPriorityModified(lhs: $1, rhs: $0) }
      case .rating:
        return { BookViewProperties.lessThanPriorityRating(lhs: $1, rhs: $0) }
      }
    }
  }

  func categorizeMetadataRecords(_ metadataRecords: [String: BookNoteMetadata]) -> [BookSection: [BookCollectionViewItem]] {
    let viewProperties = records
      .compactMap { identifier -> BookViewProperties? in
        guard let metadataRecord = metadataRecords[identifier] else {
          return nil
        }
        return BookViewProperties(
          pageKey: identifier,
          noteProperties: metadataRecord,
          cardCount: cardsPerDocument[identifier, default: 0]
        )
      }

    var categorizedItems: [BookSection: [BookCollectionViewItem]] = [:]

    let items = viewProperties
      .sorted(by: sortOrder.sortFunction)
      .map {
        BookCollectionViewItem.book($0)
      }
    for item in items {
      switch item.bookCategory {
      case .none:
        categorizedItems[.other, default: []].append(item)
      case .some(let category):
        categorizedItems[category, default: []].append(item)
      }
    }
    return categorizedItems
  }

  func sectionSnapshot(for section: BookSection, categorizedItems: [BookSection: [BookCollectionViewItem]]) -> NSDiffableDataSourceSectionSnapshot<BookCollectionViewItem>? {
    guard let items = categorizedItems[section], !items.isEmpty else {
      return nil
    }
    var bookSection = NSDiffableDataSourceSectionSnapshot<BookCollectionViewItem>()
    let headerItem = BookCollectionViewItem.header(section, items.count)
    bookSection.append([headerItem])
    bookSection.append(items, to: headerItem)
    bookSection.expand([headerItem])
    return bookSection
  }

  // "cardsPerDocument" doesn't count when determining if our snapshot builders are equal, as it doesn't
  // affect the ordering of items in the snapshot.
  static func == (lhs: BookCollectionViewSnapshotBuilder, rhs: BookCollectionViewSnapshotBuilder) -> Bool {
    return (lhs.records, lhs.sortOrder) == (rhs.records, rhs.sortOrder)
  }
}
