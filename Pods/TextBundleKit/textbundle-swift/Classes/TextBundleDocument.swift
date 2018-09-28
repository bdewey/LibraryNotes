//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import UIKit

public protocol TextBundleDocumentSaveListener: class {
  typealias ChangeBlock = () -> Void
  var textBundleListenerHasChanges: ChangeBlock? { get set }
  func textBundleDocumentWillSave(_ textBundleDocument: TextBundleDocument) throws
  func textBundleDocumentDidLoad(_ textBundleDocument: TextBundleDocument)
}

/// UIDocument class that can read and edit the text contents and metadata of a
/// textbundle wrapper.
///
/// See http://textbundle.org
public final class TextBundleDocument: UIDocumentWithPreviousError {
  
  /// The FileWrapper that contains all of the TextBundle contents.
  public var bundle: FileWrapper
  
  public override init(fileURL url: URL) {
    self.bundle = FileWrapper(directoryWithFileWrappers: [:])
    super.init(fileURL: url)
  }
  
  /// Listeners are strongly held until the document closes.
  private var listeners = [String: TextBundleDocumentSaveListener]()
  
  public func addListener(key: String, listener: TextBundleDocumentSaveListener) {
    assert(listeners[key] == nil)
    listener.textBundleListenerHasChanges = { [weak self] in self?.updateChangeCount(.done) }
    listeners[key] = listener
  }

  public func listener<Listener: TextBundleDocumentSaveListener>(
    for key: String,
    constructor: (TextBundleDocument) -> Listener
  ) -> Listener {
    precondition(!documentState.contains(.closed))
    if let listener = listeners[key] {
      return listener as! Listener
    }
    let listener = constructor(self)
    addListener(key: key, listener: listener)
    return listener
  }
  
  /// Write in-memory contents to textBundle and return textBundle for storage.
  override public func contents(forType typeName: String) throws -> Any {
    for (_, listener) in listeners {
      try listener.textBundleDocumentWillSave(self)
    }
    return bundle
  }
  
  /// Loads the textbundle.
  public override func load(
    fromContents contents: Any,
    ofType typeName: String?
  ) throws {
    guard let directory = contents as? FileWrapper else {
      throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError, userInfo: nil)
    }
    bundle = directory
    for (_, listener) in listeners {
      listener.textBundleDocumentDidLoad(self)
    }
  }
}

extension TextBundleDocument {
  
  public enum Error: Swift.Error {
    
    /// A bundle key is already in use in the package.
    case keyAlreadyUsed(key: String)
    
    /// The key is not used to identify data in the bundle.
    case noSuchDataKey(key: String)
    
    /// The child directory path cannot be used
    case invalidChildPath(error: Swift.Error)
  }
  
  /// Convenience: Exposes the names of the assets in the bundle.
  public var assetNames: [String] {
    if let assetNames = bundle.fileWrappers?["assets"]?.fileWrappers?.keys {
      return Array(assetNames)
    } else {
      return []
    }
  }
  
  // MARK: - Manipulating bundle contents
  
  /// Adds data to the bundle.
  ///
  /// - parameter data: The data to add.
  /// - parameter preferredFilename: The key to access the data
  /// - parameter childDirectoryPath: The path to a child directory in the bundle. Use an empty
  ///                                 array to add the data to the root of the bundle.
  /// - returns: The actual key used to store the data.
  /// - throws: Error.invalidChildDirectoryPath if childDirectoryPath cannot be used, for example
  ///           if something in the path array is already used by a non-directory file wrapper.
  @discardableResult
  public func addData(
    _ data: Data,
    preferredFilename: String,
    replaceIfExists: Bool = true,
    childDirectoryPath: [String] = []
  ) throws -> String {
    let container = try containerWrapper(at: childDirectoryPath)
    let child = FileWrapper(regularFileWithContents: data)
    child.preferredFilename = preferredFilename
    if replaceIfExists, let existingWrapper = container.fileWrappers?[preferredFilename] {
      container.removeFileWrapper(existingWrapper)
    }
    let key = container.addFileWrapper(child)
    undoManager.registerUndo(withTarget: container) { (container) in
      container.removeFileWrapper(child)
    }
    return key
  }
  
  /// Returns the keys used by a container in the bundle.
  /// - parameter childDirectoryPath: The path to a child directory in the bundle. Use an empty
  ///                                 array to add the data to the root of the bundle.
  /// - returns: The keys used in the container.
  /// - throws: Error.invalidChildDirectoryPath if childDirectoryPath cannot be used, for example
  ///           if something in the path array is already used by a non-directory file wrapper.
  public func keys(at childDirectoryPath: [String] = []) throws -> [String] {
    let container = try containerWrapper(at: childDirectoryPath)
    if let fileWrappers = container.fileWrappers {
      return Array(fileWrappers.keys)
    } else {
      return []
    }
  }
  
  /// Returns the data associated with a key in the bundle.
  /// - parameter key: The key identifying the data.
  /// - parameter childDirectoryPath: The path to a child directory in the bundle. Use an empty
  ///                                 array to add the data to the root of the bundle.
  /// - returns: The data associated with the key.
  /// - throws: Error.noSuchDataKey if the key is not used to identify data in the bundle.
  public func data(for key: String, at childDirectoryPath: [String] = []) throws -> Data {
    let container = try containerWrapper(at: childDirectoryPath)
    guard let wrapper = container.fileWrappers?[key], let data = wrapper.regularFileContents else {
      throw Error.noSuchDataKey(key: key)
    }
    return data
  }
  
  /// Finds or creates a container wrapper at a given path.
  /// - parameter childDirectoryPath: The path to a child directory in the bundle. Use an empty
  ///                                 array to add the data to the root of the bundle.
  /// - throws: Error.invalidChildDirectoryPath if childDirectoryPath cannot be used, for example
  ///           if something in the path array is already used by a non-directory file wrapper.
  private func containerWrapper(at childDirectoryPath: [String]) throws -> FileWrapper {
    var containerWrapper = bundle
    for pathComponent in childDirectoryPath {
      do {
        containerWrapper = try directory(with: pathComponent, in: containerWrapper)
      } catch {
        throw Error.invalidChildPath(error: error)
      }
    }
    return containerWrapper
  }
  
  /// Returns a directory FileWrapper.
  /// - parameter key: The key used to access the directory.
  /// - returns: The directory FileWrapper.
  /// - throws: Error.keyAlreadyUsed if the key is already in use in the bundle for a non-directory.
  private func directory(with key: String, in container: FileWrapper) throws -> FileWrapper {
    if let wrapper = container.fileWrappers?[key] {
      if wrapper.isDirectory {
        return wrapper
      } else {
        throw Error.keyAlreadyUsed(key: key)
      }
    } else {
      let wrapper = FileWrapper(directoryWithFileWrappers: [:])
      wrapper.preferredFilename = key
      container.addFileWrapper(wrapper)
      undoManager.registerUndo(withTarget: container) { (bundle) in
        bundle.removeFileWrapper(wrapper)
      }
      return wrapper
    }
  }
}
