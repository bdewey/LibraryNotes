// Copyright © 2018 Brian's Brain. All rights reserved.

import CocoaLumberjack
import Foundation
import UIKit

/// A "notebook" is a directory that contains individual "pages" (either plain text files
/// or textbundle bundles). Each page may contain "cards", which are individual facts to review
/// using a spaced repetition algorithm.
public final class Notebook: NSObject {
  public init(container: URL) {
    self.container = container

    super.init()
    addPresenter()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(removePresenter),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(addPresenter),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  public let container: URL
  public let presentedItemOperationQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    return queue
  }()

  @objc private func removePresenter() {
    NSFileCoordinator.removeFilePresenter(self)
  }

  @objc private func addPresenter() {
    NSFileCoordinator.addFilePresenter(self)
  }
}

// Monitor and respond to changes in the container.
extension Notebook: NSFilePresenter {
  public var presentedItemURL: URL? { return container }

  public func presentedSubitemDidAppear(at url: URL) {
    DDLogInfo("presentedSubitemDidAppear at \(url.lastPathComponent)")
  }

  public func presentedSubitemDidChange(at url: URL) {
    DDLogInfo("presentedSubitemDidChange at \(url.lastPathComponent)")
    do {
      let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
      print("modification date = \(attributes[FileAttributeKey.creationDate])")
    } catch {
      // NOTHING
    }
  }

  public func presentedSubitem(at oldURL: URL, didMoveTo newURL: URL) {
    DDLogInfo("presentedSubitem at old \(oldURL.lastPathComponent) didMoveTo \(newURL.lastPathComponent)")
  }

  public func accommodatePresentedSubitemDeletion(at url: URL, completionHandler: @escaping (Error?) -> Void) {
    DDLogInfo("Deleting \(url.lastPathComponent)")
    completionHandler(nil)
  }

  public func presentedSubitem(at url: URL, didGain version: NSFileVersion) {
    DDLogInfo("Item gained version: \(url.lastPathComponent): \(version.modificationDate)")
  }
}
