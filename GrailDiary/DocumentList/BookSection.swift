//
//  BookSection.swift
//  BookSection
//
//  Created by Brian Dewey on 8/29/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import Foundation

/// Sections of the collection view
enum BookSection {
  case wantToRead
  /// Books we are reading
  case currentlyReading
  /// Books we have read
  case read

  /// Pages that aren't associated with books.
  case other

  /// The sections that hold books.
  static let bookSections: [BookSection] = [.currentlyReading, .wantToRead, .read]
}

