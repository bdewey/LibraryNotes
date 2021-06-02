// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public enum ApplicationMimeType: String {
  /// Private MIME type for URLs.
  case url = "text/vnd.grail.url"

  /// MIME type for Book
  case book = "application/json;type=Book"
}
