// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import SwiftUI

struct ParsedStringView: View {
  typealias TextModifier = (Text) -> Text

  let parsedString: ParsedString
  let syntaxModifiers: [SyntaxTreeNodeType: TextModifier]
  var leafModifier: TextModifier = { $0 }

  @ViewBuilder
  var body: some View {
    if let node = try? parsedString.result.get() {
      makeText(anchoredNode: AnchoredNode(node: node, startIndex: 0))
    } else {
      leafModifier(Text(parsedString.string))
    }
  }

  private func makeText(anchoredNode: AnchoredNode) -> Text {
    // Provide default conversion
    let text: Text
    if anchoredNode.node.children.isEmpty {
      let characters = parsedString[anchoredNode.range]
      let string = String(utf16CodeUnits: characters, count: characters.count)
      text = leafModifier(Text(string))
    } else {
      let children = anchoredNode.children.map { makeText(anchoredNode: $0) }
      text = children.reduce(Text(""), +)
    }

    if let modifier = syntaxModifiers[anchoredNode.node.type] {
      return modifier(text)
    } else {
      return text
    }
  }
}
