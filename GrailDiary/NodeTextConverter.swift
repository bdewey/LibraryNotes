// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import SwiftUI

extension ParsedString {
  typealias TextConversionFunction = (Text) -> Text

  func makeText(conversionFunctions: [SyntaxTreeNodeType: TextConversionFunction]) -> Text {
    guard let node = try? result.get() else {
      return Text("Error")
    }
    let rootNode = AnchoredNode(node: node, startIndex: 0)
    return makeText(anchoredNode: rootNode, conversionFunctions: conversionFunctions)
  }

  func makeText(anchoredNode: AnchoredNode, conversionFunctions: [SyntaxTreeNodeType: TextConversionFunction]) -> Text {
    // Provide default conversion
    let text: Text
    if anchoredNode.node.children.isEmpty {
      let characters = self[anchoredNode.range]
      let string = String(utf16CodeUnits: characters, count: characters.count)
      text = Text(string)
    } else {
      let children = anchoredNode.children.map { makeText(anchoredNode: $0, conversionFunctions: conversionFunctions) }
      text = children.reduce(Text(""), +)
    }

    if let conversionFunction = conversionFunctions[anchoredNode.node.type] {
      return conversionFunction(text)
    } else {
      return text
    }
  }
}
