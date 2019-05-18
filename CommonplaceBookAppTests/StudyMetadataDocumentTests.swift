// Copyright © 2019 Brian's Brain. All rights reserved.
// swiftlint:disable force_try

import CommonplaceBookApp
import FlashcardKit
import MiniMarkdown
import XCTest

final class StudyMetadataDocumentTests: XCTestCase {
  var metadataProvider: TestMetadataProvider!

  override func setUp() {
    metadataProvider = TestMetadataProvider(
      fileInfo: [
        TestMetadataProvider.FileInfo(fileName: "page1.txt", contents: "Sample #hashtag #test1"),
        TestMetadataProvider.FileInfo(fileName: "page2.txt", contents: "Sample #hashtag #test2"),
        TestMetadataProvider.FileInfo(fileName: "educated.txt", contents: educatedText),
        TestMetadataProvider.FileInfo(fileName: "mans-search.txt", contents: msfmText),
      ],
      parsingRules: parsingRules
    )
  }

  let parsingRules: ParsingRules = {
    var parsingRules = ParsingRules()
    parsingRules.inlineParsers.parsers.insert(Cloze.nodeParser, at: 0)
    return parsingRules
  }()

  func testRoundTripDocument() {
    let file = try! TemporaryFile(creatingTempDirectoryForFilename: "notebook.review")
    defer { try? file.deleteDirectory() }
    let document = openDocument(fileURL: file.fileURL)
    loadAllPages(into: document)
    let expectedChallengeTemplateCount = 10
    verifyDocument(
      document,
      pageCount: metadataProvider.fileMetadata.count,
      challengeTemplateCount: expectedChallengeTemplateCount,
      logCount: metadataProvider.fileMetadata.count + expectedChallengeTemplateCount
    )
    closeDocument(document)

    let roundTripDocument = openDocument(fileURL: file.fileURL)
    verifyDocument(
      roundTripDocument,
      pageCount: metadataProvider.fileMetadata.count,
      challengeTemplateCount: expectedChallengeTemplateCount,
      logCount: metadataProvider.fileMetadata.count + expectedChallengeTemplateCount
    )

    // Re-importing pages shouldn't change anything. I already have this data.
    loadAllPages(into: roundTripDocument, expectToLoad: false)
    verifyDocument(
      roundTripDocument,
      pageCount: metadataProvider.fileMetadata.count,
      challengeTemplateCount: expectedChallengeTemplateCount,
      logCount: metadataProvider.fileMetadata.count + expectedChallengeTemplateCount
    )
    closeDocument(roundTripDocument)
  }
}

extension StudyMetadataDocumentTests {
  private func verifyDocument(
    _ document: StudyMetadataDocument,
    pageCount: Int,
    challengeTemplateCount: Int,
    logCount: Int
  ) {
    XCTAssertEqual(document.pageProperties.count, pageCount)
    XCTAssertEqual(document.challengeTemplates.count, challengeTemplateCount)
    XCTAssertEqual(document.log.count, logCount)
  }

  private func openDocument(fileURL: URL) -> StudyMetadataDocument {
    let document = StudyMetadataDocument(
      fileURL: fileURL,
      parsingRules: parsingRules
    )
    let didOpen = expectation(description: "did open")
    document.openOrCreate { success in
      XCTAssertTrue(success)
      didOpen.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
    return document
  }

  private func closeDocument(_ document: StudyMetadataDocument) {
    let didClose = expectation(description: "did close")
    document.close { success in
      XCTAssertTrue(success)
      didClose.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
  }

  private func loadAllPages(into document: StudyMetadataDocument, expectToLoad: Bool = true) {
    let group = DispatchGroup()
    for fileInfo in metadataProvider.fileMetadata {
      group.enter()
      document.updatePage(
        for: fileInfo,
        in: metadataProvider,
        completion: { (didLoad) in
          XCTAssertEqual(didLoad, expectToLoad)
          group.leave()
        }
      )
    }
    let allLoadsFinished = expectation(description: "Loaded all pages")
    group.notify(queue: .main, execute: { allLoadsFinished.fulfill() })
    waitForExpectations(timeout: 3, handler: nil)
  }
}

// swiftlint:disable line_length

private let educatedText = """
# *Educated*, Tara Westover

* The author of *Educated* is ?[](Tara Westover).
* *Educated* takes place at ?[mountain name](Buck’s Peak), in ?[state](Idaho).
* Tara Westover did her undergraduate education at ?[collage](BYU).

## Quotes

> It’s a tranquillity born of sheer immensity; it calms with its very magnitude, which renders the merely human of no consequence. (26)

> Ain’t nothin’ funnier than real life, I tell you what. (34)

> Choices, numberless as grains of sand, had layered and compressed, coalescing into sediment, then into rock, until all was set in stone. (35)

> My brothers were like a pack of wolves. They tested each other constantly, with scuffles breaking out every time some young pup hit a growth spurt and dreamed of moving up. (43)

> In retrospect, I see that this was my education, the one that would matter: the hours I spent sitting at a borrowed desk, struggling to parse narrow strands of Mormon doctrine in mimicry of a brother who’d deserted me. The skill I was learning was a crucial one, the patience to read things I could not yet understand. (62)

"""

private let msfmText = """
# *Man's Search for Meaning*, Viktor E. Frankl

> We had to learn for ourselves and, furthermore, we had to teach the despairing men, that ?[](it did not really matter what we expected from life, but rather what life expected from us).
"""
// From https://oleb.net/blog/2018/03/temp-file-helper/

// A wrapper around a temporary file in a temporary directory. The directory
/// has been especially created for the file, so it's safe to delete when you're
/// done working with the file.
///
/// Call `deleteDirectory` when you no longer need the file.
struct TemporaryFile {
  let directoryURL: URL
  let fileURL: URL
  /// Deletes the temporary directory and all files in it.
  let deleteDirectory: () throws -> Void

  /// Creates a temporary directory with a unique name and initializes the
  /// receiver with a `fileURL` representing a file named `filename` in that
  /// directory.
  ///
  /// - Note: This doesn't create the file!
  init(creatingTempDirectoryForFilename filename: String) throws {
    let (directory, deleteDirectory) = try FileManager.default
      .urlForUniqueTemporaryDirectory()
    self.directoryURL = directory
    self.fileURL = directory.appendingPathComponent(filename)
    self.deleteDirectory = deleteDirectory
  }
}

extension FileManager {
  /// Creates a temporary directory with a unique name and returns its URL.
  ///
  /// - Returns: A tuple of the directory's URL and a delete function.
  ///   Call the function to delete the directory after you're done with it.
  ///
  /// - Note: You should not rely on the existence of the temporary directory
  ///   after the app is exited.
  func urlForUniqueTemporaryDirectory(preferredName: String? = nil) throws
    -> (url: URL, deleteDirectory: () throws -> Void)
  {
    let basename = preferredName ?? UUID().uuidString

    var counter = 0
    var createdSubdirectory: URL? = nil
    repeat {
      do {
        let subdirName = counter == 0 ? basename : "\(basename)-\(counter)"
        let subdirectory = temporaryDirectory
          .appendingPathComponent(subdirName, isDirectory: true)
        try createDirectory(at: subdirectory, withIntermediateDirectories: false)
        createdSubdirectory = subdirectory
      } catch CocoaError.fileWriteFileExists {
        // Catch file exists error and try again with another name.
        // Other errors propagate to the caller.
        counter += 1
      }
    } while createdSubdirectory == nil

    let directory = createdSubdirectory!
    let deleteDirectory: () throws -> Void = {
      try self.removeItem(at: directory)
    }
    return (directory, deleteDirectory)
  }
}
