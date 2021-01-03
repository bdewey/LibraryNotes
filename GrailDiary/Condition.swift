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

/// A synchronization primitive that asynchronously executes blocks when a condition is true.
public final class Condition {
  /// Public access to the condition.
  ///
  /// It is safe to **set** the condition. If you set the condition true, then any previously
  /// scheduled blocks will execute and any future blocks will get queued without delay. You can
  /// later set the condition to false to queue future blocks, etc.
  ///
  /// You don't want to **read** the condition and use it to make decisions.
  public var condition: Bool {
    get {
      assertionFailure("Are you sure you want to do this?")
      var conditionCopy: Bool?
      synchronized {
        conditionCopy = self.storedCondition
      }
      return conditionCopy!
    }
    set {
      synchronized {
        self.storedCondition = newValue
        if newValue {
          self.performAndClearWorkQueue()
        }
      }
    }
  }

  /// Performs a block when the condition is true.
  public func asyncWhenTrue(onQueue queue: DispatchQueue, execute: @escaping () -> Void) {
    synchronized {
      if self.storedCondition {
        queue.async(execute: execute)
      } else {
        self.workQueue.append((queue: queue, blockToExecute: execute))
      }
    }
  }

  /// Private serial queue for access to internal data.
  private let synchronizationQueue = DispatchQueue(
    label: "Condition synchronization",
    qos: .default,
    attributes: []
  )

  /// Internal state of the condition. Protected by synchronizationQueue.
  private var storedCondition = false

  /// Internal: Saves the association of queues & blocks to execute when the condition becomes true.
  /// Protected by synchronizationQueue.
  private var workQueue: [(queue: DispatchQueue, blockToExecute: () -> Void)] = []

  /// Helper for locking.
  private func synchronized(_ block: @escaping () -> Void) {
    synchronizationQueue.sync(execute: block)
  }

  /// Internal helper -- performs all queued work and clears the queue.
  /// Must be called on synchronizationQueue.
  private func performAndClearWorkQueue() {
    for (queue, block) in workQueue {
      queue.async(execute: block)
    }
    workQueue = []
  }
}

public extension DispatchQueue {
  /// Syntactic sugar for executing a block when a condition is true.
  func async(when condition: Condition, execute: @escaping () -> Void) {
    condition.asyncWhenTrue(onQueue: self, execute: execute)
  }
}
