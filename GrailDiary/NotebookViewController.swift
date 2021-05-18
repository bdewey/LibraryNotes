// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Logging
import SnapKit
import UIKit

/// Protocol for any UIViewController that displays "reference" material for which we can also show related notes
protocol ReferenceViewController: UIViewController {
  var relatedNotesViewController: UIViewController? { get set }
}

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
public final class NotebookViewController: UIViewController {
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
  // TODO: Get rid of this copy, just read from documentListViewController
  private var focusedNotebookStructure: NotebookStructureViewController.StructureIdentifier = .read {
    didSet {
      documentListViewController.focusedStructure = focusedNotebookStructure
      if notebookSplitViewController.isCollapsed {
        let compactListViewController = DocumentListViewController(database: database)
        compactListViewController.delegate = self
        compactListViewController.focusedStructure = focusedNotebookStructure
        compactNavigationController.pushViewController(compactListViewController, animated: true)
      }
    }
  }

  public func setSecondaryViewController(_ viewController: UIViewController, pushIfCollapsed: Bool) {
    if notebookSplitViewController.isCollapsed {
      if pushIfCollapsed {
        if compactNavigationController.viewControllers.count < 3 {
          compactNavigationController.pushViewController(viewController, animated: true)
        } else {
          compactNavigationController.popToViewController(compactNavigationController.viewControllers[1], animated: true)
          compactNavigationController.pushViewController(viewController, animated: true)
        }
      }
    } else {
      notebookSplitViewController.setViewController(UINavigationController.notebookNavigationController(rootViewController: viewController), for: .secondary)
    }
  }

  public func pushSecondaryViewController(_ viewController: UIViewController) {
    if notebookSplitViewController.isCollapsed {
      compactNavigationController.pushViewController(viewController, animated: true)
    } else {
      notebookSplitViewController.setViewController(viewController, for: .secondary)
    }
  }

  private lazy var primaryNavigationController: UINavigationController = UINavigationController.notebookNavigationController(rootViewController: structureViewController, prefersLargeTitles: true)

  private lazy var structureViewController = makeStructureViewController()

  private func makeStructureViewController() -> NotebookStructureViewController {
    let structureViewController = NotebookStructureViewController(
      database: documentListViewController.database
    )
    structureViewController.delegate = self
    return structureViewController
  }

  /// A list of notes inside the notebook, displayed in the supplementary column
  private lazy var documentListViewController: DocumentListViewController = {
    let documentListViewController = DocumentListViewController(database: database)
    documentListViewController.delegate = self
    return documentListViewController
  }()

  private lazy var compactNavigationController = UINavigationController.notebookNavigationController(rootViewController: makeStructureViewController(), prefersLargeTitles: true)

  /// The split view we are managing.
  private lazy var notebookSplitViewController: UISplitViewController = {
    let supplementaryNavigationController = UINavigationController.notebookNavigationController(rootViewController: documentListViewController)

    let splitViewController = UISplitViewController(style: .tripleColumn)
    splitViewController.setViewController(primaryNavigationController, for: .primary)
    splitViewController.setViewController(supplementaryNavigationController, for: .supplementary)
    splitViewController.setViewController(
      UINavigationController.notebookNavigationController(rootViewController: SavingTextEditViewController(database: database, folder: nil)),
      for: .secondary
    )
    splitViewController.setViewController(compactNavigationController, for: .compact)
    splitViewController.preferredDisplayMode = .oneBesideSecondary
    splitViewController.showsSecondaryOnlyButton = true
    splitViewController.delegate = self
    return splitViewController
  }()

  public override func viewDidLoad() {
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

  public override var canBecomeFirstResponder: Bool { true }

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
    notebookSplitViewController.show(.supplementary)
    documentListViewController.searchBecomeFirstResponder()
  }

  @objc func tagsBecomeFirstResponder() {
    notebookSplitViewController.show(.primary)
    structureViewController.becomeFirstResponder()
  }

  @objc func notesBecomeFirstResponder() {
    notebookSplitViewController.show(.supplementary)
    documentListViewController.becomeFirstResponder()
  }

  @objc func toggleEditMode() {
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
    let hashtag = focusedNotebookStructure.hashtag
    let folder = focusedNotebookStructure.predefinedFolder
    let viewController = SavingTextEditViewController(database: database, folder: folder, currentHashtag: hashtag, autoFirstResponder: true)
    setSecondaryViewController(viewController, pushIfCollapsed: true)
    Logger.shared.info("Created a new view controller for a blank document")
  }

  public func makeNewNoteButtonItem() -> UIBarButtonItem {
    var extraActions = [UIAction]()
    if let apiKey = ApiKey.googleBooks, !apiKey.isEmpty {
      let bookNoteAction = UIAction(title: "Book Note", image: UIImage(systemName: "text.book.closed"), handler: { [weak self] _ in
        let bookSearchViewController = BookSearchViewController(apiKey: apiKey)
        bookSearchViewController.delegate = self
        bookSearchViewController.title = "New Note About Book"
        let navigationController = UINavigationController(rootViewController: bookSearchViewController)
        navigationController.navigationBar.tintColor = .grailTint
        self?.present(navigationController, animated: true)
      })
      extraActions.append(bookNoteAction)
    }
    let webImporters = WebImporterConfiguration.shared.map { config -> UIAction in
      UIAction(title: config.title, image: config.image, handler: { [weak self] _ in
        guard let self = self else { return }
        let webViewController = WebScrapingViewController(initialURL: config.initialURL, javascript: config.importJavascript)
        webViewController.delegate = self
        let navigationController = UINavigationController(rootViewController: webViewController)
        navigationController.navigationBar.tintColor = .grailTint
        self.present(navigationController, animated: true, completion: nil)
      })
    }
    extraActions.append(contentsOf: webImporters)
    let menu: UIMenu? = extraActions.isEmpty ? nil : UIMenu(options: [.displayInline], children: extraActions)
    let primaryAction = UIAction { [weak self] _ in
      self?.makeNewNote()
    }
    let button = UIBarButtonItem(image: UIImage(systemName: "square.and.pencil"), primaryAction: primaryAction, menu: menu)
    button.accessibilityIdentifier = "new-document"
    return button
  }

  func showNoteEditor(noteIdentifier: Note.Identifier?, note: Note, shiftFocus: Bool) {
    let actualNoteIdentifier = noteIdentifier ?? UUID().uuidString
    let noteViewController = SavingTextEditViewController(
      configuration: SavingTextEditViewController.Configuration(
        folder: focusedNotebookStructure.predefinedFolder,
        noteIdentifier: actualNoteIdentifier,
        noteRawText: note.text ?? "",
        noteTitle: note.title
      ),
      noteStorage: database
    )
    noteViewController.setTitleMarkdown(note.title)
    setSecondaryViewController(noteViewController, pushIfCollapsed: shiftFocus)
  }

  // MARK: - State restoration

  private enum ActivityKey {
    static let notebookStructure = "org.brians-brain.GrailDiary.NotebookStructure"
    static let displayMode = "org.brians-brain.GrailDiary.notebookSplitViewController.displayMode"
    static let secondaryViewControllerType = "org.brians-brain.GrailDiary.notebookSplitViewController.secondaryType"
  }

  func updateUserActivity(_ userActivity: NSUserActivity) {
    userActivity.addUserInfoEntries(from: [
      ActivityKey.notebookStructure: focusedNotebookStructure.rawValue,
      ActivityKey.displayMode: notebookSplitViewController.displayMode.rawValue,
    ])
    structureViewController.updateUserActivity(userActivity)

    if let secondaryViewController = self.secondaryViewController {
      userActivity.addUserInfoEntries(from: [ActivityKey.secondaryViewControllerType: secondaryViewController.notebookDetailType])
      secondaryViewController.updateUserActivity(userActivity)
    }
  }

  var secondaryViewController: NotebookSecondaryViewController? {
    if notebookSplitViewController.isCollapsed {
      if compactNavigationController.viewControllers.count >= 3 {
        return compactNavigationController.topViewController as? NotebookSecondaryViewController
      } else {
        return nil
      }
    } else {
      return notebookSplitViewController.viewController(for: .secondary) as? NotebookSecondaryViewController
    }
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
      notebookSplitViewController.preferredDisplayMode = displayMode
    }
    structureViewController.configure(with: userActivity)
    // TODO: Recover secondary controller
    assertionFailure("Not implemented")
  }
}

public extension NotebookViewController {
  func pushNote(with noteIdentifier: Note.Identifier) {
    Logger.shared.info("Handling openNoteCommand. Note id = \(noteIdentifier)")
    do {
      let note = try database.note(noteIdentifier: noteIdentifier)
      let noteViewController = SavingTextEditViewController(
        configuration: SavingTextEditViewController.Configuration(
          folder: focusedNotebookStructure.predefinedFolder,
          noteIdentifier: noteIdentifier,
          noteRawText: note.text ?? "",
          noteTitle: note.title
        ),
        noteStorage: database
      )
      noteViewController.setTitleMarkdown(note.title)
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
    // TODO: There's an awful lot repeated in the book search method
    let hashtag = focusedNotebookStructure.hashtag
    let folder = focusedNotebookStructure.predefinedFolder
    // TODO: I'm abusing the "title" parameter here
    let viewController = SavingTextEditViewController(
      database: database,
      folder: folder,
      title: markdown,
      currentHashtag: hashtag,
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

extension NotebookViewController: BookSearchViewControllerDelegate {
  public func bookSearchViewController(_ viewController: BookSearchViewController, didSelect book: Book) {
    dismiss(animated: true, completion: nil)
    let hashtag = focusedNotebookStructure.hashtag
    let folder = focusedNotebookStructure.predefinedFolder
    let viewController = SavingTextEditViewController(
      database: database,
      folder: folder,
      title: book.markdownTitle,
      initialImage: book.coverImage,
      currentHashtag: hashtag,
      autoFirstResponder: true
    )
    setSecondaryViewController(viewController, pushIfCollapsed: true)
    Logger.shared.info("Created a new view controller for a book!")
  }

  public func bookSearchViewControllerDidCancel(_ viewController: BookSearchViewController) {
    dismiss(animated: true, completion: nil)
  }
}

// MARK: - NotebookStructureViewControllerDelegate

extension NotebookViewController: NotebookStructureViewControllerDelegate {
  func notebookStructureViewController(_ viewController: NotebookStructureViewController, didSelect structure: NotebookStructureViewController.StructureIdentifier) {
    focusedNotebookStructure = structure
  }

  func notebookStructureViewControllerDidRequestChangeFocus(_ viewController: NotebookStructureViewController) {
    notebookSplitViewController.show(.supplementary)
    documentListViewController.becomeFirstResponder()
  }
}

// MARK: - DocumentListViewControllerDelegate

extension NotebookViewController: DocumentListViewControllerDelegate {
  func documentListViewControllerDidRequestChangeFocus(_ viewController: DocumentListViewController) {
    tagsBecomeFirstResponder()
  }

  func documentListViewController(
    _ viewController: DocumentListViewController,
    didRequestShowNote note: Note,
    noteIdentifier: Note.Identifier?,
    shiftFocus: Bool
  ) {
    showNoteEditor(noteIdentifier: noteIdentifier, note: note, shiftFocus: shiftFocus)
  }

  func documentListViewController(_ viewController: DocumentListViewController, didRequestShowQuotes quotes: [ContentFromNote], shiftFocus: Bool) {
    let quotesViewController = QuotesViewController(nibName: nil, bundle: nil)
    quotesViewController.quotes = quotes
    quotesViewController.title = "Random Quotes"
    setSecondaryViewController(quotesViewController, pushIfCollapsed: shiftFocus)
  }

  private func referenceViewController(for note: Note) -> ReferenceViewController? {
    switch note.reference {
    case .none: return nil
    case .some(.webPage(let url)):
      return WebViewController(url: url)
    }
  }
}

private extension UINavigationController {
  /// Creates a UINavigationController with the expected configuration for being a notebook navigation controller.
  static func notebookNavigationController(rootViewController: UIViewController, prefersLargeTitles: Bool = false) -> UINavigationController {
    let navigationController = HackNavigationController(
      rootViewController: rootViewController
    )
    navigationController.navigationBar.prefersLargeTitles = prefersLargeTitles
    navigationController.navigationBar.barTintColor = .grailBackground
    return navigationController
  }
}

// MARK: - UISplitViewControllerDelegate

extension NotebookViewController: UISplitViewControllerDelegate {
  public func splitViewController(
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

  public func splitViewController(
    _ svc: UISplitViewController,
    topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column
  ) -> UISplitViewController.Column {
    let compactDocumentList = DocumentListViewController(database: database)
    compactDocumentList.focusedStructure = focusedNotebookStructure
    compactNavigationController.popToRootViewController(animated: false)
    compactNavigationController.pushViewController(compactDocumentList, animated: false)
    return .compact
//    guard let currentNoteEditor = currentNoteEditor else {
//      // If there's nothing meaningful in the secondary pane, we should show supplementary.
//      return .supplementary
//    }
//
//    // If the current note has reference material, keep it in view.
//    if currentNoteEditor.note.reference != nil {
//      return .secondary
//    }
//
//    // If the current note isn't saved, prefer the supplementary view.
//    if currentNoteEditor.noteIdentifier == nil {
//      return .supplementary
//    }
//
//    // No reason to second-guess UIKit.
//    return proposedTopColumn
  }
}

private final class HackNavigationController: UINavigationController {
  override func pushViewController(_ viewController: UIViewController, animated: Bool) {
    if viewController is UINavigationController {
      Logger.shared.error("What are you doing bro?")
    }
    super.pushViewController(viewController, animated: animated)
  }
}
