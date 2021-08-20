// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import UIKit

/// View controllers that we show in the detail screen of the NotebookViewController conform to this protocol.
public protocol NotebookSecondaryViewController: UIViewController {
  /// A string identifying the type of detail screen (editor, quotes)
  static var notebookDetailType: String { get }

  func userActivityData() throws -> Data

  /// If true, this view controller should be pushed on the view hierarchy for the "collapsed" split view state. Otherwise, the supplementary view controller will
  /// be the visible view controller after collapsing.
  var shouldShowWhenCollapsed: Bool { get }
  static func makeFromUserActivityData(data: Data, database: NoteDatabase, coverImageCache: CoverImageCache) throws -> Self
}

/// Maintains a mapping between secondary view controller "type strings" and actual types.
public struct NotebookSecondaryViewControllerRegistry {
  private let typeMapping: [String: NotebookSecondaryViewController.Type]

  private init(types: [NotebookSecondaryViewController.Type]) {
    var typeMapping: [String: NotebookSecondaryViewController.Type] = [:]
    for type in types {
      typeMapping[type.notebookDetailType] = type
    }
    self.typeMapping = typeMapping
  }

  /// All known kinds of secondary view controllers. If you add a new secondary view controller, you need to also add it to this list.
  public static let shared = NotebookSecondaryViewControllerRegistry(types: [
    SavingTextEditViewController.self,
    QuotesViewController.self,
  ])

  /// Builds a secondary view controller give its serialized data.
  public func reconstruct(
    type typeName: String,
    data: Data,
    database: NoteDatabase,
    coverImageCache: CoverImageCache
  ) throws -> NotebookSecondaryViewController {
    guard let type = typeMapping[typeName] else {
      throw CocoaError.error(.coderValueNotFound)
    }
    return try type.makeFromUserActivityData(data: data, database: database, coverImageCache: coverImageCache)
  }
}
