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

/// Classes that wrap documents and have convenience open & close methods.
public protocol DocumentProtocol {
  typealias CompletionHandler = (Bool) -> Void
  
  /// Opens the associated document.
  func open(completionHandler: CompletionHandler?)
  
  /// Closes the associated document.
  func close(completionHandler: CompletionHandler?)
}

/// An implementation of DocumentProtocol that wraps another UIDocument and forwards methods to it.
public protocol WrappingDocument: DocumentProtocol {
  associatedtype Document: UIDocument
  
  /// The wrapped document.
  var document: Document { get }
}

/// By default, forward open & close to the associated document.
extension WrappingDocument {
  
  public func open(completionHandler: CompletionHandler?) {
    document.open(completionHandler: completionHandler)
  }
  
  public func close(completionHandler: CompletionHandler?) {
    document.close(completionHandler: completionHandler)
  }
}
