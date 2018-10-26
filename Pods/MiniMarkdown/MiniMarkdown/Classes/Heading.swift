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

extension NodeType {
  public static let heading = NodeType(rawValue: "heading")
}

/// An ATX heading: https://spec.commonmark.org/0.28/#atx-headings
public final class Heading: InlineContainingNode, LineParseable {
  public let headingLevel: Int

  public init(slice: StringSlice, headingLevel: Int, headerDelimiterIndex: String.Index) {
    self.headingLevel = headingLevel
    let delimiterSlice = StringSlice(
      string: slice.string,
      range: slice.startIndex ..< headerDelimiterIndex
    )
    self.headerDelimiter = Delimiter(delimiterSlice)
    super.init(type: .heading, slice: slice)
    headerDelimiter.parent = self
  }

  private let headerDelimiter: Delimiter

  public override var memoizedChildrenPrefix: [Node] {
    return [headerDelimiter]
  }

  public override var inlineSlice: StringSlice {
    return StringSlice(
      string: slice.string,
      range: headerDelimiter.slice.endIndex ..< slice.endIndex
    )
  }

  public static let parser
    = Parser { (_ stream: LineParseable.Stream) -> (Heading, LineParseable.Stream)? in
      guard
        let line = stream.first,
        let headerPrefix = line.substring.headerPrefix,
        (1...6).contains(headerPrefix.headingLevel)
        else {
          return nil
      }
      return (
        Heading(
          slice: line,
          headingLevel: headerPrefix.headingLevel,
          headerDelimiterIndex: headerPrefix.index
        ),
        stream.dropFirst()
      )
    }
}

extension StringProtocol where Self.SubSequence == Substring {
  /// For a MiniMarkdown formatted line, the heading level of the line.
  ///
  /// - A line that starts with 4 or more spaces cannot be a heading.
  /// - A line that starts with between 1 and 6 "#" characters is a heading IF it is followed by
  ///   whitespace or end-of-line.
  /// - The number of "#" characters is the heading level.
  fileprivate var headerPrefix: (index: String.Index, headingLevel: Int)? {
    let (leadingWhitespace, remainder) = self.leadingWhitespace
    if leadingWhitespace.count >= 4 { return nil }
    let leadingHashes = remainder.prefix(while: { $0 == "#" })
    if leadingHashes.endIndex < remainder.endIndex,
      !remainder[leadingHashes.endIndex].isWhitespace {
      return nil
    }
    if (1...6).contains(leadingHashes.count) {
      let delimterTrailingWhitespace = self[leadingHashes.endIndex...]
        .prefix(while: { $0.isWhitespace })
      return (index: delimterTrailingWhitespace.endIndex, headingLevel: leadingHashes.count)
    } else {
      return nil
    }
  }
}
