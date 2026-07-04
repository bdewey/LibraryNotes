// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

/// A generic book import request.
public struct BookImportRequest<Item> {
  /// The item to import
  public var item: Item

  /// Hashtags to apply to the imported book.
  public var hashtags: String

  /// If true, download a cover image on import.
  public var downloadCoverImages: Bool

  /// If true, this request is a "dry run" -- if `Item` is a collection, do not import everything.
  public var dryRun: Bool

  public init(item: Item, hashtags: String, downloadCoverImages: Bool, dryRun: Bool) {
    self.item = item
    self.hashtags = hashtags
    self.downloadCoverImages = downloadCoverImages
    self.dryRun = dryRun
  }

  public func replacingItem<NewItem>(_ newItem: NewItem) -> BookImportRequest<NewItem> {
    BookImportRequest<NewItem>(item: newItem, hashtags: hashtags, downloadCoverImages: downloadCoverImages, dryRun: dryRun)
  }
}
