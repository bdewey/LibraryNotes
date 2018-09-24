// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation

import TextBundleKit

/// Stores a StudyStatisticsStorage structure in `statistics.json` in a text bundle.
public final class StudyStatisticsStorage {

  init(document: TextBundleDocument) {
    self.document = document
    document.addListener(self)
    self.statistics.storage = self
  }

  /// The TextBundle we work with.
  private let document: TextBundleDocument

  /// In-memory copy of the StudySession.Statistics structure.
  public var statistics = DocumentProperty<StudyStatisticsStorage>()

  /// Where we persist the StudySession.Statistics in the text bundle.
  private let key = "statistics.json"
}

extension StudyStatisticsStorage: TextBundleDocumentSaveListener {
  public func textBundleDocumentDidLoad(_ textBundleDocument: TextBundleDocument) {
    statistics.invalidate()
  }

  private static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()

  public func textBundleDocumentWillSave(_ textBundleDocument: TextBundleDocument) throws {
    if let value = statistics.clean() {
      let data = try StudyStatisticsStorage.encoder.encode(value)
      try document.addData(data, preferredFilename: key, replaceIfExists: true)
    }
  }
}

extension StudyStatisticsStorage: StableStorage {

  private static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  public func documentPropertyInitialValue() throws -> [StudySession.Statistics] {
    guard let data = try? document.data(for: key) else { return [] }
    return try StudyStatisticsStorage.decoder.decode([StudySession.Statistics].self, from: data)
  }

  public func documentPropertyDidChange() {
    document.updateChangeCount(.done)
  }
}
