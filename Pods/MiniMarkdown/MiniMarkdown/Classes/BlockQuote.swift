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
  public static let blockQuote = NodeType(rawValue: "blockQuote")
}

/// https://github.github.com/gfm/#block-quotes
/// - note: This implementation does not handle continuations. Each line of a block quote
/// is parsed separately and lexical structures like paragraphs cannot span lines.
public final class BlockQuote: Node, LineParseable {

  public init(delimiter: Delimiter, remainder: StringSlice) {
    self.delimiter = delimiter
    self.remainder = remainder
    super.init(type: .blockQuote, slice: delimiter.slice + remainder)
  }

  private let delimiter: Delimiter
  private let remainder: StringSlice
  private var memoizedChildren: [Node]?

  public override var children: [Node] {
    if let memoizedChildren = memoizedChildren {
      return memoizedChildren
    } else {
      let results = parsingRules.parse([remainder])
      assert(results.allSatisfy({ $0.slice.string == remainder.string }))
      var memoizedChildren = [Node]()
      memoizedChildren.append(delimiter)
      memoizedChildren.append(contentsOf: results)
      for node in memoizedChildren {
        node.parent = self
      }
      self.memoizedChildren = memoizedChildren
      return memoizedChildren
    }
  }

  public static let parser = Parser<BlockQuote, ArraySlice<StringSlice>>
  { (stream) -> (BlockQuote, ArraySlice<StringSlice>)? in
    guard let line = stream.first,
          let delimiterRange = line.substring.range(
            of: "^\\s{0,3}>\\s?",
            options: .regularExpression
      ) else { return nil }
    let delimiter = Delimiter(StringSlice(string: line.string, range: delimiterRange))
    let remainder = StringSlice(
      string: line.string,
      range: delimiterRange.upperBound ..< line.range.upperBound
    )
    return (BlockQuote(delimiter: delimiter, remainder: remainder), stream.dropFirst())
  }
//
//  public static let parser = BlockQuote.init <^> LineParsers.line(where: { (line) -> Bool in
//    return line.decomposedBlockQuote != nil
//  })
}

extension StringSlice {

  /// If the line starts with a block quote delimiter, returns the decomposition of the line
  /// as a delimiter slice and a remainder slice. Otherwise returns nil.
  fileprivate var decomposedBlockQuote: (delimiter: StringSlice, remainder: StringSlice)? {
    guard let delimiterRange = substring.range(
      of: "^\\s{0,3}>\\s?",
      options: .regularExpression
    ) else {
      return nil
    }
    return (
      StringSlice(string: self.string, range: delimiterRange),
      StringSlice(string: self.string, range: delimiterRange.upperBound ..< self.range.upperBound)
    )
  }
}
