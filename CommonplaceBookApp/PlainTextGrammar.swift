//
//  PlainTextGrammar.swift
//  CommonplaceBookApp
//
//  Created by Brian Dewey on 11/23/20.
//  Copyright © 2020 Brian's Brain. All rights reserved.
//

import Foundation

public extension SyntaxTreeNodeType {
  static let plainText: SyntaxTreeNodeType = "plain-text"
}

/// Just interprets all text as "plain-text"
public struct PlainTextGrammar: PackratGrammar {
  public let start: ParsingRule = DotRule().repeating(0...).wrapping(in: .plainText)
}
