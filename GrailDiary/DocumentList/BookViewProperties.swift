//
//  BookViewProperties.swift
//  BookViewProperties
//
//  Created by Brian Dewey on 8/29/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import Foundation

/// All properties needed to display a book in the book collection view.
struct BookViewProperties: Hashable {
  /// UUID for this page
  let pageKey: Note.Identifier
  /// Page properties (serialized into the document)
  let noteProperties: BookNoteMetadata
  /// How many cards are eligible for study in this page (dynamic and not serialized)
  var cardCount: Int

  let author: PersonNameComponents?

  let bookCategory: BookSection?

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

  static func == (lhs: BookViewProperties, rhs: BookViewProperties) -> Bool {
    lhs.pageKey == rhs.pageKey
  }

  static func lessThanPriorityAuthor(lhs: BookViewProperties, rhs: BookViewProperties) -> Bool {
    return
      (lhs.author, lhs.noteProperties.title, lhs.noteProperties.creationTimestamp, lhs.noteProperties.modifiedTimestamp) <
      (rhs.author, rhs.noteProperties.title, rhs.noteProperties.creationTimestamp, rhs.noteProperties.modifiedTimestamp)
  }

  static func lessThanPriorityTitle(lhs: BookViewProperties, rhs: BookViewProperties) -> Bool {
    return
      (lhs.noteProperties.title, lhs.author, lhs.noteProperties.creationTimestamp, lhs.noteProperties.modifiedTimestamp) <
      (rhs.noteProperties.title, rhs.author, rhs.noteProperties.creationTimestamp, rhs.noteProperties.modifiedTimestamp)
  }

  static func lessThanPriorityCreation(lhs: BookViewProperties, rhs: BookViewProperties) -> Bool {
    return
      (lhs.noteProperties.creationTimestamp, lhs.author, lhs.noteProperties.title, lhs.noteProperties.modifiedTimestamp) <
      (rhs.noteProperties.creationTimestamp, rhs.author, rhs.noteProperties.title, rhs.noteProperties.modifiedTimestamp)
  }

  static func lessThanPriorityModified(lhs: BookViewProperties, rhs: BookViewProperties) -> Bool {
    return
      (lhs.noteProperties.modifiedTimestamp, lhs.author, lhs.noteProperties.title, lhs.noteProperties.creationTimestamp) <
      (rhs.noteProperties.modifiedTimestamp, rhs.author, rhs.noteProperties.title, rhs.noteProperties.creationTimestamp)
  }

  static func lessThanPriorityRating(lhs: BookViewProperties, rhs: BookViewProperties) -> Bool {
    let lhsRating = lhs.noteProperties.book?.rating ?? 0
    let rhsRating = rhs.noteProperties.book?.rating ?? 0
    return
      (lhsRating, lhs.noteProperties.creationTimestamp, lhs.author, lhs.noteProperties.title, lhs.noteProperties.modifiedTimestamp) <
      (rhsRating, rhs.noteProperties.creationTimestamp, rhs.author, rhs.noteProperties.title, rhs.noteProperties.modifiedTimestamp)
  }
}

