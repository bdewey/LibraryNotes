// Copyright © 2018 Brian's Brain. All rights reserved.

import XCTest

import MiniMarkdown

struct ExpectedNode {
  
  indirect enum Error: Swift.Error, CustomStringConvertible {
    case typeDoesNotMatch(expectedType: NodeType, actualType: NodeType)
    case stringDoesNotMatch(expectedString: String, actualString: String)
    case childCountDoesNotMatch(text: String, expectedCount: Int, actualCount: Int)
    case invalidChild(childIndex: Int, validationError: Error)
    
    var description: String {
      switch self {
      case let .typeDoesNotMatch(expectedType: expected, actualType: actual):
        return "Type mismatch: Expected \(expected.rawValue), got \(actual.rawValue)"
      case let .stringDoesNotMatch(expectedString: expected, actualString: actual):
        return "String does not match: Expected \(expected), got \(actual)"
      case let .childCountDoesNotMatch(text: text, expectedCount: expected, actualCount: actual):
        return "Child count does not match: Expected \(expected), got: \(actual)\n\n\"\(text)\""
      case let .invalidChild(childIndex: index, validationError: error):
        let description = String(describing: error)
        return "\(index).\(description)"
      }
    }
  }
  
  let type: NodeType
  let string: String?
  let children: [ExpectedNode]
  
  init(type: NodeType, string: String? = nil, children: [ExpectedNode] = []) {
    self.type = type
    self.string = string
    self.children = children
  }
  
  func validateNode(_ node: Node) throws {
    if type != node.type {
      throw Error.typeDoesNotMatch(expectedType: type, actualType: node.type)
    }
    if let string = string, string != node.slice.substring {
      throw Error.stringDoesNotMatch(
        expectedString: string,
        actualString: String(node.slice.substring)
      )
    }
    if children.count != node.children.count {
      throw Error.childCountDoesNotMatch(
        text: String(node.slice.substring),
        expectedCount: children.count,
        actualCount: node.children.count
      )
    }
    for ((index, child), otherChild) in zip(zip(children.indices, children), node.children) {
      do {
        try child.validateNode(otherChild)
      } catch let error as Error {
        throw Error.invalidChild(childIndex: index, validationError: error)
      }
    }
  }
}

final class MiniMarkdownProtocolTests: XCTestCase {

  func testHeadingAndText() {
    let example = """
                  # Heading
                  Text
                  """
    let results = ParsingRules().parse(example)
    XCTAssertEqual(results.count, 2)
    XCTAssert(results[0].type == .heading)
    XCTAssert(results[1].type == .paragraph)
  }
  
  func testTextAndHeading() {
    let example = """
                  Text
                  # Heading
                  """
    let results = ParsingRules().parse(example)
    XCTAssertEqual(results.count, 2)
    XCTAssert(results[0].type == .paragraph)
    XCTAssert(results[1].type == .heading)
  }

  func testParsePlainText() {
    let example = "This is just text."
    let block = ParsingRules().parse(example)[0]
    XCTAssertEqual(block.type, .paragraph)
    XCTAssertEqual(block.children.count, 1)
    if let inline = block.children.first {
      XCTAssertEqual(inline.type, .text)
      XCTAssertEqual(inline.slice.substring, "This is just text.")
    }
  }
  
  func testParseJustEmphasis() {
    let example = "*This is emphasized text.*"
    let block = ParsingRules().parse(example)[0]
    XCTAssertEqual(block.type, .paragraph)
    XCTAssertEqual(block.children.count, 1)
    if let inline = block.children.first {
      XCTAssertEqual(inline.type, .emphasis)
      XCTAssertEqual(inline.slice.substring, "*This is emphasized text.*")
    }
  }
  
  func testParseTextWithEmphasis() {
    let example = "This is text with *emphasis.*"
    let block = ParsingRules().parse(example)[0]
    XCTAssertEqual(block.type, .paragraph)
    XCTAssertEqual(block.children.count, 2)
    XCTAssert(StringSlice(example).covered(by: block.children.map { return $0.slice }))
    XCTAssertEqual(block.children[1].slice.substring, "*emphasis.*")
  }
  
  func testParseTextWithBold() {
    let example = "This is text with **bold**."
    let block = ParsingRules().parse(example)[0]
    XCTAssertEqual(block.type, .paragraph)
    XCTAssertEqual(block.children.count, 3)
    XCTAssert(StringSlice(example).covered(by: block.children.map { return $0.slice }))
    XCTAssertEqual(block.children[1].type, .bold)
  }
  
  func testEmphasisDoesNotSpanListItems() {
    let example = """
- Item *one
- Item *two
"""
    let blocks = ParsingRules().parse(example)
    XCTAssertEqual(blocks.count, 1)
    XCTAssert(blocks[0].isList(type: .unordered))
    let inlines = blocks[0].children
    XCTAssertEqual(inlines.count, 2)
  }
  
  func testDelimitersNeedToHugText() {
    let example = "This star * does not start emphasis.*"
    let inlines = ParsingRules().parse(example)[0].children
    XCTAssertEqual(inlines.count, 1)
    XCTAssertEqual(inlines[0].type, .text)
  }
  
  func testParseTable() {
    let example = """
| foo | bar |
| --- | --- |
| baz | bim |
| fe  |     |
"""
    let blocks = ParsingRules().parse(example)
    XCTAssertEqual(blocks.count, 1)
    XCTAssertEqual(blocks[0].type, .table)
    guard let table = blocks[0] as? MiniMarkdown.Table else { XCTFail(); return }
    XCTAssertEqual(table.rows.count, 2)
    XCTAssertEqual(table.columnCount, 2)
    XCTAssertEqual(table.rows[0].children[1].contents, "baz")
    XCTAssertEqual(table.rows[0].cells[0].contents, "baz")
    XCTAssertEqual(table.rows[1].children[1].contents, "fe")
  }
  
  func testHeadingsCanHaveFormatting() {
    let example = "# This is a heading with *emphasis*"
    let blocks = ParsingRules().parse(example)
    XCTAssertEqual(blocks.count, 1)
    XCTAssertEqual(blocks[0].type, .heading)
    XCTAssertEqual(blocks[0].children.count, 2)
    XCTAssertEqual(blocks[0].children[0].type, .text)
    XCTAssertEqual(blocks[0].children[1].type, .emphasis)
  }
  
  func testListItemsCanHaveFormatting() {
    let example = "- This is a list item with **strong emphasis**"
    let blocks = ParsingRules().parse(example)
    let expectedStructure = ExpectedNode(type: .list, children: [
      ExpectedNode(type: .listItem, children: [
        ExpectedNode(type: .paragraph, children: [
          ExpectedNode(type: .text, string: "This is a list item with "),
          ExpectedNode(type: .bold, string: "**strong emphasis**"),
          ]),
        ])
      ])
    do {
      try expectedStructure.validateNode(blocks[0])
    } catch {
      XCTFail(String(describing: error))
    }
  }
  
  func testTableCellsCanHaveInlines() {
    let example = """
| Spanish | English |
| ------- | ------- |
| tenedor | ![fork](assets/fork.png) |
"""
    let blocks = ParsingRules().parse(example)
    let twoCells = [
      ExpectedNode(type: .tablePipe),
      ExpectedNode(type: .tableCell, children: [ExpectedNode(type: .text)]),
      ExpectedNode(type: .tablePipe),
      ExpectedNode(type: .tableCell, children: [ExpectedNode(type: .text)]),
      ExpectedNode(type: .tablePipe),
    ]
    let expectedStructure = ExpectedNode(type: .table, children: [
      ExpectedNode(type: .tableHeader, children: twoCells),
      ExpectedNode(type: .tableDelimiter, children: twoCells),
      ExpectedNode(type: .tableRow, children: [
        ExpectedNode(type: .tablePipe),
        ExpectedNode(type: .tableCell, children: [ExpectedNode(type: .text)]),
        ExpectedNode(type: .tablePipe),
        ExpectedNode(type: .tableCell, children: [
          ExpectedNode(type: .image),
          ExpectedNode(type: .text),
          ]),
        ExpectedNode(type: .tablePipe),
        ])
      ])
    do {
      try expectedStructure.validateNode(blocks[0])
    } catch {
      XCTFail(String(describing: error))
    }
  }

  func testTablesCanBeFollowedByOtherContent() {
    let example = """
# Example vocabulary

| Spanish | English                  |
| ------- | ------------------------ |
| tenedor | ![fork](assets/fork.png) |

And now there is a paragraph.

"""
    let blocks = ParsingRules().parse(example)
    let twoCells = [
      ExpectedNode(type: .tablePipe),
      ExpectedNode(type: .tableCell, children: [ExpectedNode(type: .text)]),
      ExpectedNode(type: .tablePipe),
      ExpectedNode(type: .tableCell, children: [ExpectedNode(type: .text)]),
      ExpectedNode(type: .tablePipe),
      ]
    let expectedStructure = [
      ExpectedNode(type: .heading, children: [
        ExpectedNode(type: .text, string: "# Example vocabulary\n"),
        ]),
      ExpectedNode(type: .blank),
      ExpectedNode(type: .table, children: [
        ExpectedNode(type: .tableHeader, children: twoCells),
        ExpectedNode(type: .tableDelimiter, children: twoCells),
        ExpectedNode(type: .tableRow, children: [
          ExpectedNode(type: .tablePipe),
          ExpectedNode(type: .tableCell, children: [ExpectedNode(type: .text)]),
          ExpectedNode(type: .tablePipe),
          ExpectedNode(type: .tableCell, children: [
            ExpectedNode(type: .image),
            ExpectedNode(type: .text),
            ]),
          ExpectedNode(type: .tablePipe),
          ])
        ]),
      ExpectedNode(type: .blank),
      ExpectedNode(type: .paragraph, children: [
        ExpectedNode(type: .text, string: "And now there is a paragraph.\n")
        ])
    ]
    XCTAssertEqual(blocks.count, expectedStructure.count)
    do {
      for (block, structure) in zip(blocks, expectedStructure) {
        try structure.validateNode(block)
      }
    } catch {
      XCTFail(String(describing: error))
    }
  }

  func testParseImages() {
    let example = "This text has an image reference: ![xkcd](https://imgs.xkcd.com/comics/october_30th.png)"
    let block = ParsingRules().parse(example)[0]
    XCTAssertEqual(block.type, .paragraph)
    XCTAssertEqual(block.children.count, 2)
    XCTAssert(StringSlice(example).covered(by: block.children.map { return $0.slice }))
    XCTAssertEqual(block.children[1].type, .image)
    guard let image = block.children[1] as? MiniMarkdown.Image else { XCTFail(); return }
    XCTAssertEqual(image.text, "xkcd")
    XCTAssertEqual(image.url, "https://imgs.xkcd.com/comics/october_30th.png")
  }

  func testParseHashtag() {
    let example = "#hashtag"
    let blocks = ParsingRules().parse(example)
    let expectedStructure = ExpectedNode(type: .paragraph, children: [
      ExpectedNode(type: .hashtag, string: "#hashtag")
      ])
    do {
      try expectedStructure.validateNode(blocks[0])
    } catch {
      XCTFail(String(describing: error))
    }
  }

  func testHashtagCannotStartInMiddleOfAWord() {
    let example = "This paragraph does not contain a#hashtag because there is no space at the start."
    let blocks = ParsingRules().parse(example)
    let expectedStructure = ExpectedNode(type: .paragraph, children: [
      ExpectedNode(type: .text, string: example)
      ])
    do {
      try expectedStructure.validateNode(blocks[0])
    } catch {
      XCTFail(String(describing: error))
    }
  }

  func testHashtagCanComeInTheMiddle() {
    let example = "This sentence contains a #hashtag"
    let blocks = ParsingRules().parse(example)
    let expectedStructure = ExpectedNode(type: .paragraph, children: [
      ExpectedNode(type: .text, string: "This sentence contains a "),
      ExpectedNode(type: .hashtag, string: "#hashtag")
      ])
    do {
      try expectedStructure.validateNode(blocks[0])
    } catch {
      XCTFail(String(describing: error))
    }
  }

  func testWhitespaceSeparatesParagraphs() {
    let example = """
This is a line.
This next line is part of the same paragraph because there is no whitespace.

This is a new paragraph thanks to the whitespace.
"""
    let blocks = ParsingRules().parse(example)
    let expectedStructure = [
      ExpectedNode(type: .paragraph, children: [
        ExpectedNode(type: .text, string: "This is a line.\nThis next line is part of the same paragraph because there is no whitespace.\n")
        ]),
      ExpectedNode(type: .blank),
      ExpectedNode(type: .paragraph, children: [
        ExpectedNode(type: .text, string: "This is a new paragraph thanks to the whitespace.")
        ]),
    ]
    XCTAssertEqual(blocks.count, expectedStructure.count)
    do {
      for (block, structure) in zip(blocks, expectedStructure) {
        try structure.validateNode(block)
      }
    } catch {
      XCTFail(String(describing: error))
    }
  }

  func testAllUnorderedListMarkers() {
    let example = """
- This is a list item.
+ So is this.
* And so is this.

"""
    let blocks = ParsingRules().parse(example)
    let expectedStructure = [
      ExpectedNode(type: .list, children: [
        ExpectedNode(type: .listItem, children: [
          ExpectedNode(type: .paragraph, children: [
            ExpectedNode(type: .text, string: "This is a list item.\n")
            ]),
          ]),
        ExpectedNode(type: .listItem, children: [
          ExpectedNode(type: .paragraph, children: [
            ExpectedNode(type: .text, string: "So is this.\n")
            ]),
          ]),
        ExpectedNode(type: .listItem, children: [
          ExpectedNode(type: .paragraph, children: [
            ExpectedNode(type: .text, string: "And so is this.\n")
            ]),
          ]),
        ]),
      ]
    XCTAssertEqual(blocks.count, expectedStructure.count)
    do {
      for (block, structure) in zip(blocks, expectedStructure) {
        try structure.validateNode(block)
      }
    } catch {
      XCTFail(String(describing: error))
    }
  }

  func testOrderedListMarkers() {
    let example = """
1. this is the first item
2. this is the second item
3) This is also legit.

"""
    let blocks = ParsingRules().parse(example)
    let expectedStructure = [
      ExpectedNode(type: .list, children: [
        ExpectedNode(type: .listItem, children: [
          ExpectedNode(type: .paragraph, children: [
            ExpectedNode(type: .text, string: "this is the first item\n")
            ]),
          ]),
        ExpectedNode(type: .listItem, children: [
          ExpectedNode(type: .paragraph, children: [
            ExpectedNode(type: .text, string: "this is the second item\n")
            ]),
          ]),
        ExpectedNode(type: .listItem, children: [
          ExpectedNode(type: .paragraph, children: [
            ExpectedNode(type: .text, string: "This is also legit.\n")
            ]),
          ]),
        ]),
      ]
    XCTAssertEqual(blocks.count, expectedStructure.count)
    do {
      for (block, structure) in zip(blocks, expectedStructure) {
        try structure.validateNode(block)
      }
    } catch {
      XCTFail(String(describing: error))
    }
  }

  func testOrderedMarkerCannotBeTenDigits() {
    let example = """
12345678900) This isn't a list.
"""
    let blocks = ParsingRules().parse(example)
    let expectedStructure = [
      ExpectedNode(type: .paragraph, children: [
        ExpectedNode(type: .text, string: "12345678900) This isn't a list.")
        ]),
      ]
    XCTAssertEqual(blocks.count, expectedStructure.count)
    do {
      for (block, structure) in zip(blocks, expectedStructure) {
        try structure.validateNode(block)
      }
    } catch {
      XCTFail(String(describing: error))
    }
  }

  func testListItemContainsNestedContent() {
    let example = """
* This is the first list item.
  This is part of the same paragraph.

  This is a new paragraph that is part of the list item.

* This is the second list item in the same list.

  1. A nested ordered list.
  2. With multiple items.

And back to a normal paragraph outside the list.
"""
    let blocks = ParsingRules().parse(example)
    let expectedStructure = [
      ExpectedNode(type: .list, children: [
        ExpectedNode(type: .listItem, children: [
          ExpectedNode(type: .paragraph, children: [
            // TODO: I don't want the indenting spaces to be part of the text. (Do I?)
            ExpectedNode(type: .text, string: "This is the first list item.\n  This is part of the same paragraph.\n"),
            ]),
          ExpectedNode(type: .blank),
          ExpectedNode(type: .paragraph, children: [
            ExpectedNode(type: .text, string: "  This is a new paragraph that is part of the list item.\n"),
            ]),
          ExpectedNode(type: .blank),
          ]),
        ExpectedNode(type: .listItem, children: [
          ExpectedNode(type: .paragraph, children: [
            ExpectedNode(type: .text, string: "This is the second list item in the same list.\n"),
            ]),
          ExpectedNode(type: .blank),
          ExpectedNode(type: .list, children: [
            ExpectedNode(type: .listItem, children: [
              ExpectedNode(type: .paragraph, children: [
                ExpectedNode(type: .text, string: "A nested ordered list.\n"),
                ]),
              ]),
            ExpectedNode(type: .listItem, children: [
              ExpectedNode(type: .paragraph, children: [
                ExpectedNode(type: .text, string: "With multiple items.\n"),
                ]),
              ExpectedNode(type: .blank),
              ]),
            ]),
          ]),
        ]),
      ExpectedNode(type: .paragraph, children: [
        ExpectedNode(type: .text, string: "And back to a normal paragraph outside the list."),
        ]),
      ]
    XCTAssertEqual(blocks.count, expectedStructure.count)
    do {
      for (block, structure) in zip(blocks, expectedStructure) {
        try structure.validateNode(block)
      }
    } catch {
      XCTFail(String(describing: error))
    }
  }
}
