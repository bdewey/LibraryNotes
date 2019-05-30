// Copyright © 2017-present Brian's Brain. All rights reserved.

import Foundation
import TextBundleKit

private enum StudyStatisticsStorage {
  /// Where we persist the StudySession.Statistics in the text bundle.
  fileprivate static let key = "statistics.json"

  private static func read(from document: TextBundleDocument) throws -> [StudySession.Statistics] {
    guard let data = try? document.data(for: key) else { return [] }
    return try decoder.decode([StudySession.Statistics].self, from: data)
  }

  private static func writeValue(
    _ value: [StudySession.Statistics],
    to document: TextBundleDocument
  ) throws {
    let data = try StudyStatisticsStorage.encoder.encode(value)
    try document.addData(data, preferredFilename: key, replaceIfExists: true)
  }

  fileprivate static func makeProperty(
    for document: TextBundleDocument
  ) -> DocumentProperty<[StudySession.Statistics]> {
    return DocumentProperty(document: document, readFunction: read, writeFunction: writeValue)
  }

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
}

extension TextBundleDocument {
  public var studyStatistics: DocumentProperty<[StudySession.Statistics]> {
    return listener(
      for: StudyStatisticsStorage.key,
      constructor: StudyStatisticsStorage.makeProperty
    )
  }
}
