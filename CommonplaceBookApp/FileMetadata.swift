// Copyright © 2017-present Brian's Brain. All rights reserved.

// swiftlint:disable force_cast

import CocoaLumberjack
import Foundation
import Logging
import MobileCoreServices

/// Contains the properties of a file at a point in time (the structure is immutable)
/// You can create this either from an NSMetadataItem (Spotlight for iCloud documents)
/// or from a URL to a local file.
public struct FileMetadata: Equatable {
  /// Extract file metadata from an `NSMetadataItem`
  public init(metadataItem: NSMetadataItem) {
    self.contentChangeDate = metadataItem.value(
      forAttribute: NSMetadataItemFSContentChangeDateKey
    ) as! Date
    self.contentType = String(
      metadataItem.value(forAttribute: NSMetadataItemContentTypeKey) as! NSString
    )
    let nsStringArray = metadataItem.value(
      forAttribute: NSMetadataItemContentTypeTreeKey
    ) as? [NSString] ?? []
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

  /// Extract file metadata from the file system
  public init(fileURL: URL) throws {
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path) as NSDictionary
    self.contentChangeDate = attributes.fileModificationDate()!
    let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileURL.pathExtension as CFString, nil)?.takeRetainedValue()
    self.contentType = (uti as String?) ?? ""
    self.contentTypeTree = []
    self.displayName = FileManager.default.displayName(atPath: fileURL.path)
    self.downloadingStatus = NSMetadataUbiquitousItemDownloadingStatusCurrent
    self.fileName = fileURL.lastPathComponent
    self.isDownloading = false
    self.isUploading = false
  }

  /// Helpful initializer for testing.
  public init(
    fileName: String,
    contentChangeDate: Date = Date(),
    contentType: String = "public.plain-text"
  ) {
    self.fileName = fileName
    self.contentChangeDate = contentChangeDate
    self.contentType = contentType

    self.contentTypeTree = []
    self.displayName = fileName
    self.downloadingStatus = NSMetadataUbiquitousItemDownloadingStatusCurrent
    self.isDownloading = false
    self.isUploading = false
  }

  // Persisted properties
  public var contentChangeDate: Date
  public let contentType: String
  public let contentTypeTree: [String]
  public let displayName: String
  public let downloadingStatus: String
  public var fileName: String

  // Transient properties
  public let isDownloading: Bool
  public let isUploading: Bool
}

extension FileMetadata: CustomStringConvertible {
  public var description: String {
    return "Name = '\(displayName)' isUploading=\(isUploading)"
  }
}

// Need custom Codable conformance because we don't want to load/save transient properties.
extension FileMetadata: Codable {
  enum CodingKeys: String, CodingKey {
    case contentChangeDate
    case contentType
    case contentTypeTree
    case displayName
    case downloadingStatus
    case fileName
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.contentChangeDate = try container.decode(Date.self, forKey: .contentChangeDate)
    self.contentType = try container.decode(String.self, forKey: .contentType)
    self.contentTypeTree = try container.decode([String].self, forKey: .contentTypeTree)
    self.displayName = try container.decode(String.self, forKey: .displayName)
    self.downloadingStatus = try container.decode(String.self, forKey: .downloadingStatus)
    self.fileName = try container.decode(String.self, forKey: .fileName)

    self.isDownloading = false
    self.isUploading = false
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(contentChangeDate, forKey: .contentChangeDate)
    try container.encode(contentType, forKey: .contentType)
    try container.encode(contentTypeTree, forKey: .contentTypeTree)
    try container.encode(displayName, forKey: .displayName)
    try container.encode(downloadingStatus, forKey: .downloadingStatus)
    try container.encode(fileName, forKey: .fileName)
  }
}

extension FileMetadata {
  /// Triggers download from iCloud if needed.
  /// - note: TODO: This should be part of the FileMetadataProvider.
  /// - parameter container: The URL of the directory that contains the item.
  public func downloadIfNeeded(in container: URL) {
    if downloadingStatus != NSMetadataUbiquitousItemDownloadingStatusCurrent {
      FileMetadata.downloadItem(self, in: container)
    }
  }

  /// Background serial queue for downloading.
  private static let downloadQueue = DispatchQueue(
    label: "org.brians-brain.FileMetadata.download",
    qos: .default,
    attributes: []
  )

  /// Actually download items, one at a time, in a background queue.
  private static func downloadItem(_ item: FileMetadata, in container: URL) {
    let fileURL = container.appendingPathComponent(item.fileName)
    downloadQueue.async {
      Logger.shared.debug("Downloading \(String(describing: item.fileName))")
      try? FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
    }
  }
}
