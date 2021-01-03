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

/// Contains just the year/month/day for a date.
public struct DayComponents: Equatable, Comparable, Hashable {
  public let year: Int
  public let month: Int
  public let day: Int

  /// Initialize from a date.
  ///
  /// Note: This does the component extraction from the current calendar.
  public init(_ date: Date) {
    let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
    year = components.year!
    self.month = components.month!
    self.day = components.day!
  }

  /// Gets the Date equivalent of the components in the current calendar.
  public var date: Date {
    return Calendar.current.date(from: dateComponents)!
  }

  public static func < (lhs: DayComponents, rhs: DayComponents) -> Bool {
    return lhs.year < rhs.year || lhs.month < rhs.month || lhs.day < rhs.day
  }

  /// Returns the number of days between two components.
  public static func - (lhs: DayComponents, rhs: DayComponents) -> Int {
    let dayComponents = Calendar.current.dateComponents([.day], from: rhs.date, to: lhs.date)
    return dayComponents.day!
  }

  private var dateComponents: DateComponents {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return components
  }

  public static func + (lhs: DayComponents, rhs: Int) -> DayComponents {
    var components = DateComponents()
    components.day = rhs
    let date = Calendar.current.date(byAdding: components, to: lhs.date)!
    return DayComponents(date)
  }
}

extension DayComponents: LosslessStringConvertible {
  public init?(_ description: String) {
    let components = description.split(separator: "-")
    if components.count != 3 {
      return nil
    }
    guard let year = Int(components[0]),
          let month = Int(components[1]),
          let day = Int(components[2])
    else { return nil }
    self.year = year
    self.month = month
    self.day = day
  }

  public var description: String {
    return [
      String(year),
      String(format: "%02d", month),
      String(format: "%02d", day),
    ].joined(separator: "-")
  }
}

// When encoding DayComponents, just encode / decode its string representation.
extension DayComponents: Codable {
  public enum Error: Swift.Error {
    case cannotParseField(String)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(description)
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let description = try container.decode(String.self)
    guard let value = DayComponents(description) else { throw Error.cannotParseField(description) }
    self = value
  }
}

// We don't need to see separate year-month-day in the debugger; the string is enough.
extension DayComponents: CustomReflectable {
  public var customMirror: Mirror {
    return Mirror(DayComponents.self, children: ["day": String(describing: self)])
  }
}
