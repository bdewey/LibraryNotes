// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown

extension NodeType {
  public static let cloze = NodeType(rawValue: "cloze")
}

public final class Cloze: Node, CharacterParseable {
  public let hintSlice: StringSlice
  public let hiddenTextSlice: StringSlice

  public init(
    questionMark: StringCharacter,
    hintSlice: StringSlice,
    hiddenTextSlice: StringSlice
  ) {
    self.hintSlice = hintSlice
    self.hiddenTextSlice = hiddenTextSlice
    let combinedSlice = StringSlice(questionMark) + hintSlice + hiddenTextSlice
    super.init(type: .cloze, slice: combinedSlice, markdown: String(combinedSlice.substring))
  }

  public var hiddenText: Substring {
    return hiddenTextSlice.substring.dropFirst().dropLast()
  }

  public var hint: Substring {
    return hintSlice.substring.dropFirst().dropLast()
  }

  public static let parser = curry(Cloze.init)
    <^> CharacterParsers.character(where: { $0 == "?" })
    <*> CharacterParsers.slice(between: "[", and: "]")
    <*> CharacterParsers.slice(between: "(", and: ")")
}
