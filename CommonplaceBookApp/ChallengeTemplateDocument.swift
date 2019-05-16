// Copyright © 2019 Brian's Brain. All rights reserved.

import CwlSignal
import FlashcardKit
import TextBundleKit
import enum TextBundleKit.Result
import UIKit

/// Manages a ChallengeTemplateCollection, auto-saving it to disk.
///
/// - note: This class doesn't announce changes to `challengeTemplates` because you're
///         just supposed to look up / append values to it. You're not supposed to react to it.
public final class ChallengeTemplateDocument: UIDocumentWithPreviousError {
  public private(set) var challengeTemplates = ChallengeTemplateCollection()

  public func insert(_ challengeTemplate: ChallengeTemplate) throws -> String {
    assert(Thread.isMainThread)
    let (key, didChange) = try challengeTemplates.insert(challengeTemplate)
    if didChange {
      updateChangeCount(.done)
    }
    return key
  }

  public override func contents(forType typeName: String) throws -> Any {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(challengeTemplates)
  }

  public override func load(fromContents contents: Any, ofType typeName: String?) throws {
    guard let data = contents as? Data else { throw NSError.fileWriteInapplicableStringEncoding }
    challengeTemplates = try JSONDecoder().decode(ChallengeTemplateCollection.self, from: data)
  }
}

// Need to rethink what "EditableDocument" is, in the context of a Notebook.
// That's the only reason I need this conformance, and as you can see, it doesn't really work.
extension ChallengeTemplateDocument: EditableDocument {
  public var currentTextResult: Result<Tagged<String>> {
    preconditionFailure()
  }

  public var textSignal: Signal<Tagged<String>> {
    preconditionFailure()
  }

  public func applyTaggedModification(tag: Tag, modification: (String) -> String) {
    preconditionFailure()
  }
}
