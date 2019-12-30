// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import SnapKit
import SwiftUI
import UIKit

/// Allows editing a vocabulary list.
final class VocabularyViewController: UIViewController {
  init(notebook: NoteStorage) {
    self.notebook = notebook
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// The notebook we write changes back to
  let notebook: NoteStorage

  /// The page that stores our vocabulary.
  var properties = PageProperties() {
    didSet {
      title = properties.title
      dataSource.apply(makeSnapshot(), animatingDifferences: true)
      if let pageIdentifier = pageIdentifier {
        notebook.changePageProperties(for: pageIdentifier, to: properties)
      } else {
        pageIdentifier = notebook.insertPageProperties(properties)
      }
    }
  }

  /// Identifier of the page. If nil, it means we're working with unsaved content.
  var pageIdentifier: NoteIdentifier?

  private lazy var addCardButton: UIBarButtonItem = {
    UIBarButtonItem(image: .add, style: .plain, target: self, action: #selector(didTapAddButton))
  }()

  @objc private func didTapAddButton() {
    let template = VocabularyChallengeTemplate(
      front: VocabularyChallengeTemplate.Word(text: "", language: "es"),
      back: VocabularyChallengeTemplate.Word(text: "", language: "en"),
      parsingRules: notebook.parsingRules
    )
    let viewController = UIHostingController(
      rootView: EditVocabularyView(notebook: notebook, vocabularyTemplate: template, onCommit: { [weak self] in
        self?.commit(template: template, indexPath: nil)
        self?.dismiss(animated: true, completion: nil)
      }).environmentObject(ImageSearchRequest())
    )
    present(viewController, animated: true, completion: nil)
  }

  private func commit(template: VocabularyChallengeTemplate, indexPath: IndexPath?) {
    do {
      let key = try notebook.insertChallengeTemplate(template)
      if let index = indexPath?.item {
        // indexPath is reversed, so I need to re-reverse to edit the right model object
        properties.cardTemplates[properties.cardTemplates.count - index - 1] = key.description
      } else {
        properties.cardTemplates.append(key.description)
      }
    } catch {
      DDLogError("Unexpected error: \(error)")
    }
  }

  private func deleteTemplate(at indexPath: IndexPath) {
    // Reverse to get index
    let index = properties.cardTemplates.count - indexPath.item - 1
    properties.cardTemplates.remove(at: index)
  }

  private lazy var tableView: UITableView = {
    let tableView = UITableView(frame: .zero, style: .plain)
    tableView.delegate = self
    return tableView
  }()

  private lazy var dataSource: DataSource = {
    let dataSource = DataSource(tableView: tableView) { [weak self] (innerTableView, _, template) -> UITableViewCell? in
      var cell: UITableViewCell! = innerTableView.dequeueReusableCell(withIdentifier: Identifier.cell)
      if cell == nil {
        cell = UITableViewCell(style: .subtitle, reuseIdentifier: Identifier.cell)
      }
      cell.textLabel?.text = template.front.text
      cell.detailTextLabel?.text = template.back.text
      if let key = template.imageAsset, let data = self?.notebook.data(for: key), let image = UIImage(data: data) {
        cell.imageView?.image = image
      } else {
        cell.imageView?.image = nil
      }
      return cell
    }
    dataSource.viewController = self
    return dataSource
  }()

  // MARK: - Lifecycle

  override func viewDidLoad() {
    view.backgroundColor = UIColor.systemBackground
    view.addSubview(tableView)
    navigationItem.rightBarButtonItem = addCardButton
    tableView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    dataSource.apply(makeSnapshot())
  }
}

extension VocabularyViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    guard let template = dataSource.itemIdentifier(for: indexPath) else { return }
    let viewController = UIHostingController(
      rootView: EditVocabularyView(notebook: notebook, vocabularyTemplate: template, onCommit: { [weak self] in
        self?.commit(template: template, indexPath: indexPath)
        self?.dismiss(animated: true, completion: nil)
      }).environmentObject(ImageSearchRequest())
    )
    present(viewController, animated: true, completion: nil)
  }
}

// MARK: - Private

private extension VocabularyViewController {
  final class DataSource: UITableViewDiffableDataSource<Section, VocabularyChallengeTemplate> {
    /// The owning view controller
    weak var viewController: VocabularyViewController?

    override func tableView(
      _ tableView: UITableView,
      commit editingStyle: UITableViewCell.EditingStyle,
      forRowAt indexPath: IndexPath
    ) {
      switch editingStyle {
      case .delete:
        viewController?.deleteTemplate(at: indexPath)
      default:
        break
      }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
      return true
    }
  }

  typealias Snapshot = NSDiffableDataSourceSnapshot<Section, VocabularyChallengeTemplate>

  enum Identifier {
    static let cell = "Cell"
  }

  enum Section: Hashable {
    case vocabularyItems
  }

  func makeSnapshot() -> Snapshot {
    var snapshot = VocabularyViewController.Snapshot()
    snapshot.appendSections([.vocabularyItems])
    let items = properties.cardTemplates
      .reversed()
      .compactMap(notebook.challengeTemplate(for:))
      .compactMap { $0 as? VocabularyChallengeTemplate }
    snapshot.appendItems(items)
    return snapshot
  }
}
