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
  static func deleteItem(_ noteIdentifier: Note.Identifier, in database: NoteDatabase) -> BookAction? {
    guard let metadata = database.bookMetadata(identifier: noteIdentifier) else { return nil }
    return BookAction(title: "Delete", image: UIImage(systemName: "trash"), destructive: true) {
      if metadata.folder == PredefinedFolder.recentlyDeleted.rawValue {
        try database.deleteNote(noteIdentifier: noteIdentifier)
      } else {
        try database.updateNote(noteIdentifier: noteIdentifier, updateBlock: { note in
          var note = note
          note.metadata.folder = PredefinedFolder.recentlyDeleted.rawValue
          return note
        })
      }
    }
  }

  /// Returns an action for moving the book represented by `viewProperties` to the `.read` section of the collection.
  static func moveItemToRead(_ noteIdentifier: Note.Identifier, in database: NoteDatabase) -> BookAction? {
    guard let viewProperties = database.bookMetadata(identifier: noteIdentifier),
          viewProperties.bookSection != .read
    else {
      return nil
    }
    return BookAction(title: "Read", image: UIImage(systemName: "books.vertical"), backgroundColor: .grailTint, availableAsSwipeAction: false) {
      try database.updateNote(noteIdentifier: noteIdentifier, updateBlock: { note -> Note in
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
      Logger.shared.info("Moved \(noteIdentifier) to 'read'")
    }
  }

  /// Returns an action for moving the book represented by `viewProperties` to the `.currentlyReading` section of the collection.
  static func moveItemToCurrentlyReading(_ noteIdentifier: Note.Identifier, in database: NoteDatabase) -> BookAction? {
    guard let viewProperties = database.bookMetadata(identifier: noteIdentifier),
          viewProperties.bookSection != .currentlyReading
    else {
      return nil
    }
    return BookAction(title: "Currently Reading", image: UIImage(systemName: "book"), backgroundColor: .grailTint, availableAsSwipeAction: false) {
      try database.updateNote(noteIdentifier: noteIdentifier, updateBlock: { note -> Note in
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
      Logger.shared.info("Moved \(noteIdentifier) to 'read'")
    }
  }

  /// Returns an action for moving the book represented by `viewProperties` to the `.wantToRead` section of the collection.
  static func moveItemToWantToRead(_ noteIdentifier: Note.Identifier, in database: NoteDatabase) -> BookAction? {
    guard let viewProperties = database.bookMetadata(identifier: noteIdentifier),
          viewProperties.bookSection != .wantToRead
    else {
      return nil
    }
    return BookAction(title: "Want to Read", image: UIImage(systemName: "list.star"), backgroundColor: .systemIndigo, availableAsSwipeAction: false) {
      try database.updateNote(noteIdentifier: noteIdentifier, updateBlock: { note -> Note in
        var note = note
        if var book = note.metadata.book {
          book.readingHistory = nil
          note.metadata.book = book
        }
        return note
      })
      Logger.shared.info("Moved \(noteIdentifier) to 'want to read'")
    }
  }

  /// Returns an action for studying the items in the book represented by `viewProperties`
  @MainActor
  static func studyItem(
    _ noteIdentifier: Note.Identifier,
    database: NoteDatabase,
    delegate: DocumentTableControllerDelegate?
  ) -> BookAction? {
    do {
      let studySession = try database.studySession(noteIdentifiers: [noteIdentifier], date: .now)
      if studySession.isEmpty {
        return nil
      } else {
        return BookAction(title: "Study", image: UIImage(systemName: "rectangle.stack"), backgroundColor: .systemBlue) {
          #if targetEnvironment(macCatalyst)
            UIApplication.shared.activateStudySessionScene(databaseURL: database.fileURL, studyTarget: .note(noteIdentifier))
          #else
            delegate?.presentStudySessionViewController(for: studySession)
          #endif
        }
      }
    } catch {
      Logger.shared.error("Error getting study session for note \(noteIdentifier): \(error)")
      return nil
    }
  }
}
