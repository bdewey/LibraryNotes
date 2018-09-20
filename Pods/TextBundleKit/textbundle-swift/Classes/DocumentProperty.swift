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

/// Coordination protocol with stable storage.
public protocol StableStorage: class {
  associatedtype Value
  
  /// Supplies the stable storage version of the value.
  func documentPropertyInitialValue() throws -> Value
  
  /// Lets stable storage know that the in-memory copy has changed.
  func documentPropertyDidChange()
}

/// Holds an mutable in-memory copy of data that is in stable storage, and tracks whether
/// the in-memory copy has changed since being in stable storage ("dirty").
public final class DocumentProperty<Storage: StableStorage> {

  public typealias ValueWithSource = DocumentValueWithSource<Storage.Value>

  public init(storage: Storage) { self.storage = storage }
  
  /// Weak reference back to stable storage.
  private weak var storage: Storage?
  
  /// In-memory copy of the value.
  private var _result: Result<ValueWithSource>?
  
  private let (publishingEndpoint, publisher) = Publisher<ValueWithSource>.create()

  /// Discards the cached value and reloads from stable storage.
  public func invalidate() {
    _result = nil
    if publisher.hasActiveSubscribers {
      publishingEndpoint(currentValueWithSource)
    }
  }
  
  /// Returns the in-memory copy of the value.
  public var currentResult: Result<Storage.Value> {
    return currentValueWithSource.flatMap { $0.value }
  }

  private var currentValueWithSource: Result<ValueWithSource> {
    if let value = _result { return value }
    _result = Result<ValueWithSource> {
      let value = try storage!.documentPropertyInitialValue()
      return DocumentValueWithSource(source: .document, value: value)
    }
    return _result!
  }
  
  /// Changes the in-memory copy of the value.
  public func setValue(_ value: Storage.Value) {
    setResult(.success(value))
  }

  public func changeValue(_ mutation: (Storage.Value) -> Storage.Value) {
    setResult(currentResult.flatMap(mutation))
  }
  
  private func setResult(_ result: Result<Storage.Value>) {
    self._result = result.flatMap { DocumentValueWithSource(source: .memory, value: $0) }
    publishingEndpoint(currentValueWithSource)
    storage?.documentPropertyDidChange()
  }

  /// If the in-memory copy is dirty, returns that value and sets its state to clean.
  ///
  /// - note: This is intended to only be called by the stable storage when writing the
  ///         in-memory copy.
  public func clean() -> Storage.Value? {
    var returnValue: Storage.Value? = nil
    _result = _result?.flatMap({ (valueWithSource) -> ValueWithSource in
      switch valueWithSource.source {
      case .document:
        return valueWithSource
      case .memory:
        returnValue = valueWithSource.value
        return valueWithSource.settingSource(.document)
      }
    })
    return returnValue
  }
}

extension DocumentProperty: CustomReflectable {
  public var customMirror: Mirror {
    return Mirror(
      self,
      children: ["currentResult": _result, "subscribers": publisher],
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
