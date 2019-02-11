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

precedencegroup SequencePrecedence {
  associativity: left
  higherThan: AdditionPrecedence
}

infix operator <*>: SequencePrecedence
infix operator *>: SequencePrecedence
infix operator <*: SequencePrecedence
infix operator <^>: SequencePrecedence

/// A generic stream parser.
public struct Parser<T, Stream: Sequence> where Stream.SubSequence == Stream {
  public typealias ParseFunction = (Stream) -> (T, Stream)?

  /// The parse function: Given an input stream, returns the parsed type plus the remaining
  /// unparsed content of the stream.
  public let parse: ParseFunction

  public init(_ parse: @escaping ParseFunction) {
    self.parse = parse
  }

  /// Option operator -- parses either the left or the right.
  public static func || (lhs: Parser, rhs: Parser) -> Parser {
    return Parser({ (stream) -> (T, Stream)? in
      if let result = lhs.parse(stream) { return result }
      return rhs.parse(stream)
    })
  }

  public var oneOrMore: Parser<[T], Stream> {
    let prepend = { (element: T, array: [T]) -> [T] in
      var array = array
      array.insert(element, at: 0)
      return array
    }
    return curry(prepend) <^> self <*> many
  }

  /// Matches zero or more of the receiver.
  public var many: Parser<[T], Stream> {
    return Parser<[T], Stream>({ (stream) -> ([T], Stream) in
      var stream = stream
      var results: [T] = []
      while let (output, remainder) = self.parse(stream) {
        results.append(output)
        stream = remainder
      }
      return (results, stream)
    })
  }

  /// A parser that tests if the receiver matches the contents of the stream,
  /// without removing the contents.
  public var peek: Parser<T, Stream> {
    return Parser { (stream) -> (T, Stream)? in
      guard let (results, _) = self.parse(stream) else { return nil }
      return (results, stream)
    }
  }

  /// Matches the receiver followed by another parser.
  ///
  /// - parameter parser: The parser that must follow the receiver.
  /// - returns: A parser that recognizes the tuple of the receiver's contents
  ///            and `parser`s contents.
  public func followed<U>(by parser: Parser<U, Stream>) -> Parser<(T, U), Stream> {
    return Parser<(T, U), Stream> { (stream: Stream) -> ((T, U), Stream)? in
      guard let (firstResult, next) = self.parse(stream),
        let (secondResult, remainder) = parser.parse(next)
      else { return nil }
      return ((firstResult, secondResult), remainder)
    }
  }

  /// Map a function over the parse results.
  ///
  /// - parameter f: The function to apply to the parse results.
  /// - returns: A parser that returns the transformed output of the receiver's output.
  public func map<U>(_ function: @escaping (T) -> U) -> Parser<U, Stream> {
    return Parser<U, Stream> { (stream) -> (U, Stream)? in
      guard let (result, remainder) = self.parse(stream) else { return nil }
      return (function(result), remainder)
    }
  }
}

public protocol AnyOptional {
  associatedtype Value

  var value: Value? { get }
}

extension Optional: AnyOptional {
  public var value: Wrapped? {
    switch self {
    case .none:
      return nil
    case .some(let wrapped):
      return wrapped
    }
  }
}

extension Parser where T: AnyOptional {
  /// For parsers of the form <T?, Stream>, constructs a parser of form <T, Stream>
  public var unwrapped: Parser<T.Value, Stream> {
    return Parser<T.Value, Stream> { stream in
      guard
        let (results, remainder) = self.parse(stream),
        let value = results.value
      else { return nil }
      return (value, remainder)
    }
  }
}

// TODO: I first put this as a static function on Parser, but that lead to cryptic
// compiler errors. Someday figure out why that didn't work.
public func any<T, Stream>(of parsers: [Parser<T, Stream>]) -> Parser<T, Stream> {
  return Parser<T, Stream> { (stream) -> (T, Stream)? in
    for childParser in parsers {
      if let results = childParser.parse(stream) {
        return results
      }
    }
    return nil
  }
}

/// Sequence operator
public func <*> <A, B, Stream>(
  lhs: Parser<(A) -> B, Stream>,
  rhs: Parser<A, Stream>
) -> Parser<B, Stream> {
  return lhs.followed(by: rhs).map { function, argument in function(argument) }
}

/// Sequence, discarding the output of the first operator.
public func *> <A, B, Stream>(
  lhs: Parser<A, Stream>,
  rhs: Parser<B, Stream>
) -> Parser<B, Stream> {
  // Terse code from objc.io...
  // Start with a function that just returns its second argument, then map that over the sequence
  // of lhs, rhs.
  return curry({ _, rhs in rhs }) <^> lhs <*> rhs
}

/// Sequence, discarding the output of the second operator.
public func <* <A, B, Stream>(
  lhs: Parser<A, Stream>,
  rhs: Parser<B, Stream>
) -> Parser<A, Stream> {
  return curry({ lhs, _ in lhs }) <^> lhs <*> rhs
}

/// Map operator
public func <^> <A, B, Stream>(
  lhs: @escaping (A) -> B,
  rhs: Parser<A, Stream>
) -> Parser<B, Stream> {
  return rhs.map(lhs)
}
