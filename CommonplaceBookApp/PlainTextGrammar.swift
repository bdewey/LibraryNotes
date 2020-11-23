//
//  PlainTextGrammar.swift
//  CommonplaceBookApp
//
//  Created by Brian Dewey on 11/23/20.
//  Copyright © 2020 Brian's Brain. All rights reserved.
//

import Foundation

public extension NewNodeType {
  static let plainText: NewNodeType = "plain-text"
}

/// Just interprets all text as "plain-text"
public struct PlainTextGrammar: PackratGrammar {
  public let start: ParsingRule = DotRule().repeating(0...).wrapping(in: .plainText)
}
