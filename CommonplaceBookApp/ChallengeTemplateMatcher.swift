// Copyright © 2020 Brian's Brain. All rights reserved.

import Foundation

/// When you edit markdown notes, the challenge templates extracted from the text don't have "identity"
/// This extension compares templates from one version of a note to another version of a note to find matching identities.
extension ChallengeTemplate {
  public static func assignMatchingTemplateIdentifiers(
    from existingTemplates: [ChallengeTemplate],
    to newTemplates: [ChallengeTemplate]
  ) {
    assert(existingTemplates.allSatisfy({ $0.templateIdentifier != nil }))
    let existingIdentifiers = newTemplates
      .compactMap { $0.templateIdentifier }
      .asSet()
    let tuples = existingTemplates
      .filter { !existingIdentifiers.contains($0.templateIdentifier!) }
    var existingUnusedIdentifiers = Dictionary(grouping: tuples, by: { $0.fingerprint })

    // Look for exact matches
    for template in newTemplates where template.templateIdentifier == nil {
      if let (candidate, remainder) = existingUnusedIdentifiers[template.fingerprint, default: []]
        .findFirst(where: { $0.rawValue == template.rawValue }) {
        template.templateIdentifier = candidate.templateIdentifier
        existingUnusedIdentifiers[template.fingerprint] = remainder
      }
    }

    // Look for close-enough matches
    // TODO: This doesn't try to optimize things at all.
    for template in newTemplates where template.templateIdentifier == nil {
      if let (candidate, remainder) = existingUnusedIdentifiers[template.fingerprint, default: []]
        .findFirst(where: { template.closeEnough(to: $0) }) {
        template.templateIdentifier = candidate.templateIdentifier
        existingUnusedIdentifiers[template.fingerprint] = remainder
      }
    }
  }

  private struct TemplateFingerprint: Hashable {
    let templateType: ChallengeTemplateType
    let challengeCount: Int
  }

  private var fingerprint: TemplateFingerprint {
    TemplateFingerprint(templateType: type, challengeCount: challenges.count)
  }

  private func closeEnough(to other: ChallengeTemplate) -> Bool {
    assert(other.type == type)
    assert(other.challenges.count == challenges.count)
    let diff = rawValue.difference(from: other.rawValue)
    return diff.count < rawValue.count
  }
}

extension Array where Element: AnyObject {
  func findFirst(where predicate: (Element) -> Bool) -> (value: Element, remainder: [Element])? {
    var value: Element?
    var remainder = [Element]()
    for element in self {
      if value == nil, predicate(element) {
        value = element
      } else {
        remainder.append(element)
      }
    }
    if let value = value {
      return (value: value, remainder: remainder)
    } else {
      return nil
    }
  }
}
