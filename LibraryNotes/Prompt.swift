// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import AVFoundation
import Foundation
import UIKit

/// Uniquely identifies a prompt.
public struct PromptIdentifier: Hashable, Codable {
  public var noteId: String
  public var promptKey: String
  public var promptIndex: Int
}

/// A specific thing to recall.
@MainActor
public protocol Prompt {
  /// Returns a view that can quiz a person about the thing to remember.
  ///
  /// - parameter document: The document the card came from. Can be used for things like
  ///                       loading images.
  /// - parameter properties: Relevant properties of `document`
  func promptView(
    database: NoteDatabase,
    properties: CardDocumentProperties
  ) -> PromptView
}
