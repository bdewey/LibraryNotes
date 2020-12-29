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

import Logging
import SnapKit
import UIKit

/// Protocol for any UIViewController that displays "reference" material for which we can also show related notes
protocol ReferenceViewController: UIViewController {
  var relatedNotesViewController: UIViewController? { get set }
}

/// Manages the UISplitViewController that shows the contents of a notebook. It's a three-column design:
/// - primary: The overall notebook structure (currently based around hashtags)
/// - supplementary: A list of notes
/// - secondary: An individual note
final class NotebookViewController: UIViewController {
  init(database: NoteDatabase) {
    self.database = database
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// The notebook we are viewing
  private let database: NoteDatabase

  /// What are we viewing in the current structure?
  private var focusedNotebookStructure: NotebookStructureViewController.StructureIdentifier = .allNotes {
    didSet {
      documentListViewController.setFocus(focusedNotebookStructure)
    }
  }

  /// A list of notes inside the notebook, displayed in the supplementary column
  private lazy var documentListViewController: DocumentListViewController = {
    let documentListViewController = DocumentListViewController(database: database)
    documentListViewController.delegate = self
    return documentListViewController
  }()

  private lazy var supplementaryNavigationController: UINavigationController = {
    let supplementaryNavigationController = UINavigationController(
      rootViewController: documentListViewController
    )
    supplementaryNavigationController.navigationBar.prefersLargeTitles = false
    supplementaryNavigationController.navigationBar.barTintColor = .grailBackground
    return supplementaryNavigationController
  }()

  /// The split view we are managing.
  private lazy var notebookSplitViewController: UISplitViewController = {
    let hashtagViewController = NotebookStructureViewController(
      database: documentListViewController.database
    )
    hashtagViewController.delegate = self
    let primaryNavigationController = UINavigationController(rootViewController: hashtagViewController)
    primaryNavigationController.navigationBar.prefersLargeTitles = true
    primaryNavigationController.navigationBar.barTintColor = .grailBackground

    let splitViewController = UISplitViewController(style: .tripleColumn)
    let detailViewController = SavingTextEditViewController(database: documentListViewController.database)
      .wrappingInNavigationController()
    splitViewController.viewControllers = [
      primaryNavigationController,
      supplementaryNavigationController,
      detailViewController,
    ]
    splitViewController.preferredDisplayMode = .oneBesideSecondary
    splitViewController.showsSecondaryOnlyButton = true
    splitViewController.delegate = self
    return splitViewController
  }()

  override func viewDidLoad() {
    super.viewDidLoad()

    // Set up notebookSplitViewController as a child
    view.addSubview(notebookSplitViewController.view)
    notebookSplitViewController.view.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    addChild(notebookSplitViewController)
    notebookSplitViewController.didMove(toParent: self)
  }

  func makeNewNote() {
    let hashtag: String?
    switch focusedNotebookStructure {
    case .allNotes:
      hashtag = nil
    case .hashtag(let focusedHashtag):
      hashtag = focusedHashtag
    }
    let viewController = SavingTextEditViewController(database: database, currentHashtag: hashtag, autoFirstResponder: true).wrappingInNavigationController()
    notebookSplitViewController.showDetailViewController(viewController, sender: nil)
    Logger.shared.info("Created a new view controller for a blank document")
  }
}

// MARK: - NotebookStructureViewControllerDelegate

extension NotebookViewController: NotebookStructureViewControllerDelegate {
  func notebookStructureViewController(_ viewController: NotebookStructureViewController, didSelect structure: NotebookStructureViewController.StructureIdentifier) {
    focusedNotebookStructure = structure
  }
}

// MARK: - DocumentListViewControllerDelegate

extension NotebookViewController: DocumentListViewControllerDelegate {
  func documentListViewController(
    _ viewController: DocumentListViewController,
    didRequestShowNote note: Note,
    noteIdentifier: Note.Identifier?
  ) {
    let noteViewController = SavingTextEditViewController(
      configuration: SavingTextEditViewController.Configuration(noteIdentifier: noteIdentifier, note: note),
      noteStorage: database
    )
    noteViewController.setTitleMarkdown(note.metadata.title)

    if let referenceViewController = self.referenceViewController(for: note) {
      referenceViewController.relatedNotesViewController = noteViewController
      // In a non-collapsed environment, we'll show the notes in the supplementary view.
      // In a collapsed environment, we rely on a button in the web view to modally present notes.
      if !notebookSplitViewController.isCollapsed {
        supplementaryNavigationController.pushViewController(noteViewController, animated: true)
      }
      notebookSplitViewController.setViewController(
        referenceViewController.wrappingInNavigationController(),
        for: .secondary
      )
    } else {
      notebookSplitViewController.setViewController(noteViewController.wrappingInNavigationController(), for: .secondary)
    }
    notebookSplitViewController.show(.secondary)
  }

  private func referenceViewController(for note: Note) -> ReferenceViewController? {
    switch note.reference {
    case .none: return nil
    case .some(.webPage(let url)):
      return WebViewController(url: url)
    }
  }
}

// MARK: - UISplitViewControllerDelegate

extension NotebookViewController: UISplitViewControllerDelegate {
  func splitViewController(
    _ splitViewController: UISplitViewController,
    collapseSecondary secondaryViewController: UIViewController,
    onto primaryViewController: UIViewController
  ) -> Bool {
    guard
      let navigationController = secondaryViewController as? UINavigationController,
      let textEditViewController = navigationController.visibleViewController as? SavingTextEditViewController
    else {
      assertionFailure()
      return false
    }
    // Per documentation:
    // Return false to let the split view controller try and incorporate the secondary view
    // controller’s content into the collapsed interface or true to indicate that you do not want
    // the split view controller to do anything with the secondary view controller.
    //
    // In our case, if the textEditViewController doesn't represent a real page, we don't
    // want to show it.
    return textEditViewController.noteIdentifier == nil
  }

  func splitViewController(_ svc: UISplitViewController, topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
    return .supplementary
  }
}
