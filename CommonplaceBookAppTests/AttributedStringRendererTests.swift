// Copyright © 2018 Brian's Brain. All rights reserved.

import XCTest

import MiniMarkdown
@testable import CommonplaceBookApp

final class AttributedStringRendererTests: XCTestCase {

  var renderer = AttributedStringRenderer()
  
  override func setUp() {
    super.setUp()
    
    renderer.image = { (imageInline, attributes) in
      let attachment = NSTextAttachment(data: "testing".data(using: .utf8)!, ofType: "public.plain-text")
      return NSAttributedString(attachment: attachment)
    }
    renderer.listItem = { (attributedString, listItem, attributes) in
      let location = attributedString.length
      self.renderer.defaultBlockRenderer(attributedString, listItem, attributes)
      let tab = NSAttributedString(string: "\t", attributes: attributes.attributes)
      attributedString.replaceCharacters(in: NSRange(location: location + 1, length: 1), with: tab)
    }
  }
  
  func testImageSubstitution() {
    let example = "This text has an image reference: ![xkcd](https://imgs.xkcd.com/comics/october_30th.png)"
    let rendered = renderer.render(markdown: example, baseAttributes: NSAttributedString.Attributes(UIFont.systemFont(ofSize: 14)))
    XCTAssertEqual(rendered.string, "This text has an image reference: \u{fffc}")
  }
  
  func testImageAndTabSubstitution() {
    let example = "- This is a list element with an image reference: ![xkcd](https://imgs.xkcd.com/comics/october_30th.png), and some text after it."
    let rendered = renderer.render(markdown: example, baseAttributes: NSAttributedString.Attributes(UIFont.systemFont(ofSize: 14)))
    XCTAssertEqual(rendered.string, "-\tThis is a list element with an image reference: \u{fffc}, and some text after it.")
  }
}
