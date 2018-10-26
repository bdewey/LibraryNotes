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

/// A node that consists of a left delimiter, a right delimiter, and optional text in between.
public class DelimitedText: Node {

  public init(type: NodeType, delimitedSlice: DelimitedSlice) {
    self.memoizedChildren = delimitedSlice.nodes
    let slice = delimitedSlice.completeSlice
    super.init(type: type, slice: slice)
    for child in memoizedChildren {
      child.parent = self
    }
  }

  private let memoizedChildren: [Node]

  public override var children: [Node] {
    return memoizedChildren
  }
}

extension DelimitedSlice {
  fileprivate var nodes: [Node] {
    if let textSlice = slice {
      return [
        leftDelimiter,
        Text(slice: textSlice),
        rightDelimiter,
      ]
    } else {
      return [
        leftDelimiter,
        rightDelimiter,
      ]
    }
  }
}

