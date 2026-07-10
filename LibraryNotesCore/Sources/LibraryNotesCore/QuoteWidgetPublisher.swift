// Copyright (c) 2018-2026  Brian Dewey. Covered by the Apache 2.0 license.

import ImageIO
import UniformTypeIdentifiers

/// Publishes the quote projection that the widget reads from the app-group database.
public struct QuoteWidgetPublisher {
  private let store: QuoteWidgetStore

  public init(store: QuoteWidgetStore = QuoteWidgetStore()) {
    self.store = store
  }

  /// Copies quotes from a library database into the widget's dedicated cache.
  ///
  /// The source database remains authoritative. Covers are downsampled before
  /// publication so a widget only reads small, display-ready image blobs.
  public func publish(from database: NoteDatabase) async throws -> QuoteWidgetPublication {
    let quoteIdentifiers = try await allQuoteIdentifiers(in: database)
    let candidates = try database.attributedQuotes(for: quoteIdentifiers).map { quote in
      var candidate = QuoteWidgetCandidate(quote)
      candidate.thumbnailImage = quote.thumbnailImage?.widgetThumbnailData(maxPixelSize: 160)
      return candidate
    }
    let sourceLibraryDisplayName = database.fileURL.deletingPathExtension().lastPathComponent
    try store.replaceQuotes(
      sourceLibraryDisplayName: sourceLibraryDisplayName,
      cacheTimestamp: .now,
      candidates: candidates
    )
    return QuoteWidgetPublication(
      sourceLibraryDisplayName: sourceLibraryDisplayName,
      quoteCount: candidates.count,
      coverCount: candidates.count { $0.thumbnailImage != nil },
      firstCoverByteCount: candidates.first(where: { $0.thumbnailImage != nil })?.thumbnailImage?.count ?? 0,
      databaseURL: store.databaseURL
    )
  }

  private func allQuoteIdentifiers(in database: NoteDatabase) async throws -> [ContentIdentifier] {
    for try await quoteIdentifiers in database.promptCollectionPublisher(promptType: .quote, tagged: nil).values {
      return quoteIdentifiers
    }
    return []
  }
}

public struct QuoteWidgetPublication: Sendable {
  public let sourceLibraryDisplayName: String
  public let quoteCount: Int
  public let coverCount: Int
  public let firstCoverByteCount: Int
  public let databaseURL: URL?
}

private extension Data {
  func widgetThumbnailData(maxPixelSize: CGFloat) -> Data? {
    guard let imageSource = CGImageSourceCreateWithData(self as CFData, nil) else {
      return nil
    }
    let options: [NSString: NSObject] = [
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize as NSObject,
      kCGImageSourceCreateThumbnailFromImageAlways: true as NSObject,
      kCGImageSourceCreateThumbnailWithTransform: true as NSObject,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary?) else {
      return nil
    }
    let imageData = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(imageData, UTType.jpeg.identifier as CFString, 1, nil) else {
      return nil
    }
    CGImageDestinationAddImage(
      destination,
      image,
      [kCGImageDestinationLossyCompressionQuality: 0.72] as CFDictionary
    )
    guard CGImageDestinationFinalize(destination) else {
      return nil
    }
    return imageData as Data
  }
}
