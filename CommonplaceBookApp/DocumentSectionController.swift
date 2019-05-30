// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import Foundation
import IGListKit
import MiniMarkdown
import SwipeCellKit
import TextBundleKit

public final class DocumentSectionController: ListSectionController {
  init(
    notebook: NoteArchiveDocument,
    stylesheet: Stylesheet
  ) {
    self.notebook = notebook
    self.stylesheet = stylesheet
  }

  private let notebook: NoteArchiveDocument
  private let stylesheet: Stylesheet
  private var object: NoteBundlePagePropertiesListDiffable!

  /// Used to create attributed strings from page titles.
  ///
  /// Right now, this:
  ///
  /// - applies italics
  /// - removes any Markdown delimiters
  private lazy var titleRenderer: RenderedMarkdown = {
    var formatters: [NodeType: RenderedMarkdown.FormattingFunction] = [:]
    formatters[.emphasis] = { $1.italic = true }
    var renderers: [NodeType: RenderedMarkdown.RenderFunction] = [:]
    renderers[.delimiter] = { _, _ in NSAttributedString() }
    let renderer = RenderedMarkdown(
      parsingRules: ParsingRules(),
      formatters: formatters,
      renderers: renderers
    )
    renderer.defaultAttributes = stylesheet.attributes(style: .subtitle1)
    return renderer
  }()

  public override func cellForItem(at index: Int) -> UICollectionViewCell {
    let cell = collectionContext!.dequeueReusableCell(
      of: DocumentCollectionViewCell.self,
      for: self,
      at: index
    ) as! DocumentCollectionViewCell // swiftlint:disable:this force_cast
    cell.stylesheet = stylesheet
    titleRenderer.markdown = object.properties.title
    cell.titleLabel.attributedText = titleRenderer.attributedString
    cell.accessibilityLabel = object.properties.title
    var detailString = object.properties.hashtags.joined(separator: ", ")
    if object.cardCount > 0 {
      if !detailString.isEmpty { detailString += ". " }
      if object.cardCount == 1 {
        detailString += "1 card."
      } else {
        detailString += "\(object.cardCount) cards."
      }
    }
    cell.detailLabel.attributedText = NSAttributedString(
      string: detailString,
      attributes: stylesheet.attributes(style: .body2, emphasis: .darkTextMediumEmphasis)
    )
    let now = Date()
    let dateDelta = now.timeIntervalSince(object.properties.timestamp)
    cell.ageLabel.attributedText = NSAttributedString(
      string: ageFormatter.string(from: dateDelta) ?? "",
      attributes: stylesheet.attributes(style: .caption, emphasis: .darkTextMediumEmphasis)
    )
    cell.delegate = self
    cell.setNeedsLayout()
    return cell
  }

  public override func sizeForItem(at index: Int) -> CGSize {
    return CGSize(width: collectionContext!.containerSize.width, height: 72)
  }

  public override func didUpdate(to object: Any) {
    // swiftlint:disable:next force_cast
    self.object = (object as! NoteBundlePagePropertiesListDiffable)
  }

  // TODO: Edit documents
  public override func didSelectItem(at index: Int) {
    guard let object = object else {
      assertionFailure("Unexpected object type")
      return
    }
    do {
      let textEditViewController = TextEditViewController(
        parsingRules: notebook.parsingRules,
        stylesheet: stylesheet
      )
      textEditViewController.pageIdentifier = object.pageKey
      textEditViewController.markdown = try notebook.currentTextContents(for: object.pageKey)
      textEditViewController.delegate = notebook
      viewController?.navigationController?
        .pushViewController(textEditViewController, animated: true)
    } catch {
      DDLogError("Unexpected error loading page: \(error)")
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

    let dataSource = notebook
    var actions = [SwipeAction]()
    if let properties = self.object {
      if properties.cardCount > 0,
        let viewController = self.viewController as? DocumentListViewController {
        let studyAction = SwipeAction(style: .default, title: "Study") { action, _ in
          let studySession = self.notebook.studySession(
            filter: { name, _ in name == properties.pageKey }
          )
          viewController.presentStudySessionViewController(for: studySession)
          action.fulfill(with: ExpansionFulfillmentStyle.reset)
        }
        studyAction.image = UIImage(named: "round_school_black_24pt")
        studyAction.hidesWhenSelected = true
        studyAction.backgroundColor = stylesheet.colors.secondaryColor
        studyAction.textColor = stylesheet.colors.onSecondaryColor
        actions.append(studyAction)
      }

      let deleteAction = SwipeAction(style: .destructive, title: "Delete") { action, _ in
        try? dataSource.deletePage(pageIdentifier: properties.pageKey)
        // handle action by updating model with deletion
        action.fulfill(with: .delete)
      }
      deleteAction.image = UIImage(named: "round_delete_forever_black_24pt")
      deleteAction.hidesWhenSelected = true
      actions.append(deleteAction)
    }
    return actions
  }
}

extension FileMetadata {
  fileprivate func languageViewController(
    for document: TextBundleDocument,
    parsingRules: ParsingRules
  ) -> UIViewController {
    let textViewController = TextEditViewController(
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
