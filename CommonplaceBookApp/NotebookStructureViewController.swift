// Copyright © 2020 Brian's Brain. All rights reserved.

import Combine
import SnapKit
import UIKit

protocol NotebookStructureViewControllerDelegate: AnyObject {
  func notebookStructureViewController(_ viewController: NotebookStructureViewController, didSelect structure: NotebookStructureViewController.StructureIdentifier)
}

/// Displays a list of any "structure" inside the notebook -- currently just hashtags
final class NotebookStructureViewController: UIViewController {

  enum StructureIdentifier: Hashable, CustomStringConvertible {
    case allNotes
    case hashtag(String)

    var description: String {
      switch self {
      case .allNotes: return "All Notes"
      case .hashtag(let hashtag): return hashtag
      }
    }
  }

  private enum Section: CaseIterable {
    case allNotes
    case hashtags
  }

  public init(notebook: NoteStorage) {
    self.notebook = notebook
    super.init(nibName: nil, bundle: nil)
    title = AppDelegate.appName
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public weak var delegate: NotebookStructureViewControllerDelegate?
  public let notebook: NoteStorage
  private var notebookSubscription: AnyCancellable?

  private lazy var collectionView: UICollectionView = {
    let layout = UICollectionViewCompositionalLayout { (sectionIndex, layoutEnvironment) in
      var config = UICollectionLayoutListConfiguration(appearance: .sidebar)
      config.backgroundColor = .grailBackground
      // the first section has no header; everything else gets a header.
      config.headerMode = (sectionIndex == 0) ? .none : .supplementary
      let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
      return section
    }
    let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
    view.delegate = self
    return view
  }()

  private lazy var dataSource: UICollectionViewDiffableDataSource<Section, StructureIdentifier> = {
    let hashtagRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, StructureIdentifier> { (cell, _, structureIdentifier) in
      var contentConfiguration = cell.defaultContentConfiguration()
      contentConfiguration.text = structureIdentifier.description
      contentConfiguration.textProperties.color = .label
      cell.contentConfiguration = contentConfiguration
    }
    let dataSource = UICollectionViewDiffableDataSource<Section, StructureIdentifier>(collectionView: collectionView) { (view, indexPath, item) -> UICollectionViewCell? in
      view.dequeueConfiguredReusableCell(using: hashtagRegistration, for: indexPath, item: item)
    }

    dataSource.supplementaryViewProvider = { [weak dataSource] (collectionView, kind, indexPath) in
      guard kind == UICollectionView.elementKindSectionHeader, dataSource?.snapshot().indexOfSection(.hashtags) == indexPath.section else {
        return nil
      }
      let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewCell>(elementKind: UICollectionView.elementKindSectionHeader) { (headerView, _, _) in
        var headerConfiguration = UIListContentConfiguration.sidebarHeader()
        headerConfiguration.text = "Tags"
        headerView.contentConfiguration = headerConfiguration
      }
      return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
    }
    return dataSource
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(collectionView)
    collectionView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    updateSnapshot()
    // start with "all notes" selected.
    collectionView.selectItem(at: dataSource.indexPath(for: .allNotes), animated: false, scrollPosition: [])
    notebookSubscription = notebook.notesDidChange.receive(on: DispatchQueue.main).sink { [weak self] in
      self?.updateSnapshot()
    }
    navigationController?.setToolbarHidden(false, animated: false)
    toolbarItems = [AppCommandsButtonItems.documentBrowser]
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setToolbarHidden(false, animated: false)
  }

  private func updateSnapshot() {
    var snapshot = NSDiffableDataSourceSnapshot<Section, StructureIdentifier>()
    snapshot.appendSections([.allNotes])
    snapshot.appendItems([.allNotes])
    if !notebook.hashtags.isEmpty {
      snapshot.appendSections([.hashtags])
      snapshot.appendItems(notebook.hashtags.map { .hashtag($0) })
    }
    dataSource.apply(snapshot)
  }
}

extension NotebookStructureViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    if let structureIdentifier = dataSource.itemIdentifier(for: indexPath) {
      delegate?.notebookStructureViewController(self, didSelect: structureIdentifier)
      splitViewController?.show(.supplementary)
    }
  }
}
