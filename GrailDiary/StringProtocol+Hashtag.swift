// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public extension StringProtocol {
  /// Given that the receiver names a hierarchical path with components separated by `pathSeparator`, returns true if the receiver contains `otherPath`
  ///
  /// Examples:
  /// - `book` is a prefix of `book` (trivial case)
  /// - `book` is a prefix of `book/2020`
  /// - `book/2020` **is not** a prefix of `book`
  /// - `book` **is not** a prefix of `books` (path components must exactly match)
  func isPathPrefix<S: StringProtocol>(
    of otherPath: S,
    pathSeparator: Character = "/",
    compareOptions: String.CompareOptions = [.caseInsensitive]
  ) -> Bool {
    let countOfPathComponents = split(separator: pathSeparator).count
    let componentPrefix = otherPath.split(separator: pathSeparator)
      .prefix(countOfPathComponents)
      .joined(separator: String(pathSeparator))
    return compare(componentPrefix, options: compareOptions) == .orderedSame
  }
}
