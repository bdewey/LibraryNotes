//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

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
