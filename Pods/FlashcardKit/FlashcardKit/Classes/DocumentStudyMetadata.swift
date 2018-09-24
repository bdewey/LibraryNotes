// Copyright 2004-present Facebook. All Rights Reserved.

import CommonplaceBook
import Foundation
import TextBundleKit

/// Stores the IdentifiersToStudyMetadata association inside `study-metadata.json` in a textbundle.
public final class DocumentStudyMetadata {
  init(document: TextBundleDocument) {
    self.document = document
    identifiersToStudyMetadata.storage = self
    document.addListener(self)
  }

  let document: TextBundleDocument
  let identifiersToStudyMetadata = DocumentProperty<DocumentStudyMetadata>()

  func update(with studySession: StudySession, on date: Date) {
    let day = DayComponents(date)
    identifiersToStudyMetadata.changeValue { (dictionary) -> Dictionary<String, StudyMetadata> in
      var dictionary = dictionary
      for (identifier, statistics) in studySession.results {
        if let existingMetadata = dictionary[identifier] {
          dictionary[identifier] = existingMetadata.updatedMetadata(with: statistics, on: day)
        } else {
          dictionary[identifier] = StudyMetadata(day: day, lastAnswers: statistics)
        }
      }
      return dictionary
    }
  }
}

extension DocumentStudyMetadata: TextBundleDocumentSaveListener {
  public func textBundleDocumentWillSave(_ textBundleDocument: TextBundleDocument) throws {
    if let value = identifiersToStudyMetadata.clean() {
      let data = try DocumentStudyMetadata.encoder.encode(value)
      try document.addData(data, preferredFilename: DocumentStudyMetadata.key)
    }
  }

  public func textBundleDocumentDidLoad(_ textBundleDocument: TextBundleDocument) {
    identifiersToStudyMetadata.invalidate()
  }
}

extension DocumentStudyMetadata: StableStorage {

  static let key = "study-metadata.json"
  static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()
  static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  public func documentPropertyInitialValue() throws -> IdentifierToStudyMetadata {
    do {
      let data = try document.data(for: DocumentStudyMetadata.key)
      return (try? DocumentStudyMetadata.decoder.decode(IdentifierToStudyMetadata.self, from: data)) ?? IdentifierToStudyMetadata.empty
    } catch {
      if case TextBundleDocument.Error.noSuchDataKey(_) = error {
        return IdentifierToStudyMetadata.empty
      } else {
        throw error
      }
    }
  }

  public func documentPropertyDidChange() {
    document.updateChangeCount(.done)
  }
}
