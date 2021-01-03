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

extension StringProtocol {
  /// True if `pattern` is contained in the receiver, with any number of intervening characters.
  /// - note: The algorithm does case-insensive comparisons of  characters.
  /// - note: If the pattern is empty, the method returns `true`
  func fuzzyMatch<S: StringProtocol>(pattern: S) -> Bool {
    var searchRange = startIndex ..< endIndex
    var patternIndex = pattern.startIndex
    while patternIndex != pattern.endIndex {
      if let resultRange = range(of: pattern[patternIndex ... patternIndex], options: .caseInsensitive, range: searchRange) {
        searchRange = index(after: resultRange.lowerBound) ..< endIndex
      } else {
        return false
      }
      patternIndex = pattern.index(after: patternIndex)
    }
    return true
  }
}
