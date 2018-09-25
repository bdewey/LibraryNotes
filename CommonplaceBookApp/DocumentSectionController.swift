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
    guard let editingViewController = fileMetadata.editingViewController else { return }
    viewController?.navigationController?.pushViewController(
      editingViewController,
      animated: true
    )
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
  private var editableDocument: EditableDocument? {
    if contentTypeTree.contains("public.plain-text") {
      return PlainTextDocument(fileURL: fileURL)
    } else if contentTypeTree.contains("org.textbundle.package") {
      return TextBundleEditableDocument(fileURL: fileURL)
    } else {
      return nil
    }
  }

  private var languageDeck: LanguageDeck? {
    guard contentTypeTree.contains("org.brians-brain.swiftflash") else { return nil }
    let languageDeck = LanguageDeck(document: TextBundleDocument(fileURL: fileURL))
    languageDeck.document.open(completionHandler: nil)
    return languageDeck
  }

  private func viewController(for languageDeck: LanguageDeck) -> UIViewController {
    let tabBarViewController = ScrollingTopTabBarViewController()
    let vocabularyViewController = VocabularyViewController(storage: languageDeck)
    let textViewController = TextEditViewController(
      document: TextBundleEditableDocument(document: languageDeck.document),
      stylesheet: Stylesheet.hablaEspanol
    )
    textViewController.title = "Notes"
    
    let challengesViewController = ChallengesViewController(storage: languageDeck)
    challengesViewController.title = "Challenges"
    let statisticsViewController = StatisticsViewController(
      studyStatisticsContainer: languageDeck
    )
    tabBarViewController.viewControllers = [
      vocabularyViewController,
      textViewController,
      challengesViewController,
      statisticsViewController,
    ]
    return tabBarViewController
  }

  var editingViewController: UIViewController? {
    if let languageDeck = self.languageDeck {
      return viewController(for: languageDeck)
    }
    if let document = editableDocument {
      document.open(completionHandler: nil)
      return TextEditViewController(document: document, stylesheet: Stylesheet.default)
    }
    return nil
  }
}
