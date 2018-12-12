// Copyright © 2018 Brian's Brain. All rights reserved.

import CocoaLumberjack
import CommonplaceBook
import CwlSignal
import FlashcardKit
import Foundation
import IGListKit
import MiniMarkdown
import TextBundleKit

extension Tag {
  public static let fromCache = Tag(rawValue: "fromCache")
  public static let placeholder = Tag(rawValue: "placeholder")
  public static let truth = Tag(rawValue: "truth")
}

public protocol NotebookChangeListener: AnyObject {
  /// Sent when a significant change happened to the Notebook.
  /// - parameter notebook: The notebook that changed.
  /// - parameter change: A description of the change that happened.
  func notebook(_ notebook: Notebook, didChange key: Notebook.Key)
}

/// A "notebook" is a directory that contains individual "pages" (either plain text files
/// or textbundle bundles). Each page may contain "cards", which are individual facts to review
/// using a spaced repetition algorithm.
public final class Notebook {

  /// Extensible enum that talks about the kind of data in the Notebook.
  public struct Key: RawRepresentable, Hashable {
    public init(rawValue: String) {
      self.rawValue = rawValue
      Key.allKnownKeys.insert(rawValue)
    }

    public let rawValue: String

    public static var allKnownKeys = Set<String>()
  }

  /// Designated initializer.
  ///
  /// - parameter parsingrules: The rules used to parse the text content of documents.
  /// - parameter metadataProvider: Where we store all of the pages of the notebook (+ metadata)
  public init(
    parsingRules: ParsingRules,
    metadataProvider: FileMetadataProvider
  ) {
    self.parsingRules = parsingRules
    self.metadataProvider = metadataProvider

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    decoder.userInfo[.markdownParsingRules] = parsingRules
    self.decoder = decoder
  }

  deinit {
    openMetadocuments.forEach { $0.1.close() }
  }

  /// Bag of arbitrary data keyed off of MetadocumentKey
  internal var internalNotebookData = [Key: Any]()

  private var metadocumentLoadedConditions = [Key: Condition]()

  internal func conditionForKey(_ key: Key) -> Condition {
    if let condition = metadocumentLoadedConditions[key] {
      return condition
    } else {
      let condition = Condition()
      metadocumentLoadedConditions[key] = condition
      return condition
    }
  }
  
  internal var endpoints: [Cancellable] = []

  /// Decoder for this notebook. It depend on the parsing rules, which is why it is an instance
  /// property and not a class property.
  public let decoder: JSONDecoder

  public static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()

  /// The rules used to parse the text content of documents.
  public let parsingRules: ParsingRules

  public let metadataProvider: FileMetadataProvider

  /// Provides access to the container URL
  public var containerURL: URL { return metadataProvider.container }

  /// Where we cache our properties.
  internal var openMetadocuments = [Key: EditableDocument]()

  internal struct WeakListener {
    weak var listener: NotebookChangeListener?
    init(_ listener: NotebookChangeListener) { self.listener = listener }
  }
  private var listeners: [WeakListener] = []

  /// Registers an NotebookPageChangeListener.
  ///
  /// - parameter listener: The listener to register. It will get notifications of changes.
  public func addListener(_ listener: NotebookChangeListener) {
    listeners.append(WeakListener(listener))
  }

  /// Removes the NotebookPageChangeListener. It will no longer get notifications of changes.
  ///
  /// - parameter listener: The listener to unregister.
  public func removeListener(_ listener: NotebookChangeListener) {
    guard let index = listeners.firstIndex(where: { $0.listener === listener }) else { return }
    listeners.remove(at: index)
  }

  /// Tell all registered list adapters to perform updates.
  internal func notifyListeners(changed key: Key) {
    for adapter in listeners {
      adapter.listener?.notebook(self, didChange: key)
    }
  }
}

/// Any IGListKit ListAdapter can be a NotebookPageChangeListener.
extension ListAdapter: NotebookChangeListener {
  public func notebook(_ notebook: Notebook, didChange key: Notebook.Key) {
    if key == .pageProperties { performUpdates(animated: true) }
  }
}

