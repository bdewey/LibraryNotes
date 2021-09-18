// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

@testable import LibraryNotes
import KeyValueCRDT
import XCTest

/// Specific test cases around merging database content.
final class NoteSqliteStorageMergeTests: XCTestCase {
  /// If you copy a file, then try to merge it in, nothing happens.
  func testNoopMerge() async throws {
    var noteIdentifier: Note.Identifier!
    try await MergeTestCase()
      .withInitialState { storage in
        noteIdentifier = try storage.createNote(.withChallenges)
      }
      .validate { localStorage in
        XCTAssertFalse(localStorage.hasUnsavedChanges)
        XCTAssertEqual(try localStorage.note(noteIdentifier: noteIdentifier), Note.withChallenges)
      }
      .run(self)
  }

  func testRemoteCreationGetsIntegrated() async throws {
    var simpleIdentifier: Note.Identifier!
    var challengeIdentifier: Note.Identifier!

    try await MergeTestCase()
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

  func testRemoteHashtagGetsDeleted() async throws {
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
    try await MergeTestCase()
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
        XCTAssertEqual(storage.bookMetadata.count, 1)
      }
      .run(self)
  }

  func testRemoteStudyOfLocalPageGetsIncorporated() async throws {
    try await MergeTestCase()
      .withInitialState { storage in
        _ = try storage.createNote(.withChallenges)
      }
      .performRemoteModification { storage in
        // New items aren't eligible for at 3-5 days.
        let future = Date().addingTimeInterval(5 * 24 * 60 * 60)
        var studySession = try await storage.studySession(filter: nil, date: future)
        XCTAssertEqual(3, studySession.count)
        while studySession.currentPrompt != nil {
          studySession.recordAnswer(correct: true)
        }
        try storage.updateStudySessionResults(studySession, on: future, buryRelatedPrompts: true)
        XCTAssertTrue(storage.hasUnsavedChanges)
        XCTAssertEqual(storage.studyLog.count, studySession.count)
      }
      .validate { storage in
        XCTAssertTrue(storage.hasUnsavedChanges)
        let future = Date().addingTimeInterval(5 * 24 * 60 * 60)
        let studySession = try await storage.studySession(filter: nil, date: future)
        XCTAssertEqual(0, studySession.count)
      }
      .run(self)
  }

  func testRemoteStudyOfRemotePageGetsIncorporated() async throws {
    try await MergeTestCase()
      .performRemoteModification { storage in
        _ = try storage.createNote(.withChallenges)
        // New items aren't eligible for at 3-5 days.
        let future = Date().addingTimeInterval(5 * 24 * 60 * 60)
        var studySession = try await storage.studySession(filter: nil, date: future)
        XCTAssertEqual(3, studySession.count)
        while studySession.currentPrompt != nil {
          studySession.recordAnswer(correct: true)
        }
        try storage.updateStudySessionResults(studySession, on: future, buryRelatedPrompts: true)
        XCTAssertTrue(storage.hasUnsavedChanges)
        XCTAssertEqual(storage.studyLog.count, studySession.count)
      }
      .validate { storage in
        XCTAssertTrue(storage.hasUnsavedChanges)
        let future = Date().addingTimeInterval(5 * 24 * 60 * 60)
        let studySession = try await storage.studySession(filter: nil, date: future)
        XCTAssertEqual(0, studySession.count)
        XCTAssertEqual(1, storage.bookMetadata.count)
        let futureStudySession = try await storage.studySession(filter: nil, date: future.addingTimeInterval(30 * 24 * 60 * 60))
        XCTAssertEqual(3, futureStudySession.count)
      }
      .run(self)
  }

  func testLocalChangeIsPreserved() async throws {
    var simpleIdentifier: Note.Identifier!
    var modifiedNote = Note(markdown: "Updated! #hashtag")
    modifiedNote.metadata.modifiedTimestamp = Date().addingTimeInterval(60)
    try await MergeTestCase()
      .withInitialState { storage in
        simpleIdentifier = try storage.createNote(.simpleTest)
      }
      .performLocalModification { storage in
        try storage.updateNote(noteIdentifier: simpleIdentifier) { _ in modifiedNote }
      }
      .validate { storage in
        XCTAssertTrue(storage.hasUnsavedChanges)
        XCTAssertEqual(try storage.note(noteIdentifier: simpleIdentifier), modifiedNote)
        XCTAssertEqual(storage.bookMetadata.count, 1)
      }
      .run(self)
  }

  func testRemoteChangeGetsCopied() async throws {
    var simpleIdentifier: Note.Identifier!
    var modifiedNote = Note(markdown: "Updated! #hashtag")
    modifiedNote.metadata.modifiedTimestamp = Date().addingTimeInterval(60)

    try await MergeTestCase()
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

  func testLastWriterWins() async throws {
    var simpleIdentifier: Note.Identifier!
    var modifiedNote = Note(markdown: "Updated! #hashtag")
    modifiedNote.metadata.modifiedTimestamp = Date().addingTimeInterval(60)
    var conflictingNote = Note(markdown: "I'm going to win! #winning")
    conflictingNote.metadata.modifiedTimestamp = Date().addingTimeInterval(120)

    try await MergeTestCase()
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
  typealias StorageModificationBlock = (NoteDatabase) async throws -> Void
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

  func run(_ runner: NoteSqliteStorageMergeTests) async throws {
    try await runner.runKeyValueTestCase(self)
  }
}

private extension NoteSqliteStorageMergeTests {
  static func openKeyValueDatabase(
    device: TestDevice,
    fileURL: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  ) async throws -> NoteDatabase {
    return try await NoteDatabase(
      fileURL: fileURL,
      authorDescription: device.name
    )
  }

  func runKeyValueTestCase(_ testCase: MergeTestCase) async throws {
    let localURL = try await makeKeyValueFile(device: .local, modificationBlock: testCase.initialLocalStorageBlock)
    let remoteURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.copyItem(at: localURL, to: remoteURL)
    let localStorage = try await Self.openKeyValueDatabase(device: .local, fileURL: localURL)
    let remoteStorage = try await Self.openKeyValueDatabase(device: .remote, fileURL: remoteURL)
    try await testCase.localModificationBlock?(localStorage)
    try await testCase.remoteModificationBlock?(remoteStorage)
    _ = try localStorage.merge(other: remoteStorage)
    try await testCase.validationBlock?(localStorage)
  }

  func makeKeyValueFile(
    device: TestDevice,
    modificationBlock: MergeTestCase.StorageModificationBlock?
  ) async throws -> URL {
    let database = try await Self.openKeyValueDatabase(device: device)
    try await modificationBlock?(database)
    if await !database.close() {
      throw TestError.couldNotCloseDatabase
    }
    return database.fileURL
  }
}

extension NoteDatabase {
  func studySession(filter: ((Note.Identifier, BookNoteMetadata) -> Bool)?, date: Date) async throws -> StudySession {
    let sessionGenerator = SessionGenerator(database: self)
    try await sessionGenerator.startMonitoringDatabase()
    return try await sessionGenerator.studySession(filter: filter, date: date)
  }
}
