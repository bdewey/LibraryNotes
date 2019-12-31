// Copyright © 2017-present Brian's Brain. All rights reserved.

import Combine
import Foundation
import MiniMarkdown
import UIKit

/// Abstract interface for something that can store notes, challenges, and study logs, and can also generate study sessions.
public protocol NoteStorage: TextEditViewControllerDelegate, MarkdownEditingTextViewImageStoring {
  /// This is the main data stored in this container.
  var noteProperties: [NoteIdentifier: NoteProperties] { get }

  /// This publisher sends a signal whenver `noteProperties` changed.
  var notePropertiesDidChange: PassthroughSubject<Void, Never> { get }

  /// Deletes a note.
  func deleteNote(noteIdentifier: NoteIdentifier) throws

  /// The parsing rules used to interpret text contents and extract properties from the note.
  var parsingRules: ParsingRules { get }

  // MARK: - Direct property manipulation

  // Often, the note properties are implicitly updated when note content changes. However, to
  // support some kinds of notes (like "vocabulary lists" as an experiment), we allow direct
  // manipulation of the note properties.

  /// Creates a new note to contain the given note properties.
  func insertNoteProperties(_ noteProperties: NoteProperties) -> NoteIdentifier

  /// Replaces the note properties for an existing note.
  func setNoteProperties(for noteIdentifier: NoteIdentifier, to noteProperties: NoteProperties)

  // MARK: - Challenge template manipulation

  /// Inserts a new challenge template into the store.
  func insertChallengeTemplate(_ challengeTemplate: ChallengeTemplate) throws -> ChallengeTemplateArchiveKey

  /// Retrieves a challenge template.
  func challengeTemplate(for keyString: String) -> ChallengeTemplate?

  // MARK: - Text contents

  /// Gets the current text contents for a note.
  func currentTextContents(for noteIdentifier: NoteIdentifier) throws -> String

  /// Changes the text contents for a note.
  func changeTextContents(for noteIdentifier: NoteIdentifier, to text: String)

  // MARK: - Asset storage.

  /// Gets data contained in a file wrapper
  /// - parameter fileWrapperKey: A path to a named file wrapper. E.g., "assets/image.png"
  /// - returns: The data contained in that wrapper if it exists, nil otherwise.
  func data<S: StringProtocol>(for fileWrapperKey: S) -> Data?

  /// Stores asset data into the document.
  /// - parameter data: The asset data to store
  /// - parameter typeHint: A hint about the data type, e.g., "jpeg" -- will be used for the data key
  /// - returns: A key that can be used to get the data later.
  func storeAssetData(_ data: Data, typeHint: String) -> String

  // MARK: - Study sessions

  /// Update the notebook with the result of a study session.
  ///
  /// - parameter studySession: The completed study session.
  /// - parameter date: The date the study session took place.
  func updateStudySessionResults(_ studySession: StudySession, on date: Date)

  /// The complete record of all study sessions.
  var studyLog: StudyLog { get }

  // MARK: - Importing

  func importFileMetadataItems(
    _ items: [FileMetadata],
    from metadataProvider: FileMetadataProvider,
    importDate: Date,
    completion: (() -> Void)?
  )
}

extension NoteStorage {
  /// Computes a studySession for the relevant pages in the notebook.
  /// - parameter filter: An optional filter closure to determine if the page's challenges should be included in the session. If nil, all pages are included.
  /// - parameter date: An optional date for determining challenge eligibility. If nil, will be today's date.
  /// - parameter completion: A completion routine to get the StudySession. Will be called on the main thread.
  public func studySession(
    filter: ((NoteIdentifier, NoteProperties) -> Bool)? = nil,
    date: Date = Date(),
    completion: @escaping (StudySession) -> Void
  ) {
    DispatchQueue.global(qos: .default).async {
      let result = self.synchronousStudySession(filter: filter, date: date)
      DispatchQueue.main.async {
        completion(result)
      }
    }
  }

  /// Blocking function that gets the study session. Safe to call from background threads. Only `internal` and not `private` so tests can call it.
  // TODO: On debug builds, this is *really* slow. Worth optimizing.
  internal func synchronousStudySession(
    filter: ((NoteIdentifier, NoteProperties) -> Bool)? = nil,
    date: Date = Date()
  ) -> StudySession {
    let filter = filter ?? { _, _ in true }
    let suppressionDates = studyLog.identifierSuppressionDates()
    return noteProperties
      .filter { filter($0.key, $0.value) }
      .map { (name, reviewProperties) -> StudySession in
        let challengeTemplates = reviewProperties.cardTemplates
          .compactMap(challengeTemplate(for:))
        // TODO: Filter down to eligible cards
        let eligibleCards = challengeTemplates.cards
          .filter { challenge -> Bool in
            guard let suppressionDate = suppressionDates[challenge.challengeIdentifier] else {
              return true
            }
            return date >= suppressionDate
          }
        return StudySession(
          eligibleCards,
          properties: CardDocumentProperties(
            documentName: name,
            attributionMarkdown: reviewProperties.title,
            parsingRules: self.parsingRules
          )
        )
      }
      .reduce(into: StudySession()) { $0 += $1 }
  }

  /// All hashtags used across all pages, sorted.
  public var hashtags: [String] {
    let hashtags = noteProperties.values.reduce(into: Set<String>()) { hashtags, props in
      hashtags.formUnion(props.hashtags)
    }
    return Array(hashtags).sorted()
  }

  /// Adds a renderer tthat knows how to render images using assets from this document
  /// - parameter renderers: The collection of render functions
  public func addImageRenderer(to renderers: inout [NodeType: RenderedMarkdown.RenderFunction]) {
    renderers[.image] = { [weak self] node, attributes in
      guard
        let self = self,
        let imageNode = node as? Image,
        let data = self.data(for: imageNode.url),
        let image = data.image(maxSize: 200)
      else {
        return NSAttributedString(string: node.markdown, attributes: attributes)
      }
      let attachment = NSTextAttachment()
      attachment.image = image
      return NSAttributedString(attachment: attachment)
    }
  }
}

private extension Data {
  func image(maxSize: CGFloat) -> UIImage? {
    guard let imageSource = CGImageSourceCreateWithData(self as CFData, nil) else {
      return nil
    }
    let options: [NSString: NSObject] = [
      kCGImageSourceThumbnailMaxPixelSize: maxSize as NSObject,
      kCGImageSourceCreateThumbnailFromImageAlways: true as NSObject,
      kCGImageSourceCreateThumbnailWithTransform: true as NSObject,
    ]
    let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary?).flatMap { UIImage(cgImage: $0) }
    return image
  }
}
