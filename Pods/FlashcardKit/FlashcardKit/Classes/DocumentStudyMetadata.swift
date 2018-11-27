// Copyright 2004-present Facebook. All Rights Reserved.

import CommonplaceBook
import Foundation
import TextBundleKit

private enum DocumentStudyMetadata {
  fileprivate static let key = "study-metadata.json"

  private static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()

  private static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  private static func read(from document: TextBundleDocument) throws -> IdentifierToStudyMetadata {
    do {
      let data = try document.data(for: DocumentStudyMetadata.key)
      return (try? decoder.decode(IdentifierToStudyMetadata.self, from: data)) ?? IdentifierToStudyMetadata.empty
    } catch {
      if case TextBundleDocument.Error.noSuchDataKey(_) = error {
        return IdentifierToStudyMetadata.empty
      } else {
        throw error
      }
    }
  }

  private static func writeValue(_ value: IdentifierToStudyMetadata, to document: TextBundleDocument) throws {
    let data = try DocumentStudyMetadata.encoder.encode(value)
    try document.addData(data, preferredFilename: DocumentStudyMetadata.key)
  }

  fileprivate static func makeProperty(for document: TextBundleDocument) -> DocumentProperty<IdentifierToStudyMetadata> {
    return DocumentProperty(document: document, readFunction: read, writeFunction: writeValue)
  }
}

extension TextBundleDocument {
  var documentStudyMetadata: DocumentProperty<IdentifierToStudyMetadata> {
    return listener(
      for: DocumentStudyMetadata.key,
      constructor: DocumentStudyMetadata.makeProperty
    )
  }
}

extension DocumentProperty where Value == IdentifierToStudyMetadata {
  func update(with studySession: StudySession, on date: Date) {
    let day = DayComponents(date)
    changeValue { (dictionary) -> Dictionary<String, StudyMetadata> in
      var dictionary = dictionary
      for (_, documentResults) in studySession.results {
        for (identifier, statistics) in documentResults {
          if let existingMetadata = dictionary[identifier] {
            dictionary[identifier] = existingMetadata.updatedMetadata(with: statistics, on: day)
          } else {
            dictionary[identifier] = StudyMetadata(day: day, lastAnswers: statistics)
          }
        }
      }
      return dictionary
    }
  }
}
