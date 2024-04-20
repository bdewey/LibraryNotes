// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

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

  static let summaryDelimiter: SyntaxTreeNodeType = "summary_delimiter"
  static let summaryBody: SyntaxTreeNodeType = "summary_body"
  static let summary: SyntaxTreeNodeType = "summary"
}

public final class GrailDiaryGrammar: PackratGrammar {
  @MainActor public static let shared = GrailDiaryGrammar()

  public init() {
    let coreGrammar = MiniMarkdownGrammar(
      trace: false
    )

    let cloze = InOrder(
      Literal("?[").as(.delimiter),
      Characters(CharacterSet(charactersIn: "\n]").inverted).repeating(0...).as(.clozeHint),
      Literal("](").as(.delimiter),
      Characters(CharacterSet(charactersIn: "\n)").inverted).repeating(0...).as(.clozeAnswer),
      Literal(")").as(.delimiter)
    ).wrapping(in: .cloze).memoize()

    coreGrammar.customInlineStyleRules = [cloze]

    /// My custom addition to markdown for handling questions-and-answers
    let questionAndAnswer = InOrder(
      InOrder(Literal("Q:").as(.text), Literal(" ").as(.softTab)).wrapping(in: .qnaDelimiter),
      coreGrammar.singleLineStyledText.wrapping(in: .qnaQuestion),
      InOrder(Literal("\nA:").as(.text), Literal(" ").as(.softTab)).wrapping(in: .qnaDelimiter),
      coreGrammar.singleLineStyledText.wrapping(in: .qnaAnswer),
      coreGrammar.paragraphTermination.zeroOrOne().wrapping(in: .text)
    ).wrapping(in: .questionAndAnswer).memoize()

    let summary = InOrder(
      Choice(
        InOrder(Literal("Summary: ", compareOptions: [.caseInsensitive]).as(.summaryDelimiter)),
        InOrder(Literal("tl;dr: ", compareOptions: [.caseInsensitive]).as(.summaryDelimiter))
      ),
      coreGrammar.singleLineStyledText.wrapping(in: .summaryBody),
      coreGrammar.newline.zeroOrOne().wrapping(in: .summaryBody)
    ).wrapping(in: .summary).memoize()

    coreGrammar.customBlockRules = [questionAndAnswer, summary]
    self.coreGrammar = coreGrammar
  }

  private let coreGrammar: MiniMarkdownGrammar

  public var start: ParsingRule { coreGrammar.start }
}

public extension PackratGrammar where Self == GrailDiaryGrammar {
  static var grailDiary: GrailDiaryGrammar { GrailDiaryGrammar() }
}
