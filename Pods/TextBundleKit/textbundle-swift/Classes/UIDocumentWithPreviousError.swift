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

import UIKit

/// This is a simple UIDocument subclass that stores the last error in the property `previousError`
open class UIDocumentWithPreviousError: UIDocument {

  private(set) public var previousError: Swift.Error?
  
  /// Remembers the error that it was asked to handle, but does no other recovery.
  open override func handleError(_ error: Swift.Error, userInteractionPermitted: Bool) {
    self.previousError = error
    finishedHandlingError(error, recovered: false)
  }
}
