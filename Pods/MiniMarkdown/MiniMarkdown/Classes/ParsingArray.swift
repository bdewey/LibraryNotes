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

/// An ordered array of parsers, where each parser operates on the same kind of input stream
/// (e.g., characters or lines).
public struct ParsingArray<Stream: Collection> where Stream.SubSequence == Stream {
  public typealias ChunkParser = Parser<Node, Stream>
  public var parsers: [ChunkParser]

  public init(_ parsers: [ChunkParser]) {
    self.parsers = parsers
  }

  private var parser: Parser<[Node], Stream> {
    return any(of: parsers).many
  }

  /// Parses the input stream.
  ///
  /// - note: Rules are applied in order. The last item in the rules should match any input
  ///         item to guarantee that the entire input stream will be parsed.
  ///
  /// - parameter input: The input stream to parse.
  /// - returns: An array of parsed nodes.
  public func parse(_ input: Stream) -> [Node] {
    guard let (results, remainder) = parser.parse(input) else { return [] }
    assert(remainder.isEmpty)
    return results.combineElements()
  }
}
