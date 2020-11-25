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

/// Given a base file name and an extension, implements an infinite sequence of file names
/// formed by appending an counter to the base name.
struct FileNameGenerator: Sequence {
  let baseName: String
  let pathExtension: String

  struct Iterator: IteratorProtocol {
    let generator: FileNameGenerator
    var counter: Int

    var currentName: String {
      if counter == 0 {
        return generator.baseName + "." + generator.pathExtension
      } else {
        return generator.baseName + "-" + String(counter) + "." + generator.pathExtension
      }
    }

    mutating func next() -> String? {
      let returnValue = currentName
      counter += 1
      return returnValue
    }
  }

  func makeIterator() -> FileNameGenerator.Iterator {
    return Iterator(generator: self, counter: 0)
  }

  func firstName(notIn metadataProvider: FileMetadataProvider) -> String {
    for name in self {
      let itemExists = (try? metadataProvider.itemExists(with: name)) ?? false
      if !itemExists { return name }
    }
    preconditionFailure("Unreachable: self is infinite sequence")
  }
}
