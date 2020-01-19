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

/**
 Generates a 63 bit integers for use in database primary keys. The value is k-ordered by time and has the following layout:
 - 41 bits timestamp with custom epoch
 - 12 bits sequence number
 - 10 bits instance ID
 */
public class FlakeMaker {

    static let customEpoch : TimeInterval = {
        // custom epoch is 1 March 2018 00:00 UTC
        let utc = TimeZone(identifier: "UTC")!
        let cal = Calendar(identifier: .iso8601)
        var markerDate = DateComponents()
        markerDate.calendar = cal
        markerDate.timeZone = utc
        markerDate.year = 2018
        markerDate.month = 3
        markerDate.day = 1
        return markerDate.date!.timeIntervalSinceReferenceDate
    }()

    static let limitInstanceNumber = UInt16(0x400)

    var lastGenerateTime = Int64(0)

    var instanceNumber : UInt16

    var sequenceNumber = UInt16(0)

    public init(instanceNumber: Int) {
        self.instanceNumber = UInt16(instanceNumber % Int(FlakeMaker.limitInstanceNumber))
    }

    /**
     Generates the next identifier value.
     */
    public func nextValue() -> Int64 {
        let now = Date.timeIntervalSinceReferenceDate
        let customEpoch = FlakeMaker.customEpoch
        var generateTime = Int64(floor( (now - customEpoch) * 1000) )

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
        return (generateTime << 22) | (Int64(sequenceNumber & 0xFFF) << 10) | Int64(instanceNumber & (FlakeMaker.limitInstanceNumber-1))
    }
}

// MARK: Hashable

extension FlakeMaker: Hashable {
    public var hashValue: Int {
        get {
            return Int(instanceNumber)
        }
    }
}

public func ==(lhs: FlakeMaker, rhs: FlakeMaker) -> Bool {
    return lhs.instanceNumber == rhs.instanceNumber && lhs.lastGenerateTime == rhs.lastGenerateTime && lhs.sequenceNumber == rhs.sequenceNumber
}

/**
 A `FlakeMaker` with automatically managed instance ID values.
 This class automatically manages the instance number from a process-wide pool of instance numbers and returning
 identifiers to the pool when as objects get deallocated.
 Either use `InProcessFlakeMaker` exclusively or its superclass `FlakeMaker` exclusively but not both
 since the instance ID values are obtained from the same pool of integer ranges.
 Note that the maximum number of instances at any given moment is 1024 for a process. Otherwise init() would
 crash due to running out of instance numbers.
 */
public class InProcessFlakeMaker : FlakeMaker {

    /**
     The set of instance numbers that are still available.
     */
    static var availableInstanceNumbers = IndexSet(integersIn: 0..<Int(FlakeMaker.limitInstanceNumber))
    static let classQueue = DispatchQueue(label: "com.basilsalad.InProcessFlakeMaker")

    /**
     Returns the number of instances that may still be created
     */
    public static var instancesAvailable : Int {
        get {
            return classQueue.sync {
                return availableInstanceNumbers.count
            }
        }
    }

    override private init(instanceNumber: Int) {
        fatalError("Do not specify instance number when constructing InProcessFlakeMaker")
    }

    /**
     Creates a generator instance with randomly-selected instance number.
     This would fail if there are no more instance numbers left (there are a global limit of 1024 instance numbers
     available at any given time.
     */
    public init?() {
        let starterNumber = Int(arc4random_uniform(UInt32(FlakeMaker.limitInstanceNumber)))
        let ownType = type(of:self)
        guard let num = ownType.classQueue.sync(execute:{
            () -> Int? in
            guard let selectedNum = (
                    ownType.availableInstanceNumbers.integerLessThanOrEqualTo(starterNumber) ??
                    ownType.availableInstanceNumbers.integerGreaterThan(starterNumber)
                ) else {
                    return nil
            }
            ownType.availableInstanceNumbers.remove(selectedNum)
            return selectedNum
        }) else {
            return nil
        }
        super.init(instanceNumber:num)
    }

    deinit {
        let returnedInstanceNumber = Int(instanceNumber)
        let ownType = type(of:self)
        _ = ownType.classQueue.sync {
            ownType.availableInstanceNumbers.update(with: returnedInstanceNumber)
        }
    }

    /**
     Returns the ID generator for the current thread, or create a new one if it doesn't exists.
     The generator instance is placed inside the `threadDictionary` of the current thread.
     */
    static func flakeMaker(thread: Thread) -> FlakeMaker  {
        let objectName = "com.basilsalad.FlakeMaker.thread"
        let threadDict = thread.threadDictionary
        if let existingFlakeMaker = threadDict[objectName] as? InProcessFlakeMaker {
            return existingFlakeMaker
        }
        let fm = InProcessFlakeMaker()!
        threadDict[objectName] = fm
        return fm
    }
}

public extension Thread {
    /**
     Returns the next ID for the current thread. Creates an ID generator if necessary in the thread-local storage.
     */
    @objc
    public func nextFlakeID() -> Int64 {
        return InProcessFlakeMaker.flakeMaker(thread:self).nextValue()
    }
}
