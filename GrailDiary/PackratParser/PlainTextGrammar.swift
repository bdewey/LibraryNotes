// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

public extension SyntaxTreeNodeType {
  static let plainText: SyntaxTreeNodeType = "plain-text"
}

/// Just interprets all text as "plain-text"
public struct PlainTextGrammar: PackratGrammar {
  public let start: ParsingRule = DotRule().repeating(0...).wrapping(in: .plainText)
}
