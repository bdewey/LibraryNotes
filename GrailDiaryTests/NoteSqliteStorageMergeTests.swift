// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Combine
@testable import GrailDiary
import KeyValueCRDT
import XCTest

/// Specific test cases around merging database content.
final class NoteSqliteStorageMergeTests: XCTestCase {
  /// If you copy a file, then try to merge it in, nothing happens.
  func testNoopMerge() {
    var noteIdentifier: Note.Identifier!
    MergeTestCase()
      .withInitialState { storage in
        noteIdentifier = try storage.createNote(.withChallenges)
      }
      .validate { localStorage in
        XCTAssertFalse(localStorage.hasUnsavedChanges)
        XCTAssertEqual(try localStorage.note(noteIdentifier: noteIdentifier), Note.withChallenges)
      }
      .run(self)
  }

  func testRemoteCreationGetsIntegrated() {
    var simpleIdentifier: Note.Identifier!
    var challengeIdentifier: Note.Identifier!

    MergeTestCase()
      .withInitialState { storage in
        simpleIdentifier = try storage.createNote(.simpleTest)
      }
      .performRemoteModification { storage in
        challengeIdentifier = try storage.createNote(.withChallenges)
      }
      .validate { storage in
        XCTAssertTrue(storage.hasUnsavedChanges)
        XCTAssertEqual(try storage.note(noteIdentifier: simpleIdentifier), Note.simpleTest)
        XCTAssertEqual(try storage.note(noteIdentifier: challengeIdentifier), Note.withChallenges)
      }
      .run(self)
  }

  func testRemoteHashtagGetsDeleted() {
    let initialText = """
    # Test content

    #testing

    > We have a quote challenge template.

    """
    let withoutHashtagText = """
    # Test content

    > We have a quote challenge template.

    """
    var noteIdentifier: Note.Identifier!
    let withoutHashtagNote = Note(markdown: withoutHashtagText)
    MergeTestCase()
      .withInitialState { storage in
        noteIdentifier = try storage.createNote(Note(markdown: initialText))
      }
      .performRemoteModification { storage in
        do {
          try storage.updateNote(noteIdentifier: noteIdentifier) { _ in withoutHashtagNote }
        } catch {
          print("Unexpected error updating note: \(error)")
        }
      }
      .validate { storage in
        XCTAssertTrue(storage.hasUnsavedChanges)
        XCTAssertEqual(try storage.note(noteIdentifier: noteIdentifier), withoutHashtagNote)
        XCTAssertEqual(try storage.bookMetadata.count, 1)
      }
      .run(self)
  }

  func testRemoteStudyOfLocalPageGetsIncorporated() {
    MergeTestCase()
      .withInitialState { storage in
        _ = try storage.createNote(.withChallenges)
      }
      .performRemoteModification { storage in
        // New items aren't eligible for at 3-5 days.
        let future = Date().addingTimeInterval(5 * 24 * 60 * 60)
        var studySession = storage.synchronousStudySession(filter: nil, date: future)
        XCTAssertEqual(3, studySession.count)
        while studySession.currentPrompt != nil {
          studySession.recordAnswer(correct: true)
        }
        try storage.updateStudySessionResults(studySession, on: Date(), buryRelatedPrompts: true)
        XCTAssertTrue(storage.hasUnsavedChanges)
        XCTAssertEqual(storage.studyLog.count, studySession.count)
      }
      .validate { storage in
        XCTAssertTrue(storage.hasUnsavedChanges)
        let future = Date().addingTimeInterval(5 * 24 * 60 * 60)
        let studySession = storage.synchronousStudySession(filter: nil, date: future)
        XCTAssertEqual(0, studySession.count)
      }
      .run(self)
  }

  func testRemoteStudyOfRemotePageGetsIncorporated() {
    MergeTestCase()
      .performRemoteModification { storage in
        _ = try storage.createNote(.withChallenges)
        // New items aren't eligible for at 3-5 days.
        let future = Date().addingTimeInterval(5 * 24 * 60 * 60)
        var studySession = storage.synchronousStudySession(filter: nil, date: future)
        XCTAssertEqual(3, studySession.count)
        while studySession.currentPrompt != nil {
          studySession.recordAnswer(correct: true)
        }
        try storage.updateStudySessionResults(studySession, on: Date(), buryRelatedPrompts: true)
        XCTAssertTrue(storage.hasUnsavedChanges)
        XCTAssertEqual(storage.studyLog.count, studySession.count)
      }
      .validate { storage in
        XCTAssertTrue(storage.hasUnsavedChanges)
        let future = Date().addingTimeInterval(5 * 24 * 60 * 60)
        let studySession = storage.synchronousStudySession(filter: nil, date: future)
        XCTAssertEqual(0, studySession.count)
        XCTAssertEqual(1, try storage.bookMetadata.count)
        let futureStudySession = storage.synchronousStudySession(filter: nil, date: future.addingTimeInterval(30 * 24 * 60 * 60))
        XCTAssertEqual(3, futureStudySession.count)
      }
      .run(self)
  }

  func testLocalChangeIsPreserved() {
    var simpleIdentifier: Note.Identifier!
    var modifiedNote = Note(markdown: "Updated! #hashtag")
    modifiedNote.timestamp = Date().addingTimeInterval(60)
    MergeTestCase()
      .withInitialState { storage in
        simpleIdentifier = try storage.createNote(.simpleTest)
      }
      .performLocalModification { storage in
        try storage.updateNote(noteIdentifier: simpleIdentifier) { _ in modifiedNote }
      }
      .validate { storage in
        XCTAssertTrue(storage.hasUnsavedChanges)
        XCTAssertEqual(try storage.note(noteIdentifier: simpleIdentifier), modifiedNote)
        XCTAssertEqual(try storage.bookMetadata.count, 1)
      }
      .run(self)
  }

  func testRemoteChangeGetsCopied() {
    var simpleIdentifier: Note.Identifier!
    var modifiedNote = Note(markdown: "Updated! #hashtag")
    modifiedNote.timestamp = Date().addingTimeInterval(60)

    MergeTestCase()
      .withInitialState { storage in
        simpleIdentifier = try storage.createNote(.simpleTest)
      }
      .performRemoteModification { storage in
        try storage.updateNote(noteIdentifier: simpleIdentifier) { _ in modifiedNote }
      }
      .validate { storage in
        XCTAssertTrue(storage.hasUnsavedChanges)
        XCTAssertEqual(try storage.note(noteIdentifier: simpleIdentifier), modifiedNote)
      }
      .run(self)
  }

  func testLastWriterWins() {
    var simpleIdentifier: Note.Identifier!
    var modifiedNote = Note(markdown: "Updated! #hashtag")
    modifiedNote.timestamp = Date().addingTimeInterval(60)
    var conflictingNote = Note(markdown: "I'm going to win! #winning")
    conflictingNote.timestamp = Date().addingTimeInterval(120)

    MergeTestCase()
      .withInitialState { storage in
        simpleIdentifier = try storage.createNote(.simpleTest)
      }
      .performLocalModification { storage in
        try storage.updateNote(noteIdentifier: simpleIdentifier) { _ in modifiedNote }
      }
      .performRemoteModification { storage in
        try storage.updateNote(noteIdentifier: simpleIdentifier) { _ in conflictingNote }
      }
      .validate { storage in
        XCTAssertTrue(storage.hasUnsavedChanges)
        XCTAssertEqual(try storage.note(noteIdentifier: simpleIdentifier), conflictingNote)
      }
      .run(self)
  }
}

private struct TestDevice {
  let name: String
  let identifierForVendor: UUID? = UUID()

  static let local = TestDevice(name: "local")
  static let remote = TestDevice(name: "remote")
}

private struct MergeTestCase {
  typealias StorageModificationBlock = (NoteDatabase) throws -> Void
  var initialLocalStorageBlock: StorageModificationBlock?
  var localModificationBlock: StorageModificationBlock?
  var remoteModificationBlock: StorageModificationBlock?
  var validationBlock: StorageModificationBlock?

  func withInitialState(_ block: @escaping StorageModificationBlock) -> Self {
    var copy = self
    copy.initialLocalStorageBlock = block
    return copy
  }

  func performLocalModification(_ block: @escaping StorageModificationBlock) -> Self {
    var copy = self
    copy.localModificationBlock = block
    return copy
  }

  func performRemoteModification(_ block: @escaping StorageModificationBlock) -> Self {
    var copy = self
    copy.remoteModificationBlock = block
    return copy
  }

  func validate(_ validationBlock: @escaping StorageModificationBlock) -> Self {
    var copy = self
    copy.validationBlock = validationBlock
    return copy
  }

  func run(_ runner: NoteSqliteStorageMergeTests) {
    runner.runKeyValueTestCase(self)
  }
}

private extension NoteSqliteStorageMergeTests {
  static func openKeyValueDatabase(
    device: TestDevice,
    fileURL: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  ) -> Future<NoteDatabase, Error> {
    return Future<NoteDatabase, Error> { promise in
      do {
        let database = try NoteDatabase(
          fileURL: fileURL,
          author: Author(id: device.identifierForVendor!, name: device.name)
        )
        database.open { _ in
          promise(.success(database))
        }
      } catch {
        promise(.failure(error))
      }
    }
  }

  func runKeyValueTestCase(_ testCase: MergeTestCase) {
    let pipelineRan = expectation(description: "pipeline ran")
    let cancelable = makeKeyValueFile(device: .local, modificationBlock: testCase.initialLocalStorageBlock)
      .tryMap { localURL -> (URL, URL) in
        let remoteURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: localURL, to: remoteURL)
        return (localURL, remoteURL)
      }
      .flatMap { tuple in
        Self.openKeyValueDatabase(device: .local, fileURL: tuple.0).map { ($0, tuple.1) }
      }
      .flatMap { tuple in
        Self.openKeyValueDatabase(device: .remote, fileURL: tuple.1).map { (tuple.0, $0) }
      }
      .tryMap { localStorage, remoteStorage -> Bool in
        try testCase.localModificationBlock?(localStorage)
        try testCase.remoteModificationBlock?(remoteStorage)
        _ = try localStorage.merge(other: remoteStorage)
        try testCase.validationBlock?(localStorage)
        return true
      }
      .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          break
        case .failure(let error):
          XCTFail("Unexpected error: \(error)")
        }
        pipelineRan.fulfill()
      }, receiveValue: { _ in })
    waitForExpectations(timeout: 300, handler: nil)
    // cancel() should be a no-op
    cancelable.cancel()
  }

  func makeKeyValueFile(
    device: TestDevice,
    modificationBlock: MergeTestCase.StorageModificationBlock?
  ) -> AnyPublisher<URL, Error> {
    Self.openKeyValueDatabase(device: device)
      .tryMap { database -> NoteDatabase in
        try modificationBlock?(database)
        return database
      }
      .flatMap { database -> Future<URL, Error> in
        Future { promise in
          database.close { _ in
            promise(.success(database.fileURL))
          }
        }
      }
      .eraseToAnyPublisher()
  }
}
