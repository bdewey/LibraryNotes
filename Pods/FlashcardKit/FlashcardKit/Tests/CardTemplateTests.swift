// Copyright © 2018-present Brian's Brain. All rights reserved.

import FlashcardKit
import MiniMarkdown
import XCTest

private let mixedExample = """
# Spanish study

| Spanish           | Engish |
| ----------------- | ------ |
| tenedor #spelling | fork   |
| hombre            | man    |

1. *Ser* is used to identify a person, an animal, a concept, a thing, or any noun.
2. *Estar* is used to show location.
3. *Ser*, with an adjective, describes the "norm" of a thing.
   - La nieve ?[to be](es) blanca.
4. *Estar* with an adjective shows a "change" or "condition."

* Yo ?[to be](soy) de España. ¿De dónde ?[to be](es) ustedes?

"""

private let parsingRules: MiniMarkdown.ParsingRules = {
  var parsingRules = MiniMarkdown.ParsingRules()
  parsingRules.inlineParsers.parsers.insert(Cloze.nodeParser, at: 0)
  return parsingRules
}()

final class CardTemplateTests: XCTestCase {
  func testHeterogenousSerialization() {
    let nodes = parsingRules.parse(mixedExample)
    var templates = [ChallengeTemplate]()
    templates.append(contentsOf: VocabularyAssociation.makeAssociations(from: nodes).0)
    templates.append(contentsOf: ClozeTemplate.extract(from: nodes))

    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    encoder.dateEncodingStrategy = .iso8601
    let data = try! encoder.encode(templates.map { CardTemplateSerializationWrapper($0) })
    print(String(data: data, encoding: .utf8)!)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    decoder.userInfo[.markdownParsingRules] = parsingRules
    let roundTrip = try! decoder.decode([CardTemplateSerializationWrapper].self, from: data)
    XCTAssertEqual(roundTrip.count, templates.count)
    for (original, decoded) in zip(templates, roundTrip) {
      XCTAssert(type(of: original) === type(of: decoded.value))
    }
  }
}
