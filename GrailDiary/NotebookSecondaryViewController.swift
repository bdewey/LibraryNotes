//
//  NotebookDetailViewController.swift
//  GrailDiary
//
//  Created by Brian Dewey on 5/17/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import UIKit

/// View controllers that we show in the detail screen of the NotebookViewController conform to this protocol.
public protocol NotebookSecondaryViewController: UIViewController {
  /// A string identifying the type of detail screen (editor, quotes)
  static var notebookDetailType: String { get }

  func userActivityData() throws -> Data
  static func makeFromUserActivityData(data: Data, database: NoteDatabase) throws -> Self
}

public struct NotebookSecondaryViewControllerRegistry {
  private let typeMapping: [String: NotebookSecondaryViewController.Type]

  private init(types: [NotebookSecondaryViewController.Type]) {
    var typeMapping: [String: NotebookSecondaryViewController.Type] = [:]
    for type in types {
      typeMapping[type.notebookDetailType] = type
    }
    self.typeMapping = typeMapping
  }

  public static let shared = NotebookSecondaryViewControllerRegistry(types: [
    SavingTextEditViewController.self,
    QuotesViewController.self,
  ])

  public func reconstruct(type typeName: String, data: Data, database: NoteDatabase) throws -> NotebookSecondaryViewController {
    guard let type = typeMapping[typeName] else {
      throw CocoaError.error(.coderValueNotFound)
    }
    return try type.makeFromUserActivityData(data: data, database: database)
  }
}
