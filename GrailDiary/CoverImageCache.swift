// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import Logging
import UIKit

/// A simple cache of book cover images.
public final class CoverImageCache {
  /// Designated initializer.
  /// - parameter database: The database that stores books.
  init(database: NoteDatabase) {
    self.database = database
  }

  private let database: NoteDatabase
  private let cache = NSCache<CacheKey, UIImage>()

  /// Gets the cover image for a book.
  /// - Parameters:
  ///   - bookID: Note identifier for the book.
  ///   - maxSize: The length of the maximum dimension of the decoded thumbnail image. The aspect ratio will be preserved.
  /// - Returns: The cover image, if one exists.
  public func coverImage(bookID: String, maxSize: CGFloat) -> UIImage? {
    let cacheKey = CacheKey(noteIdentifier: bookID, maxSize: maxSize)
    let cacheKey2 = CacheKey(noteIdentifier: bookID, maxSize: maxSize)
    assert(cacheKey == cacheKey2)
    assert(cacheKey.hashValue == cacheKey2.hashValue)
    if let image = cache.object(forKey: cacheKey) {
      return image
    }
    guard
      let data = try? database.read(noteIdentifier: bookID, key: .coverImage).resolved(with: .lastWriterWins)?.blob,
      let thumbnail = data.image(maxSize: maxSize)
    else {
      return nil
    }
    cache.setObject(thumbnail, forKey: cacheKey)
    assert(cache.object(forKey: cacheKey) != nil)
    return thumbnail
  }
}

private extension CoverImageCache {
  /// Cache key.
  /// - note: `NSCache` uses the `NSObject` methods for hashing & equality.
  final class CacheKey: NSObject {
    init(noteIdentifier: Note.Identifier, maxSize: CGFloat) {
      self.noteIdentifier = noteIdentifier
      self.maxSize = Int(round(maxSize))
    }

    let noteIdentifier: Note.Identifier
    let maxSize: Int

    override var hash: Int {
      var hasher = Hasher()
      hasher.combine(noteIdentifier)
      hasher.combine(maxSize)
      return hasher.finalize()
    }

    static func == (lhs: CoverImageCache.CacheKey, rhs: CoverImageCache.CacheKey) -> Bool {
      return (lhs.noteIdentifier, lhs.maxSize) == (rhs.noteIdentifier, rhs.maxSize)
    }

    override func isEqual(_ object: Any?) -> Bool {
      guard let other = object as? CacheKey else { return false }
      return self == other
    }

    override var description: String {
      "<Cache key: \(noteIdentifier) \(maxSize)>"
    }
  }
}
