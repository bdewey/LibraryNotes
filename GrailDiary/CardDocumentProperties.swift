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

/// A struct that combines document attribution with the parsing rules for interpreting the contents
/// of the document.
public struct CardDocumentProperties {
  /// The document name that the card came from.
  public let documentName: Note.Identifier

  /// Attribution to use when displaying cards from the document, with markdown formatting.
  public let attributionMarkdown: String

  public init(documentName: Note.Identifier, attributionMarkdown: String) {
    self.documentName = documentName
    self.attributionMarkdown = attributionMarkdown
  }
}
