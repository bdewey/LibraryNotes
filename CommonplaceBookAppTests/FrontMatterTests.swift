// Copyright © 2019 Brian's Brain. All rights reserved.

import XCTest
import Yams

private let simpleYaml = """
title: A simple Yaml doc
author: Brian Dewey
version: 2.0
"""

private let markdownWithFrontMatter = """
---
title: This is my title
hashtags: #test, #foo
format: document
---
# This is my title

#test #foo

This is a simple **Markdown** document with Yaml front matter, like all the cool blog sites use.
"""

private struct TestIndexCard: Codable {
  let front: String
  let back: String
}

final class FrontMatterTests: XCTestCase {
  func testParseSimpleYaml() {
    do {
      guard let node = try Yams.compose(yaml: simpleYaml) else {
        XCTFail("Node should not be nil")
        return
      }
      XCTAssertEqual(node["title"], "A simple Yaml doc")
      XCTAssertEqual(node["version"], 2.0)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testParseFrontMatter() {
    do {
      guard let node = try Yams.compose(yaml: markdownWithFrontMatter) else {
        XCTFail("Node should not be nil")
        return
      }
      XCTAssertEqual(node["title"], "This is my title")
      XCTAssertEqual(node["format"], "document")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testYamlSerializeTestIndexCards() {
    let testCards = [
      TestIndexCard(front: "man", back: "hombre"),
      TestIndexCard(front: "woman", back: "mujer"),
      TestIndexCard(front: "boy", back: "niño"),
      TestIndexCard(front: "girl", back: "niña"),
      TestIndexCard(front: "sonrisa", back: "Smile\n![](assets/smile.jpg)"),
    ]
    do {
      let output = try YAMLEncoder().encode(testCards)
      print(output)
      XCTAssertEqual(output.count, 180)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }
}

