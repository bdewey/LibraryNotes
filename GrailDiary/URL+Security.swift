// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public extension URL {
  /// If this is an http url, convert it to https
  func asSecureURL() -> URL {
    guard var components = URLComponents(string: absoluteString) else { return self }
    if components.scheme == "http" {
      components.scheme = "https"
    }
    return components.url!
  }
}
