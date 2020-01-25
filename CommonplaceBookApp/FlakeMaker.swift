// Copyright © 2017-present Brian's Brain. All rights reserved.


//
//  FlakeMaker.swift
//  MiniFlake
//
//  Copyright © Sasmito Adibowo
//  http://cutecoder.org
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation

public struct FlakeID: RawRepresentable, Hashable, Comparable {
  public var rawValue: Int64

  public init(rawValue: Int64) {
    self.rawValue = rawValue
  }

  public init(date: Date, instanceNumber: Int, sequenceNumber: UInt16) {
    let millisecondsSinceEpoch = Int64(floor((date.timeIntervalSinceReferenceDate - Self.customEpoch) * 1000))
    let clampedInstanceNumber = UInt16(instanceNumber % Int(FlakeMaker.limitInstanceNumber))
    self.init(
      millisecondsSinceEpoch: millisecondsSinceEpoch,
      clampedInstanceNumber: clampedInstanceNumber,
      sequenceNumber: sequenceNumber
    )
  }

  public init(millisecondsSinceEpoch: Int64, clampedInstanceNumber: UInt16, sequenceNumber: UInt16) {
    /*
     Value is
     - 41 bits timestamp with custom epoch
     - 12 bits sequence number
     - 10 bits instance ID
     */
    let rawValue = (millisecondsSinceEpoch << 22) | (Int64(sequenceNumber & 0xFFF) << 10) | Int64(clampedInstanceNumber & (Self.limitInstanceNumber-1))
    self.init(rawValue: rawValue)
  }

  public var timestamp: Date {
    let millisecondsSinceEpoch = rawValue >> 22
    let timeIntervalSinceEpoch = Double(millisecondsSinceEpoch) / 1000
    return Date(timeIntervalSinceReferenceDate: Self.customEpoch + timeIntervalSinceEpoch)
  }

  public var instanceNumber: Int {
    return Int(rawValue & Int64(Self.limitInstanceNumber - 1))
  }

  public var sequenceNumber: UInt16 {
    return UInt16((rawValue >> 10) & 0xFFF)
  }

  public static let customEpoch: TimeInterval = {
    // custom epoch is 1 January 2019 00:00 UTC
    let utc = TimeZone(identifier: "UTC")!
    let cal = Calendar(identifier: .iso8601)
    var markerDate = DateComponents()
    markerDate.calendar = cal
    markerDate.timeZone = utc
    markerDate.year = 2020
    markerDate.month = 1
    markerDate.day = 1
    return markerDate.date!.timeIntervalSinceReferenceDate
  }()

  private static let limitInstanceNumber = UInt16(0x400)

  public static func < (lhs: FlakeID, rhs: FlakeID) -> Bool {
    return lhs.rawValue < rhs.rawValue
  }
}

extension FlakeID: Codable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(Int64.self)
    self.init(rawValue: rawValue)
  }
}

extension FlakeID: CustomStringConvertible {
  public var description: String {
    return "\(rawValue)"
  }
}

/**
 Generates a 63 bit integers for use in database primary keys. The value is k-ordered by time and has the following layout:
 - 41 bits timestamp with custom epoch
 - 12 bits sequence number
 - 10 bits instance ID
 */
public class FlakeMaker {

  static let limitInstanceNumber = UInt16(0x400)

  var lastGenerateTime = Int64(0)

  var instanceNumber: UInt16

  var sequenceNumber = UInt16(0)

  public init(instanceNumber: Int) {
    self.instanceNumber = UInt16(instanceNumber % Int(FlakeMaker.limitInstanceNumber))
  }

  /**
   Generates the next identifier value.
   */
  public func nextValue() -> FlakeID {
    let now = Date.timeIntervalSinceReferenceDate
    var generateTime = Int64(floor( (now - FlakeID.customEpoch) * 1000) )

    let sequenceNumberMax = 0x1000
    if generateTime > lastGenerateTime {
      lastGenerateTime = generateTime
      sequenceNumber = 0
    } else {
      if generateTime < lastGenerateTime {
        // timestamp went backwards, probably because of NTP resync.
        // we need to keep the sequence number go forward
        generateTime = lastGenerateTime
      }
      sequenceNumber += 1
      if sequenceNumber == sequenceNumberMax {
        sequenceNumber = 0
        // we overflowed the sequence number, bump the overflow into the time field
        generateTime += 1
        lastGenerateTime = generateTime
      }
    }

    /*
     Value is
     - 41 bits timestamp with custom epoch
     - 12 bits sequence number
     - 10 bits instance ID
     */
    return FlakeID(
      millisecondsSinceEpoch: generateTime,
      clampedInstanceNumber: instanceNumber,
      sequenceNumber: sequenceNumber
    )
  }
}

// MARK: Hashable

extension FlakeMaker: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(instanceNumber)
  }
}

public func ==(lhs: FlakeMaker, rhs: FlakeMaker) -> Bool {
  return lhs.instanceNumber == rhs.instanceNumber && lhs.lastGenerateTime == rhs.lastGenerateTime && lhs.sequenceNumber == rhs.sequenceNumber
}
