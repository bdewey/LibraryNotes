// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

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
