//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import Combine
import Logging
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

  public init(database: NoteDatabase) {
    self.database = database
    super.init(nibName: nil, bundle: nil)
    title = AppDelegate.appName
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public weak var delegate: NotebookStructureViewControllerDelegate?
  private let database: NoteDatabase
  private var notebookSubscription: AnyCancellable?

  private lazy var collectionView: UICollectionView = {
    let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
      var config = UICollectionLayoutListConfiguration(appearance: .sidebar)
      config.backgroundColor = .grailBackground
      // the first section has no header; everything else gets a header.
      config.headerMode = (sectionIndex == 0) ? .none : .supplementary
      // The last section gets a footer
      config.footerMode = (sectionIndex == Section.allCases.count - 1) ? .supplementary : .none
      let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
      return section
    }
    let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
    view.delegate = self
    return view
  }()

  private lazy var dataSource: UICollectionViewDiffableDataSource<Section, StructureIdentifier> = {
    let hashtagRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, StructureIdentifier> { cell, _, structureIdentifier in
      var contentConfiguration = cell.defaultContentConfiguration()
      contentConfiguration.text = structureIdentifier.description
      contentConfiguration.textProperties.color = .label
      cell.contentConfiguration = contentConfiguration
      cell.accessories = [.outlineDisclosure()]
    }
    let dataSource = UICollectionViewDiffableDataSource<Section, StructureIdentifier>(collectionView: collectionView) { (view, indexPath, item) -> UICollectionViewCell? in
      view.dequeueConfiguredReusableCell(using: hashtagRegistration, for: indexPath, item: item)
    }

    dataSource.supplementaryViewProvider = { [weak dataSource] collectionView, kind, indexPath in
      guard dataSource?.snapshot().indexOfSection(.hashtags) == indexPath.section
      else {
        Logger.shared.debug("Skipping supplementary view for \(indexPath) because it isn't the hashtag section")
        return nil
      }
      if kind == UICollectionView.elementKindSectionHeader {
        let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewCell>(elementKind: UICollectionView.elementKindSectionHeader) { headerView, _, _ in
          var headerConfiguration = UIListContentConfiguration.sidebarHeader()
          headerConfiguration.text = "Tags"
          headerView.contentConfiguration = headerConfiguration
        }
        return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
      }
      if kind == UICollectionView.elementKindSectionFooter {
        let footerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionFooter) { footerView, _, _ in
          var footerConfiguration = footerView.defaultContentConfiguration()
          footerConfiguration.text = "Version \(UIApplication.versionString)"
          footerConfiguration.textProperties.font = UIFont.preferredFont(forTextStyle: .caption1)
          footerConfiguration.textProperties.color = UIColor.secondaryLabel
          footerView.contentConfiguration = footerConfiguration
        }
        return collectionView.dequeueConfiguredReusableSupplementary(using: footerRegistration, for: indexPath)
      }
      Logger.shared.error("Unexpected supplementary kind \(kind), returning nil")
      return nil
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
    notebookSubscription = database.notesDidChange.receive(on: DispatchQueue.main).sink { [weak self] in
      self?.updateSnapshot()
    }
    navigationController?.setToolbarHidden(false, animated: false)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setToolbarHidden(false, animated: false)
    configureToolbar()
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    configureToolbar()
  }
}

// MARK: - UICollectionViewDelegate

extension NotebookStructureViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    if let structureIdentifier = dataSource.itemIdentifier(for: indexPath) {
      delegate?.notebookStructureViewController(self, didSelect: structureIdentifier)
      splitViewController?.show(.supplementary)
    }
  }
}

// MARK: - Private

private extension NotebookStructureViewController {
  func configureToolbar() {
    var toolbarItems = [AppCommandsButtonItems.documentBrowser(), UIBarButtonItem.flexibleSpace()]
    if splitViewController?.isCollapsed ?? false {
      toolbarItems.append(AppCommandsButtonItems.newNote())
    }
    self.toolbarItems = toolbarItems
  }

  func updateSnapshot() {
    var snapshot = NSDiffableDataSourceSnapshot<Section, StructureIdentifier>()
    snapshot.appendSections([.allNotes])
    snapshot.appendItems([.allNotes])
    var hashtagSectionSnapshot = NSDiffableDataSourceSectionSnapshot<StructureIdentifier>()
    for hashtag in database.hashtags {
      hashtagSectionSnapshot.insertHashtag(hashtag)
    }
    if !hashtagSectionSnapshot.items.isEmpty {
      snapshot.appendSections([.hashtags])
    }
    dataSource.apply(snapshot)
    if !hashtagSectionSnapshot.items.isEmpty {
      dataSource.apply(hashtagSectionSnapshot, to: .hashtags)
    }
  }
}

private extension NSDiffableDataSourceSectionSnapshot where ItemIdentifierType == NotebookStructureViewController.StructureIdentifier {
  mutating func insertHashtag(_ hashtag: String) {
    var parent: NotebookStructureViewController.StructureIdentifier?
    for (index, character) in hashtag.enumerated() where character == "/" {
      let parentHashtag = hashtag.prefix(index)
      let currentParent = NotebookStructureViewController.StructureIdentifier.hashtag(String(parentHashtag))
      if !contains(currentParent) {
        append([currentParent], to: parent)
      }
      parent = currentParent
    }
    self.append([.hashtag(hashtag)], to: parent)
  }
}
