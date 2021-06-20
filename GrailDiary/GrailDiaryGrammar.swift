//
//  GrailDiaryGrammar.swift
//  GrailDiary
//
//  Created by Brian Dewey on 6/16/21.
//  Copyright © 2021 Brian's Brain. All rights reserved.
//

import Foundation
import TextMarkupKit

public extension SyntaxTreeNodeType {
  static let cloze: SyntaxTreeNodeType = "cloze"
  static let clozeHint: SyntaxTreeNodeType = "cloze_hint"
  static let clozeAnswer: SyntaxTreeNodeType = "cloze_answer"

  static let questionAndAnswer: SyntaxTreeNodeType = "question_and_answer"
  static let qnaQuestion: SyntaxTreeNodeType = "qna_question"
  static let qnaAnswer: SyntaxTreeNodeType = "qna_answer"
  static let qnaDelimiter: SyntaxTreeNodeType = "qna_delimiter"
}

public final class GrailDiaryGrammar: PackratGrammar {
  public static let shared = GrailDiaryGrammar()

  public init() {
    let cloze = InOrder(
      Literal("?[").as(.delimiter),
      Characters(CharacterSet(charactersIn: "\n]").inverted).repeating(0...).as(.clozeHint),
      Literal("](").as(.delimiter),
      Characters(CharacterSet(charactersIn: "\n)").inverted).repeating(0...).as(.clozeAnswer),
      Literal(")").as(.delimiter)
    ).wrapping(in: .cloze).memoize()

    let coreGrammar = MiniMarkdownGrammar(
      customInlineStyleRules: [cloze],
      trace: false
    )

    /// My custom addition to markdown for handling questions-and-answers
    let questionAndAnswer = InOrder(
      InOrder(Literal("Q:").as(.text), Literal(" ").as(.softTab)).wrapping(in: .qnaDelimiter),
      coreGrammar.singleLineStyledText.wrapping(in: .qnaQuestion),
      InOrder(Literal("\nA:").as(.text), Literal(" ").as(.softTab)).wrapping(in: .qnaDelimiter),
      coreGrammar.singleLineStyledText.wrapping(in: .qnaAnswer),
      coreGrammar.paragraphTermination.zeroOrOne().wrapping(in: .text)
    ).wrapping(in: .questionAndAnswer).memoize()

    coreGrammar.customBlockRules = [questionAndAnswer]
    self.coreGrammar = coreGrammar
  }
  
  private let coreGrammar: MiniMarkdownGrammar

  public var start: ParsingRule { coreGrammar.start }
}

extension PackratGrammar where Self == GrailDiaryGrammar {
  public static var grailDiary: GrailDiaryGrammar { GrailDiaryGrammar() }
}
