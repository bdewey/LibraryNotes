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

/// What it says: Maintains an array of blocks that accept a value, and can invoke all
/// of the blocks with that value.
public struct BlockArray<Value> {
  public typealias Block = (Value) -> Void
  private var blocks: [Block?] = []
  private var activeCount = 0

  /// Adds a block to the collection.
  ///
  /// - returns: The index that can be used in a subsequent call to `remove(at:)`
  public mutating func append(_ block: @escaping Block) -> Int {
    activeCount += 1
    blocks.append(block)
    return blocks.count - 1
  }

  /// Removes the block at a specific index.
  ///
  /// - note: Removing a block does not invalidate other indexes.
  public mutating func remove(at index: Int) {
    activeCount -= 1
    blocks[index] = nil
  }

  /// Invokes all valid blocks with the parameter `value`
  public func invoke(with value: Value) {
    for block in blocks {
      block?(value)
    }
  }

  /// Returns true if there are no blocks in the collection.
  public var isEmpty: Bool {
    return activeCount == 0
  }
}

extension BlockArray: CustomReflectable {
  public var customMirror: Mirror {
    return Mirror(
      self,
      children: ["activeSubscribers": activeCount],
      displayStyle: .class,
      ancestorRepresentation: .suppressed
    )
  }
}
