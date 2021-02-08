// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import Logging
import SnapKit
import UIKit

/// Creates and wraps a TextEditViewController, then watches for changes and saves them to a database.
/// Changes are autosaved on a periodic interval and flushed when this VC closes.
final class SavingTextEditViewController: UIViewController, TextEditViewControllerDelegate {
  enum ExistingOrUncreatedNote {
    /// An unsaved note that will go into a folder when it is created.
    case unsaved(folder: PredefinedFolder?)

    /// An existing note. It lives in whatever folder it lives in.
    case existing(identifier: Note.Identifier)
  }

  /// Holds configuration settings for the view controller.
  struct Configuration {
    var noteIdentifier: ExistingOrUncreatedNote
    var note: Note
    var initialSelectedRange = NSRange(location: 0, length: 0)
    var autoFirstResponder = false
  }

  /// Designated initializer.
  /// - parameter configuration: Configuration object
  /// - parameter NoteSqliteStorage: Where to save the contents.
  init(configuration: Configuration, noteStorage: NoteDatabase) {
    self.configuration = configuration
    self.noteStorage = noteStorage

    super.init(nibName: nil, bundle: nil)
    setTitleMarkdown(configuration.note.title)
  }

  /// Initializes a view controller for a new, unsaved note.
  convenience init(database: NoteDatabase, folder: PredefinedFolder?, currentHashtag: String? = nil, autoFirstResponder: Bool = false) {
    let (note, initialOffset) = Note.makeBlankNote(hashtag: currentHashtag)
    let configuration = Configuration(
      noteIdentifier: .unsaved(folder: folder),
      note: note,
      initialSelectedRange: NSRange(location: initialOffset, length: 0),
      autoFirstResponder: autoFirstResponder
    )
    self.init(configuration: configuration, noteStorage: database)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public enum ChromeStyle {
    case modal
    case splitViewController
  }

  /// Controls configuration of toolbars & navigation items
  public var chromeStyle = ChromeStyle.splitViewController

  private var configuration: Configuration
  private let noteStorage: NoteDatabase
  private lazy var textEditViewController: TextEditViewController = {
    let viewController = TextEditViewController(imageStorage: noteStorage)
    viewController.delegate = self
    viewController.markdown = configuration.note.text ?? ""
    viewController.selectedRange = configuration.initialSelectedRange
    viewController.autoFirstResponder = configuration.autoFirstResponder
    return viewController
  }()

  private var hasUnsavedChanges = false
  private var autosaveTimer: Timer?

  /// The identifier for the displayed note; nil if the note is not yet saved to the database.
  var noteIdentifier: Note.Identifier? {
    guard case .existing(let noteIdentifier) = configuration.noteIdentifier else {
      return nil
    }
    return noteIdentifier
  }

  /// The current note.
  var note: Note { configuration.note }

  internal func setTitleMarkdown(_ markdown: String) {
    guard chromeStyle == .splitViewController else { return }
    navigationItem.title = ParsedAttributedString(string: markdown, settings: .plainText(textStyle: .body)).string
  }

  override var isEditing: Bool {
    get { textEditViewController.isEditing }
    set { textEditViewController.isEditing = newValue }
  }

  func editEndOfDocument() { textEditViewController.editEndOfDocument() }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(textEditViewController.view)
    textEditViewController.view.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    addChild(textEditViewController)
    textEditViewController.didMove(toParent: self)
    autosaveTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
      if self?.hasUnsavedChanges ?? false { Logger.shared.info("SavingTextEditViewController: autosave") }
      self?.saveIfNeeded()
    })
    navigationItem.largeTitleDisplayMode = .never
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    configureToolbar()
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    configureToolbar()
  }

  @objc private func closeModal() {
    dismiss(animated: true, completion: nil)
  }

  private func configureToolbar() {
    switch chromeStyle {
    case .modal:
      let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeModal))
      navigationItem.rightBarButtonItem = closeButton
    case .splitViewController:
      if splitViewController?.isCollapsed ?? false {
        navigationItem.rightBarButtonItem = nil
        navigationController?.isToolbarHidden = false
        toolbarItems = [UIBarButtonItem.flexibleSpace(), AppCommandsButtonItems.newNote()]
      } else {
        navigationItem.rightBarButtonItem = AppCommandsButtonItems.newNote()
        navigationController?.isToolbarHidden = true
        toolbarItems = []
      }
    }
  }

  /// Writes a note to storage.
  private func updateNote(_ note: Note) {
    assert(Thread.isMainThread)
    var note = note
    // Copy over the initial reference, if any
    note.reference = configuration.note.reference
    setTitleMarkdown(note.title)
    do {
      switch configuration.noteIdentifier {
      case .existing(identifier: let noteIdentifier):
        Logger.shared.info("SavingTextEditViewController: Updating note \(noteIdentifier)")
        try noteStorage.updateNote(noteIdentifier: noteIdentifier, updateBlock: { oldNote in
          var mergedNote = note
          mergedNote.copyContentKeysForMatchingContent(from: oldNote)
          mergedNote.folder = oldNote.folder
          return mergedNote
        })
      case .unsaved(folder: let folder):
        note.folder = folder?.rawValue
        let noteIdentifier = try noteStorage.createNote(note)
        Logger.shared.info("SavingTextEditViewController: Created note \(noteIdentifier)")
        configuration.noteIdentifier = .existing(identifier: noteIdentifier)
      }
    } catch {
      Logger.shared.error("SavingTextEditViewController: Unexpected error saving page: \(error)")
      let alert = UIAlertController(title: "Oops", message: "There was an error saving this note: \(error)", preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
      present(alert, animated: true, completion: nil)
    }
  }

  /// If there is updated markdown, creates a new Note in the background then saves it to storage.
  /// - parameter completion: A block to call after processing changes.
  private func saveIfNeeded(completion: (() -> Void)? = nil) {
    assert(Thread.isMainThread)
    guard hasUnsavedChanges else {
      completion?()
      return
    }
    let note = Note(parsedString: textEditViewController.textStorage.storage.rawString)
    updateNote(note)
    hasUnsavedChanges = false
    completion?()
  }

  func textEditViewControllerDidChangeContents(_ viewController: TextEditViewController) {
    hasUnsavedChanges = true
  }

  func textEditViewControllerDidClose(_ viewController: TextEditViewController) {
    saveIfNeeded {
      Logger.shared.info("SavingTextEditViewController: Flushing and canceling timer")
      try? self.noteStorage.flush()
      self.autosaveTimer?.invalidate()
      self.autosaveTimer = nil
    }
  }

  func testEditViewController(_ viewController: TextEditViewController, hashtagSuggestionsFor hashtag: String) -> [String] {
    let existingHashtags = noteStorage.hashtags.filter { $0.hasPrefix(hashtag) }

    // Make sure that "hashtag" is in the suggested results
    if existingHashtags.first == hashtag {
      return existingHashtags
    } else {
      return Array([[hashtag], existingHashtags].joined())
    }
  }
}
