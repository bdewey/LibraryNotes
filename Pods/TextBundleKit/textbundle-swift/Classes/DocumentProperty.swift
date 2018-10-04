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

extension Tag {
  public static let document = Tag(rawValue: "document")
  public static let memory = Tag(rawValue: "memory")
}

/// Holds an mutable in-memory copy of data that is in stable storage, and tracks whether
/// the in-memory copy has changed since being in stable storage ("dirty").
public final class DocumentProperty<Value> {

  /// Reads values from the document.
  public typealias ReadFunction = (TextBundleDocument) throws -> Value

  /// Writes values back to the document.
  public typealias WriteFunction = (Value, TextBundleDocument) throws -> Void

  public init(
    document: TextBundleDocument,
    readFunction: @escaping ReadFunction,
    writeFunction: @escaping WriteFunction
  ) {
    self.readFunction = readFunction
    self.writeFunction = writeFunction
    let initialResult = Result<Value> { try readFunction(document) }
    self.taggedResult = initialResult.flatMap { Tagged(tag: .document, value: $0 )}
  }

  private let readFunction: ReadFunction
  private let writeFunction: WriteFunction
  private let (publishingEndpoint, publisher) = Publisher<Tagged<Value>>.create()

  /// For TextBundleSaveListener conformance: Tells our document that we have something to save.
  public var textBundleListenerHasChanges: TextBundleDocumentSaveListener.ChangeBlock?

  public var taggedResult: Result<Tagged<Value>> {
    didSet {
      publishingEndpoint(taggedResult)
      if let tag = taggedResult.value?.tag, tag != Tag.document {
        textBundleListenerHasChanges?()
      }
    }
  }
  
  /// Changes the in-memory copy of the value.
  public func setValue(_ value: Value, tag: Tag = .memory) {
    taggedResult = .success(Tagged(tag: tag, value: value))
  }

  public func changeValue(tag: Tag = .memory, mutation: (Value) -> Value) {
    taggedResult = taggedResult.flatMap({ Tagged(tag: tag, value: mutation($0.value)) })
  }
}

extension DocumentProperty: TextBundleDocumentSaveListener {
  public func textBundleDocumentWillSave(_ textBundleDocument: TextBundleDocument) throws {
    guard let valueWithSource = taggedResult.value else { return }
    if valueWithSource.tag != .document {
      try writeFunction(valueWithSource.value, textBundleDocument)
      taggedResult = .success(valueWithSource.tagging(.document))
    }
  }

  public final func textBundleDocumentDidLoad(_ textBundleDocument: TextBundleDocument) {
    taggedResult = Result<Tagged<Value>> {
      Tagged(tag: .document, value: try readFunction(textBundleDocument))
    }
  }
}

extension DocumentProperty: CustomReflectable {
  public var customMirror: Mirror {
    return Mirror(
      self,
      children: [
        "taggedResult": String(describing: taggedResult),
        "subscribers": publisher,
      ],
      displayStyle: .class,
      ancestorRepresentation: .suppressed
    )
  }
}

extension DocumentProperty {
  public func subscribe(_ block: @escaping (Result<Tagged<Value>>) -> Void) -> AnySubscription {
    block(taggedResult)
    return publisher.subscribe(block)
  }

  public func removeSubscription(_ subscription: AnySubscription) {
    publisher.removeSubscription(subscription)
  }
}
