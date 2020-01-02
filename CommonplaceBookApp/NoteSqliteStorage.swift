// Copyright © 2020 Brian's Brain. All rights reserved.

import Foundation
import GRDB
import MiniMarkdown

/// Implementation of the NoteStorage protocol that stores all of the notes in a single sqlite database.
/// It loads the entire database into memory and uses NSFileCoordinator to be compatible with iCloud Document storage.
public final class NoteSqliteStorage: NSObject {
  public init(fileURL: URL, parsingRules: ParsingRules) {
    self.fileURL = fileURL
    self.parsingRules = parsingRules
  }

  /// URL to the sqlite file
  public let fileURL: URL

  /// Parsing rules used to extract metadata from note contents.
  public let parsingRules: ParsingRules

  private var dbQueue: DatabaseQueue?

  public enum Error: String, Swift.Error {
    case databaseAlreadyOpen = "The database is already open."
  }

  /// Opens the database.
  /// - parameter completionHandler: A handler called after opening the database. If the error is nil, the database opened successfully.
  public func open(completionHandler: ((Swift.Error?) -> Void)? = nil) {
    guard dbQueue == nil else {
      completionHandler?(Error.databaseAlreadyOpen)
      return
    }
    do {
      try dbQueue = memoryDatabaseQueue(fileURL: fileURL)
      completionHandler?(nil)
    } catch {
      completionHandler?(error)
    }
  }
}

// MARK: - Private
private extension NoteSqliteStorage {
  /// Creates an in-memory database queue for the contents of the file at `fileURL`
  /// - note: If fileURL does not exist, this method returns an empty database queue.
  /// - parameter fileURL: The file URL to read.
  /// - returns: An in-memory database queue with the contents of fileURL.
  func memoryDatabaseQueue(fileURL: URL) throws -> DatabaseQueue {
    let coordinator = NSFileCoordinator(filePresenter: self)
    var coordinatorError: NSError?
    var result: Result<DatabaseQueue, Swift.Error>?
    coordinator.coordinate(readingItemAt: fileURL, options: [], error: &coordinatorError) { coordinatedURL in
      result = Result {
        let queue = try DatabaseQueue(path: ":memory:")
        if let fileQueue = try? DatabaseQueue(path: coordinatedURL.path) {
          try fileQueue.backup(to: queue)
        }
        return queue
      }
    }

    if let coordinatorError = coordinatorError {
      throw coordinatorError
    }

    switch result {
    case .failure(let error):
      throw error
    case .success(let dbQueue):
      return dbQueue
    case .none:
      preconditionFailure()
    }
  }
}

// MARK: - NSFilePresenter
extension NoteSqliteStorage: NSFilePresenter {
  public var presentedItemURL: URL? { fileURL }
  public var presentedItemOperationQueue: OperationQueue { OperationQueue.main }
}
