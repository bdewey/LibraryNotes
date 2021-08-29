//
//  BookCollectionViewSnapshot.swift
//  BookCollectionViewSnapshot
//
//  Created by Brian Dewey on 8/29/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import Foundation
import UIKit

typealias BookCollectionViewSnapshot = NSDiffableDataSourceSnapshot<BookSection, BookCollectionViewItem>

struct BookCollectionViewSnapshotBuilder {
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
}

