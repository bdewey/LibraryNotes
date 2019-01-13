// Copyright © 2019 Brian's Brain. All rights reserved.
// swiftlint:disable line_length
// swiftlint:disable force_try

import CommonplaceBookApp
import MiniMarkdown
import XCTest

private let testContent = """
# *Educated*, Tara Westover

* The author of *Educated* is ?[](Tara Westover).
* *Educated* takes place at ?[mountain name](Buck’s Peak), in ?[state](Idaho).
* Tara Westover did her undergraduate education at ?[collage](BYU).

## Quotes

> It’s a tranquillity born of sheer immensity; it calms with its very magnitude, which renders the merely human of no consequence. (26)

> Ain’t nothin’ funnier than real life, I tell you what. (34)

> Choices, numberless as grains of sand, had layered and compressed, coalescing into sediment, then into rock, until all was set in stone. (35)

> My brothers were like a pack of wolves. They tested each other constantly, with scuffles breaking out every time some young pup hit a growth spurt and dreamed of moving up. (43)

> In retrospect, I see that this was my education, the one that would matter: the hours I spent sitting at a borrowed desk, struggling to parse narrow strands of Mormon doctrine in mimicry of a brother who’d deserted me. The skill I was learning was a crucial one, the patience to read things I could not yet understand. (62)

"""

final class QuoteTemplateTests: XCTestCase {
  func testLoadQuotes() {
    let nodes = ParsingRules().parse(testContent)
    let quoteTemplates = QuoteTemplate.extract(from: nodes)
    XCTAssertEqual(quoteTemplates.count, 5)
  }

  func testSerialization() {
    let nodes = ParsingRules().parse(testContent)
    let quoteTemplates = QuoteTemplate.extract(from: nodes)
    let data = try! JSONEncoder().encode(quoteTemplates)
    let decoder = JSONDecoder()
    decoder.userInfo[.markdownParsingRules] = ParsingRules()
    let decodedTemplates = try! decoder.decode([QuoteTemplate].self, from: data)
    XCTAssertEqual(decodedTemplates, quoteTemplates)
  }
}
