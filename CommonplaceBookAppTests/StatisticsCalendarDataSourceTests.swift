// Copyright © 2017-present Brian's Brain. All rights reserved.

@testable import CommonplaceBookApp
@testable import TextBundleKit
import XCTest

final class TestCollectionView: StatisticsCalendarCollectionView {
  var reloadCount = 0
  func register(_ cellClass: AnyClass?, forCellWithReuseIdentifier identifier: String) {}

  func register(
    _ viewClass: AnyClass?,
    forSupplementaryViewOfKind elementKind: String,
    withReuseIdentifier identifier: String
  ) {}

  func reloadData() {
    reloadCount += 1
  }
}

final class StatisticsCalendarDataSourceTests: LanguageDeckBase {
  var dataSource: StatisticsCalendarDataSource!
  let collectionView = UICollectionView(
    frame: .zero,
    collectionViewLayout: UICollectionViewFlowLayout()
  )
  var testCollectionView: TestCollectionView!

  override func setUp() {
    super.setUp()
    dataSource = StatisticsCalendarDataSource(studyStatistics: languageDeck.document.studyStatistics)

    // Need to first assign the real collection view to really register cells...
    dataSource.collectionView = collectionView

    // then replace with the test collection view to track reloads.
    testCollectionView = TestCollectionView()
    dataSource.collectionView = testCollectionView
  }

  func testDataSourceStartsEmpty() {
    XCTAssertEqual(1, dataSource.numberOfSections(in: collectionView))
    for i in 0 ..< dataSource.collectionView(collectionView, numberOfItemsInSection: 0) {
      let indexPath = IndexPath(row: i, section: 0)
      let cell = dataSource.collectionView(
        collectionView,
        cellForItemAt: indexPath
      ) as! StatisticsCalendarDataSource.DateCell // swiftlint:disable:this force_cast
      XCTAssertTrue(cell.isEmpty)
    }
  }

  func testStudyingRefreshesCalendar() {
    guard let vocabularyAssociations = languageDeck.document.vocabularyAssociations.value else {
      XCTFail("No cards?")
      return
    }
    var studySession = StudySession(
      vocabularyAssociations.cards,
      properties: CardDocumentProperties(
        documentName: languageDeck.document.fileURL.lastPathComponent,
        attributionMarkdown: "",
        parsingRules: LanguageDeck.parsingRules
      )
    )
    // Answer everything correctly.
    let today = Date()
    studySession.studySessionStartDate = today
    studySession.studySessionEndDate = today
    while studySession.currentCard != nil {
      studySession.recordAnswer(correct: true)
    }
    languageDeck.document.documentStudyMetadata.update(with: studySession, on: Date())
    if let statistics = studySession.statistics {
      languageDeck
        .document
        .studyStatistics
        .changeValue { (array) -> [StudySession.Statistics] in
          var array = array
          array.append(statistics)
          return array
        }
    }
    XCTAssertEqual(testCollectionView.reloadCount, 1)
    let components = Calendar.current.dateComponents([.day], from: today)
    let cell = dataSource.collectionView(
      collectionView,
      cellForItemAt: IndexPath(row: components.day! - 1, section: 0)
    ) as! StatisticsCalendarDataSource.DateCell // swiftlint:disable:this force_cast
    XCTAssertFalse(cell.isEmpty)
  }
}
