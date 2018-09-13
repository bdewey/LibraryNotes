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

public enum DocumentPropertySource {
  /// The value came from the document
  case document

  /// The value came from in-memory modification
  case memory
}

/// A structure that carries both a the value and its "source" (did it come from the document
/// or an in-memory modification)
public struct DocumentValueWithSource<Value> {

  public init(source: DocumentPropertySource, value: Value) {
    self.source = source
    self.value = value
  }

  /// Where'd the value come from
  public let source: DocumentPropertySource

  /// The value itself
  public let value: Value

  public func settingSource(_ source: DocumentPropertySource) -> DocumentValueWithSource<Value> {
    return DocumentValueWithSource(source: source, value: self.value)
  }
}

