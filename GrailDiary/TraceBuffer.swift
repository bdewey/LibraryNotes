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

/// Used for tracing the execution of rules.
public final class TraceBuffer: CustomStringConvertible {
  /// Singleton. This is ugly but I can get rid of it if I move to regular code generation.
  public static let shared = TraceBuffer()

  /// All completed test entries.
  public var traceEntries: [Entry] = []

  /// Start working on an entry.
  public func pushEntry(_ entry: Entry) {
    entryStack.append(entry)
  }

  /// Finish the most recent entry
  public func popEntry() {
    guard let popped = entryStack.popLast() else {
      assertionFailure()
      return
    }
    if let last = entryStack.last {
      last.subentries.append(popped)
    } else {
      traceEntries.append(popped)
    }
  }

  public func entry(at indexPath: IndexPath) -> Entry {
    precondition(!indexPath.isEmpty)
    return traceEntries[indexPath.first!].entry(at: indexPath.dropFirst())
  }

  /// All in-progress entries
  private var entryStack: [Entry] = []

  public var description: String {
    traceEntries.enumerated().map { index, entry in
      "\(index):\n\(entry)\n\n"
    }.joined()
  }

  public final class Entry: CustomStringConvertible {
    public init(rule: ParsingRule, index: Int, locationHint: String) {
      self.rule = rule
      self.index = index
      self.locationHint = locationHint
    }

    public let rule: ParsingRule
    public let index: Int
    public let locationHint: String
    public var result: ParsingResult?
    public var subentries: [Entry] = []

    public var description: String {
      var buffer = ""
      writeRecursiveDescription(to: &buffer, indexPath: [], maxLevel: 2)
      return buffer
    }

    public var fullDescription: String {
      var buffer = ""
      writeRecursiveDescription(to: &buffer, indexPath: [])
      return buffer
    }

    public func entry(at indexPath: IndexPath) -> Entry {
      if indexPath.isEmpty { return self }
      return subentries[indexPath.first!].entry(at: indexPath.dropFirst())
    }

    private func writeRecursiveDescription(to buffer: inout String, indexPath: IndexPath, maxLevel: Int = Int.max) {
      let indentLevel = indexPath.count
      guard indentLevel <= maxLevel else { return }
      let space = String(repeating: "| ", count: indentLevel)
      buffer.append("\(space)+ \(rule)@\(index): \(locationHint) \(indexPath)\n")
      for (index, subentry) in subentries.enumerated() {
        subentry.writeRecursiveDescription(to: &buffer, indexPath: indexPath.appending(index), maxLevel: maxLevel)
      }
      let resultString = result.map(String.init(describing:)) ?? "nil"
      buffer.append("\(space)= \(rule)@\(index): \(resultString)\n")
    }
  }
}
