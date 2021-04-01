// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import os

/// A Packrat grammar is a collection of parsing rules, one of which is the designated `start` rule.
public protocol PackratGrammar {
  /// The designated starting rule for parsing the grammar. This rule should produce exactly one syntax tree `Node`.
  var start: ParsingRule { get }
}

private let log = OSLog(subsystem: "org.brians-brain.PackratParser", category: "PackratParser")

/// Implements a packrat parsing algorithm.
public final class MemoizationTable: CustomStringConvertible {
  /// Designated initializer.
  /// - Parameters:
  ///   - grammar: The grammar rules to apply to the contents of `buffer`
  // TODO: This should probably take a block that constructs a grammar rather than a grammar
  public init(grammar: PackratGrammar) {
    self.memoizedResults = []
    self.grammar = grammar
  }

  public let grammar: PackratGrammar

  private func reserveCapacity(_ capacity: Int) {
    assert(memoizedResults.count < capacity)
    memoizedResults = Array(repeating: MemoColumn(), count: capacity)
  }

  /// Parses the contents of the buffer.
  /// - Throws: If the grammar could not parse the entire contents, throws `Error.incompleteParsing`. If the grammar resulted in more than one resulting node, throws `Error.ambiguousParsing`.
  /// - Returns: The single node at the root of the syntax tree resulting from parsing `buffer`
  public func parseBuffer(_ buffer: SafeUnicodeBuffer) throws -> SyntaxTreeNode {
    if memoizedResults.count < buffer.count + 1 {
      reserveCapacity(buffer.count + 1)
    }
    os_signpost(.begin, log: log, name: "parseBuffer")
    let result = grammar.start.parsingResult(from: buffer, at: 0, memoizationTable: self)
    os_signpost(.end, log: log, name: "parseBuffer")
    guard let node = result.node, node.length == buffer.count else {
      throw ParsingError.incompleteParsing(length: result.node?.length ?? result.length)
    }
    #if DEBUG
    try! node.validateLength() // swiftlint:disable:this force_try
    #endif
    return node
  }

  public var description: String {
    let (totalEntries, successfulEntries) = memoizationStatistics()
    let properties: [String: Any] = [
      "totalEntries": totalEntries,
      "successfulEntries": successfulEntries,
      "memoizationChecks": memoizationChecks,
      "memoizationHits": memoizationHits,
      "memoizationHitRate": String(format: "%.2f%%", 100.0 * Double(memoizationHits) / Double(memoizationChecks)),
    ]
    return "PackratParser: \(properties)"
  }

  private var memoizationChecks = 0
  private var memoizationHits = 0

  /// Returns the memoized result of applying a rule at an index into the buffer, if it exists.
  public func memoizedResult(rule: ObjectIdentifier, index: Int) -> ParsingResult? {
    let result = memoizedResults[index][rule]
    memoizationChecks += 1
    if result != nil { memoizationHits += 1 }
    return result
  }

  /// Memoizes the result of applying a rule at an index in the buffer.
  /// - Parameters:
  ///   - result: The parsing result to memoize.
  ///   - rule: The rule that generated the result that we are memoizing.
  ///   - index: The position in the input at which we applied the rule to get the result.
  public func memoizeResult(_ result: ParsingResult, rule: ObjectIdentifier, index: Int) {
    assert(result.examinedLength > 0)
    assert(result.examinedLength >= result.length)
    #if DEBUG
    do {
      try result.node?.validateLength()
    } catch {
      fatalError()
    }
    #endif
    memoizedResults[index][rule] = result
  }

  /// Adjust the memo tables for reuse after an edit to the input text where the characters in `originalRange` were replaced
  /// with `replacementLength` characters.
  public func applyEdit(originalRange: NSRange, replacementLength: Int) {
    precondition(replacementLength >= 0)
    let lengthIncrease = replacementLength - originalRange.length
    if lengthIncrease < 0 {
      // We need to *shrink* the memo table.
      memoizedResults.removeSubrange(originalRange.location ..< originalRange.location + abs(lengthIncrease))
    } else if lengthIncrease > 0 {
      // We need to *grow* the memo table.
      memoizedResults.insert(
        contentsOf: [MemoColumn](repeating: MemoColumn(), count: lengthIncrease),
        at: originalRange.location
      )
    }
    // Now that we've adjusted the length of the memo table, everything in these columns is invalid.
    let invalidRange = NSRange(location: originalRange.location, length: replacementLength)
    for column in Range(invalidRange)! {
      memoizedResults[column].removeAll()
    }
    // Finally go through everything to the left of the removed range and invalidate memoization
    // results where it overlaps the edited range.
    var removedResults = [Int: [ParsingResult]]()
    for column in 0 ..< invalidRange.location {
      let invalidLength = invalidRange.location - column
      if memoizedResults[column].maxExaminedLength >= invalidLength {
        let victims = memoizedResults[column].remove {
          $0.examinedLength >= invalidLength
        }
        removedResults[column] = victims
      }
    }
  }

  // MARK: - Memoization internals

  private var memoizedResults: [MemoColumn]

  public func memoizationStatistics() -> (totalEntries: Int, successfulEntries: Int) {
    var totalEntries = 0
    var successfulEntries = 0
    for column in memoizedResults {
      for (_, result) in column {
        totalEntries += 1
        if result.succeeded { successfulEntries += 1 }
      }
    }
    return (totalEntries: totalEntries, successfulEntries: successfulEntries)
  }

  #if DEBUG
  func debugPrintInterestingContents() {
    for index in memoizedResults.indices {
      for (_, result) in memoizedResults[index] where result.succeeded && result.length > 0 {
        do {
          try result.node?.validateLength()
          print("Column \(index): \(result)")
        } catch {
          print("Column \(index): INVALID LENGTH \(result)")
        }
      }
    }
  }
  #endif
}

// MARK: - Memoization

private extension MemoizationTable {
  struct MemoColumn {
    private(set) var maxExaminedLength = 0
    private var storage = [ObjectIdentifier: ParsingResult]()

    subscript(id: ObjectIdentifier) -> ParsingResult? {
      get {
        storage[id]
      }
      set {
        guard let newValue = newValue else {
          assertionFailure()
          return
        }
        storage[id] = newValue
        maxExaminedLength = Swift.max(maxExaminedLength, newValue.examinedLength)
      }
    }

    mutating func removeAll() {
      storage.removeAll()
      maxExaminedLength = 0
    }

    /// Removes results that match a predicate.
    @discardableResult
    mutating func remove(where predicate: (ParsingResult) -> Bool) -> [ParsingResult] {
      var maxExaminedLength = 0
      var removedResults = [ParsingResult]()
      let keysAndValues = storage.compactMap { key, value -> (key: ObjectIdentifier, value: ParsingResult)? in
        guard !predicate(value) else {
          removedResults.append(value)
          return nil
        }
        maxExaminedLength = Swift.max(maxExaminedLength, value.examinedLength)
        return (key: key, value: value)
      }
      storage = Dictionary(uniqueKeysWithValues: keysAndValues)
      self.maxExaminedLength = maxExaminedLength
      return removedResults
    }
  }
}

extension MemoizationTable.MemoColumn: Collection {
  typealias Index = Dictionary<ObjectIdentifier, ParsingResult>.Index
  var startIndex: Index { storage.startIndex }
  var endIndex: Index { storage.endIndex }
  func index(after i: Index) -> Index {
    return storage.index(after: i)
  }

  subscript(position: Index) -> (key: ObjectIdentifier, value: ParsingResult) {
    storage[position]
  }
}
