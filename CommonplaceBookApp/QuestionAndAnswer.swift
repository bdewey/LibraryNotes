// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown

extension NodeType {
  public static let questionAndAnswer = NodeType(rawValue: "questionAndAnswer")
  public static let question = NodeType(rawValue: "question")
  public static let answer = NodeType(rawValue: "answer")
}

/// The simplest possible question-and-answer format:
/// On two consecutive lines, the first line starts with Q: and the second line starts with A:.
public final class QuestionAndAnswer: Node, LineParseable {
  init(question: PrefixedLine, answer: PrefixedLine) {
    self.question = question
    self.answer = answer
    super.init(type: .questionAndAnswer, slice: question.slice + answer.slice)
    question.parent = self
    answer.parent = self
  }

  public let question: PrefixedLine
  public let answer: PrefixedLine

  public override var children: [Node] {
    [question, answer]
  }

  public static var parser: Parser<QuestionAndAnswer, ArraySlice<StringSlice>> =
    curry(QuestionAndAnswer.init)
    <^> PrefixedLine.parser(type: .question, prefix: "Q: ")
    <*> PrefixedLine.parser(type: .answer, prefix: "A: ")

  /// One of the lines of the question-and-answer format.
  public final class PrefixedLine: InlineContainingNode {
    public init(type: NodeType, delimiter: Delimiter, remainder: StringSlice) {
      self.prefixDelimiter = delimiter
      self.remainder = remainder
      super.init(type: type, slice: delimiter.slice + remainder)
      prefixDelimiter.parent = self
    }

    public let prefixDelimiter: Delimiter
    private let remainder: StringSlice

    public override var inlineSlice: StringSlice {
      return remainder
    }

    public override var memoizedChildrenPrefix: [Node] {
      return [prefixDelimiter]
    }

    public static func parser(
      type: NodeType,
      prefix: String
    ) -> Parser<QuestionAndAnswer.PrefixedLine, ArraySlice<StringSlice>> {
      return Parser { stream -> (PrefixedLine, ArraySlice<StringSlice>)? in
        guard
          let line = stream.first,
          let parsed = line.starts(with: prefix)
        else {
          return nil
        }
        return (PrefixedLine(type: type, delimiter: parsed.prefix, remainder: parsed.suffix), stream.dropFirst())
      }
    }
  }
}

private extension StringSlice {
  /// If the reciever starts with `prefix`, return the starting prefix delimiter and the remainder. Otherwise, nil.
  func starts(with prefix: String) -> (prefix: Delimiter, suffix: StringSlice)? {
    let actualPrefix = substring.prefix(prefix.count)
    if actualPrefix == prefix {
      return (
        prefix: Delimiter(StringSlice(string: string, substring: actualPrefix)),
        suffix: StringSlice(string: string, range: actualPrefix.endIndex ..< endIndex)
      )
    }
    return nil
  }
}
