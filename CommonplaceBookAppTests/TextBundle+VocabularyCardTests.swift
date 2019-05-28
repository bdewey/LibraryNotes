// Copyright © 2018-present Brian's Brain. All rights reserved.

@testable import CommonplaceBookApp
@testable import TextBundleKit
import XCTest

private let markdownWithOtherContents = """
# Unit One Vocabulary

| Spanish | Engish |
| ------- | ------ |
| tenedor | fork   |
| hombre  | man    |
| mujer   | woman  |
| niño    | boy    |
| niña    | girl   |

## Notes

- I should be able make notes and not lose them when I save vocabulary.

"""

private let sampleAssociations = [
  VocabularyAssociation(spanish: "tenedor", english: "fork"),
  VocabularyAssociation(spanish: "hombre", english: "man"),
  VocabularyAssociation(spanish: "mujer", english: "woman"),
  VocabularyAssociation(spanish: "niño", english: "boy"),
  VocabularyAssociation(spanish: "niña", english: "girl"),
]

final class TextBundleVocabularyCardTests: XCTestCase {
  var document: TextBundleDocument!

  override func setUp() {
    super.setUp()
    let uniqueComponent = UUID().uuidString + ".deck"
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueComponent)
    document = TextBundleDocument(fileURL: url)
    let didCreate = expectation(description: "did create document")
    document.save(to: url, for: .forCreating) { success in
      precondition(success)
      didCreate.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
    document.text.setValue(markdownWithOtherContents)
  }

  override func tearDown() {
    let didClose = expectation(description: "did close")
    document.close { _ in
      try? FileManager.default.removeItem(at: self.document.fileURL)
      didClose.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
    document = nil
  }

  func testLoading() {
    let associations = document.vocabularyAssociations.value!
    XCTAssertEqual(associations, sampleAssociations)
  }

  func testAppendDoesNotClobber() {
    let newAssociation = VocabularyAssociation(spanish: "bosque", english: "forest")
    document.appendVocabularyAssociation(newAssociation)
    let associations = document.vocabularyAssociations.value!
    let expected = sampleAssociations.appending(newAssociation)
    XCTAssertEqual(associations, expected)
    let expectedText = """
    # Unit One Vocabulary

    | Spanish | Engish |
    | ------- | ------ |
    | tenedor | fork   |
    | hombre  | man    |
    | mujer   | woman  |
    | niño    | boy    |
    | niña    | girl   |
    | bosque  | forest |

    ## Notes

    - I should be able make notes and not lose them when I save vocabulary.

    """
    let actualText = document.text.taggedResult.value!.value
    XCTAssertEqual(actualText, expectedText)
  }

  func testReplaceDoeNotClobber() {
    let associations = document.vocabularyAssociations.value!
    let victim = associations[2]
    var replacement = victim
    replacement.testSpelling = true
    document.replaceVocabularyAssociation(victim, with: replacement)
    let expectedText = """
    # Unit One Vocabulary

    | Spanish         | Engish |
    | --------------- | ------ |
    | tenedor         | fork   |
    | hombre          | man    |
    | mujer #spelling | woman  |
    | niño            | boy    |
    | niña            | girl   |

    ## Notes

    - I should be able make notes and not lose them when I save vocabulary.

    """
    let actualText = document.text.taggedResult.value!.value
    XCTAssertEqual(actualText, expectedText)
  }
}
