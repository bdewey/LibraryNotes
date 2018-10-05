// Copyright © 2018 Brian's Brain. All rights reserved.

// swiftlint:disable force_cast

import Foundation
import IGListKit

// TODO: This now looks like it should just be type-safe extensions on NSMetadataItem

public final class FileMetadata: Equatable {
  private let metadataItem: NSMetadataItem

  public init(metadataItem: NSMetadataItem) {
    assert(metadataItem.attributes.contains(NSMetadataItemURLKey))
    assert(metadataItem.attributes.contains(NSMetadataItemDisplayNameKey))
    assert(metadataItem.attributes.contains(NSMetadataItemContentTypeKey))
    assert(metadataItem.attributes.contains(NSMetadataItemContentTypeTreeKey))
    self.metadataItem = metadataItem
  }

  public func downloadIfNeeded() {
    if downloadingStatus != NSMetadataUbiquitousItemDownloadingStatusCurrent {
      FileMetadata.downloadItem(self)
    }
  }

  public var fileURL: URL {
    return metadataItem.value(forAttribute: NSMetadataItemURLKey) as! URL
  }

  public var displayName: String {
    let nsstring = metadataItem.value(forAttribute: NSMetadataItemDisplayNameKey) as! NSString
    return String(nsstring)
  }

  public var contentType: String {
    let nsstring = metadataItem.value(forAttribute: NSMetadataItemContentTypeKey) as! NSString
    return String(nsstring)
  }

  public var downloadingStatus: String {
    let nsstring = metadataItem.value(
      forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey
    ) as! NSString
    return String(nsstring)
  }

  public var isDownloading: Bool {
    let value = metadataItem.value(
      forAttribute: NSMetadataUbiquitousItemIsDownloadingKey
      ) as! NSNumber
    return value.boolValue
  }

  public var isUploading: Bool {
    let value = metadataItem.value(
      forAttribute: NSMetadataUbiquitousItemIsUploadingKey
    ) as! NSNumber
    return value.boolValue
  }

  public var contentTypeTree: [String] {
    let nsStringArray = metadataItem.value(
      forAttribute: NSMetadataItemContentTypeTreeKey
    ) as! [NSString]
    return nsStringArray.map { String($0) }
  }

  public static func == (lhs: FileMetadata, rhs: FileMetadata) -> Bool {
    return lhs.metadataItem === rhs.metadataItem
  }
}

extension FileMetadata: ListDiffable {
  public func diffIdentifier() -> NSObjectProtocol {
    return fileURL as NSURL
  }

  public func isEqual(toDiffableObject object: ListDiffable?) -> Bool {
    guard let otherItem = object as? FileMetadata else { return false }
    if fileURL != otherItem.fileURL { return false }
    if downloadingStatus != otherItem.downloadingStatus {
        return false
    }
    return true
  }
}

extension FileMetadata {
  private static let downloadQueue = DispatchQueue(
    label: "org.brians-brain.FileMetadata.download",
    qos: .default,
    attributes: []
  )

  private static func downloadItem(_ item: FileMetadata) {
    downloadQueue.async {
      try? FileManager.default.startDownloadingUbiquitousItem(at: item.fileURL)
    }
  }
}
