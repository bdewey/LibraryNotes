// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import Logging

public final class AttributesCache {
  private var cache = [AttributedStringAttributesDescriptor: AttributedStringAttributes]()

  public func getAttributes(
    for descriptor: AttributedStringAttributesDescriptor
  ) -> AttributedStringAttributes {
    if let cachedAttributes = cache[descriptor] {
      return cachedAttributes
    }
    let attributes = descriptor.makeAttributes()
    cache[descriptor] = attributes
    return attributes
  }
}

/// A run-length encoded array of NSAttributedString attributes.
public struct AttributesArray {
  private var runs: [Run]
  public private(set) var count: Int
  private let attributesCache: AttributesCache

  public init(attributesCache: AttributesCache) {
    runs = []
    count = 0
    self.attributesCache = attributesCache
  }

  public enum Error: Swift.Error {
    /// When comparing attribute arrays, the arrays have different lengths.
    case arraysHaveDifferentLength
  }

  public mutating func appendAttributes(_ attributes: AttributedStringAttributesDescriptor, length: Int) {
    count += length
    if let last = runs.last, last.descriptor == attributes {
      runs[runs.count - 1].adjustLength(by: length)
    } else {
      runs.append(Run(descriptor: attributes, length: length))
    }
    assert(runs.map({ $0.length }).reduce(0, +) == count)
  }

  public mutating func adjustLengthOfRun(at location: Int, by amount: Int, defaultAttributes: AttributedStringAttributesDescriptor) {
    count += amount
    let index = self.index(startIndex, offsetBy: location)
    if index == endIndex {
      assert(amount >= 0)
      runs.append(Run(descriptor: defaultAttributes, length: amount))
    } else {
      runs[index.runIndex].adjustLength(by: amount)
    }
    if runs[index.runIndex].length == 0 {
      runs.remove(at: index.runIndex)
    }
    assert(runs.map({ $0.length }).reduce(0, +) == count)
  }

  public func attributes(at location: Int, effectiveRange: NSRangePointer?) -> AttributedStringAttributes {
    let index = self.index(startIndex, offsetBy: location)
    effectiveRange?.pointee = NSRange(location: location - index.offsetInRun, length: runs[index.runIndex].length)
    return attributesCache.getAttributes(for: runs[index.runIndex].descriptor)
  }

  public func rangeOfAttributeDifferences(from otherAttributes: AttributesArray) throws -> NSRange? {
    if count != otherAttributes.count {
      throw Error.arraysHaveDifferentLength
    }
    var firstDifferingIndex = 0
    for (lhs, rhs) in zip(runs, otherAttributes.runs) {
      if lhs.descriptor != rhs.descriptor {
        break
      }
      firstDifferingIndex += Swift.min(lhs.length, rhs.length)
      if lhs.length != rhs.length {
        break
      }
    }
    if firstDifferingIndex == count {
      return nil
    }
    var lastDifferingIndex = count
    for (lhs, rhs) in zip(runs.reversed(), otherAttributes.runs.reversed()) {
      if lhs.descriptor != rhs.descriptor {
        break
      }
      lastDifferingIndex -= Swift.min(lhs.length, rhs.length)
      if lhs.length != rhs.length {
        break
      }
    }
    assert(lastDifferingIndex >= firstDifferingIndex)
    if lastDifferingIndex > firstDifferingIndex {
      return NSRange(location: firstDifferingIndex, length: lastDifferingIndex - firstDifferingIndex)
    } else {
      return nil
    }
  }

  private func runIfChanging(at index: Index) -> Run? {
    index.offsetInRun > 0 ? runs[index.runIndex] : nil
  }

  private func runRange<R: RangeExpression>(for indexRange: R) -> Range<Int> where R.Bound == Index {
    let bounds = indexRange.relative(to: self)
    if bounds.upperBound.offsetInRun > 0 {
      return bounds.lowerBound.runIndex ..< bounds.upperBound.runIndex + 1
    } else {
      return bounds.lowerBound.runIndex ..< bounds.upperBound.runIndex
    }
  }
}

// MARK: - Collection

extension AttributesArray: Collection {
  public struct Index: Comparable {
    fileprivate var runIndex: Int
    fileprivate var offsetInRun: Int

    public static func < (lhs: AttributesArray.Index, rhs: AttributesArray.Index) -> Bool {
      return (lhs.runIndex, lhs.offsetInRun) < (rhs.runIndex, rhs.offsetInRun)
    }
  }

  public var startIndex: Index { Index(runIndex: 0, offsetInRun: 0) }
  public var endIndex: Index { Index(runIndex: runs.endIndex, offsetInRun: 0) }

  public func index(after i: Index) -> Index {
    if i.offsetInRun + 1 == runs[i.runIndex].length {
      return Index(runIndex: i.runIndex + 1, offsetInRun: 0)
    } else {
      return Index(runIndex: i.runIndex, offsetInRun: i.offsetInRun + 1)
    }
  }

  public func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
    var distance = distance
    var offsetInRun = i.offsetInRun
    for runIndex in i.runIndex ..< runs.endIndex {
      let run = runs[runIndex]
      let charactersInRun = runIndex == limit.runIndex
        ? limit.offsetInRun - offsetInRun
        : run.length - offsetInRun
      if distance < charactersInRun {
        return Index(runIndex: runIndex, offsetInRun: offsetInRun + distance)
      }
      offsetInRun = 0
      distance -= charactersInRun
    }
    if distance == 0 {
      return limit
    } else {
      return nil
    }
  }

  public func index(_ i: Index, offsetBy distance: Int) -> Index {
    return index(i, offsetBy: distance, limitedBy: endIndex)!
  }

  public func distance(from start: Index, to end: Index) -> Int {
    var distance = 0
    for runIndex in start.runIndex ... end.runIndex where runIndex < runs.endIndex {
      let run = runs[runIndex]
      let lowerBound = (runIndex == start.runIndex) ? start.offsetInRun : 0
      let upperBound = (runIndex == end.runIndex) ? end.offsetInRun : run.length
      distance += (upperBound - lowerBound)
    }
    return distance
  }

  public subscript(position: Index) -> AttributedStringAttributes {
    return attributesCache.getAttributes(for: runs[position.runIndex].descriptor)
  }
}

// MARK: - Private

private var hackCache = [AttributedStringAttributesDescriptor: AttributedStringAttributes]()

private extension AttributesArray {
  struct Run {
    internal init(descriptor: AttributedStringAttributesDescriptor, length: Int) {
      self.descriptor = descriptor
      self.length = length
    }

    var descriptor: AttributedStringAttributesDescriptor
    var length: Int

    func adjustingLength(by amount: Int) -> Self {
      var copy = self
      copy.length += amount
      return copy
    }

    mutating func adjustLength(by amount: Int) {
      length += amount
    }

    func nilIfZeroLength() -> Self? {
      if length == 0 { return nil }
      return self
    }
  }
}
