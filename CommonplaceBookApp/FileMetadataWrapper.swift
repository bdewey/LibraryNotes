// Copyright © 2018 Brian's Brain. All rights reserved.

// swiftlint:disable force_cast

import CocoaLumberjack
import Foundation
import IGListKit
import MobileCoreServices

public struct FileMetadata: Equatable {
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

  // Persisted properties
  public let contentChangeDate: Date
  public let contentType: String
  public let contentTypeTree: [String]
  public let displayName: String
  public let downloadingStatus: String
  public let fileName: String

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

extension FileMetadataWrapper: CustomStringConvertible {
  public var description: String { return value.description }
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
