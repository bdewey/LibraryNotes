// Copyright © 2018 Brian's Brain. All rights reserved.

// swiftlint:disable force_cast

import CocoaLumberjack
import Foundation
import IGListKit

public struct FileMetadata: Equatable, Codable {
  public init(metadataItem: NSMetadataItem) {
    self.contentChangeDate = metadataItem.value(
      forAttribute: NSMetadataItemFSContentChangeDateKey
    ) as! Date
    self.contentType = String(
      metadataItem.value(forAttribute: NSMetadataItemContentTypeKey) as! NSString
    )
    let nsStringArray = metadataItem.value(
      forAttribute: NSMetadataItemContentTypeTreeKey
      ) as! [NSString]
    self.contentTypeTree = nsStringArray.map { String($0) }
    self.displayName = String(
      metadataItem.value(forAttribute: NSMetadataItemDisplayNameKey) as! NSString
    )
    self.downloadingStatus = String(metadataItem.value(
      forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey
      ) as! NSString)
    let fileURL = metadataItem.value(forAttribute: NSMetadataItemURLKey) as! URL
    self.fileName = fileURL.lastPathComponent
    self.isDownloading = (metadataItem.value(
      forAttribute: NSMetadataUbiquitousItemIsDownloadingKey
    ) as! NSNumber).boolValue
    self.isUploading = (metadataItem.value(
      forAttribute: NSMetadataUbiquitousItemIsUploadingKey
    ) as! NSNumber).boolValue
  }

  public let contentChangeDate: Date
  public let contentType: String
  public let contentTypeTree: [String]
  public let displayName: String
  public let downloadingStatus: String
  public let fileName: String
  public let isDownloading: Bool
  public let isUploading: Bool
}

// Immutable value object with key properties of an NSMetadataItem, which apparently mutates.
public final class FileMetadataWrapper: Equatable {
  public init(metadataItem: NSMetadataItem) {
    self.value = FileMetadata(metadataItem: metadataItem)
  }

  public let value: FileMetadata

  public static func == (lhs: FileMetadataWrapper, rhs: FileMetadataWrapper) -> Bool {
    return lhs.value == rhs.value
  }

  public func downloadIfNeeded(in container: URL) {
    if value.downloadingStatus != NSMetadataUbiquitousItemDownloadingStatusCurrent {
      FileMetadataWrapper.downloadItem(self, in: container)
    }
  }
}

extension FileMetadataWrapper {
  private static let downloadQueue = DispatchQueue(
    label: "org.brians-brain.FileMetadata.download",
    qos: .default,
    attributes: []
  )

  private static func downloadItem(_ item: FileMetadataWrapper, in container: URL) {
    let fileURL = container.appendingPathComponent(item.value.fileName)
    downloadQueue.async {
      DDLogDebug("Downloading " + String(describing: item.value.fileName))
      try? FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
    }
  }
}
