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

public extension Range {
  /// Returns a new range that combines the current range with an adjacent range.
  ///
  /// - parameter other: The adjacent range
  /// - precondition: `other` is adjacent to `self`; i.e., self.upperBound == other.lowerBound
  /// - returns: A new range that encompasses both `self` and `other`
  public func concat(_ other: Range) -> Range {
    precondition(upperBound == other.lowerBound)
    return lowerBound ..< other.upperBound
  }
}
