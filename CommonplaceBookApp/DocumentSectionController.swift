// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import FlashcardKit
import Foundation
import IGListKit
import MiniMarkdown
import SwipeCellKit
import TextBundleKit

public final class DocumentSectionController: ListSectionController {

  init(dataSource: DocumentDataSource, stylesheet: Stylesheet) {
    self.dataSource = dataSource
    self.stylesheet = stylesheet
  }

  private let dataSource: DocumentDataSource
  private let stylesheet: Stylesheet
  private var properties: DocumentPropertiesListDiffable!

  public override func cellForItem(at index: Int) -> UICollectionViewCell {
    let cell = collectionContext!.dequeueReusableCell(
      of: DocumentCollectionViewCell.self,
      for: self,
      at: index
    ) as! DocumentCollectionViewCell // swiftlint:disable:this force_cast
    cell.stylesheet = stylesheet
    cell.titleLabel.attributedText = NSAttributedString(
      string: properties.value.title,
      attributes: stylesheet.attributes(style: .subtitle1, emphasis: .darkTextHighEmphasis)
    )
    if properties.value.fileMetadata.isUploading {
      cell.statusIcon.image = UIImage(named: "round_cloud_upload_black_24pt")
    } else if properties.value.fileMetadata.isDownloading {
      cell.statusIcon.image = UIImage(named: "round_cloud_download_black_24pt")
    } else if properties.value.fileMetadata.downloadingStatus != NSMetadataUbiquitousItemDownloadingStatusCurrent {
      cell.statusIcon.image = UIImage(named: "round_cloud_queue_black_24pt")
    } else {
      cell.statusIcon.image = nil
    }
    let now = Date()
    let dateDelta = now.timeIntervalSince(properties.value.fileMetadata.contentChangeDate)
    cell.ageLabel.attributedText = NSAttributedString(
      string: ageFormatter.string(from: dateDelta) ?? "",
      attributes: stylesheet.attributes(style: .caption, emphasis: .darkTextMediumEmphasis)
    )
    cell.delegate = self
    return cell
  }

  public override func sizeForItem(at index: Int) -> CGSize {
    return CGSize(width: collectionContext!.containerSize.width, height: 56)
  }

  public override func didUpdate(to object: Any) {
    // swiftlint:disable:next force_cast
    self.properties = (object as! DocumentPropertiesListDiffable)
  }

  public override func didSelectItem(at index: Int) {
    properties.value.fileMetadata.loadEditingViewController(
      parsingRules: dataSource.parsingRules,
      stylesheet: stylesheet
    ) { (editingViewController) in
      guard let editingViewController = editingViewController else { return }
      self.viewController?.navigationController?.pushViewController(
        editingViewController,
        animated: true
      )
    }
  }
}

private let ageFormatter: DateComponentsFormatter = {
  let ageFormatter = DateComponentsFormatter()
  ageFormatter.maximumUnitCount = 1
  ageFormatter.unitsStyle = .abbreviated
  ageFormatter.allowsFractionalUnits = false
  ageFormatter.allowedUnits = [.day, .hour, .minute]
  return ageFormatter
}()

extension DocumentSectionController: SwipeCollectionViewCellDelegate {
  public func collectionView(
    _ collectionView: UICollectionView,
    editActionsForItemAt indexPath: IndexPath,
    for orientation: SwipeActionsOrientation
  ) -> [SwipeAction]? {
    guard orientation == .right else { return nil }

    let dataSource = self.dataSource
    if let propertiesToDelete = self.properties {
      let deleteAction = SwipeAction(style: .destructive, title: "Delete") { action, _ in
        dataSource.deleteDocument(propertiesToDelete)
        // handle action by updating model with deletion
        action.fulfill(with: .delete)
      }
      // TODO: customize the action appearance
      deleteAction.image = UIImage(named: "delete")
      deleteAction.hidesWhenSelected = true
      return [deleteAction]
    } else {
      return []
    }
  }
}

extension FileMetadata {
  internal var editableDocument: (UIDocumentWithPreviousError & EditableDocument)? {
    if contentTypeTree.contains("public.plain-text") {
      return PlainTextDocument(fileURL: fileURL)
    } else if contentTypeTree.contains("org.textbundle.package") {
      return TextBundleDocument(fileURL: fileURL)
    } else {
      return nil
    }
  }

  private func languageViewController(
    for document: TextBundleDocument,
    parsingRules: ParsingRules
  ) -> UIViewController {
    let textViewController = TextEditViewController(
      document: document,
      parsingRules: LanguageDeck.parsingRules,
      stylesheet: Stylesheet.hablaEspanol
    )
    let languageDeck = LanguageDeck(
      document: document,
      miniMarkdownSignal: textViewController.miniMarkdownSignal
    )
    let tabBarViewController = ScrollingTopTabBarViewController()
    let vocabularyViewController = VocabularyViewController(languageDeck: languageDeck)
    textViewController.title = "Notes"

    let challengesViewController = ChallengesViewController(
      studyStatistics: languageDeck.document.studyStatistics
    )
    challengesViewController.title = "Challenges"
    let statisticsViewController = StatisticsViewController(
      studyStatistics: languageDeck.document.studyStatistics
    )
    tabBarViewController.viewControllers = [
      vocabularyViewController,
      textViewController,
      challengesViewController,
      statisticsViewController,
    ]
    return tabBarViewController
  }

  func loadEditingViewController(
    parsingRules: ParsingRules,
    stylesheet: Stylesheet,
    completion: @escaping (UIViewController?) -> Void
  ) {
    guard let document = self.editableDocument else {
      completion(nil)
      return
    }
    document.open { (success) in
      guard success else { completion(nil); return }
      if self.contentTypeTree.contains("org.brians-brain.swiftflash") {
        completion(self.languageViewController(
          for: document as! TextBundleDocument, // swiftlint:disable:this force_cast
          parsingRules: parsingRules
        ))
      } else {
        completion(
          TextEditViewController(
            document: document,
            parsingRules: LanguageDeck.parsingRules,
            stylesheet: stylesheet
          )
        )
      }
    }
  }
}
