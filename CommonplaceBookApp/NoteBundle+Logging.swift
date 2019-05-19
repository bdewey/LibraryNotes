// Copyright © 2019 Brian's Brain. All rights reserved.

import CommonplaceBook
import FlashcardKit
import Foundation
import TextBundleKit

/// Extension types for logging.
extension NoteBundle {
  enum Change: LosslessStringConvertible {

    /// We added a template to the document.
    case addedChallengeTemplate(id: String)

    /// Added a page to the document.
    case addedPage(name: String, digest: String)

    case study(identifier: ChallengeIdentifier, statistics: AnswerStatistics)

    /// Decode a change from a string.
    public init?(_ description: String) {
      if let digest = description.removingPrefix(Prefix.addChallengeTemplate) {
        self = .addedChallengeTemplate(id: String(digest))
      } else if let digestAndName = description.removingPrefix(Prefix.addPage) {
        let components = digestAndName.split(separator: " ")
        if components.count > 1 {
          let name = String(components[1...].joined(separator: " "))
          self = .addedPage(name: name, digest: String(components[0]))
        } else {
          return nil
        }
      } else if let remainder = description.removingPrefix(Prefix.study).flatMap(String.init) {
        guard let regex = NSRegularExpression.studyRecord else { return nil }
        let range = NSRange(remainder.startIndex ..< remainder.endIndex, in: remainder)
        guard
          let result = regex.matches(in: remainder, options: [], range: range).first,
          result.numberOfRanges == 5,
          let index = remainder.int(at: result.range(at: 2)),
          let correct = remainder.int(at: result.range(at: 3)),
          let incorrect = remainder.int(at: result.range(at: 4))
          else {
            return nil
        }
        let digest = remainder.string(at: result.range(at: 1))
        // TODO: AnswerStatistics needs a public constructor!
        var statistics = AnswerStatistics.empty
        statistics.correct = correct
        statistics.incorrect = incorrect
        self = .study(
          identifier: ChallengeIdentifier(templateDigest: digest, index: index),
          statistics: statistics
        )
      } else {
        return nil
      }
    }

    /// Turn a change into a string.
    public var description: String {
      switch self {
      case .addedChallengeTemplate(let digest):
        return Prefix.addChallengeTemplate + digest
      case .addedPage(name: let name, digest: let digest):
        return Prefix.addPage + digest + " " + name
      case .study(identifier: let identifier, statistics: let statistics):
        return Prefix.study + "\(identifier.templateDigest!) \(identifier.index) correct \(statistics.correct) incorrect \(statistics.incorrect)"
      }
    }

    private enum Prefix {
      static let addChallengeTemplate = "add-template        "
      static let addPage              = "add-page            "
      static let study                = "study               "
    }
  }

  struct ChangeRecord: LosslessStringConvertible {
    let timestamp: Date
    let change: Change

    public init(timestamp: Date, change: Change) {
      self.timestamp = timestamp
      self.change = change
    }

    public init?(_ description: String) {
      guard let firstWhitespace = description.firstIndex(of: " ") else {
        return nil
      }
      let dateSlice = description[description.startIndex ..< firstWhitespace]
      let skippingWhitespace = description.index(after: firstWhitespace)
      let changeSlice = description[skippingWhitespace...]
      guard let timestamp = ISO8601DateFormatter().date(from: String(dateSlice)),
        let change = Change(String(changeSlice)) else {
          return nil
      }
      self.timestamp = timestamp
      self.change = change
    }

    public var description: String {
      return ISO8601DateFormatter().string(from: timestamp) + " " + change.description
    }
  }
}

private extension String {
  func removingPrefix(_ prefix: String) -> Substring? {
    guard hasPrefix(prefix) else { return nil }
    return suffix(from: index(startIndex, offsetBy: prefix.count))
  }
}

private extension NSRegularExpression {
  static let studyRecord: NSRegularExpression? = {
    return try? NSRegularExpression(pattern: "^^([0-9a-f]{40}) (\\d+) correct (\\d+) incorrect (\\d+)$", options: [])
  }()
}

// TODO: Put this someplace sharable
private extension String {
  func string(at range: NSRange) -> String {
    return String(self[Range(range, in: self)!])
  }

  func int(at range: NSRange) -> Int? {
    return Int(string(at: range))
  }
}
