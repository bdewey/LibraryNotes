//
//  GrailDiaryGrammar.swift
//  GrailDiary
//
//  Created by Brian Dewey on 6/16/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import Foundation
import TextMarkupKit

public final class GrailDiaryGrammar: MiniMarkdownGrammar {
  public override var inlineStyleRules: [ParsingRule] {
    var foo = super.inlineStyleRules
    foo.append(contentsOf: [cloze])
    return foo
  }

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
