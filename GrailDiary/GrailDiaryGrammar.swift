//
//  GrailDiaryGrammar.swift
//  GrailDiary
//
//  Created by Brian Dewey on 6/16/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import Foundation
import TextMarkupKit

public final class GrailDiaryGrammar: PackratGrammar {
  public static let shared = GrailDiaryGrammar()
  
  private lazy var customizedGrammar = MiniMarkdownGrammar(customInlineStyleRules: [cloze], trace: false)

  public var start: ParsingRule { customizedGrammar.start }

  lazy var cloze = InOrder(
    Literal("?[").as(.delimiter),
    Characters(CharacterSet(charactersIn: "\n]").inverted).repeating(0...).as(.clozeHint),
    Literal("](").as(.delimiter),
    Characters(CharacterSet(charactersIn: "\n)").inverted).repeating(0...).as(.clozeAnswer),
    Literal(")").as(.delimiter)
  ).wrapping(in: .cloze).memoize()
}

extension PackratGrammar where Self == GrailDiaryGrammar {
  public static var grailDiary: GrailDiaryGrammar { GrailDiaryGrammar() }
}
