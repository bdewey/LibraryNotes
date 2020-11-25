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

public extension String {
  func appendingNewlineIfNecessary() -> String {
    if last == "\n" {
      return self
    } else {
      return appending("\n")
    }
  }

  func string(at range: NSRange) -> String {
    return String(self[Range(range, in: self)!])
  }

  func int(at range: NSRange) -> Int? {
    return Int(string(at: range))
  }

  var completeRange: NSRange {
    return NSRange(startIndex ..< endIndex, in: self)
  }

  func count(of character: Character) -> Int {
    return reduce(0) { (count, stringCharacter) -> Int in
      if stringCharacter == character { return count + 1 }
      return count
    }
  }
}

public extension StringProtocol {
  /// Returns the index that is *after* the `count` occurence of `character` in the receiver.
  func index(after count: Int, character: Character) -> String.Index? {
    var index = startIndex
    var newlineCount = 0
    while index != endIndex {
      if self[index] == character { newlineCount += 1 }
      index = self.index(after: index)
      if newlineCount == count {
        return index
      }
    }
    return nil
  }
}
