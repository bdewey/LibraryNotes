// Copyright © 2019 Brian's Brain. All rights reserved.

import CommonCrypto
import FlashcardKit
import Foundation

public struct ChallengeTemplateCollection {
  public init() { }

  private var data: [String: String] = [:]

  @discardableResult
  public mutating func insert(_ cardTemplate: ChallengeTemplate) throws -> String {
    let wrapped = CardTemplateSerializationWrapper(cardTemplate)
    let encoder = JSONEncoder()
    let data = try encoder.encode(wrapped)
    var digest = Data(repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))

    data.withUnsafeBytes { dataPtr -> Void in
      digest.withUnsafeMutableBytes({ digestPtr -> Void in
        CC_SHA1(dataPtr, CC_LONG(data.count), digestPtr)
      })
    }
    let key = digest.toHexString()
    self.data[key] = String(data: data, encoding: .utf8)!
    return key
  }
}

extension ChallengeTemplateCollection: Codable {
  private struct CodingKey: Swift.CodingKey {
    var stringValue: String

    init?(stringValue: String) {
      self.stringValue = stringValue
    }

    var intValue: Int? { return nil }

    init?(intValue: Int) {
      return nil
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKey.self)
    for (key, value) in data {
      try container.encode(value, forKey: CodingKey(stringValue: key)!)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKey.self)
    var data: [String: String] = [:]
    for key in container.allKeys {
      data[key.stringValue] = try container.decode(String.self, forKey: key)
    }
    self.data = data
  }
}

private extension Data {

  func toHexString() -> String {
    return lazy.map { (byte) in
      (byte <= 0xF ? "0" : "") + String(byte, radix: 16)
    }.joined()
  }
}
