// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Foundation
import Logging
import UIKit

/// An action we can perform on a book in the library.
///
/// A `BookAction` can be used as either a swipe action or in a contextual menu.
struct BookAction {
  /// Title for the action.
  var title: String?

  /// Optional icon for the action.
  var image: UIImage?

  /// If the action will be shown as a swipe action, the background color for the action.
  var backgroundColor: UIColor?

  /// True if this action is destructive.
  var destructive: Bool = false

  /// True if this action should be available as a swipe action on this book.
  var availableAsSwipeAction = true

  /// The handler invoked when the person picks this action.
  var handler: () throws -> Void

  /// Returns the action as a `UIContextualAction`, if possible.
  func asContextualAction() -> UIContextualAction? {
    guard availableAsSwipeAction else { return nil }
    let action = UIContextualAction(style: destructive ? .destructive : .normal, title: title) { _, _, completion in
      do {
        try handler()
        completion(true)
      } catch {
        Logger.shared.error("Unexpected error executing action \(String(describing: title)): \(error)")
        completion(false)
      }
    }
    action.image = image
    action.backgroundColor = backgroundColor
    return action
  }

  func asAction() -> UIAction {
    UIAction(title: title ?? "", image: image, attributes: destructive ? [.destructive] : []) { _ in
      do {
        try handler()
      } catch {
        Logger.shared.error("Unexpected error executing action \(String(describing: title)): \(error)")
      }
    }
  }

  /// Returns an action for deleting the book represented by `viewProperties`
  static func deleteItem(_ viewProperties: BookViewProperties, in database: NoteDatabase) -> BookAction? {
    return BookAction(title: "Delete", image: UIImage(systemName: "trash"), destructive: true) {
      if viewProperties.noteProperties.folder == PredefinedFolder.recentlyDeleted.rawValue {
        try database.deleteNote(noteIdentifier: viewProperties.pageKey)
      } else {
        try database.updateNote(noteIdentifier: viewProperties.pageKey, updateBlock: { note in
          var note = note
          note.metadata.folder = PredefinedFolder.recentlyDeleted.rawValue
          return note
        })
      }
    }
  }

  /// Returns an action for moving the book represented by `viewProperties` to the `.read` section of the collection.
  static func moveItemToRead(_ viewProperties: BookViewProperties, in database: NoteDatabase) -> BookAction? {
    guard viewProperties.bookCategory != .read else {
      return nil
    }
    return BookAction(title: "Read", image: UIImage(systemName: "books.vertical"), backgroundColor: .grailTint, availableAsSwipeAction: false) {
      try database.updateNote(noteIdentifier: viewProperties.pageKey, updateBlock: { note -> Note in
        var note = note
        if var book = note.metadata.book {
          let today = Calendar.current.dateComponents([.year, .month, .day], from: Date())
          if book.readingHistory == nil {
            book.readingHistory = ReadingHistory()
          }
          book.readingHistory!.finishReading(finishDate: today)
          note.metadata.book = book
        }
        return note
      })
      Logger.shared.info("Moved \(viewProperties.pageKey) to 'read'")
    }
  }

  /// Returns an action for moving the book represented by `viewProperties` to the `.currentlyReading` section of the collection.
  static func moveItemToCurrentlyReading(_ viewProperties: BookViewProperties, in database: NoteDatabase) -> BookAction? {
    guard viewProperties.bookCategory != .currentlyReading else {
      return nil
    }
    return BookAction(title: "Currently Reading", image: UIImage(systemName: "book"), backgroundColor: .grailTint, availableAsSwipeAction: false) {
      try database.updateNote(noteIdentifier: viewProperties.pageKey, updateBlock: { note -> Note in
        var note = note
        if var book = note.metadata.book {
          let today = Calendar.current.dateComponents([.year, .month, .day], from: Date())
          if book.readingHistory == nil {
            book.readingHistory = ReadingHistory()
          }
          book.readingHistory!.startReading(startDate: today)
          note.metadata.book = book
        }
        return note
      })
      Logger.shared.info("Moved \(viewProperties.pageKey) to 'read'")
    }
  }

  /// Returns an action for moving the book represented by `viewProperties` to the `.wantToRead` section of the collection.
  static func moveItemToWantToRead(_ viewProperties: BookViewProperties, in database: NoteDatabase) -> BookAction? {
    guard viewProperties.bookCategory != .wantToRead else {
      return nil
    }
    return BookAction(title: "Want to Read", image: UIImage(systemName: "list.star"), backgroundColor: .systemIndigo, availableAsSwipeAction: false) {
      try database.updateNote(noteIdentifier: viewProperties.pageKey, updateBlock: { note -> Note in
        var note = note
        if var book = note.metadata.book {
          book.readingHistory = nil
          note.metadata.book = book
        }
        return note
      })
      Logger.shared.info("Moved \(viewProperties.pageKey) to 'want to read'")
    }
  }

  /// Returns an action for studying the items in the book represented by `viewProperties`
  static func studyItem(
    _ viewProperties: BookViewProperties,
    sessionGenerator: SessionGenerator,
    delegate: DocumentTableControllerDelegate?
  ) -> BookAction? {
    if viewProperties.cardCount == 0 { return nil }
    return BookAction(title: "Study", image: UIImage(systemName: "rectangle.stack"), backgroundColor: .systemBlue) {
      Task {
        let studySession = try await sessionGenerator.studySession(filter: { name, _ in name == viewProperties.pageKey }, date: Date())
        await delegate?.presentStudySessionViewController(for: studySession)
      }
    }
  }
}