import Foundation
import TextMarkupKit
import XCTest

// TODO: Provide a version of parseText that works with a ParsedString

open class TextMarkupTestBase: XCTestCase {
  /// The grammar that is used inside `parseText`.
  open var parseTextGrammar: PackratGrammar { MiniMarkdownGrammar.shared }

  /// Verify that parsed text matches expected structure.
  @discardableResult
  public func parseText(
    _ text: String,
    expectedStructure: String,
    file: StaticString = #file,
    line: UInt = #line
  ) -> SyntaxTreeNode? {
    let parsedString = ParsedString(text, grammar: parseTextGrammar)
    return verifyParsedStructure(of: parsedString, meets: expectedStructure, file: file, line: line)
  }

  @discardableResult
  public func verifyParsedStructure(
    of text: ParsedString,
    meets expectedStructure: String,
    file: StaticString = #file,
    line: UInt = #line
  ) -> SyntaxTreeNode? {
    do {
      let tree = try text.result.get()
      if tree.length != text.count {
        let unparsedText = text[NSRange(location: tree.length, length: text.count - tree.length)]
        XCTFail("Test case \(name): Unparsed text = '\(unparsedText.debugDescription)'", file: file, line: line)
      }
      if expectedStructure != tree.compactStructure {
        print("### Failure: \(name)")
        print("Got:      " + tree.compactStructure)
        print("Expected: " + expectedStructure)
        print("\n")
        print(tree.debugDescription(withContentsFrom: text))
        print("\n\n\n")
        print(TraceBuffer.shared)
      }
      XCTAssertEqual(tree.compactStructure, expectedStructure, "Unexpected structure", file: file, line: line)
      return tree
    } catch {
      XCTFail("Unexpected error: \(error)", file: file, line: line)
      return nil
    }
  }

}
