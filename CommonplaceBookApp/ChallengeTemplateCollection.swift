// Copyright © 2019 Brian's Brain. All rights reserved.

import CommonCrypto
import FlashcardKit
import Foundation
import MiniMarkdown

/// An append-only, content-addressable collection of ChallengeTemplate objects.
/// When challenge templates are inserted into the collection, you get a key you can use
/// to retrieve that template later. The key persists across saving/restoring the collection.
public struct ChallengeTemplateCollection {
  public init() { }

  private var challengeTemplates: [String: ChallengeTemplate] = [:]

  public var keys: [String] {
    return Array(challengeTemplates.keys)
  }

  /// Inserts a ChallengeTemplate into the collection.
  /// - returns: A string you can use to retrieve this ChallengeTemplate later.
  @discardableResult
  public mutating func insert(
    _ cardTemplate: ChallengeTemplate
  ) -> (key: String, wasInserted: Bool) {
    let key = cardTemplate.asMarkdown.sha1Digest()
    if self.challengeTemplates[key] == nil {
      self.challengeTemplates[key] = cardTemplate
      cardTemplate.templateIdentifier = key
      return (key, true)
    } else {
      return (key, false)
    }
  }

  public mutating func insert<S: Sequence>(contentsOf templates: S) where S.Element == ChallengeTemplate {
    for template in templates {
      insert(template)
    }
  }

  /// Merges another ChallengeTemplateCollection into this one.
  /// - returns: An array of keys added to the receiver.
  @discardableResult
  public mutating func merge(_ other: ChallengeTemplateCollection) -> [String] {
    var addedKeys: [String] = []
    for (key, value) in other where challengeTemplates[key] == nil {
      challengeTemplates[key] = value
      addedKeys.append(key)
    }
    return addedKeys
  }

  public subscript(key: String) -> ChallengeTemplate? {
    return challengeTemplates[key]
  }
}

extension ChallengeTemplateCollection: Collection {
  public var startIndex: Dictionary<String, ChallengeTemplate>.Index {
    return challengeTemplates.startIndex
  }

  public var endIndex: Dictionary<String, ChallengeTemplate>.Index {
    return challengeTemplates.endIndex
  }

  public var count: Int {
    return challengeTemplates.count
  }

  public func index(after i: Dictionary<String, ChallengeTemplate>.Index) -> Dictionary<String, ChallengeTemplate>.Index {
    return challengeTemplates.index(after: i)
  }

  public subscript (position: Dictionary<String, ChallengeTemplate>.Index) -> (key: String, value: ChallengeTemplate) {
    return challengeTemplates[position]
  }
}

// swiftlint:disable:next force_try
private let headerRegularExpression = try! NSRegularExpression(
  pattern: "^([0-9a-f]{40}) (\\w+) (\\d+)$",
  options: []
)

extension ChallengeTemplateCollection {
  enum Error: Swift.Error {
    case invalidDigest
    case headerFailedRegex
  }

  public init(parsingRules: ParsingRules, data: Data) throws {
    var challengeTemplates: [String: ChallengeTemplate] = [:]
    let lines = String(data: data, encoding: .utf8)!
      .split(separator: "\n", omittingEmptySubsequences: false)
      .dropLast() // The final "\n" gets interpreted as having an empty line after; ignore
    var currentSlice = ArraySlice(lines)
    while let (key, template, remainder) = try ChallengeTemplateCollection.parseChallengeTemplate(
      parsingRules: parsingRules,
      lines: currentSlice
    ) {
      challengeTemplates[key] = template
      template.templateIdentifier = key
      currentSlice = remainder
    }
    self.challengeTemplates = challengeTemplates
  }

  /// Returns a single (key, ChallengeTemplate) pair from the start of `lines`
  private static func parseChallengeTemplate(
    parsingRules: ParsingRules,
    lines: ArraySlice<Substring>
  ) throws -> (String, ChallengeTemplate, ArraySlice<Substring>)? {
    guard let header = lines.first.flatMap(String.init) else { return nil }
    let remainder = lines.dropFirst()
    let range = NSRange(header.startIndex ..< header.endIndex, in: header)
    guard let result = headerRegularExpression.matches(in: header, options: [], range: range).first,
      result.numberOfRanges == 4
      else {
        throw Error.headerFailedRegex
    }
    let digest = String(header[Range(result.range(at: 1), in: header)!])
    let typeIdentifier = String(header[Range(result.range(at: 2), in: header)!])
    guard
      let templateClass = ChallengeTemplateType.classMap[typeIdentifier],
      let lineCount = Int(header[Range(result.range(at: 3), in: header)!]) else {
      throw Error.headerFailedRegex
    }
    let templateLines = remainder[remainder.startIndex ..< (remainder.startIndex + lineCount)].joined()
    let template = try templateClass.init(markdown: templateLines, parsingRules: parsingRules)
    // +1 for the extra line at the end
    return (digest, template, remainder.dropFirst(lineCount))
  }

  public func data() -> Data {
    var results = String()
    for key in challengeTemplates.keys.sorted() {
      let template = challengeTemplates[key]!
      results.append(key)
      results.append(" ")
      results.append(template.type.rawValue)
      results.append(" ")
      let lineCount = template.asMarkdown
        .split(separator: "\n", omittingEmptySubsequences: false).count
      results.append(String(lineCount))
      results.append("\n")
      results.append(template.asMarkdown)
      results.append("\n")
    }
    return results.data(using: .utf8)!
  }
}
