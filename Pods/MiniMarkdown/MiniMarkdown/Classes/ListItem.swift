//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import Foundation

public enum ListType {
  case unordered
  case ordered
}

extension NodeType {
  public static let listItem = NodeType(rawValue: "listItem")
}

/// A list item: https://spec.commonmark.org/0.28/#list-items
public final class ListItem: BlockContainingNode, LineParseable {
  public let listType: ListType
  public let markerRange: Range<String.Index>

  init(listType: ListType, markerRange: Range<String.Index>, slice: StringSlice) {
    self.listType = listType
    self.markerRange = markerRange
    super.init(type: .listItem, slice: slice)
  }

  /// The lines contained in this list item.
  ///
  /// - note: The first line if the list item determines how much indentation each successive
  ///         line will hae to be part of the same list item. When parsing this content, we want
  ///         to disregard this indentation.
  public override var containedLines: [StringSlice] {

    // How many characters we throw away from the beginning of each line.
    let countToDrop = NSRange(markerRange, in: slice.string).length
    return LineSequence(slice).map { (lineSlice) -> StringSlice in
      // Move the lower bound forward.
      var offsetLowerBound = lineSlice.range.lowerBound
      for _ in 0 ..< countToDrop {
        // It's possible for containedLines to have completely blank lines, which won't have
        // enough content to offset the lower bound. In this case return everything.
        if offsetLowerBound == lineSlice.range.upperBound { return lineSlice }
        offsetLowerBound = lineSlice.string.index(after: offsetLowerBound)
      }
      return StringSlice(
        string: lineSlice.string,
        range: offsetLowerBound ..< lineSlice.range.upperBound
      )
    }
  }

  public static let parser =
    listItemParser(type: .ordered, itemRecognizer: orderedRecognizer) ||
      listItemParser(type: .unordered, itemRecognizer: unorderedRecognizer)

  private static func listItemParser(
    type: ListType,
    itemRecognizer: @escaping (Substring) -> Range<Substring.Index>?
  ) -> Parser<ListItem, ArraySlice<StringSlice>> {
    return Parser { (stream) -> (ListItem, LineParseable.Stream)? in
      guard let line = stream.first,
            let markerRange = itemRecognizer(line.substring) else { return nil }
      let markerNSRange = NSRange(markerRange, in: line.string)
      let continuationParser = LineParsers.line(where: { (slice) -> Bool in
        let leadingWhitespace = slice.substring.prefix(while: { $0.isWhitespaceOrNewline })
        if leadingWhitespace.endIndex == slice.endIndex { return true }
        let whitespaceRange = NSRange(
          leadingWhitespace.startIndex ..< leadingWhitespace.endIndex,
          in: slice.string
        )
        return whitespaceRange.length == markerNSRange.length
      }).many
      if let continuationLines = continuationParser.parse(stream.dropFirst()) {
        let combinedSlice = continuationLines.0.reduce(line, { (result, slice) -> StringSlice in
          return result + slice
        })
        return (ListItem(listType: type, markerRange: markerRange, slice: combinedSlice),
                continuationLines.1)
      } else {
        return (ListItem(listType: type, markerRange: markerRange, slice: line),
                stream.dropFirst())
      }
    }
  }
}

private let unorderedListMarkerRegularExpression = "^\\s*[-\\+\\*]\\s"
private let orderedListMarkerRegularExpression = "^\\s*\\d{1,9}[\\.\\)]\\s"

private func rangeOfRegularExpression(
  _ regularExpression: String,
  in substring: Substring
) -> Range<Substring.Index>? {
  return substring.range(of: regularExpression, options: .regularExpression)
}

private let unorderedRecognizer =
  curry(rangeOfRegularExpression)(unorderedListMarkerRegularExpression)
private let orderedRecognizer =
  curry(rangeOfRegularExpression)(orderedListMarkerRegularExpression)
