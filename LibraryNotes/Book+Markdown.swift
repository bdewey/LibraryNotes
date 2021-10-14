// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Foundation

extension Book {
  /// A citation for this book in simple Markdown.
  var markdownTitle: String {
    var title = "_\(self.title)_"
    if !authors.isEmpty {
      let authors = self.authors.joined(separator: ", ")
      title += ": \(authors)"
    }
    if let publishedDate = originalYearPublished ?? yearPublished {
      title += " (\(publishedDate))"
    }
    return title
  }
}
