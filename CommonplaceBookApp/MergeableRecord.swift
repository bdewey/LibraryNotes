// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import GRDB

/// This is a database record that can be merged between two separate copies of a database using version vectors to determine
/// what records need to be copied and what records conflict.
public protocol MergeInfoRecord: FetchableRecord {
  /// A request for all relevant MergeInfoRecords in a database.
  static var cursorRequest: QueryInterfaceRequest<Self> { get }

  /// Requests a *specific* instance of a MergeInfoRecord from a database that corresponds to the receiver.
  var instanceRequest: QueryInterfaceRequest<Self> { get }

  /// The timestamp when this record was modified.
  var timestamp: Date { get }

  /// The device UUID that this record was modified on.
  var deviceUUID: String { get }

  /// The update sequence number for latest modification of this record. USNs are monitonically increasing on the device.
  var updateSequenceNumber: Int64 { get }

  /// Copy the underlying data from one database to another.
  func copy(from sourceDatabase: Database, to destinationDatabase: Database) throws

  /// There is a conflict between this record and another. Resolve it and write the resolution into the destination database.
  func resoveConflict(
    with otherRecord: Self,
    sourceDatabase: Database,
    destinationDatabase: Database
  ) throws

  /// True if this record encodes the same change (timestamp & device) as another record.
  func sameChange(as otherRecord: Self) -> Bool
}

/// Describes the outcome of a merge operation.
public struct MergeResult: Equatable, CustomStringConvertible {
  /// How many items changed in the merge?
  public var changes = 0

  /// How many conflicts were resolved in the merge?
  public var conflicts = 0

  public static func + (lhs: MergeResult, rhs: MergeResult) -> MergeResult {
    MergeResult(changes: lhs.changes + rhs.changes, conflicts: lhs.conflicts + rhs.conflicts)
  }

  public static func += (lhs: inout MergeResult, rhs: MergeResult) {
    lhs.changes += rhs.changes
    lhs.conflicts += rhs.conflicts
  }

  public var description: String {
    return "Changes = \(changes) Conflicts = \(conflicts)"
  }

  /// True if the merge resulted in absolutely no updates.
  public var isEmpty: Bool {
    return changes == 0 && conflicts == 0
  }
}

public extension MergeInfoRecord {
  func sameChange(as otherRecord: Self) -> Bool {
    return updateSequenceNumber == otherRecord.updateSequenceNumber && deviceUUID == otherRecord.deviceUUID
  }

  /// Implements "last writer wins"
  func resoveConflict(
    with otherRecord: Self,
    sourceDatabase: Database,
    destinationDatabase: Database
  ) throws {
    if timestamp > otherRecord.timestamp {
      try copy(from: sourceDatabase, to: destinationDatabase)
    }
  }
}

private extension Database {
  /// True if this instance of the database "knows" about a specific change.
  func knowsAbout<R: MergeInfoRecord>(_ mergeInfoRecord: R) -> Bool {
    guard let device = try? Sqlite.Device.fetchOne(self, key: ["uuid": mergeInfoRecord.deviceUUID]) else {
      return false
    }
    return device.updateSequenceNumber >= mergeInfoRecord.updateSequenceNumber
  }
}
