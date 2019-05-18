// Copyright © 2019 Brian's Brain. All rights reserved.
// swiftlint:disable force_try

import CommonplaceBookApp
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

private func makeTemplates() -> [ChallengeTemplate] {
  let nodes = parsingRules.parse(mixedExample)
  var templates = [ChallengeTemplate]()
  templates.append(contentsOf: VocabularyAssociation.makeAssociations(from: nodes).0)
  templates.append(contentsOf: ClozeTemplate.extract(from: nodes))
  return templates
}

final class ChallengeTemplateCollectionTests: XCTestCase {
  func testCollectionSerialization() {
    let templates = makeTemplates()
    var collection = ChallengeTemplateCollection()
    collection.insert(contentsOf: templates)
    let data = collection.data()
    print(String(data: data, encoding: .utf8)!)
    let newCollection = try! ChallengeTemplateCollection(parsingRules: parsingRules, data: data)
    XCTAssertEqual(collection.count, newCollection.count)
    XCTAssertEqual(collection.keys.sorted(), newCollection.keys.sorted())
  }
}
