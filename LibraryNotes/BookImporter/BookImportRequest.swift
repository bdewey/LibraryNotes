// Copyright © 2021 Brian's Brain. All rights reserved.

import Foundation

/// A generic book import request.
struct BookImportRequest<Item> {
  /// The item to import
  var item: Item

  /// Hashtags to apply to the imported book.
  var hashtags: String

  /// If true, download a cover image on import.
  var downloadCoverImages: Bool

  /// If true, this request is a "dry run" -- if `Item` is a collection, do not import everything.
  var dryRun: Bool

  func replacingItem<NewItem>(_ newItem: NewItem) -> BookImportRequest<NewItem> {
    BookImportRequest<NewItem>(item: newItem, hashtags: hashtags, downloadCoverImages: downloadCoverImages, dryRun: dryRun)
  }
}
