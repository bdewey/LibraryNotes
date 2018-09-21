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

extension NodeType {
  public static let table = NodeType(rawValue: "table")
  public static let tableHeader = NodeType(rawValue: "table-header")
  public static let tableDelimiter = NodeType(rawValue: "table-delimiter")
  public static let tableRow = NodeType(rawValue: "table-row")
  public static let tableCell = NodeType(rawValue: "table-cell")
}

/// A table: https://github.github.com/gfm/#tables-extension-
public final class Table: Node, LineParseable {
  public let columnCount: Int
  public override var parsingRules: ParsingRules! {
    didSet {
      for child in children { child.parsingRules = parsingRules }
    }
  }

  public let header: TableRow
  public let delimiter: TableDelimiter
  public let rows: [TableRow]

  public override var children: [Node] {
    var results: [Node] = [header, delimiter]
    results.append(contentsOf: rows)
    return results
  }

  public init?(header: TableRow, delimiter: TableDelimiter, rows: [TableRow]) {
    guard header.children.count == delimiter.children.count else { return nil }
    self.header = header
    self.delimiter = delimiter
    self.rows = rows
    columnCount = delimiter.children.count
    let partialSlice = header.slice + delimiter.slice
    let completeSlice = rows.reduce(into: partialSlice, { $0 += $1.slice })
    super.init(type: .table, slice: completeSlice)
  }

  public static let parser = (curry(Table.init)
    <^> TableRow.parser(type: .tableHeader)
    <*> TableDelimiter.parser
    <*> TableRow.parser(type: .tableRow).many).unwrapped
}

public final class TableCell: InlineContainingNode {
  public init(slice: StringSlice) {
    super.init(type: .tableCell, slice: slice)
  }

  // "Spaces between pipes and cell content are trimmed."
  public override var contents: Substring {
    return slice.substring.strippingLeadingAndTrailingWhitespace
  }
}

public final class TableRow: Node {
  public override var parsingRules: ParsingRules! {
    didSet {
      for child in children { child.parsingRules = parsingRules }
    }
  }
  public let cells: [TableCell]

  public override var children: [Node] {
    return cells
  }

  public override init(type: NodeType, slice: StringSlice) {
    self.cells = slice.tableCells.map({ MiniMarkdown.TableCell(slice: $0) })
    super.init(type: type, slice: slice)
  }

  public static func parser(type: NodeType) -> Parser<TableRow, ArraySlice<StringSlice>> {
    assert(type == .tableHeader || type == .tableRow)
    return curry(TableRow.init)(type)
      <^> LineParsers.line(where: { !$0.substring.isWhitespace })
  }
}

public final class TableDelimiter: Node, LineParseable {
  public override var parsingRules: ParsingRules! {
    didSet {
      for child in children { child.parsingRules = parsingRules }
    }
  }

  public let cells: [TableCell]
  public override var children: [Node] { return cells }

  public init(slice: StringSlice) {
    self.cells = slice.tableCells.map({ MiniMarkdown.TableCell(slice: $0) })
    super.init(type: .tableDelimiter, slice: slice)
  }

  public static let parser = TableDelimiter.init <^>
    LineParsers.line(where: { (slice) in
      slice.tableCells.allSatisfy({ $0.substring.isTableDelimiterCell })
    })
}
