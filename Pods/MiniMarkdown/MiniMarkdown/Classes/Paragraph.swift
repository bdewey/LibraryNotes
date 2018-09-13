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
  public static let paragraph = NodeType(rawValue: "paragraph")
}

/// A paragraph: https://spec.commonmark.org/0.28/#paragraphs
public final class Paragraph: InlineContainingNode, LineParseable {
  init(slice: StringSlice) {
    super.init(type: .paragraph, slice: slice)
  }

  /// Combines successive Paragraph structures into one.
  public override func combining(with other: Node) -> Self? {
    guard let otherParagraph = other as? Paragraph else { return nil }
    return .init(slice: slice + otherParagraph.slice)
  }

  /// Parses individual lines of a paragraph.
  ///
  /// - note: This will parse each line as its own paragraph. Combining multiple individual
  ///         lines into one paragraph happens as a separate step after parsing. This gives
  ///         an opportunity to parse the next line as something more specific than just a
  ///         paragraph line.
  public static let parser = Paragraph.init <^> LineParsers.anyLine
}
