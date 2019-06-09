// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown

extension NodeType {
  public static let cloze = NodeType(rawValue: "cloze")
  public static let clozeHint = NodeType(rawValue: "clozeHint")
  public static let clozeHiddenText = NodeType(rawValue: "clozeHiddenText")
}

public final class Cloze: Node, CharacterParseable {
  public let hiddenText: String
  public let hint: String

  private let questionMark: Delimiter
  private let hintSlice: DelimitedText
  private let hiddenTextSlice: DelimitedText

  private let memoizedChildren: [Node]

  public init(
    questionMark: StringCharacter,
    hintSlice: DelimitedSlice,
    hiddenTextSlice: DelimitedSlice
  ) {
    self.hiddenText = String(hiddenTextSlice.slice?.substring ?? "")
    self.hint = String(hintSlice.slice?.substring ?? "")
    self.questionMark = Delimiter(questionMark)
    self.hintSlice = DelimitedText(type: .clozeHint, delimitedSlice: hintSlice)
    self.hiddenTextSlice = DelimitedText(type: .clozeHiddenText, delimitedSlice: hiddenTextSlice)
    let combinedSlice = StringSlice(questionMark) +
      hintSlice.completeSlice +
      hiddenTextSlice.completeSlice
    let memoizedChildren: [Node] = [
      self.questionMark,
      self.hintSlice,
      self.hiddenTextSlice,
    ]
    self.memoizedChildren = memoizedChildren
    super.init(type: .cloze, slice: combinedSlice)
    memoizedChildren.forEach { $0.parent = self }
  }

  public override var children: [Node] {
    return memoizedChildren
  }

  public static let parser = curry(Cloze.init)
    <^> CharacterParsers.character(where: { $0 == "?" })
    <*> CharacterParsers.slice(between: "[", and: "]")
    <*> CharacterParsers.slice(between: "(", and: ")")
}
