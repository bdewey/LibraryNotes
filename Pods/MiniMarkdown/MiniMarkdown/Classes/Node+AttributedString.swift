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

/// Defines the location of this node in a Markdown document.
public struct LocationPair {

  /// The location of this node in the Markdown string.
  public var markdown: Int

  /// The location of the attributed text in the rendered version of the string.
  // TODO: This should be a property of the rendering, if we support multiple renderings
  //       for the same forest.
  public var rendered: Int
}

extension Node.Key {
  internal static let initialLocationPair = Node.Key(rawValue: "initialLocationPair")
  internal static let renderedResult = Node.Key(rawValue: "renderedResult")
}

extension Node {
  public var attributedString: NSAttributedString {
    get {
      return getProperty(key: .renderedResult, default: { NSAttributedString() })
    }
    set {
      properties[Key.renderedResult] = newValue
    }
  }

  public var initialLocationPair: LocationPair {
    get {
      return getProperty(
        key: .initialLocationPair,
        default: { LocationPair(markdown: 0, rendered: 0) }
      )
    }
    set {
      properties[.initialLocationPair] = newValue
    }
  }

  internal func updateInitialLocationPair(_ locationPair: LocationPair) -> LocationPair {
    var locationPair = locationPair
    initialLocationPair = locationPair
    locationPair.markdown += markdown.count
    locationPair.rendered += attributedString.length
    for child in children {
      locationPair = child.updateInitialLocationPair(locationPair)
    }
    return locationPair
  }
}
