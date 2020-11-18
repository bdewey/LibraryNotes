// Copyright © 2017-present Brian's Brain. All rights reserved.

import Combine
import Foundation
import UIKit

/// Abstract interface for something that can store notes, challenges, and study logs, and can also generate study sessions.
public protocol NoteStorage: AnyObject {
  /// The URL for the storage.
  var fileURL: URL { get }

  /// Metadata for all notes in the store.
  var allMetadata: [Note.Identifier: Note.Metadata] { get }

  /// This publisher sends a signal whenver `noteProperties` changed.
  var notesDidChange: AnyPublisher<Void, Never> { get }

  func makeIdentifier() -> FlakeID

  /// Gets a note with a specific identifier.
  func note(noteIdentifier: Note.Identifier) throws -> Note

  /// Updates a note.
  /// - parameter noteIdentifier: The identifier of the note to update.
  /// - parameter updateBlock: A block that receives the current value of the note and returns the updated value.
  func updateNote(noteIdentifier: Note.Identifier, updateBlock: (Note) -> Note) throws

  /// Creates a new note.
  func createNote(_ note: Note) throws -> Note.Identifier

  /// Deletes a note.
  func deleteNote(noteIdentifier: Note.Identifier) throws

  /// Retrieve a specific challenge.
  // TODO: When I stop supporting NoteDocumentStorage, I'll no longer need the noteIdentifier.
  func challenge(
    noteIdentifier: Note.Identifier,
    challengeIdentifier: ChallengeIdentifier
  ) throws -> Challenge

  func eligibleChallengeIdentifiers(
    before date: Date,
    limitedTo noteIdentifier: Note.Identifier?
  ) throws -> [ChallengeIdentifier]

  func search(for searchPattern: String) throws -> [Note.Identifier]

  /// Open the storage.
  func open(completionHandler: ((Bool) -> Void)?)

  /// Close the storage.
  func close(completionHandler: ((Bool) -> Void)?)

  /// Ensure contents are saved to stable storage.
  func flush() throws

  /// Attempt to pull new content from iCloud.
  func refresh(completionHandler: ((Bool) -> Void)?)

  // MARK: - Asset storage.

  /// Gets data contained in a file wrapper
  /// - parameter fileWrapperKey: A path to a named file wrapper. E.g., "assets/image.png"
  /// - returns: The data contained in that wrapper if it exists, nil otherwise.
  func data<S: StringProtocol>(for fileWrapperKey: S) throws -> Data?

  /// All assets.
  var assetKeys: [String] { get }

  /// Stores asset data into the document.
  /// - parameter data: The asset data to store
  /// - parameter typeHint: A hint about the data type, e.g., "jpeg" -- will be used for the data key
  /// - returns: A key that can be used to get the data later.
  func storeAssetData(_ data: Data, key: String) throws -> String

  // MARK: - Study sessions

  func recordStudyEntry(_ entry: StudyLog.Entry, buryRelatedChallenges: Bool) throws

  /// The complete record of all study sessions.
  var studyLog: StudyLog { get }
}

extension NoteStorage {
  /// Computes a studySession for the relevant pages in the notebook.
  /// - parameter filter: An optional filter closure to determine if the page's challenges should be included in the session. If nil, all pages are included.
  /// - parameter date: An optional date for determining challenge eligibility. If nil, will be today's date.
  /// - parameter completion: A completion routine to get the StudySession. Will be called on the main thread.
  public func studySession(
    filter: ((Note.Identifier, Note.Metadata) -> Bool)? = nil,
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
    filter: ((Note.Identifier, Note.Metadata) -> Bool)? = nil,
    date: Date = Date()
  ) -> StudySession {
    let filter = filter ?? { _, _ in true }
    return allMetadata
      .filter { filter($0.key, $0.value) }
      .map { (name, reviewProperties) -> StudySession in
        let challengeIdentifiers = try? eligibleChallengeIdentifiers(before: date, limitedTo: name)
        return StudySession(
          challengeIdentifiers ?? [],
          properties: CardDocumentProperties(
            documentName: name,
            attributionMarkdown: reviewProperties.title
          )
        )
      }
      .reduce(into: StudySession()) { $0 += $1 }
  }

  /// Update the notebook with the result of a study session.
  ///
  /// - parameter studySession: The completed study session.
  /// - parameter date: The date the study session took place.
  func updateStudySessionResults(_ studySession: StudySession, on date: Date, buryRelatedChallenges: Bool) throws {
    let entries = studySession.results.map { tuple -> StudyLog.Entry in
      StudyLog.Entry(timestamp: date, identifier: tuple.key, statistics: tuple.value)
    }
    for entry in entries {
      try recordStudyEntry(entry, buryRelatedChallenges: buryRelatedChallenges)
    }
  }

  /// All hashtags used across all pages, sorted.
  public var hashtags: [String] {
    let hashtags = allMetadata.values.reduce(into: Set<String>()) { hashtags, props in
      hashtags.formUnion(props.hashtags)
    }
    return Array(hashtags).sorted()
  }

  // TODO: Bring this back in the new architecture
  /// Adds a renderer tthat knows how to render images using assets from this document
  /// - parameter renderers: The collection of render functions
//  public func addImageRenderer(to renderers: inout [NodeType: RenderedMarkdown.RenderFunction]) {
//    renderers[.image] = { [weak self] node, attributes in
//      guard
//        let self = self,
//        let imageNode = node as? Image,
//        let data = try? self.data(for: imageNode.url),
//        let image = data.image(maxSize: 200)
//      else {
//        return NSAttributedString(string: node.markdown, attributes: attributes)
//      }
//      let attachment = NSTextAttachment()
//      attachment.image = image
//      return NSAttributedString(attachment: attachment)
//    }
//  }
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
