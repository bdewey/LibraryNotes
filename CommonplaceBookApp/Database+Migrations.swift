// Copyright © 2020 Brian's Brain. All rights reserved.

import Foundation
import GRDB

extension Database {
  func rewriteTable(named tableName: String, columns: String, tableBuilder: (String) throws -> Void) throws {
    let temporaryTableName = "temporaryMigration\(Int.random(in: 0 ..< Int.max))"
    try tableBuilder(temporaryTableName)
    try execute(sql: "INSERT INTO \(temporaryTableName) SELECT \(columns) FROM \(tableName)")
    try drop(table: tableName)
    try rename(table: temporaryTableName, to: tableName)
  }

  func updateRows(
    selectSql: String,
    updateStatement: UpdateStatement,
    argumentBlock: (Row) throws -> StatementArguments
  ) throws {
    let rows = try Row.fetchAll(self, sql: selectSql)
    for row in rows {
      let arguments = try argumentBlock(row)
      try updateStatement.execute(arguments: arguments)
    }
  }
}
