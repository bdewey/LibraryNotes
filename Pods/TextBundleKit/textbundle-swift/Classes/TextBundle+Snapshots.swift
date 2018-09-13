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

fileprivate let snapshotPath = ["snapshots"]
fileprivate let snapshotPrefix = "snapshot-"
fileprivate let formatter = ISO8601DateFormatter()

extension String {
  
  fileprivate func removingPrefix(_ prefix: String) -> Substring? {
    guard hasPrefix(prefix) else { return nil }
    return suffix(from: index(startIndex, offsetBy: prefix.count))
  }
  
  fileprivate var snapshotDate: Date? {
    guard let suffix = removingPrefix(snapshotPrefix) else { return nil }
    return formatter.date(from: String(suffix))
  }
}

extension Date {
  
  fileprivate var snapshotKey: String {
    return snapshotPrefix + formatter.string(from: self)
  }
}

// TODO: Move this into a separate pod; the goal is to have composable bundle functionality.
// TODO: Use https://github.com/google/diff-match-patch to store differences between snapshots.
extension TextStorage {
  
  /// Stores a snapshot of the current text.
  /// - parameter snapshotDate: The Date to use to identify the snapshot.
  /// - returns: The Date that identifies this particular snapshot.
  @discardableResult
  public func makeSnapshot(at snapshotDate: Date = Date()) throws -> Date {
    let currentText = try text.currentResult.unwrap()
    guard let data = currentText.data(using: .utf8) else {
      throw NSError(
        domain: NSCocoaErrorDomain,
        code: NSFileWriteInapplicableStringEncodingError,
        userInfo: nil
      )
    }
    let preferredFilename = snapshotDate.snapshotKey
    try document.addData(data, preferredFilename: preferredFilename, childDirectoryPath: snapshotPath)
    return snapshotDate
  }
  
  /// All snapshots in the bundle.
  public var snapshots: [Date] {
    guard let snapshotKeys = try? document.keys(at: snapshotPath) else { return [] }
    return snapshotKeys.compactMap { $0.snapshotDate }
  }
  
  /// Gets the snapshot string associated with a specific date.
  public func snapshot(at snapshotDate: Date) throws -> String {
    let data = try document.data(for: snapshotDate.snapshotKey, at: snapshotPath)
    guard let snapshot = String(data: data, encoding: .utf8) else {
      throw NSError(
        domain: NSCocoaErrorDomain,
        code: NSFileWriteInapplicableStringEncodingError,
        userInfo: nil
      )
    }
    return snapshot
  }
}
