// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation

extension SyntaxTreeNodeType {
  static let documentFragment: SyntaxTreeNodeType = "{{fragment}}"
}

/// A key for associating values of a specific type with a node.
public protocol SyntaxTreeNodePropertyKey {
  associatedtype Value

  /// The string key used to identify the value in the property bag.
  static var key: String { get }

  /// Type-safe accessor for getting the value from the property bag.
  static func getProperty(from bag: [String: Any]?) -> Value?

  /// Type-safe setter for the value in the property bag.
  static func setProperty(_ value: Value, in bag: inout [String: Any]?)
}

/// Default implementation of getter / setter.
public extension SyntaxTreeNodePropertyKey {
  static func getProperty(from bag: [String: Any]?) -> Value? {
    guard let bag = bag else { return nil }
    if let value = bag[key] {
      return (value as! Value) // swiftlint:disable:this force_cast
    } else {
      return nil
    }
  }

  static func setProperty(_ value: Value, in bag: inout [String: Any]?) {
    if bag == nil {
      bag = [key: value]
    } else {
      bag?[key] = value
    }
  }
}

public protocol SyntaxTreeNodeChildren: Sequence {
  mutating func removeFirst()
  mutating func removeLast()
  mutating func append(_ node: SyntaxTreeNode)
  mutating func merge(with newElements: Self)
  var count: Int { get }
  var isEmpty: Bool { get }
  var first: SyntaxTreeNode? { get }
  var last: SyntaxTreeNode? { get }
}

/// Holds a SyntaxTreeNode in a doubly-linked list.
private final class DoublyLinkedNode {
  internal init(value: SyntaxTreeNode, next: DoublyLinkedNode? = nil, previous: DoublyLinkedNode? = nil) {
    self.value = value
    self.next = next
    self.previous = previous
  }

  let value: SyntaxTreeNode
  var next: DoublyLinkedNode?
  var previous: DoublyLinkedNode?
}

/// A specific DoublyLinkedList of SyntaxTreeNode values.
public final class DoublyLinkedList: SyntaxTreeNodeChildren {
  public var count: Int = 0

  // swiftlint:disable:next empty_count
  public var isEmpty: Bool { count == 0 }

  private var head: DoublyLinkedNode?
  private var tail: DoublyLinkedNode?

  public func removeFirst() {
    count -= 1
    if head === tail {
      // swiftlint:disable:next empty_count
      assert(count == 0)
      head = nil
      tail = nil
    } else {
      let next = head?.next
      next?.previous = nil
      head = next
    }
    assert(map { _ in 1 }.reduce(0, +) == count)
  }

  public func removeLast() {
    count -= 1
    if head === tail {
      // swiftlint:disable:next empty_count
      assert(count == 0)
      head = nil
      tail = nil
    } else {
      let previous = tail?.previous
      previous?.next = nil
      tail = previous
    }
    assert(map { _ in 1 }.reduce(0, +) == count)
  }

  public func append(_ node: SyntaxTreeNode) {
    count += 1
    if tail == nil {
      tail = DoublyLinkedNode(value: node, next: nil, previous: nil)
      head = tail
    } else {
      let newNode = DoublyLinkedNode(value: node, next: nil, previous: tail)
      tail?.next = newNode
      tail = newNode
    }
    assert(map { _ in 1 }.reduce(0, +) == count)
  }

  public func append<S: Sequence>(contentsOf sequence: S) where S.Element == SyntaxTreeNode {
    for otherElement in sequence {
      append(otherElement)
    }
  }

  /// Combine two DoublyLinkedLists in O(1) time.
  /// - note: This is destructive. Both the receiver and `newElements` will be the same merged list at the end.
  public func merge(with newElements: DoublyLinkedList) {
    // swiftlint:disable empty_count
    if tail == nil {
      assert(count == 0 && head == nil)
      head = newElements.head
      tail = newElements.tail
      count = newElements.count
    } else if newElements.head == nil {
      assert(newElements.count == 0)
      // DO NOTHING
    } else {
      count += newElements.count
      tail?.next = newElements.head
      newElements.head?.previous = tail
      tail = newElements.tail
    }
    assert(map { _ in 1 }.reduce(0, +) == count)
  }

  public var first: SyntaxTreeNode? { head?.value }
  public var last: SyntaxTreeNode? { tail?.value }
}

extension DoublyLinkedList: Sequence {
  public struct Iterator: IteratorProtocol {
    fileprivate var node: DoublyLinkedNode?

    public mutating func next() -> SyntaxTreeNode? {
      let item = node?.value
      node = node?.next
      return item
    }
  }

  public func makeIterator() -> Iterator {
    return Iterator(node: head)
  }
}

/// A node in the markup language's syntax tree.
public final class SyntaxTreeNode: CustomStringConvertible {
  public init(type: SyntaxTreeNodeType, length: Int = 0) {
    self.type = type
    self.length = length
  }

  public static func makeFragment() -> SyntaxTreeNode {
    return SyntaxTreeNode(type: .documentFragment, length: 0)
  }

  /// The type of this node.
  public var type: SyntaxTreeNodeType

  /// If true, this node should be considered a "fragment" (an ordered list of nodes without a root)
  public var isFragment: Bool {
    return type === SyntaxTreeNodeType.documentFragment
  }

  /// The length of the original text covered by this node (and all children).
  /// We only store the length so nodes can be efficiently reused while editing text, but it does mean you need to
  /// build up context (start position) by walking the parse tree.
  public var length: Int {
    willSet {
      assert(!frozen)
    }
  }

  #if DEBUG
    @discardableResult
    public func validateLength() throws -> Int {
      // If we are a leaf, we are valid.
      if children.isEmpty { return length }

      // Otherwise, first make sure each child has a valid length.
      let childValidatedLength = try children.map { try $0.validateLength() }.reduce(0, +)
      if childValidatedLength != length {
        throw MachError(.invalidValue)
      }
      assert(childValidatedLength == length)
      return length
    }
  #endif

  /// We do a couple of tree-construction optimizations that mutate existing nodes that don't "belong" to us
  private var disconnectedFromResult = false

  /// Children of this node.
  public var children = DoublyLinkedList() {
    willSet {
      assert(!frozen)
    }
  }

  public var treeSize: Int {
    1 + children.map { $0.treeSize }.reduce(0, +)
  }

  /// Set to true when we expect no more changes to this node.
  public private(set) var frozen = false

  public func freeze() {
    frozen = true
  }

  public func appendChild(_ child: SyntaxTreeNode) {
    assert(!frozen)
    length += child.length
    if child.isFragment {
      #if DEBUG
        try! child.validateLength() // swiftlint:disable:this force_try
      #endif

      let fragmentNodes = child.children
      var mergedChildNodes = false
      if let last = children.last, let first = fragmentNodes.first, last.children.isEmpty, first.children.isEmpty, last.type == first.type {
        // The last of our children & the first of the fragment's children have the same type. Rather than creating two nodes
        // of the same type, just change the length of our node.
        // TODO: Perhaps this can be done in a cleaner way inside of DoublyLinkedList.append(contentsOf:)?
        incrementLastChildNodeLength(by: first.length)
        mergedChildNodes = true
      }
      children.append(contentsOf: fragmentNodes.dropFirst(mergedChildNodes ? 1 : 0))

      #if DEBUG
        try! validateLength() // swiftlint:disable:this force_try
      #endif

    } else {
      // Special optimization: Adding a terminal node of the same type of the last terminal node
      // can just be a range update.
      if let lastNode = children.last, lastNode.children.isEmpty, child.children.isEmpty, lastNode.type == child.type {
        incrementLastChildNodeLength(by: child.length)
      } else {
        children.append(child)
      }
    }
  }

  private func incrementLastChildNodeLength(by length: Int) {
    guard let last = children.last else { return }
    assert(!frozen)
    precondition(last.children.isEmpty)
    if last.disconnectedFromResult {
      last.length += length
    } else {
      let copy = SyntaxTreeNode(type: last.type, length: last.length + length)
      copy.disconnectedFromResult = true
      children.removeLast()
      children.append(copy)
    }
  }

  /// True if this node corresponds to no text in the input buffer.
  public var isEmpty: Bool {
    return length == 0
  }

  public var description: String {
    "Node: \(length) \(compactStructure)"
  }

  /// Walks down the tree of nodes to find a specific node.
  public func node(at indexPath: IndexPath) -> SyntaxTreeNode? {
    if indexPath.isEmpty { return self }
    let nextChild = children.dropFirst(indexPath[0]).first(where: { _ in true })
    assert(nextChild != nil)
    return nextChild?.node(at: indexPath.dropFirst())
  }

  /// Enumerates all nodes in the tree in depth-first order.
  /// - parameter startIndex: The index at which this node starts. (An AnchoredNode knows this, but a NewNode does not and needs to be told.)
  /// - parameter block: The first parameter is the node, the second parameter is the start index of the node, and set the third parameter to `false` to stop enumeration.
  public func forEach(startIndex: Int = 0, block: (SyntaxTreeNode, Int, inout Bool) -> Void) {
    var stop: Bool = false
    forEach(stop: &stop, startIndex: startIndex, block: block)
  }

  private func forEach(stop: inout Bool, startIndex: Int, block: (SyntaxTreeNode, Int, inout Bool) -> Void) {
    guard !stop else { return }
    block(self, startIndex, &stop)
    var startIndex = startIndex
    for child in children where !stop {
      child.forEach(stop: &stop, startIndex: startIndex, block: block)
      startIndex += child.length
    }
  }

  public func findNodes(where predicate: (SyntaxTreeNode) -> Bool) -> [SyntaxTreeNode] {
    var results = [SyntaxTreeNode]()
    forEach { node, _, _ in
      if predicate(node) { results.append(node) }
    }
    return results
  }

  public func forEachPath(startIndex: Int = 0, block: ([SyntaxTreeNode], Int, inout Bool) -> Void) {
    var stop: Bool = false
    forEachPath(stop: &stop, incomingPath: [], startIndex: startIndex, block: block)
  }

  private func forEachPath(stop: inout Bool, incomingPath: [SyntaxTreeNode], startIndex: Int, block: ([SyntaxTreeNode], Int, inout Bool) -> Void) {
    guard !stop else { return }
    var currentPath = incomingPath
    currentPath.append(self)
    block(currentPath, startIndex, &stop)
    var startIndex = startIndex
    for child in children where !stop {
      child.forEachPath(stop: &stop, incomingPath: currentPath, startIndex: startIndex, block: block)
      startIndex += child.length
    }
  }

  /// Returns the first (depth-first) node where `predicate` returns true.
  public func first(where predicate: (SyntaxTreeNode) -> Bool) -> SyntaxTreeNode? {
    var result: SyntaxTreeNode?
    forEach { node, _, stop in
      if predicate(node) {
        result = node
        stop = true
      }
    }
    return result
  }

  public enum NodeSearchError: Error {
    case indexOutOfRange
  }

  /// Walks down the tree and returns the leaf node that contains a specific index.
  /// - returns: The leaf node containing the index.
  /// - throws: NodeSearchError.indexOutOfRange if the index is not valid.
  public func leafNode(containing index: Int) throws -> AnchoredNode {
    return try leafNode(containing: index, startIndex: 0)
  }

  private func leafNode(
    containing index: Int,
    startIndex: Int
  ) throws -> AnchoredNode {
    guard index < startIndex + length else {
      throw NodeSearchError.indexOutOfRange
    }
    if children.isEmpty { return AnchoredNode(node: self, startIndex: startIndex) }
    var childIndex = startIndex
    for child in children {
      if index < childIndex + child.length {
        return try child.leafNode(containing: index, startIndex: childIndex)
      }
      childIndex += child.length
    }
    throw NodeSearchError.indexOutOfRange
  }

  /// Returns the path through the syntax tree to the leaf node that contains `index`.
  /// - returns: An array of nodes where the first element is the root, and each subsequent node descends one level to the leaf.
  public func path(to index: Int) -> [AnchoredNode] {
    var results = [AnchoredNode]()
    path(to: index, startIndex: 0, results: &results)
    return results
  }

  private func path(to index: Int, startIndex: Int, results: inout [AnchoredNode]) {
    results.append(AnchoredNode(node: self, startIndex: startIndex))
    if children.isEmpty { return }
    var childIndex = startIndex
    for child in children {
      if index < childIndex + child.length {
        child.path(to: index, startIndex: childIndex, results: &results)
        return
      }
      childIndex += child.length
    }
  }

  // MARK: - Properties

  /// Lazily-allocated property bag.
  private var propertyBag: [String: Any]?

  /// Type-safe property accessor.
  public subscript<K: SyntaxTreeNodePropertyKey>(key: K.Type) -> K.Value? {
    get {
      return key.getProperty(from: propertyBag)
    }
    set {
      if let value = newValue {
        key.setProperty(value, in: &propertyBag)
      } else {
        propertyBag?.removeValue(forKey: key.key)
      }
    }
  }
}

/// An "Anchored" node simply contains a node and its starting position in the text. (Start location isn't part of Node because we
/// reuse nodes across edits.)
/// This is a class and not a struct because structs-that-contain-reference-types can't easily provide value semantics.
public final class AnchoredNode {
  public let node: SyntaxTreeNode
  public let startIndex: Int

  public init(node: SyntaxTreeNode, startIndex: Int) {
    self.node = node
    self.startIndex = startIndex
  }

  /// Convenience mechanism for getting the range covered by this node.
  public var range: NSRange { NSRange(location: startIndex, length: node.length) }

  public var children: [AnchoredNode] {
    var children: [AnchoredNode] = []
    var index = startIndex
    for child in node.children {
      children.append(AnchoredNode(node: child, startIndex: index))
      index += child.length
    }
    return children
  }

  /// Enumerates all of the nodes, depth-first.
  /// - parameter block: Receives the node, the start index of the node. Set the Bool to `false` to stop enumeration.
  public func forEach(_ block: (SyntaxTreeNode, Int, inout Bool) -> Void) {
    node.forEach(startIndex: startIndex, block: block)
  }

  public func forEachPath(_ block: ([AnchoredNode], inout Bool) -> Void) {
    var stop = false
    forEachPath(stop: &stop, path: [], block: block)
  }

  private func forEachPath(stop: inout Bool, path: [AnchoredNode], block: ([AnchoredNode], inout Bool) -> Void) {
    guard !stop else { return }
    var path = path
    path.append(self)
    block(path, &stop)
    var childIndex = startIndex
    for child in node.children where !stop {
      let anchoredChild = AnchoredNode(node: child, startIndex: childIndex)
      anchoredChild.forEachPath(stop: &stop, path: path, block: block)
      childIndex += child.length
    }
  }

  /// Returns the first AnchoredNode that matches a predicate.
  public func first(where predicate: (SyntaxTreeNode) -> Bool) -> AnchoredNode? {
    var result: AnchoredNode?
    node.forEach(startIndex: startIndex) { candidate, index, stop in
      if predicate(candidate) {
        result = AnchoredNode(node: candidate, startIndex: index)
        stop = true
      }
    }
    return result
  }

  public func findNodes(where predicate: (SyntaxTreeNode) -> Bool) -> [AnchoredNode] {
    var results = [AnchoredNode]()
    node.forEach(startIndex: startIndex) { child, startIndex, _ in
      if predicate(child) {
        results.append(AnchoredNode(node: child, startIndex: startIndex))
      }
    }
    return results
  }
}

// MARK: - Debugging support

extension SyntaxTreeNode {
  /// Returns the structure of this node as a compact s-expression.
  /// For example, `(document ((header text) blank_line paragraph blank_line paragraph)`
  public var compactStructure: String {
    var results = ""
    writeCompactStructure(to: &results)
    return results
  }

  /// Recursive helper for generating `compactStructure`
  private func writeCompactStructure(to buffer: inout String) {
    if children.isEmpty {
      buffer.append(type.rawValue)
    } else {
      buffer.append("(")
      buffer.append(type.rawValue)
      buffer.append(" ")
      for (index, child) in children.enumerated() {
        if index > 0 {
          buffer.append(" ")
        }
        child.writeCompactStructure(to: &buffer)
      }
      buffer.append(")")
    }
  }

  /// Returns the syntax tree and which parts of `textBuffer` the leaf nodes correspond to.
  public func debugDescription(withContentsFrom pieceTable: SafeUnicodeBuffer) -> String {
    var lines = ""
    writeDebugDescription(to: &lines, pieceTable: pieceTable, location: 0, indentLevel: 0)
    return lines
  }

  /// Recursive helper function for `debugDescription(of:)`
  private func writeDebugDescription<Target: TextOutputStream>(
    to lines: inout Target,
    pieceTable: SafeUnicodeBuffer,
    location: Int,
    indentLevel: Int
  ) {
    var result = String(repeating: " ", count: 2 * indentLevel)
    result.append("{\(location), \(length)}")
    result.append(type.rawValue)
    result.append(": ")
    if children.isEmpty {
      let chars = pieceTable[NSRange(location: location, length: length)]
      let str = String(utf16CodeUnits: chars, count: chars.count)
      result.append(str.debugDescription)
    }
    lines.write(result)
    lines.write("\n")
    var childLocation = location
    for child in children {
      child.writeDebugDescription(to: &lines, pieceTable: pieceTable, location: childLocation, indentLevel: indentLevel + 1)
      childLocation += child.length
    }
  }
}
