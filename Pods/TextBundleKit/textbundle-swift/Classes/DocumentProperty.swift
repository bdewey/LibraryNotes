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
    self.currentValueWithSource = initialResult.flatMap { DocumentValueWithSource(source: .document, value: $0 )}
  }

  private let readFunction: ReadFunction
  private let writeFunction: WriteFunction
  private let (publishingEndpoint, publisher) = Publisher<ValueWithSource>.create()

  /// For TextBundleSaveListener conformance: Tells our document that we have something to save.
  public var textBundleListenerHasChanges: TextBundleDocumentSaveListener.ChangeBlock?

  public typealias ValueWithSource = DocumentValueWithSource<Value>

  /// Returns the in-memory copy of the value.
  public var currentResult: Result<Value> {
    return currentValueWithSource.flatMap { $0.value }
  }

  private var currentValueWithSource: Result<ValueWithSource>
  
  /// Changes the in-memory copy of the value.
  public func setValue(_ value: Value) {
    setResult(.success(value))
  }

  public func changeValue(_ mutation: (Value) -> Value) {
    setResult(currentResult.flatMap(mutation))
  }

  internal func setDocumentResult(_ result: Result<Value>) {
    let newResult = result.flatMap { DocumentValueWithSource(source: .document, value: $0) }
    currentValueWithSource = newResult
    publishingEndpoint(newResult)
  }
  
  private func setResult(_ result: Result<Value>) {
    let newResult = result.flatMap { DocumentValueWithSource(source: .memory, value: $0) }
    currentValueWithSource = newResult
    publishingEndpoint(newResult)
    textBundleListenerHasChanges?()
  }
}

extension DocumentProperty: TextBundleDocumentSaveListener {
  public func textBundleDocumentWillSave(_ textBundleDocument: TextBundleDocument) throws {
    guard let valueWithSource = currentValueWithSource.value else { return }
    if valueWithSource.source == .memory {
      try writeFunction(valueWithSource.value, textBundleDocument)
      currentValueWithSource = .success(valueWithSource.settingSource(.document))
    }
  }

  public final func textBundleDocumentDidLoad(_ textBundleDocument: TextBundleDocument) {
    let result = Result<Value> { try readFunction(textBundleDocument) }
    setDocumentResult(result)
  }
}

extension DocumentProperty: CustomReflectable {
  public var customMirror: Mirror {
    return Mirror(
      self,
      children: [
        "currentValueWithSource": String(describing: currentValueWithSource),
        "subscribers": publisher,
      ],
      displayStyle: .class,
      ancestorRepresentation: .suppressed
    )
  }
}

extension DocumentProperty {
  public func subscribe(_ block: @escaping (Result<ValueWithSource>) -> Void) -> AnySubscription {
    block(currentValueWithSource)
    return publisher.subscribe(block)
  }

  public func removeSubscription(_ subscription: AnySubscription) {
    publisher.removeSubscription(subscription)
  }
}
