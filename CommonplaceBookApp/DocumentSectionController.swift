// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import FlashcardKit
import Foundation
import IGListKit
import SwipeCellKit
import TextBundleKit

public final class DocumentSectionController: ListSectionController {
  private let dataSource: DocumentDataSource

  init(dataSource: DocumentDataSource) {
    self.dataSource = dataSource
  }

  private var fileMetadata: FileMetadata!

  public override func cellForItem(at index: Int) -> UICollectionViewCell {
    let cell = collectionContext!.dequeueReusableCell(
      of: DocumentCollectionViewCell.self,
      for: self,
      at: index
    ) as! DocumentCollectionViewCell // swiftlint:disable:this force_cast
    cell.titleLabel.text = fileMetadata.displayName
    cell.delegate = self
    return cell
  }

  public override func sizeForItem(at index: Int) -> CGSize {
    return CGSize(width: collectionContext!.containerSize.width, height: 44)
  }

  public override func didUpdate(to object: Any) {
    self.fileMetadata = (object as! FileMetadata) // swiftlint:disable:this force_cast
  }

  public override func didSelectItem(at index: Int) {
    fileMetadata.loadEditingViewController { (editingViewController) in
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

extension FileMetadata {
  private var editableDocument: (UIDocument & EditableDocument)? {
    if contentTypeTree.contains("public.plain-text") {
      return PlainTextDocument(fileURL: fileURL)
    } else if contentTypeTree.contains("org.textbundle.package") {
      return TextBundleDocument(fileURL: fileURL)
    } else {
      return nil
    }
  }

  private func loadLanguageDeck(completion: @escaping (LanguageDeck?) -> Void) {
    guard contentTypeTree.contains("org.brians-brain.swiftflash") else {
      completion(nil)
      return
    }
    let document = TextBundleDocument(fileURL: fileURL)
    document.open { (success) in
      if success {
        completion(LanguageDeck(document: document))
      } else {
        completion(nil)
      }
    }
  }

  private func viewController(for languageDeck: LanguageDeck) -> UIViewController {
    let tabBarViewController = ScrollingTopTabBarViewController()
    let vocabularyViewController = VocabularyViewController(languageDeck: languageDeck)
    let textViewController = TextEditViewController(
      document: languageDeck.document,
      stylesheet: Stylesheet.hablaEspanol
    )
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

  func loadEditingViewController(completion: @escaping (UIViewController?) -> Void) {
    loadLanguageDeck { (languageDeck) in
      if let languageDeck = languageDeck {
        completion(self.viewController(for: languageDeck))
        return
      }
      if let document = self.editableDocument {
        document.open(completionHandler: { (success) in
          if success {
            completion(TextEditViewController(document: document, stylesheet: Stylesheet.default))
          } else {
            completion(nil)
          }
        })
        return
      }
      completion(nil)
    }
  }
}
