// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

extension Sequence {
  /// Returns an dictionary containing the results of mapping the given closure over the sequence’s elements.
  ///
  /// - parameter mapping: A closure that maps an `Element` into a (`Key`, `Value`) pair.
  /// - parameter uniqingKeysWith: If `mapping` returns two items with the same key, this closure determines which one to keep in the dictionary.
  /// - returns: A dictionary mapping keys to values.
  func dictionaryMap<Key: Hashable, Value: Any>(
    mapping: (Element) throws -> (key: Key, value: Value),
    uniquingKeysWith: (Value, Value) -> Value = { _, value in value }
  ) rethrows -> [Key: Value] {
    let tuples = try map(mapping)
    return Dictionary(tuples, uniquingKeysWith: uniquingKeysWith)
  }

  /// Returns an dictionary containing the results of mapping the given closure over the sequence’s elements.
  ///
  /// - parameter mapping: A closure that maps an `Element` into a (`Key`, `Value`) pair.
  /// - parameter uniqingKeysWith: If `mapping` returns two items with the same key, this closure determines which one to keep in the dictionary.
  /// - returns: A dictionary mapping keys to values.
  func dictionaryCompactMap<Key: Hashable, Value: Any>(
    mapping: (Element) throws -> (key: Key, value: Value)?,
    uniquingKeysWith: (Value, Value) -> Value = { _, value in value }
  ) rethrows -> [Key: Value] {
    let tuples = try compactMap(mapping)
    return Dictionary(tuples, uniquingKeysWith: uniquingKeysWith)
  }
}
