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

public struct Tag: RawRepresentable {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
}

/// A structure that carries both a the value and its "source" (did it come from the document
/// or an in-memory modification)
public struct Tagged<Value> {

  public init(tag: Tag, value: Value) {
    self.tag = tag
    self.value = value
  }

  /// Where'd the value come from
  public let tag: Tag

  /// The value itself
  public let value: Value

  public func tagging(_ tag: Tag) -> Tagged<Value> {
    return Tagged(tag: tag, value: value)
  }
}

