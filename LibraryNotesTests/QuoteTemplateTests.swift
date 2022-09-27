// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Library_Notes
import TextMarkupKit
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

private let contentWithCloze = """
> We had to learn for ourselves and, furthermore, we had to teach the despairing men, that ?[](it did not really matter what we expected from life, but rather what life expected from us).
"""

final class QuoteTemplateTests: XCTestCase {
  func testLoadQuotes() {
    let buffer = ParsedString(testContent, grammar: MiniMarkdownGrammar.shared)
    let quoteTemplates = QuotePrompt.extract(from: buffer)
    XCTAssertEqual(quoteTemplates.count, 5)
    let cards = quoteTemplates.map { $0.prompts }.joined()
    XCTAssertEqual(cards.count, 5)
  }

  func testSerialization() {
    let buffer = ParsedString(testContent, grammar: MiniMarkdownGrammar.shared)
    let quoteTemplates = QuotePrompt.extract(from: buffer)
    let strings = quoteTemplates.map { $0.rawValue }
    let decodedTemplates = strings.map { QuotePrompt(rawValue: $0) }
    XCTAssertEqual(decodedTemplates, quoteTemplates)
  }

  func testYamlEncodingIsJustMarkdown() {
    let decoded = QuotePrompt(rawValue: contentWithCloze)
    XCTAssertEqual(decoded.prompts.count, 1)
  }

  func testRenderCloze() {
    let buffer = ParsedString(contentWithCloze, grammar: MiniMarkdownGrammar.shared)
    let quoteTemplates = QuotePrompt.extract(from: buffer)

    let (front, _) = quoteTemplates[0].renderCardFront(imageStorage: nil)
    XCTAssertEqual(
      front.string,
      "We had to learn for ourselves and, furthermore, we had to teach the despairing men, that it did not really matter what we expected from life, but rather what life expected from us."
    )
  }
}
