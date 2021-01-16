// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

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

  public var fileURL: URL { database.fileURL }

  /// What are we viewing in the current structure?
  private var focusedNotebookStructure: NotebookStructureViewController.StructureIdentifier = .allNotes {
    didSet {
      documentListViewController.setFocus(focusedNotebookStructure)
    }
  }

  /// The current editor.
  private var currentNoteEditor: SavingTextEditViewController? {
    didSet {
      guard let currentNoteEditor = currentNoteEditor else { return }
      let note = currentNoteEditor.note
      if let referenceViewController = self.referenceViewController(for: note) {
        currentNoteEditor.chromeStyle = .modal
        currentNoteEditor.navigationItem.title = "Related Notes"
        referenceViewController.relatedNotesViewController = currentNoteEditor
        secondaryNavigationController.viewControllers = [referenceViewController]
      } else {
        currentNoteEditor.chromeStyle = .splitViewController
        secondaryNavigationController.viewControllers = [currentNoteEditor]
      }
      notebookSplitViewController.show(.secondary)
    }
  }

  private lazy var structureViewController: NotebookStructureViewController = {
    let structureViewController = NotebookStructureViewController(
      database: documentListViewController.database
    )
    structureViewController.delegate = self
    return structureViewController
  }()

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

  private lazy var secondaryNavigationController: UINavigationController = {
    let detailViewController = SavingTextEditViewController(database: documentListViewController.database)
    let navigationController = UINavigationController(
      rootViewController: detailViewController
    )
    navigationController.navigationBar.prefersLargeTitles = false
    navigationController.navigationBar.barTintColor = .grailBackground
    navigationController.hidesBarsOnSwipe = true
    return navigationController
  }()

  /// The split view we are managing.
  private lazy var notebookSplitViewController: UISplitViewController = {
    let primaryNavigationController = UINavigationController(rootViewController: structureViewController)
    primaryNavigationController.navigationBar.prefersLargeTitles = true
    primaryNavigationController.navigationBar.barTintColor = .grailBackground

    let splitViewController = UISplitViewController(style: .tripleColumn)
    splitViewController.viewControllers = [
      primaryNavigationController,
      supplementaryNavigationController,
      secondaryNavigationController,
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
    configureKeyCommands()
  }

  override var canBecomeFirstResponder: Bool { true }

  private func configureKeyCommands() {
    let newNoteCommand = UIKeyCommand(
      title: "New Note",
      action: #selector(makeNewNote),
      input: "n",
      modifierFlags: [.command]
    )
    addKeyCommand(newNoteCommand)

    let focusTagsCommand = UIKeyCommand(
      title: "View Tags",
      action: #selector(tagsBecomeFirstResponder),
      input: "1",
      modifierFlags: [.command]
    )
    addKeyCommand(focusTagsCommand)

    let searchKeyCommand = UIKeyCommand(
      title: "Find",
      action: #selector(searchBecomeFirstResponder),
      input: "f",
      modifierFlags: [.command]
    )
    addKeyCommand(searchKeyCommand)

    let toggleEditModeCommand = UIKeyCommand(
      title: "Toggle Edit Mode",
      action: #selector(toggleEditMode),
      input: "\r",
      modifierFlags: [.command]
    )
    addKeyCommand(toggleEditModeCommand)
  }

  @objc func searchBecomeFirstResponder() {
    notebookSplitViewController.show(.supplementary)
    documentListViewController.searchBecomeFirstResponder()
  }

  @objc func tagsBecomeFirstResponder() {
    notebookSplitViewController.show(.primary)
    structureViewController.becomeFirstResponder()
  }

  @objc func toggleEditMode() {
    if currentNoteEditor?.isEditing ?? false {
      currentNoteEditor?.isEditing = false
    } else {
      UIView.animate(withDuration: 0.2) { [notebookSplitViewController] in
        notebookSplitViewController.preferredDisplayMode = .secondaryOnly
      } completion: { [currentNoteEditor] success in
        if success { _ = currentNoteEditor?.editEndOfDocument() }
      }
    }
  }

  @objc func makeNewNote() {
    let hashtag: String?
    switch focusedNotebookStructure {
    case .allNotes:
      hashtag = nil
    case .hashtag(let focusedHashtag):
      hashtag = focusedHashtag
    }
    let viewController = SavingTextEditViewController(database: database, currentHashtag: hashtag, autoFirstResponder: true)
    currentNoteEditor = viewController
    Logger.shared.info("Created a new view controller for a blank document")
  }

  // MARK: - State restoration

  private enum ActivityKey {
    static let notebookStructure = "org.brians-brain.GrailDiary.NotebookStructure"
    static let selectedNote = "org.brians-brain.GrailDiary.SelectedNote"
    static let displayMode = "org.brians-brain.GrailDiary.notebookSplitViewController.displayMode"
  }

  func updateUserActivity(_ userActivity: NSUserActivity) {
    userActivity.addUserInfoEntries(from: [
      ActivityKey.notebookStructure: focusedNotebookStructure.rawValue,
      ActivityKey.selectedNote: currentNoteEditor?.noteIdentifier ?? "",
      ActivityKey.displayMode: notebookSplitViewController.displayMode.rawValue,
    ])
    structureViewController.updateUserActivity(userActivity)
  }

  func configure(with userActivity: NSUserActivity) {
    if
      let structureString = userActivity.userInfo?[ActivityKey.notebookStructure] as? String,
      let focusedNotebookStructure = NotebookStructureViewController.StructureIdentifier(rawValue: structureString)
    {
      self.focusedNotebookStructure = focusedNotebookStructure
    }
    if
      let noteIdentifier = userActivity.userInfo?[ActivityKey.selectedNote] as? String,
      !noteIdentifier.isEmpty,
      let note = try? database.note(noteIdentifier: noteIdentifier)
    {
      documentListViewController(documentListViewController, didRequestShowNote: note, noteIdentifier: noteIdentifier)
    }
    if let rawDisplayMode = userActivity.userInfo?[ActivityKey.displayMode] as? Int,
       let displayMode = UISplitViewController.DisplayMode(rawValue: rawDisplayMode) {
      notebookSplitViewController.preferredDisplayMode = displayMode
    }
    structureViewController.configure(with: userActivity)
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
    currentNoteEditor = noteViewController
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

  func splitViewController(
    _ svc: UISplitViewController,
    topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column
  ) -> UISplitViewController.Column {
    guard let currentNoteEditor = currentNoteEditor else {
      // If there's nothing meaningful in the secondary pane, we should show supplementary.
      return .supplementary
    }

    // If the current note has reference material, keep it in view.
    if currentNoteEditor.note.reference != nil {
      return .secondary
    }

    // If the current note isn't saved, prefer the supplementary view.
    if currentNoteEditor.noteIdentifier == nil {
      return .supplementary
    }

    // No reason to second-guess UIKit.
    return proposedTopColumn
  }
}
