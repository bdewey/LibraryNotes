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

/// A type that can be parsed from an input stream of characters.
public protocol CharacterParseable {

  typealias Stream = ArraySlice<StringCharacter>

  static var parser: Parser<Self, Stream> { get }
}

extension CharacterParseable where Self: Node {

  /// Type-erasing: Eliminate knowledge that we parse Self and replace with knowledge
  ///               that we have parsed a MiniMarkdownNode
  public static var nodeParser: Parser<Node, Stream> {
    return Parser { (stream) -> (Node, Stream)? in
      guard let (result, remainder) = parser.parse(stream) else { return nil }
      return (result, remainder)
    }
  }
}

/// Helpful character-stream parsers.
public enum CharacterParsers {
  public typealias Stream = ArraySlice<StringCharacter>

  /// Parses a sequence of characters out of a stream.
  public static func characters<S: Sequence> (_ characters: S) -> Parser<StringSlice, Stream>
    where S.Element == Character {
      return Parser { (stream: Stream) -> (StringSlice, Stream)? in
        var slice: StringSlice?
        var stream = stream
        for character in characters {
          guard let first = stream.first, character == first.character else { return nil }
          slice += StringSlice(first)
          stream = stream.dropFirst()
        }
        if let slice = slice {
          return (slice, stream)
        } else {
          return nil
        }
      }
  }

  /// Parses a single character out of a stream.
  /// - parameter predicate: Returns true if the character should be parsed.
  public static func character(where predicate: @escaping (Character) -> Bool) ->
    Parser<StringCharacter, Stream> {
      return Parser { (stream: Stream) -> (StringCharacter, Stream)? in
        guard let character = stream.first, predicate(character.character) else { return nil }
        return (character, stream.dropFirst())
      }
  }

  /// This is like a backwards peek. It will look at the *previous* character in the stream
  /// to determine if it matches a predicate. If so, it parses that character and leaves the
  /// stream unchanged. If it does not match, it will fail to parse.
  ///
  /// - parameter predicate: The predicate for evaluating the preceeding character.
  /// - parameter parseSucceedsAtStreamStart: If true, parsing succeeds if there is no
  ///             preceeding character.
  /// - returns: A parser that will peek at the preceeding character of the stream.
  public static func preceedingCharacter(
    where predicate: @escaping (Character) -> Bool,
    parseSucceedsAtStreamStart: Bool
  ) -> Parser<StringCharacter?, Stream> {
    return Parser { (stream) -> (StringCharacter?, Stream)? in
      guard let first = stream.first, let preceeding = first.previousCharacter else {
        if parseSucceedsAtStreamStart {
          return (nil, stream)
        } else {
          return nil
        }
      }
      if predicate(preceeding.character) {
        return (preceeding, stream)
      } else {
        return nil
      }
    }
  }

  /// Parse a non-whitespace character.
  public static let nonWhitespace = character(where: { !$0.isWhitespace })

  /// Parse a left-flanking delimiter.
  public static func leftFlanking<T>(_ parser: Parser<T, Stream>) -> Parser<T, Stream> {
    return parser <* nonWhitespace.peek
  }

  /// Parses a delimited slice of text.
  public static func slice(
    delimitedBy delimiter: String
  ) -> Parser<DelimitedSlice, ArraySlice<StringCharacter>> {
    return curry(DelimitedSlice.init)
      <^> leftFlanking(characters(delimiter))
      <*> character(where: { $0 != delimiter.first! }).oneOrMore
      <*> characters(delimiter)
  }

  private static func makeSlice(
    open: StringCharacter,
    middle: [StringCharacter],
    close: StringCharacter
  ) -> DelimitedSlice {
    return DelimitedSlice(
      leftDelimiter: Delimiter(open),
      slice: middle.stringSlice,
      rightDelimiter: Delimiter(close)
    )
  }

  public static func slice(
    between opening: Character,
    and closing: Character
  ) -> Parser<DelimitedSlice, Stream> {
    return curry(makeSlice)
      <^> character(where: { $0 == opening })
      <*> character(where: { $0 != closing }).many
      <*> character(where: { $0 == closing })
  }

  /// Makes a StringSlice from an opening character followed by an array of characters.
  private static func makeSlice(
    openingDelimiter: StringCharacter,
    remainder: [StringCharacter]
  ) -> StringSlice {
    if let remainderSlice = remainder.stringSlice {
      return StringSlice(openingDelimiter) + remainderSlice
    } else {
      return StringSlice(openingDelimiter)
    }
  }

  /// Parses a "whitespace terminated slice" -- a sequence of non-whitespace characters that
  /// starts with a special delimiter, like a #hashtag or a @mention.
  public static func whitespaceTerminatedSlice(
    openingDelimiter: Character
  ) -> Parser<StringSlice, Stream> {
    return curry(makeSlice)
      <^> (preceedingCharacter(where: { $0.isWhitespace }, parseSucceedsAtStreamStart: true)
        *> character(where: { $0 == openingDelimiter }))
      <*> character(where: { !$0.isWhitespace }).oneOrMore
  }
}
