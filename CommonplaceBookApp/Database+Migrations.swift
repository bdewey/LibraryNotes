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
