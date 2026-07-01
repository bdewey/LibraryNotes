// Copyright (c) 2018-2025  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Foundation
import LibraryNotesCore

enum MarkdownExport {
  static func frontmatter(for book: AugmentedBook) -> String {
    BookNoteMarkdownExporter.frontmatter(for: book)
  }

  static func yamlString(_ value: String) -> String {
    BookNoteMarkdownExporter.yamlString(value)
  }
}
