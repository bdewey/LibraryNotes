// Copyright (c) 2018-2025  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Foundation

enum MarkdownExport {
  static func frontmatter(for book: AugmentedBook) -> String {
    var buffer = "---\n"
    buffer.append("title: \(yamlString(book.title))\n")
    buffer.append("authors:\n")
    for author in book.authors {
      buffer.append("- \(yamlString(author))\n")
    }
    if let year = book.originalYearPublished ?? book.yearPublished {
      buffer.append("year-published: \(year)\n")
    }
    if let rating = book.rating {
      buffer.append("rating: \(rating)\n")
    }
    if let readingHistoryEntries = book.readingHistory?.entries?.filter({ $0.finish != nil }), !readingHistoryEntries.isEmpty {
      buffer.append("reading-history:\n")
      for entry in readingHistoryEntries {
        buffer.append("- \(entry.finish!.yaml)\n")
      }
    }
    buffer.append("---\n\n")
    return buffer
  }

  static func yamlString(_ value: String) -> String {
    guard
      let data = try? JSONEncoder().encode(value),
      let encoded = String(data: data, encoding: .utf8)
    else {
      assertionFailure("String values should always encode as JSON")
      return "\"\""
    }
    return encoded
  }
}

private extension DateComponents {
  var yaml: String {
    guard let year else {
      return ""
    }
    var output = "\(year)"
    guard let month else {
      return output
    }
    output.append("-\(month.formatted(.number.precision(.integerLength(2))))")
    guard let day else {
      return output
    }
    output.append("-\(day.formatted(.number.precision(.integerLength(2))))")
    return output
  }
}
