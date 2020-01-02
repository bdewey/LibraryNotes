// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import Foundation
import Yams

/// Supports serializing a challenge template into a TextSnippetArchive.
public struct ChallengeTemplateArchiveKey: LosslessStringConvertible, Hashable {
  /// Digest of the challenge template serialized data in the TextSnippetArchive
  public let digest: String

  /// The type of the challenge template
  public let type: String

  public init(digest: String, type: String) {
    self.digest = digest
    self.type = type
  }

  public init?(_ description: String) {
    let components = description.split(separator: ":")
    guard components.count == 2 else { return nil }
    self.digest = String(components[0])
    self.type = String(components[1])
  }

  public var description: String {
    return [digest, type].joined(separator: ":")
  }
}

/// Extensions to do type-safe insertion and extraction of ChallengeTemplate instances.
public extension TextSnippetArchive {
  mutating func insert(_ challengeTemplate: ChallengeTemplate) throws -> ChallengeTemplateArchiveKey {
    let text = try YAMLEncoder().encode(challengeTemplate)
    let snippet = insert(text)
    return ChallengeTemplateArchiveKey(
      digest: snippet.sha1Digest,
      type: challengeTemplate.type.rawValue
    )
  }

  mutating func insert<S: Sequence>(
    contentsOf sequence: S
  ) -> [ChallengeTemplateArchiveKey] where S.Element == ChallengeTemplate {
    var errors = 0
    let results = sequence.compactMap { template -> ChallengeTemplateArchiveKey? in
      let result = try? insert(template)
      if result == nil {
        errors += 1
      }
      return result
    }
    assert(errors == 0, "Errors serializing templates")
    return results
  }
}
