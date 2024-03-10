// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import os
import SnapKit
import UIKit

public extension UIViewController {
  /// Walks up parent view controllers to find one that is a NotebookViewController.
  var notebookViewController: NotebookViewController? {
    findParent(where: { $0 is NotebookViewController }) as? NotebookViewController
  }

  func findParent(where predicate: (UIViewController) -> Bool) -> UIViewController? {
    var currentViewController: UIViewController? = self
    while currentViewController != nil {
      // See the line above, we know this is non-nil
      if predicate(currentViewController!) {
        return currentViewController
      }
      currentViewController = currentViewController?.parent ?? currentViewController?.presentingViewController
    }
    return nil
  }
}

/// Manages the UISplitViewController that shows the contents of a notebook. It's a three-column design:
/// - primary: The overall notebook structure (currently based around hashtags)
/// - supplementary: A list of notes
/// - secondary: An individual note
public final class NotebookViewController: UISplitViewController {
  init(database: NoteDatabase) {
    self.database = database
    self.coverImageCache = CoverImageCache(database: database)
    self.documentListViewController = DocumentListViewController(database: database, coverImageCache: coverImageCache)
    super.init(style: .tripleColumn)
    let supplementaryNavigationController = UINavigationController.notebookNavigationController(rootViewController: documentListViewController, prefersLargeTitles: true)

    setViewController(primaryNavigationController, for: .primary)
    setViewController(supplementaryNavigationController, for: .supplementary)
    setViewController(
      UINavigationController.notebookNavigationController(rootViewController: SavingTextEditViewController(database: database, coverImageCache: coverImageCache, containsOnlyDefaultContent: true)),
      for: .secondary
    )
    setViewController(compactNavigationController, for: .compact)
    primaryBackgroundStyle = .sidebar
    preferredPrimaryColumnWidth = 240
    preferredSupplementaryColumnWidth = 340
    preferredDisplayMode = .twoBesideSecondary
    showsSecondaryOnlyButton = true
    delegate = self
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// The notebook we are viewing
  private let database: NoteDatabase

  /// Global cache
  private let coverImageCache: CoverImageCache

  public var fileURL: URL { database.fileURL }

  /// What are we viewing in the current structure?
  // TODO: Get rid of this copy, just read from documentListViewController
  private var focusedNotebookStructure: NotebookStructureViewController.StructureIdentifier = .read {
    didSet {
      documentListViewController.focusedStructure = focusedNotebookStructure
      if isCollapsed {
        let compactListViewController = DocumentListViewController(database: database, coverImageCache: coverImageCache)
        compactListViewController.focusedStructure = focusedNotebookStructure
        compactNavigationController.pushViewController(compactListViewController, animated: true)
      }
    }
  }

  public func setSecondaryViewController(_ viewController: NotebookSecondaryViewController, pushIfCollapsed: Bool) {
    if isCollapsed {
      if pushIfCollapsed {
        if compactNavigationController.viewControllers.count < 3 {
          compactNavigationController.pushViewController(viewController, animated: true)
        } else {
          compactNavigationController.popToViewController(compactNavigationController.viewControllers[1], animated: true)
          compactNavigationController.pushViewController(viewController, animated: true)
        }
      }
    } else {
      setViewController(UINavigationController.notebookNavigationController(rootViewController: viewController), for: .secondary)
    }
  }

  public func pushSecondaryViewController(_ viewController: UIViewController) {
    if isCollapsed {
      compactNavigationController.pushViewController(viewController, animated: true)
    } else {
      setViewController(viewController, for: .secondary)
    }
  }

  #if targetEnvironment(macCatalyst)
    private lazy var primaryNavigationController = UINavigationController.notebookNavigationController(
      rootViewController: structureViewController,
      barTintColor: nil,
      prefersLargeTitles: false
    )
  #else
    private lazy var primaryNavigationController = UINavigationController.notebookNavigationController(
      rootViewController: structureViewController,
      barTintColor: .grailBackground,
      prefersLargeTitles: false
    )
  #endif

  private lazy var structureViewController = makeStructureViewController()

  private func makeStructureViewController() -> NotebookStructureViewController {
    let structureViewController = NotebookStructureViewController(
      database: documentListViewController.database
    )
    structureViewController.delegate = self
    return structureViewController
  }

  /// A list of notes inside the notebook, displayed in the supplementary column
  private let documentListViewController: DocumentListViewController

  private lazy var compactNavigationController = UINavigationController.notebookNavigationController(rootViewController: makeStructureViewController(), prefersLargeTitles: true)

  override public func viewDidLoad() {
    super.viewDidLoad()

    configureKeyCommands()
  }

  override public var canBecomeFirstResponder: Bool { true }

  private var isFirstAppearance = true
  override public func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if isFirstAppearance {
      isFirstAppearance = false
      documentListViewController.becomeFirstResponder()
    }
  }

  private func configureKeyCommands() {
    let focusTagsCommand = UIKeyCommand(
      title: "View Tags",
      action: #selector(tagsBecomeFirstResponder),
      input: "1",
      modifierFlags: [.command]
    )
    addKeyCommand(focusTagsCommand)

    let focusNotesCommand = UIKeyCommand(
      title: "View Notes",
      action: #selector(notesBecomeFirstResponder),
      input: "2",
      modifierFlags: [.command]
    )
    addKeyCommand(focusNotesCommand)

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
    show(.supplementary)
    documentListViewController.searchBecomeFirstResponder()
  }

  @objc func tagsBecomeFirstResponder() {
    show(.primary)
    structureViewController.becomeFirstResponder()
  }

  @objc func notesBecomeFirstResponder() {
    show(.supplementary)
    documentListViewController.becomeFirstResponder()
  }

  @objc func toggleEditMode() {
    assertionFailure("Not implemented")
//    if currentNoteEditor?.isEditing ?? false {
//      currentNoteEditor?.isEditing = false
//    } else {
//      UIView.animate(withDuration: 0.2) { [notebookSplitViewController] in
//        notebookSplitViewController.preferredDisplayMode = .secondaryOnly
//      } completion: { [currentNoteEditor] success in
//        if success { _ = currentNoteEditor?.editEndOfDocument() }
//      }
//    }
  }

  @objc func makeNewNote() {
    if let apiKey = ApiKey.googleBooks, !apiKey.isEmpty {
      let bookSearchViewController = BookEditDetailsViewController(apiKey: apiKey, showSkipButton: true)
      bookSearchViewController.delegate = self
      bookSearchViewController.title = "Add Book"
      let navigationController = UINavigationController(rootViewController: bookSearchViewController)
      navigationController.navigationBar.tintColor = .grailTint
      present(navigationController, animated: true)
    } else {
      let hashtag = focusedNotebookStructure.hashtag
      let folder = focusedNotebookStructure.predefinedFolder
      let (text, offset) = Note.makeBlankNoteText(hashtag: hashtag)
      var note = Note(markdown: text)
      note.metadata.folder = folder?.rawValue
      let viewController = SavingTextEditViewController(
        note: note,
        database: database,
        coverImageCache: coverImageCache,
        containsOnlyDefaultContent: true,
        initialSelectedRange: NSRange(location: offset, length: 0),
        autoFirstResponder: true
      )
      setSecondaryViewController(viewController, pushIfCollapsed: true)
      Logger.shared.info("Created a new view controller for a blank document")
    }
  }

  override public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    if action == #selector(editOrInsertBookDetails) {
      return secondaryViewController is SavingTextEditViewController
    } else {
      return super.canPerformAction(action, withSender: sender)
    }
  }

  /// Forward the `editOrInsertBookDetails` selector to the active `SavingTextEditViewController`, if it is visible in the window.
  ///
  /// This is to enable the "info" toolbar button to work even when the editor window doesn't have focus, but something else in the notebook does.
  @objc private func editOrInsertBookDetails() {
    guard let editor = secondaryViewController as? SavingTextEditViewController else {
      return
    }
    editor.editOrInsertBookDetails()
  }

  public static func makeNewNoteButtonItem() -> UIBarButtonItem {
    UIBarButtonItem(title: "New book", image: UIImage(systemName: "plus"), target: nil, action: #selector(makeNewNote))
  }

  func showNoteEditor(noteIdentifier: Note.Identifier?, note: Note, shiftFocus: Bool) {
    let actualNoteIdentifier = noteIdentifier ?? UUID().uuidString
    let noteViewController = SavingTextEditViewController(
      noteIdentifier: actualNoteIdentifier,
      note: note,
      database: database,
      coverImageCache: coverImageCache,
      containsOnlyDefaultContent: false
    )
    setSecondaryViewController(noteViewController, pushIfCollapsed: shiftFocus)
  }

  // MARK: - State restoration

  private enum ActivityKey {
    static let notebookStructure = "org.brians-brain.GrailDiary.NotebookStructure"
    static let displayMode = "org.brians-brain.GrailDiary.notebookSplitViewController.displayMode"
    static let secondaryViewControllerType = "org.brians-brain.GrailDiary.notebookSplitViewController.secondaryType"
    static let secondaryViewControllerData = "org.brians-brain.GrailDiary.notebookSplitViewController.secondaryData"
  }

  func updateUserActivity(_ userActivity: NSUserActivity) {
    userActivity.addUserInfoEntries(from: [
      ActivityKey.notebookStructure: focusedNotebookStructure.rawValue,
      ActivityKey.displayMode: displayMode.rawValue,
    ])
    structureViewController.updateUserActivity(userActivity)

    if let secondaryViewController {
      do {
        let controllerType = type(of: secondaryViewController).notebookDetailType
        userActivity.addUserInfoEntries(
          from: [
            ActivityKey.secondaryViewControllerType: controllerType,
            ActivityKey.secondaryViewControllerData: try secondaryViewController.userActivityData(),
          ]
        )
      } catch {
        Logger.shared.error("Unexpected error saving secondary VC: \(error)")
      }
    }
  }

  var secondaryViewController: NotebookSecondaryViewController? {
    secondaryViewController(forCollaped: isCollapsed)
  }

  func secondaryViewController(forCollaped collapsed: Bool) -> NotebookSecondaryViewController? {
    if collapsed {
      if compactNavigationController.viewControllers.count >= 3 {
        return compactNavigationController.topViewController as? NotebookSecondaryViewController
      } else {
        return nil
      }
    } else if let navigationController = viewController(for: .secondary) as? UINavigationController {
      return navigationController.viewControllers.first as? NotebookSecondaryViewController
    }
    return nil
  }

  func configure(with userActivity: NSUserActivity) {
    if
      let structureString = userActivity.userInfo?[ActivityKey.notebookStructure] as? String,
      let focusedNotebookStructure = NotebookStructureViewController.StructureIdentifier(rawValue: structureString)
    {
      self.focusedNotebookStructure = focusedNotebookStructure
    }
    if let rawDisplayMode = userActivity.userInfo?[ActivityKey.displayMode] as? Int,
       let displayMode = UISplitViewController.DisplayMode(rawValue: rawDisplayMode)
    {
      preferredDisplayMode = displayMode
    }
    structureViewController.configure(with: userActivity)

    if let secondaryViewControllerType = userActivity.userInfo?[ActivityKey.secondaryViewControllerType] as? String,
       let secondaryViewControllerData = userActivity.userInfo?[ActivityKey.secondaryViewControllerData] as? Data
    {
      do {
        let secondaryViewController = try NotebookSecondaryViewControllerRegistry.shared.reconstruct(
          type: secondaryViewControllerType,
          data: secondaryViewControllerData,
          database: database,
          coverImageCache: coverImageCache
        )
        setSecondaryViewController(secondaryViewController, pushIfCollapsed: true)
      } catch {
        Logger.shared.error("Error recovering secondary view controller: \(error)")
      }
    }
  }
}

public extension NotebookViewController {
  func pushNote(with noteIdentifier: Note.Identifier, selectedText: String? = nil, autoFirstResponder: Bool = false) {
    Logger.shared.info("Handling openNoteCommand. Note id = \(noteIdentifier)")
    do {
      let note = try database.note(noteIdentifier: noteIdentifier)
      let rawText = note.text ?? ""
      let initialRange = selectedText.flatMap { (rawText as NSString).range(of: $0) }
      let noteViewController = SavingTextEditViewController(
        noteIdentifier: noteIdentifier,
        note: note,
        database: database,
        coverImageCache: coverImageCache,
        containsOnlyDefaultContent: false,
        initialSelectedRange: initialRange,
        autoFirstResponder: autoFirstResponder
      )
      setSecondaryViewController(noteViewController, pushIfCollapsed: true)
      // TODO: Figure out how to make a "push" make sense in a split view controller
      //      pushSecondaryViewController(noteViewController)
      documentListViewController.selectPage(with: noteIdentifier)
    } catch {
      Logger.shared.error("Unexpected error getting note \(noteIdentifier): \(error)")
    }
  }
}

// MARK: - WebScrapingViewControllerDelegate

extension NotebookViewController: WebScrapingViewControllerDelegate {
  public func webScrapingViewController(_ viewController: WebScrapingViewController, didScrapeMarkdown markdown: String) {
    dismiss(animated: true, completion: nil)
    Logger.shared.info("Creating a new page with markdown: \(markdown)")
    let (text, offset) = Note.makeBlankNoteText(title: markdown, hashtag: focusedNotebookStructure.hashtag)
    var note = Note(markdown: text)
    note.metadata.folder = focusedNotebookStructure.predefinedFolder?.rawValue
    // TODO: I'm abusing the "title" parameter here
    let viewController = SavingTextEditViewController(
      note: note,
      database: database,
      coverImageCache: coverImageCache,
      containsOnlyDefaultContent: false,
      initialSelectedRange: NSRange(location: offset, length: 0),
      autoFirstResponder: true
    )
    setSecondaryViewController(viewController, pushIfCollapsed: true)
    Logger.shared.info("Created a new view controller for a book!")
  }

  public func webScrapingViewControllerDidCancel(_ viewController: WebScrapingViewController) {
    dismiss(animated: true, completion: nil)
  }
}

// MARK: - BookSearchViewControllerDelegate

extension NotebookViewController: BookEditDetailsViewControllerDelegate {
  public func bookSearchViewController(_ viewController: BookEditDetailsViewController, didSelect book: AugmentedBook, coverImage: UIImage?) {
    dismiss(animated: true, completion: nil)
    var note = Note(markdown: "")
    note.metadata.book = book
    do {
      let identifier = try database.createNote(note)
      if let image = coverImage, let imageData = image.jpegData(compressionQuality: 0.8) {
        try NoteScopedImageStorage(identifier: identifier, database: database).storeCoverImage(imageData, type: .jpeg)
      }
      let viewController = SavingTextEditViewController(
        noteIdentifier: identifier,
        note: note,
        database: database,
        coverImageCache: coverImageCache,
        containsOnlyDefaultContent: false,
        autoFirstResponder: true
      )
      setSecondaryViewController(viewController, pushIfCollapsed: true)
      Logger.shared.info("Created a new view controller for a book!")
    } catch {
      Logger.shared.error("Unexpected error creating note for book \(String(describing: book)): \(String(describing: error))")
    }
  }

  public func bookSearchViewControllerDidSkip(_ viewController: BookEditDetailsViewController) {
    dismiss(animated: true, completion: nil)
    makeNewNote()
  }

  public func bookSearchViewControllerDidCancel(_ viewController: BookEditDetailsViewController) {
    dismiss(animated: true, completion: nil)
  }
}

// MARK: - NotebookStructureViewControllerDelegate

extension NotebookViewController: NotebookStructureViewControllerDelegate {
  func notebookStructureViewController(_ viewController: NotebookStructureViewController, didSelect structure: NotebookStructureViewController.StructureIdentifier) {
    focusedNotebookStructure = structure
  }

  func notebookStructureViewControllerDidRequestChangeFocus(_ viewController: NotebookStructureViewController) {
    show(.supplementary)
    documentListViewController.becomeFirstResponder()
  }
}

// MARK: - DocumentListViewControllerDelegate

extension NotebookViewController {
  func documentListViewControllerDidRequestChangeFocus(_ viewController: DocumentListViewController) {
    tagsBecomeFirstResponder()
  }
}

private extension UINavigationController {
  /// Creates a UINavigationController with the expected configuration for being a notebook navigation controller.
  static func notebookNavigationController(
    rootViewController: UIViewController,
    barTintColor: UIColor? = .grailBackground,
    prefersLargeTitles: Bool = false
  ) -> UINavigationController {
    let navigationController = UINavigationController(
      rootViewController: rootViewController
    )
//    navigationController.navigationBar.prefersLargeTitles = prefersLargeTitles
//    navigationController.navigationBar.barTintColor = barTintColor
    return navigationController
  }
}

// MARK: - UISplitViewControllerDelegate

extension NotebookViewController: UISplitViewControllerDelegate {
  public func splitViewController(
    _ svc: UISplitViewController,
    displayModeForExpandingToProposedDisplayMode proposedDisplayMode: UISplitViewController.DisplayMode
  ) -> UISplitViewController.DisplayMode {
    if let secondaryViewController = secondaryViewController(forCollaped: true) {
      do {
        let activityData = try secondaryViewController.userActivityData()
        let viewController = try NotebookSecondaryViewControllerRegistry.shared.reconstruct(
          type: type(of: secondaryViewController).notebookDetailType,
          data: activityData,
          database: database,
          coverImageCache: coverImageCache
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
          self.setSecondaryViewController(viewController, pushIfCollapsed: false)
        }
      } catch {
        Logger.shared.error("Unexpected error rebuilding view hierarchy")
      }
    }
    return proposedDisplayMode
  }

  public func splitViewController(
    _ svc: UISplitViewController,
    topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column
  ) -> UISplitViewController.Column {
    let compactDocumentList = DocumentListViewController(database: database, coverImageCache: coverImageCache)
    compactDocumentList.focusedStructure = focusedNotebookStructure
    compactNavigationController.popToRootViewController(animated: false)
    compactNavigationController.pushViewController(compactDocumentList, animated: false)

    if let secondaryViewController = secondaryViewController(forCollaped: false), secondaryViewController.shouldShowWhenCollapsed {
      do {
        let activityData = try secondaryViewController.userActivityData()
        let viewController = try NotebookSecondaryViewControllerRegistry.shared.reconstruct(
          type: type(of: secondaryViewController).notebookDetailType,
          data: activityData,
          database: database,
          coverImageCache: coverImageCache
        )
        compactNavigationController.pushViewController(viewController, animated: false)
      } catch {
        Logger.shared.error("Unexpected error rebuilding view hierarchy")
      }
    }
    return .compact
  }
}
