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

public enum Result<Value> {
  case success(Value)
  case failure(Error)

  public init(_ block: () throws -> Value) {
    do {
      self = .success(try block())
    } catch {
      self = .failure(error)
    }
  }
  
  public func unwrap() throws -> Value {
    switch self {
    case .success(let value):
      return value
    case .failure(let error):
      throw error
    }
  }
  
  public var value: Value? {
    switch self {
    case .success(let value):
      return value
    case .failure(_):
      return nil
    }
  }
  
  public func flatMap<Output>(_ block: (Value) -> Output) -> Result<Output> {
    switch self {
    case .success(let value):
      return .success(block(value))
    case .failure(let error):
      return .failure(error)
    }
  }
}
