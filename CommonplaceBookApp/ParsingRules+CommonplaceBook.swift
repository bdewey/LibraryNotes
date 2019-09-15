// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import MiniMarkdown

extension ParsingRules {
  /// The variant of the parsing rules we use in CommonplaceBook
  public static let commonplace: ParsingRules = {
    var parsingRules = MiniMarkdown.ParsingRules()
    parsingRules.inlineParsers.parsers.insert(Cloze.nodeParser, at: 0)
    parsingRules.blockParsers.parsers.insert(QuestionAndAnswer.nodeParser, at: 0)
    return parsingRules
  }()
}
