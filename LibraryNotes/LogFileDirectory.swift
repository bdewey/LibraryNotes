// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import ZIPFoundation

public struct LogFileDirectory {
  /// The URL of the log file directory.
  public let url: URL

  public var currentLogFileURL: URL {
    url.appendingPathComponent("grail-diary-current.log")
  }

  public func initializeCurrentLogFile() {
    if
      let existingAttributes = try? FileManager.default.attributesOfItem(atPath: currentLogFileURL.path),
      let existingSize = (existingAttributes[.size] as? Int),
      existingSize > 1024 * 1024
    {
      // Roll the log.
      let creationDate = (existingAttributes[.creationDate] as? Date) ?? Date()
      let unwantedCharacters = CharacterSet(charactersIn: "-:")
      var dateString = ISO8601DateFormatter().string(from: creationDate)
      dateString.removeAll(where: { unwantedCharacters.contains($0.unicodeScalars.first!) })
      let archiveLogFileURL = url.appendingPathComponent("grail-diary-\(dateString).log")
      try? FileManager.default.moveItem(at: currentLogFileURL, to: archiveLogFileURL)
    }
  }

  public func makeZippedLog() throws -> Data {
    let archive = Archive(accessMode: .create)!
    let data = try Data(contentsOf: currentLogFileURL)
    try archive.addEntry(with: "grail-diary-current.log", type: .file, uncompressedSize: UInt32(data.count), compressionMethod: .deflate) { position, size in
      data[position ..< (position + size)]
    }
    return archive.data!
  }

  public static var shared: LogFileDirectory {
    // Right now, put the logs into the Documents directory so they're easy to find.
    // swiftlint:disable:next force_try
    let documentsDirectoryURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let logDirectoryURL = documentsDirectoryURL.appendingPathComponent("logs")
    // Try to create the "logs" subdirectory if it does not exist.
    try? FileManager.default.createDirectory(at: logDirectoryURL, withIntermediateDirectories: false, attributes: nil)
    return LogFileDirectory(url: logDirectoryURL)
  }
}
