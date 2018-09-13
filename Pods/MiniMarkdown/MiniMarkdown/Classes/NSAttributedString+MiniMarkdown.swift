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

public extension NSMutableAttributedString {

  public enum Error: Swift.Error {
    case syntaxError
  }

  /// Applies syntax highlighting attributes to the receiver.
  ///
  /// - parameter range: The range of the string to highlight.
  /// - parameter baseAttributes: Default attributes to apply to the string
  /// - parameter stylesheet: The stylesheet that determines what attributes to apply based upon
  ///             the syntax of the receiver.
  public func applySyntaxHighlighting(
    to range: Range<String.Index>,
    baseAttributes: Attributes,
    stylesheet: AttributedStringStylesheet,
    parsingRules: ParsingRules
  ) throws {
    let blocks = parsingRules.parse(ArraySlice(LineSequence(self.string)))
    for block in blocks
      where block.slice.range.overlaps(range) || block.slice.range.contains(range.lowerBound) {
        for attribute in NSAttributedString.Attributes.keys {
          self.removeAttribute(attribute, range: block.slice.nsRange)
        }
        applyAttributes(baseAttributes, to: block, stylesheet: stylesheet)
    }
  }

  private func applyAttributes(
    _ attributes: Attributes,
    to node: Node,
    stylesheet: AttributedStringStylesheet
  ) {
    var attributes = attributes
    stylesheet[node.type]?(node, &attributes)
    self.addAttributes(attributes.attributes, range: node.slice.nsRange)
    for childNode in node.children {
      applyAttributes(attributes, to: childNode, stylesheet: stylesheet)
    }
  }
}
