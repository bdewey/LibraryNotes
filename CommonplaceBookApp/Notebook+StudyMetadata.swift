// Copyright © 2018 Brian's Brain. All rights reserved.

import CocoaLumberjack
import CommonplaceBook
import CwlSignal
import FlashcardKit
import Foundation

/// Two-level mapping: document name -> card identifier -> study metadata
public typealias NotebookStudyMetadata = [String: [String: StudyMetadata]]

extension Notebook.Key {
  public static let studyMetadata = Notebook.Key(rawValue: "study-metadata.json")
}

extension Notebook {

  public internal(set) var studyMetadata: NotebookStudyMetadata {
    get {
      if let studyMetadata = internalNotebookData[.studyMetadata] as? NotebookStudyMetadata {
        return studyMetadata
      } else {
        let studyMetadata = NotebookStudyMetadata()
        internalNotebookData[.studyMetadata] = studyMetadata
        return studyMetadata
      }
    }
    set {
      internalNotebookData[.studyMetadata] = newValue
      notifyListeners(changed: .studyMetadata)
    }
  }

  /// Loads study metadata from the FileMetadataProvider.
  @discardableResult
  public func loadStudyMetadata() -> Notebook {
    guard let studyMetadataDocument = metadataProvider.editableDocument(
      for: FileMetadata(fileName: Key.studyMetadata.rawValue)
    ) else {
      DDLogError("Cannot load study metadata.")
      return self
    }
    openMetadocuments[.studyMetadata] = studyMetadataDocument
    studyMetadataDocument.openOrCreate { (success) in
      precondition(success)
      self.endpoints += studyMetadataDocument.textSignal.subscribeValues({ (taggedString) in
        guard taggedString.tag == .document else { return }
        let data = taggedString.value.data(using: .utf8)!
        self.studyMetadata = (try? metadataDecoder.decode(NotebookStudyMetadata.self, from: data))
          ?? NotebookStudyMetadata()
        self.conditionForKey(.studyMetadata).condition = true
      })
    }
    renameBlocks[.studyMetadata] = { [weak self](oldName, newName) in
      guard let self = self else { return }
      self.studyMetadata[newName] = self.studyMetadata[oldName]
      self.studyMetadata[oldName] = nil
      self.notifyListeners(changed: .studyMetadata)
      self.saveStudyMetadata(self.studyMetadata)
    }
    return self
  }

  /// Saves notebook study metadata to disk.
  private func saveStudyMetadata(_ studyMetadata: NotebookStudyMetadata) {
    guard let document = openMetadocuments[.studyMetadata] else { return }
    document.applyTaggedModification(tag: .memory) { (_) -> String in
      if let data = try? metadataEncoder.encode(studyMetadata) {
        return String(data: data, encoding: .utf8)!
      } else {
        return ""
      }
    }
  }

  /// Returns a study session given the current notebook pages and study metadata (which indicates
  /// what cards have been studied, and therefore don't need to be studied today).
  ///
  /// - parameter filter: An optional function that determines if a page should be included in
  ///                     the study session. If no filter is given, the all pages will be used
  ///                     to construct the session.
  /// - returns: A StudySession!
  public func studySession(filter: ((PageProperties) -> Bool)? = nil) -> StudySession {
    let filter = filter ?? { (_) in return true }
    return pageProperties.values
      .map { $0.value }
      .filter(filter)
      .map { (diffableProperties) -> StudySession in
        let documentMetadata = self.studyMetadata[diffableProperties.fileMetadata.fileName, default: [:]]
        return documentMetadata.studySession(
          from: diffableProperties.cardTemplates.cards,
          limit: 500,
          properties: CardDocumentProperties(documentName: diffableProperties.fileMetadata.fileName, attributionMarkdown: diffableProperties.title, parsingRules: LanguageDeck.parsingRules)
        )
      }
      .reduce(into: StudySession(), { $0 += $1 })
  }

  /// Update the notebook with the result of a study session.
  ///
  /// - parameter studySession: The completed study session.
  /// - parameter date: The date the study session took place.
  public func updateStudySessionResults(_ studySession: StudySession, on date: Date = Date()) {
    let day = DayComponents(date)
    var dictionary = self.studyMetadata
    for (documentName, documentResults) in studySession.results {
      for (identifier, statistics) in documentResults {
        if let existingMetadata = dictionary[documentName]?[identifier] {
          dictionary[documentName]![identifier] = existingMetadata.updatedMetadata(with: statistics, on: day)
        } else {
          dictionary[documentName, default: [:]][identifier] = StudyMetadata(day: day, lastAnswers: statistics)
        }
      }
    }
    self.studyMetadata = dictionary
    saveStudyMetadata(dictionary)
  }
}

private let metadataEncoder: JSONEncoder = {
  let encoder = JSONEncoder()
  encoder.outputFormatting = .prettyPrinted
  encoder.dateEncodingStrategy = .iso8601
  return encoder
}()

private let metadataDecoder: JSONDecoder = {
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .iso8601
  return decoder
}()
