// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import FlashcardKit
import Foundation
import IGListKit
import SwipeCellKit
import TextBundleKit

public final class DocumentSectionController: ListSectionController {

  init(dataSource: DocumentDataSource, stylesheet: Stylesheet) {
    self.dataSource = dataSource
    self.stylesheet = stylesheet
  }

  private let dataSource: DocumentDataSource
  private let stylesheet: Stylesheet
  private var fileMetadata: FileMetadataWrapper!

  public override func cellForItem(at index: Int) -> UICollectionViewCell {
    let cell = collectionContext!.dequeueReusableCell(
      of: DocumentCollectionViewCell.self,
      for: self,
      at: index
    ) as! DocumentCollectionViewCell // swiftlint:disable:this force_cast
    cell.stylesheet = stylesheet
    cell.titleLabel.text = fileMetadata.value.displayName
    if fileMetadata.value.isUploading {
      cell.statusIcon.image = UIImage(named: "round_cloud_upload_black_24pt")
    } else if fileMetadata.value.isDownloading {
      cell.statusIcon.image = UIImage(named: "round_cloud_download_black_24pt")
    } else if fileMetadata.value.downloadingStatus != NSMetadataUbiquitousItemDownloadingStatusCurrent {
      cell.statusIcon.image = UIImage(named: "round_cloud_queue_black_24pt")
    } else {
      cell.statusIcon.image = nil
    }
    cell.delegate = self
    return cell
  }

  public override func sizeForItem(at index: Int) -> CGSize {
    return CGSize(width: collectionContext!.containerSize.width, height: 44)
  }

  public override func didUpdate(to object: Any) {
    self.fileMetadata = (object as! FileMetadataWrapper) // swiftlint:disable:this force_cast
  }

  public override func didSelectItem(at index: Int) {
    fileMetadata.loadEditingViewController(stylesheet: stylesheet) { (editingViewController) in
      guard let editingViewController = editingViewController else { return }
      self.viewController?.navigationController?.pushViewController(
        editingViewController,
        animated: true
      )
    }
  }
}

extension DocumentSectionController: SwipeCollectionViewCellDelegate {
  public func collectionView(
    _ collectionView: UICollectionView,
    editActionsForItemAt indexPath: IndexPath,
    for orientation: SwipeActionsOrientation
  ) -> [SwipeAction]? {
    guard orientation == .right else { return nil }

    let dataSource = self.dataSource
    let fileMetadata = self.fileMetadata
    let deleteAction = SwipeAction(style: .destructive, title: "Delete") { action, _ in
      dataSource.deleteMetadata(fileMetadata!)
      // handle action by updating model with deletion
      action.fulfill(with: .delete)
    }

    // TODO: customize the action appearance
    deleteAction.image = UIImage(named: "delete")
    deleteAction.hidesWhenSelected = true

    return [deleteAction]
  }
}

extension FileMetadataWrapper {
  internal var editableDocument: (UIDocumentWithPreviousError & EditableDocument)? {
    if value.contentTypeTree.contains("public.plain-text") {
      return PlainTextDocument(fileURL: value.fileURL)
    } else if value.contentTypeTree.contains("org.textbundle.package") {
      return TextBundleDocument(fileURL: value.fileURL)
    } else {
      return nil
    }
  }

  private func languageViewController(for document: TextBundleDocument) -> UIViewController {
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
    stylesheet: Stylesheet,
    completion: @escaping (UIViewController?) -> Void
  ) {
    guard let document = self.editableDocument else {
      completion(nil)
      return
    }
    document.open { (success) in
      guard success else { completion(nil); return }
      if self.value.contentTypeTree.contains("org.brians-brain.swiftflash") {
        // swiftlint:disable:next force_cast
        completion(self.languageViewController(for: document as! TextBundleDocument))
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
