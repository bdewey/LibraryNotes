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
  public static let list = NodeType(rawValue: "list")
}

/// A list: https://spec.commonmark.org/0.28/#lists
public final class List: Node, LineParseable {
  public init(listType: ListType, items: [MiniMarkdown.ListItem], slice: StringSlice) {
    self.listType = listType
    self.items = items
    super.init(type: .list, slice: slice)
  }

  public override var parsingRules: ParsingRules! {
    didSet {
      for item in items { item.parsingRules = parsingRules }
    }
  }

  public let listType: ListType
  public let items: [ListItem]

  public static let parser
    = Parser { (_ stream: LineParseable.Stream) -> (List, LineParseable.Stream)? in
      guard let (results, remainder) = MiniMarkdown.ListItem.parser.many.parse(stream) else {
        return nil
      }
      if let combinedSlice = results
        .map({ $0.slice })
        .reduce(nil, { (result: StringSlice?, slice: StringSlice) in
          return result + slice
        }) {
        return (List(listType: .unordered, items: results, slice: combinedSlice),
                remainder)
      } else {
        return nil
      }
    }

  override public var children: [Node] {
    return items
  }
}

extension Node {

  public func isList(type: ListType) -> Bool {
    guard let list = self as? List else { return false }
    return list.listType == type
  }
}
