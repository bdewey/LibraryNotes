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

  public init(slice: StringSlice, headingLevel: Int) {
    self.headingLevel = headingLevel
    super.init(type: .heading, slice: slice)
  }

  public static let parser
    = Parser { (_ stream: LineParseable.Stream) -> (Heading, LineParseable.Stream)? in
      guard
        let line = stream.first,
        let headingLevel = line.substring.headingLevel,
        (1...6).contains(headingLevel)
        else {
          return nil
      }
      return (Heading(slice: line, headingLevel: headingLevel),
              stream.dropFirst())
    }
}
