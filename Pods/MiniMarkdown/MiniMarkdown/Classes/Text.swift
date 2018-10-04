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
  public static let text = NodeType(rawValue: "text")
}

/// Plain text: https://spec.commonmark.org/0.28/#textual-content
public final class Text: Node, CharacterParseable {

  public init(slice: StringSlice) {
    super.init(type: .text, slice: slice, markdown: String(slice.substring))
  }

  public override func combining(with other: Node) -> Self? {
    guard let otherText = other as? Text else { return nil }
    return .init(slice: slice + otherText.slice)
  }

  public static let parser = Parser { (stream) -> (Text, CharacterParseable.Stream)? in
    guard let first = stream.first else { return nil }
    return (Text(slice: StringSlice(first)), stream.dropFirst())
  }
}
