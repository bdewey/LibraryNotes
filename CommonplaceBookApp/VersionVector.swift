// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import GRDB
import Logging

/// An in-memory representation of the "knowledge" contained in a database at a point in time.
/// It is a mapping between device ID and the latest timestamp of a change authored by that device.
// TODO: Make this generic over "identifier" and "sequence"
public struct VersionVector: Hashable, Comparable, CustomStringConvertible {
  public var versions: [String: Int64] = [:]

  /// `rhs > lhs` iff:
  /// - At least one version component exists in `rhs` that is greater than `lhs`
  /// - There are no version components in `lhs` that are greater than `rhs`
  public static func < (lhs: VersionVector, rhs: VersionVector) -> Bool {
    var hasAtLeastOneGreaterComponent = false
    for (key, value) in rhs.versions {
      if let lhsValue = lhs.versions[key] {
        if lhsValue > value {
          // We failed the second criteria -- there's a component where lhs > rhs, so
          // rhs cannot be strictly greater.
          return false
        }
        if value > lhsValue {
          hasAtLeastOneGreaterComponent = true
        }
      } else {
        hasAtLeastOneGreaterComponent = true
      }
    }
    return hasAtLeastOneGreaterComponent
  }

  /// Returns the union of one version vector and another. The result contains any device identifier from either version vector
  /// and the maximum date timestamp for that device.
  public func union(_ other: VersionVector) -> VersionVector {
    var result = self
    result.formUnion(other)
    return result
  }

  /// Updates the receiver to be the union of the receiver and `other`.
  public mutating func formUnion(_ other: VersionVector) {
    for (device, otherDate) in other.versions {
      if let date = versions[device] {
        versions[device] = max(date, otherDate)
      } else {
        versions[device] = otherDate
      }
    }
  }

  public var description: String {
    var items: [String] = []
    for item in versions.keys.sorted() {
      items.append("\(item) \(versions[item] ?? -1)")
    }
    return items.joined(separator: "\n")
  }

  /// True if this instance of the version vector "knows" about a specific change.
  func knowsAbout<R: MergeInfoRecord>(_ mergeInfoRecord: R) -> Bool {
    guard let date = versions[mergeInfoRecord.deviceUUID] else {
      return false
    }
    return date >= mergeInfoRecord.updateSequenceNumber
  }

  /// The core merge algorithm. Iterates through all records in `sourceDatabase` and copies them to `destinationDatabase`
  /// unless the destination copy is more up-to-date. Detects if there are *conflicting* changes in `sourceDatabase` and
  /// `destinationDatabase` and resolves them appropriately.
  static func merge<Record: MergeInfoRecord>(
    recordType: Record.Type,
    from sourceDatabase: Database,
    sourceKnowledge: VersionVector,
    to destinationDatabase: Database,
    destinationKnowledge: VersionVector
  ) throws -> MergeResult {
    var result = MergeResult()
    let cursor = try recordType.cursorRequest.fetchCursor(sourceDatabase)
    while let sourceRecord = try cursor.next() {
      if let destinationRecord = try sourceRecord.instanceRequest.fetchOne(destinationDatabase) {
        switch (sourceKnowledge.knowsAbout(destinationRecord), destinationKnowledge.knowsAbout(sourceRecord)) {
        case (true, true):
          if !sourceRecord.sameChange(as: destinationRecord) {
            Logger.shared.warning("Expected source to equal destination: \(sourceRecord) \(destinationRecord), treating like a conflict")
            try sourceRecord.resoveConflict(
              with: destinationRecord,
              sourceDatabase: sourceDatabase,
              destinationDatabase: destinationDatabase
            )
            result.conflicts += 1
          }
        case (true, false):
          try sourceRecord.copy(from: sourceDatabase, to: destinationDatabase)
          result.changes += 1
        case (false, true):
          // The destination has more up-to-date information; ignore this record.
          break
        case (false, false):
          // Conflict!
          try sourceRecord.resoveConflict(
            with: destinationRecord,
            sourceDatabase: sourceDatabase,
            destinationDatabase: destinationDatabase
          )
          result.conflicts += 1
        }
      } else {
        try sourceRecord.copy(from: sourceDatabase, to: destinationDatabase)
        result.changes += 1
      }
    }
    return result
  }
}
