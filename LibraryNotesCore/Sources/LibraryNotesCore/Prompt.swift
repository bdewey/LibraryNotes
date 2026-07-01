// Copyright (c) 2018-2025  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

/// Uniquely identifies a prompt.
public struct PromptIdentifier: Hashable, Codable {
  public var noteId: String
  public var promptKey: String
  public var promptIndex: Int
}

/// A specific thing to recall.
public protocol Prompt {}
