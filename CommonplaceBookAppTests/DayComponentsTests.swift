// Copyright © 2017-present Brian's Brain. All rights reserved.

// swiftlint:disable force_try

@testable import CommonplaceBookApp
import XCTest

struct JsonWrapper: Codable {
  let day: DayComponents
}

// TODO: Move this to CommonplaceBook.
final class DayComponentsTests: XCTestCase {
  func testSimpleConversion() {
    guard let day = DayComponents("2006-03-19") else { XCTFail(); return }
    XCTAssertEqual(day.year, 2006)
    XCTAssertEqual(day.month, 3)
    XCTAssertEqual(day.day, 19)
  }

  func testToString() {
    var components = DateComponents()
    components.year = 2008
    components.month = 6
    components.day = 9
    guard let date = Calendar.current.date(from: components) else { XCTFail(); return }
    let day = DayComponents(date)
    XCTAssertEqual("2008-06-09", day.description)
  }

  func testSerialization() {
    let wrapper = JsonWrapper(day: DayComponents("2008-06-09")!)
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try! encoder.encode(wrapper)
    let encoded = String(data: data, encoding: .utf8)!
    let expectedEncoding = """
    {
      "day" : "2008-06-09"
    }
    """
    XCTAssertEqual(expectedEncoding, encoded)

    let decoder = JSONDecoder()
    let roundTrip = try! decoder.decode(JsonWrapper.self, from: data)
    XCTAssertEqual(roundTrip.day.year, 2008)
    XCTAssertEqual(roundTrip.day.month, 6)
    XCTAssertEqual(roundTrip.day.day, 9)
  }
}
