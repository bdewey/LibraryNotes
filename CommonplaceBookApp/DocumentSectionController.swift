// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import FlashcardKit
import Foundation
import IGListKit
import MiniMarkdown
import SwipeCellKit
import TextBundleKit

public final class DocumentSectionController: ListSectionController {

  init(notebook: Notebook, stylesheet: Stylesheet) {
    self.notebook = notebook
    self.stylesheet = stylesheet
  }

  private let notebook: Notebook
  private let stylesheet: Stylesheet
  private var properties: PagePropertiesListDiffable!

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
    cell.detailLabel.attributedText = NSAttributedString(
      string: properties.value.hashtags.joined(separator: ", "),
      attributes: stylesheet.attributes(style: .body2, emphasis: .darkTextMediumEmphasis)
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
    if properties.cardCount > 0 {
      cell.ageLabel.attributedText = NSAttributedString(
        string: String(properties.cardCount),
        attributes: stylesheet.attributes(style: .caption, emphasis: .darkTextMediumEmphasis)
      )
    } else {
      cell.ageLabel.attributedText = nil
    }
    cell.delegate = self
    cell.setNeedsLayout()
    return cell
  }

  public override func sizeForItem(at index: Int) -> CGSize {
    return CGSize(width: collectionContext!.containerSize.width, height: 72)
  }

  public override func didUpdate(to object: Any) {
    // swiftlint:disable:next force_cast
    self.properties = (object as! PagePropertiesListDiffable)
  }

  public override func didSelectItem(at index: Int) {
    notebook.loadEditingViewController(
      for: properties.value.fileMetadata,
      parsingRules: notebook.parsingRules,
      stylesheet: stylesheet) { (editingViewController) in
      guard let editingViewController = editingViewController else { return }
      self.viewController?.navigationController?.pushViewController(
        editingViewController,
        animated: true
      )
    }
  }
}

extension Notebook {
  func loadEditingViewController(
    for metadata: FileMetadata,
    parsingRules: ParsingRules,
    stylesheet: Stylesheet,
    completion: @escaping (UIViewController?) -> Void
  ) {
    guard let document = metadataProvider.editableDocument(for: metadata) else {
      completion(nil)
      return
    }
    document.open { (success) in
      guard success else { completion(nil); return }
      if metadata.contentTypeTree.contains("org.brians-brain.swiftflash") {
        completion(metadata.languageViewController(
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

extension DocumentSectionController: SwipeCollectionViewCellDelegate {
  public func collectionView(
    _ collectionView: UICollectionView,
    editActionsForItemAt indexPath: IndexPath,
    for orientation: SwipeActionsOrientation
  ) -> [SwipeAction]? {
    guard orientation == .right else { return nil }

    let dataSource = self.notebook
    if let propertiesToDelete = self.properties {
      let deleteAction = SwipeAction(style: .destructive, title: "Delete") { action, _ in
        dataSource.deleteFileMetadata(propertiesToDelete.value.fileMetadata)
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
  fileprivate func languageViewController(
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
}
