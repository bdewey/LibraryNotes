// Copyright © 2019 Brian's Brain. All rights reserved.

import CommonCrypto
import FlashcardKit
import Foundation

/// An append-only, content-addressable collection of ChallengeTemplate objects.
/// When challenge templates are inserted into the collection, you get a key you can use
/// to retrieve that template later. The key persists across saving/restoring the collection.
public struct ChallengeTemplateCollection {
  public init() { }

  private var data: [String: String] = [:]

  var keys: [String] {
    return Array(data.keys)
  }

  /// Inserts a ChallengeTemplate into the collection.
  /// - returns: A string you can use to retrieve this ChallengeTemplate later.
  @discardableResult
  public mutating func insert(
    _ cardTemplate: ChallengeTemplate
  ) throws -> (key: String, wasInserted: Bool) {
    let wrapped = CardTemplateSerializationWrapper(cardTemplate)
    let encoder = JSONEncoder()
    let data = try encoder.encode(wrapped)
    let key = data.sha1Digest()
    if self.data[key] == nil {
      self.data[key] = String(data: data, encoding: .utf8)!
      return (key, true)
    } else {
      return (key, false)
    }
  }

  public mutating func insert<S: Sequence>(contentsOf templates: S) throws where S.Element == ChallengeTemplate {
    for template in templates {
      try insert(template)
    }
  }

  public func template(for key: String) throws -> ChallengeTemplate? {
    guard let encodedString = data[key],
      let data = encodedString.data(using: .utf8)
      else { return nil }
    let decoder = JSONDecoder()
    let wrapper = try decoder.decode(CardTemplateSerializationWrapper.self, from: data)
    return wrapper.value
  }
}

extension ChallengeTemplateCollection: Collection {
  public var startIndex: Dictionary<String, String>.Index {
    return data.startIndex
  }

  public var endIndex: Dictionary<String, String>.Index {
    return data.endIndex
  }

  public var count: Int {
    return data.count
  }

  public func index(after i: Dictionary<String, String>.Index) -> Dictionary<String, String>.Index {
    return data.index(after: i)
  }

  public subscript (position: Dictionary<String, String>.Index) -> (key: String, value: String) {
    return data[position]
  }
}

// Provide custom encoding; we don't want to encode the "data=" in JSON.
extension ChallengeTemplateCollection: Codable {

  // Just use strings as coding keys.
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
