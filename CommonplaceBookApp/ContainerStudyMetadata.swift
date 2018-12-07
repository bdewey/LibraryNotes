// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import FlashcardKit
import Foundation
import TextBundleKit

/// Two-level mapping: document name -> card identifier -> study metadata
public typealias NotebookStudyMetadata = [String: [String: StudyMetadata]]

/// Maintains a two-level mapping: document name -> card identifier -> study metadata
/// TODO: Get rid of DocumentStudyMetadata when everything is migrated to this.
private enum ContainerStudyMetadata {
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

  private static func read(
    from document: TextBundleDocument
  ) throws -> NotebookStudyMetadata {
    do {
      let data = try document.data(for: ContainerStudyMetadata.key)
      return (try? decoder.decode(NotebookStudyMetadata.self, from: data))
        ?? NotebookStudyMetadata()
    } catch TextBundleDocument.Error.noSuchDataKey(key: _) {
      return NotebookStudyMetadata()
    }
  }

  private static func writeValue(
    _ value: NotebookStudyMetadata,
    to document: TextBundleDocument
  ) throws {
    let data = try ContainerStudyMetadata.encoder.encode(value)
    try document.addData(data, preferredFilename: ContainerStudyMetadata.key)
  }

  fileprivate static func makeProperty(
    for document: TextBundleDocument
  ) -> DocumentProperty<NotebookStudyMetadata> {
    return DocumentProperty(
      document: document,
      readFunction: read,
      writeFunction: writeValue
    )
  }
}

extension TextBundleDocument {
  var containerStudyMetadata: DocumentProperty<NotebookStudyMetadata> {
    return listener(
      for: ContainerStudyMetadata.key,
      constructor: ContainerStudyMetadata.makeProperty
    )
  }
}

extension DocumentProperty where Value == NotebookStudyMetadata {
  func update(with studySession: StudySession, on date: Date) {
    let day = DayComponents(date)
    changeValue { (dictionary) -> NotebookStudyMetadata in
      var dictionary = dictionary
      for (documentName, documentResults) in studySession.results {
        for (identifier, statistics) in documentResults {
          if let existingMetadata = dictionary[documentName]?[identifier] {
            dictionary[documentName]![identifier] = existingMetadata.updatedMetadata(with: statistics, on: day)
          } else {
            dictionary[documentName, default: [:]][identifier] = StudyMetadata(day: day, lastAnswers: statistics)
          }
        }
      }
      return dictionary
    }
  }
}
