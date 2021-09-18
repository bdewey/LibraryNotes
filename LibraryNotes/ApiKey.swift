// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

enum ApiKey {
  /// The Google Books API key. Initialize this by creating ApiSecrets.xcconfig and defining `GOOGLE_BOOKS_API_KEY`
  static var googleBooks: String? {
    Bundle.main.infoDictionary?["GOOGLE_BOOKS_API_KEY"] as? String
  }
}
