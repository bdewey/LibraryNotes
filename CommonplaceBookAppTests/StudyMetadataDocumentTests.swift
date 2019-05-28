// Copyright © 2019 Brian's Brain. All rights reserved.
// swiftlint:disable force_try

@testable import CommonplaceBookApp
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

  func testLoadStudySessions() {
    let file = try! TemporaryFile(creatingTempDirectoryForFilename: "notebook.review")
    defer { try? file.deleteDirectory() }
    let document = openDocument(fileURL: file.fileURL)
    loadAllPages(into: document)
    XCTAssertEqual(document.noteBundle.studySession().count, 11)
    XCTAssertEqual(
      document.noteBundle.studySession(filter: { $1.hashtags.contains("#inspiration") }).count,
      2
    )
  }

  func testCreateStudyRecords() {
    let file = try! TemporaryFile(creatingTempDirectoryForFilename: "notebook.review")
    defer { try? file.deleteDirectory() }
    let document = openDocument(fileURL: file.fileURL)
    loadAllPages(into: document)
    let previousLogCount = document.noteBundle.log.count
    var studySession = document.noteBundle.studySession()
    XCTAssertEqual(studySession.count, 11)
    while studySession.currentCard != nil {
      studySession.recordAnswer(correct: true)
    }
    document.updateStudySessionResults(studySession)
    XCTAssertEqual(document.noteBundle.log.count, previousLogCount + studySession.count)

    // Make sure the study records round-trip.
    closeDocument(document)
    let newDocument = openDocument(fileURL: file.fileURL)
    XCTAssertEqual(newDocument.noteBundle.log.count, previousLogCount + studySession.count)

    // Shouldn't have anything new to study today.
    let repeatSession = newDocument.noteBundle.studySession()
    XCTAssertEqual(repeatSession.count, 0)
  }
}

extension StudyMetadataDocumentTests {
  private func verifyDocument(
    _ document: NoteBundleDocument,
    pageCount: Int,
    challengeTemplateCount: Int,
    logCount: Int
  ) {
    XCTAssertEqual(document.noteBundle.pageProperties.count, pageCount)
    XCTAssertEqual(document.noteBundle.challengeTemplates.count, challengeTemplateCount)
    XCTAssertEqual(document.noteBundle.log.count, logCount)
  }

  private func openDocument(fileURL: URL) -> NoteBundleDocument {
    let document = NoteBundleDocument(
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

  private func closeDocument(_ document: NoteBundleDocument) {
    let didClose = expectation(description: "did close")
    document.close { success in
      XCTAssertTrue(success)
      didClose.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
  }

  private func loadAllPages(into document: NoteBundleDocument, expectToLoad: Bool = true) {
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

#books

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

#books #inspiration

> We had to learn for ourselves and, furthermore, we had to teach the despairing men, that ?[](it did not really matter what we expected from life, but rather what life expected from us).
"""
