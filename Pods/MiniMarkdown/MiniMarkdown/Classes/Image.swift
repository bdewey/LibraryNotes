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
  public static let image = NodeType(rawValue: "image")
}

/// An image: https://spec.commonmark.org/0.28/#images
public final class Image: Node, CharacterParseable {
  public init(bang: StringCharacter, textSlice: StringSlice, urlSlice: StringSlice) {
    self.textSlice = textSlice
    self.urlSlice = urlSlice
    let slice = StringSlice(bang) + textSlice + urlSlice
    super.init(type: .image, slice: slice, markdown: String(slice.substring))
  }

  public let textSlice: StringSlice
  public let urlSlice: StringSlice

  public var text: Substring {
    return textSlice.substring.dropFirst().dropLast()
  }

  public var url: Substring {
    return urlSlice.substring.dropFirst().dropLast()
  }

  public static let parser = curry(Image.init)
    <^> CharacterParsers.character(where: { $0 == "!" })
    <*> CharacterParsers.slice(between: "[", and: "]")
    <*> CharacterParsers.slice(between: "(", and: ")")
}
