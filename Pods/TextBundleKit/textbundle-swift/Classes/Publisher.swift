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

/// Type-erasing protocol for subscriptions.
public protocol AnySubscription: class { }

/// Publishes changes to values.
///
/// This *looks* like Reactive Programming but is meant to be much less "scaffolding-rich" --
/// it just contains what's needed to inform UI components of changes to documents, which can come
/// either from other parts of the program generating model updates OR from the document changing
/// because of some other process editing it (e.g., iCloud synchronization).
public final class Publisher<Value> {
  
  /// A publishing endpoint is a function that will send the value to all subscribers.
  public typealias PublishingEndpoint = (Result<Value>) -> Void

  /// Represents a connection to a publisher.
  ///
  /// - note: The subscription maintains a strong connection back to the publisher.
  final private class Subscription: AnySubscription {
    
    /// The publisher that generates
    fileprivate let publisher: Publisher<Value>
    
    /// Index of this block in the publisher.
    fileprivate let blockIndex: Int
    
    /// Designated initializer.
    fileprivate init(publisher: Publisher<Value>, blockIndex: Int) {
      self.publisher = publisher
      self.blockIndex = blockIndex
    }
    
    /// Removes this subscription from the publisher.
    deinit {
      publisher.removeSubscription(self)
    }
  }

  /// Creates a new publisher.
  ///
  /// - returns: A tuple containing the publisher and the endpoint that can be used to
  ///            send results to the publisher.
  public static func create() -> (PublishingEndpoint, Publisher<Value>) {
    let publisher = Publisher<Value>()
    return (publisher.publishResult, publisher)
  }

  /// Arbitrary objects that this publisher depends on. As long as this publisher exists,
  /// these will exist.
  private var dependencies: [AnyObject] = []

  /// Adds a dependency.
  ///
  /// The publisher keeps a strong reference to all dependencies, making sure they exist as long
  /// as the publisher exists.
  public func addDependency(_ dependency: AnyObject) {
    dependencies.append(dependency)
  }
  
  /// All subscribers.
  private var subscribers = BlockArray<Result<Value>>()
  
  /// Publish a result to all subscribers.
  /// - note: All subscriber blocks are called synchronously on this thread.
  /// - parameter result: The result to publish to subscribers.
  private func publishResult(_ result: Result<Value>) {
    assert(Thread.isMainThread)
    subscribers.invoke(with: result)
  }
  
  /// Adds a subscriber.
  ///
  /// - parameter block: The block to invoke with new values
  public func subscribe(_ block: @escaping (Result<Value>) -> Void) -> AnySubscription {
    assert(Thread.isMainThread)
    return Subscription(publisher: self, blockIndex: subscribers.append(block))
  }
  
  /// Removes this subscription. The associated block will not get called on subsequent
  /// `invoke`
  public func removeSubscription(_ subscription: AnySubscription) {
    assert(Thread.isMainThread)
    let subscription = subscription as! Subscription
    assert(subscription.publisher === self)
    subscribers.remove(at: subscription.blockIndex)
  }
  
  public var hasActiveSubscribers: Bool {
    return !subscribers.isEmpty
  }
}

extension Publisher: CustomReflectable {
  public var customMirror: Mirror {
    return Mirror(
      self,
      children: ["subscribers": subscribers],
      displayStyle: .class,
      ancestorRepresentation: .suppressed
    )
  }
}
