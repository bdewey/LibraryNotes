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

/// Manages the UISplitViewController that shows the contents of a notebook. It's a three-column design:
/// - primary: The overall notebook structure (currently based around hashtags)
/// - supplementary: A list of notes
/// - secondary: An individual note
final class NotebookViewController: UIViewController {
  init(notebook: NoteStorage) {
    self.notebook = notebook
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// The notebook we are viewing
  public let notebook: NoteStorage

  /// What are we viewing in the current structure?
  private var focusedNotebookStructure: NotebookStructureViewController.StructureIdentifier = .allNotes {
    didSet {
      documentListViewController.setFocus(focusedNotebookStructure)
    }
  }

  /// A list of notes inside the notebook, displayed in the supplementary column
  private lazy var documentListViewController: DocumentListViewController = {
    let documentListViewController = DocumentListViewController(notebook: notebook)
    documentListViewController.didTapFilesAction = { [weak self] in
      if UIApplication.isSimulator, false {
        let messageText = "Document browser doesn't work in the simulator"
        let alertController = UIAlertController(title: "Error", message: messageText, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        documentListViewController.present(alertController, animated: true, completion: nil)
      } else {
        AppDelegate.openedDocumentBookmark = nil
        documentListViewController.dismiss(animated: true, completion: nil)
      }
    }
    return documentListViewController
  }()

  /// The split view we are managing.
  private lazy var notebookSplitViewController: UISplitViewController = {
    let supplementaryNavigationController = UINavigationController(
      rootViewController: documentListViewController
    )
    supplementaryNavigationController.navigationBar.prefersLargeTitles = false
    supplementaryNavigationController.navigationBar.barTintColor = .grailBackground

    let hashtagViewController = NotebookStructureViewController(
      notebook: documentListViewController.notebook
    )
    hashtagViewController.delegate = self
    let primaryNavigationController = UINavigationController(rootViewController: hashtagViewController)
    primaryNavigationController.navigationBar.prefersLargeTitles = true
    primaryNavigationController.navigationBar.barTintColor = .grailBackground

    let splitViewController = UISplitViewController(style: .tripleColumn)
    let detailViewController = UINavigationController(
      rootViewController:
      TextEditViewController.makeBlankDocument(
        notebook: documentListViewController.notebook,
        currentHashtag: nil,
        autoFirstResponder: false
      )
    )
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
    let viewController = TextEditViewController.makeBlankDocument(
      notebook: notebook,
      currentHashtag: hashtag,
      autoFirstResponder: true
    )
    // I don't know why but you need to wrap this in a nav controller before pushing
    let navController = UINavigationController(rootViewController: viewController)
    notebookSplitViewController.showDetailViewController(navController, sender: nil)
    Logger.shared.info("Created a new view controller for a blank document")
  }
}

extension NotebookViewController: NotebookStructureViewControllerDelegate {
  func notebookStructureViewController(_ viewController: NotebookStructureViewController, didSelect structure: NotebookStructureViewController.StructureIdentifier) {
    focusedNotebookStructure = structure
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
