//
//  DocumentListViewController+Snapshot.swift
//  DocumentListViewController+Snapshot
//
//  Created by Brian Dewey on 8/29/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import Foundation
import UIKit

internal extension DocumentTableController {
  typealias Snapshot = NSDiffableDataSourceSnapshot<DocumentSection, Item>

  private final class DataSource: UITableViewDiffableDataSource<DocumentSection, Item> {
    // New behavior in Beta 6: The built-in data source defaults to "not editable" which
    // disables the swipe actions.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
      return true
    }
  }

  /// Sections of the collection view
  enum DocumentSection {
    case wantToRead
    /// Books we are reading
    case currentlyReading
    /// Books we have read
    case read

    /// Pages that aren't associated with books.
    case other

    /// The sections that hold books.
    static let bookSections: [DocumentSection] = [.currentlyReading, .wantToRead, .read]
  }

  enum Item: Hashable, CustomStringConvertible {
    case page(ViewProperties)
    case header(DocumentSection, Int)

    var description: String {
      switch self {
      case .page(let viewProperties):
        return "Page \(viewProperties.pageKey)"
      case .header(let category, let count):
        return "\(category) (\(count))"
      }
    }

    /// The note identifier for the item, if it exists.
    var noteIdentifier: Note.Identifier? {
      if case .page(let viewProperties) = self {
        return viewProperties.pageKey
      } else {
        return nil
      }
    }

    /// If the receiver is a page, returns the category for that page, else nil.
    var bookCategory: DocumentSection? {
      if case .page(let properties) = self {
        return properties.bookCategory
      } else {
        return nil
      }
    }
  }

  /// All properties needed to display a document cell.
  struct ViewProperties: Hashable {
    /// UUID for this page
    let pageKey: Note.Identifier
    /// Page properties (serialized into the document)
    let noteProperties: BookNoteMetadata
    /// How many cards are eligible for study in this page (dynamic and not serialized)
    var cardCount: Int

    let author: PersonNameComponents?

    let bookCategory: DocumentSection?

    init(pageKey: Note.Identifier, noteProperties: BookNoteMetadata, cardCount: Int) {
      self.pageKey = pageKey
      self.noteProperties = noteProperties
      self.cardCount = cardCount

      if let book = noteProperties.book {
        if let readingHistory = book.readingHistory {
          if readingHistory.isCurrentlyReading {
            self.bookCategory = .currentlyReading
          } else {
            self.bookCategory = .read
          }
        } else {
          self.bookCategory = .wantToRead
        }
      } else {
        self.bookCategory = nil
      }

      if let book = noteProperties.book, let rawAuthorString = book.authors.first {
        let splitRawAuthor = rawAuthorString.split(separator: " ")
        var nameComponents = PersonNameComponents()
        if let last = splitRawAuthor.last {
          let first = splitRawAuthor.dropLast()
          nameComponents.familyName = String(last)
          nameComponents.givenName = first.joined(separator: " ")
        }
        self.author = nameComponents
      } else {
        self.author = nil
      }
    }

    // "Identity" for hashing & equality is just the pageKey

    func hash(into hasher: inout Hasher) {
      hasher.combine(pageKey)
    }

    static func == (lhs: ViewProperties, rhs: ViewProperties) -> Bool {
      lhs.pageKey == rhs.pageKey
    }

    static func lessThanPriorityAuthor(lhs: ViewProperties, rhs: ViewProperties) -> Bool {
      return
        (lhs.author, lhs.noteProperties.title, lhs.noteProperties.creationTimestamp, lhs.noteProperties.modifiedTimestamp) <
        (rhs.author, rhs.noteProperties.title, rhs.noteProperties.creationTimestamp, rhs.noteProperties.modifiedTimestamp)
    }

    static func lessThanPriorityTitle(lhs: ViewProperties, rhs: ViewProperties) -> Bool {
      return
        (lhs.noteProperties.title, lhs.author, lhs.noteProperties.creationTimestamp, lhs.noteProperties.modifiedTimestamp) <
        (rhs.noteProperties.title, rhs.author, rhs.noteProperties.creationTimestamp, rhs.noteProperties.modifiedTimestamp)
    }

    static func lessThanPriorityCreation(lhs: ViewProperties, rhs: ViewProperties) -> Bool {
      return
        (lhs.noteProperties.creationTimestamp, lhs.author, lhs.noteProperties.title, lhs.noteProperties.modifiedTimestamp) <
        (rhs.noteProperties.creationTimestamp, rhs.author, rhs.noteProperties.title, rhs.noteProperties.modifiedTimestamp)
    }

    static func lessThanPriorityModified(lhs: ViewProperties, rhs: ViewProperties) -> Bool {
      return
        (lhs.noteProperties.modifiedTimestamp, lhs.author, lhs.noteProperties.title, lhs.noteProperties.creationTimestamp) <
        (rhs.noteProperties.modifiedTimestamp, rhs.author, rhs.noteProperties.title, rhs.noteProperties.creationTimestamp)
    }

    static func lessThanPriorityRating(lhs: ViewProperties, rhs: ViewProperties) -> Bool {
      let lhsRating = lhs.noteProperties.book?.rating ?? 0
      let rhsRating = rhs.noteProperties.book?.rating ?? 0
      return
        (lhsRating, lhs.noteProperties.creationTimestamp, lhs.author, lhs.noteProperties.title, lhs.noteProperties.modifiedTimestamp) <
        (rhsRating, rhs.noteProperties.creationTimestamp, rhs.author, rhs.noteProperties.title, rhs.noteProperties.modifiedTimestamp)
    }
  }

  enum SortOrder: String, CaseIterable {
    case author = "Author"
    case title = "Title"
    case creationTimestamp = "Created Date"
    case modificationTimestap = "Modified Date"
    case rating = "Rating"

    fileprivate var sortFunction: (ViewProperties, ViewProperties) -> Bool {
      switch self {
      case .author:
        return ViewProperties.lessThanPriorityAuthor
      case .title:
        return ViewProperties.lessThanPriorityTitle
      case .creationTimestamp:
        return { ViewProperties.lessThanPriorityCreation(lhs: $1, rhs: $0) }
      case .modificationTimestap:
        return { ViewProperties.lessThanPriorityModified(lhs: $1, rhs: $0) }
      case .rating:
        return { ViewProperties.lessThanPriorityRating(lhs: $1, rhs: $0) }
      }
    }
  }

  struct SnapshotParameters: Equatable {
    var records: Set<Note.Identifier>
    var cardsPerDocument: [Note.Identifier: Int]
    var sortOrder: SortOrder = .author

    func snapshot() -> Snapshot {
      var snapshot = Snapshot()
      return snapshot
    }

    func categorizeMetadataRecords(_ metadataRecords: [String: BookNoteMetadata]) -> [DocumentSection: [Item]] {
      let viewProperties = records
        .compactMap { identifier -> ViewProperties? in
          guard let metadataRecord = metadataRecords[identifier] else {
            return nil
          }
          return ViewProperties(
            pageKey: identifier,
            noteProperties: metadataRecord,
            cardCount: cardsPerDocument[identifier, default: 0]
          )
        }

      var categorizedItems: [DocumentSection: [Item]] = [:]

      let items = viewProperties
        .sorted(by: sortOrder.sortFunction)
        .map {
          Item.page($0)
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

    func sectionSnapshot(for section: DocumentSection, categorizedItems: [DocumentSection: [Item]]) -> NSDiffableDataSourceSectionSnapshot<Item>? {
      guard let items = categorizedItems[section], !items.isEmpty else {
        return nil
      }
      var bookSection = NSDiffableDataSourceSectionSnapshot<Item>()
      let headerItem = Item.header(section, items.count)
      bookSection.append([headerItem])
      bookSection.append(items, to: headerItem)
      bookSection.expand([headerItem])
      return bookSection
    }
  }
}

internal extension NSDiffableDataSourceSectionSnapshot where ItemIdentifierType == DocumentTableController.Item {
  var bookCount: Int {
    var bookCount = 0
    for item in rootItems {
      switch item {
      case .header(_, let count):
        bookCount += count
      case .page:
        bookCount += 1
      }
    }
    return bookCount
  }

  mutating func collapseSections(in collapsedSections: Set<DocumentTableController.DocumentSection>) {
    for item in rootItems {
      guard case .header(let category, _) = item else { continue }
      if collapsedSections.contains(category) {
        collapse([item])
      }
    }
  }
}

