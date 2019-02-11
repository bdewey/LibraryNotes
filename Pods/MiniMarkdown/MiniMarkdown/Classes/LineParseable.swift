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

/// A type that can be parsed from an input stream of lines.
public protocol LineParseable {
  /// Input stream: A sequence of lines.
  typealias Stream = ArraySlice<StringSlice>

  /// A parser that can parse this type from a sequence of lines.
  static var parser: Parser<Self, Stream> { get }
}

extension LineParseable where Self: Node {
  /// Type-erasing: For nodes that are BlockParseable, have a parser that just
  /// parses a MiniMarkdownNode instead of the specific type.
  public static var nodeParser: Parser<Node, Stream> {
    return Parser { (stream) -> (Node, Stream)? in
      guard let (result, remainder) = parser.parse(stream) else { return nil }
      return (result, remainder)
    }
  }
}

public enum LineParsers {
  public static let anyLine = Parser { (stream) -> (StringSlice, ArraySlice<StringSlice>)? in
    guard let slice = stream.first else { return nil }
    return (slice, stream.dropFirst())
  }

  public static func line(
    where predicate: @escaping (StringSlice) -> Bool
  ) -> Parser<StringSlice, ArraySlice<StringSlice>> {
    return Parser { (stream) -> (StringSlice, ArraySlice<StringSlice>)? in
      guard let slice = stream.first, predicate(slice) else { return nil }
      return (slice, stream.dropFirst())
    }
  }
}
