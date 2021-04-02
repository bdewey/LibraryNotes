// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import Logging
import SnapKit
import UIKit
import UniformTypeIdentifiers

/// Creates and wraps a TextEditViewController, then watches for changes and saves them to a database.
/// Changes are autosaved on a periodic interval and flushed when this VC closes.
final class SavingTextEditViewController: UIViewController, TextEditViewControllerDelegate {
  /// Holds configuration settings for the view controller.
  struct Configuration {
    var folder: PredefinedFolder?
    var noteIdentifier: String
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
    self.noteIdentifier = configuration.noteIdentifier
    super.init(nibName: nil, bundle: nil)
    setTitleMarkdown(configuration.note.title)
  }

  /// Initializes a view controller for a new, unsaved note.
  convenience init(
    database: NoteDatabase,
    folder: PredefinedFolder?,
    title: String? = nil,
    initialImage: UIImage? = nil,
    currentHashtag: String? = nil,
    autoFirstResponder: Bool = false
  ) {
    let (note, initialOffset) = Note.makeBlankNote(title: title, hashtag: currentHashtag)
    let configuration = Configuration(
      folder: folder,
      noteIdentifier: UUID().uuidString,
      note: note,
      initialSelectedRange: NSRange(location: initialOffset, length: 0),
      autoFirstResponder: autoFirstResponder
    )
    self.init(configuration: configuration, noteStorage: database)
    if let initialImage = initialImage,
       let convertedData = initialImage.jpegData(compressionQuality: 0.8)
    {
      insertImageData(convertedData, type: .jpeg)
    }
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
    let viewController = TextEditViewController(imageStorage: self)
    viewController.markdown = configuration.note.text ?? ""
    viewController.selectedRange = configuration.initialSelectedRange
    viewController.autoFirstResponder = configuration.autoFirstResponder
    viewController.delegate = self
    return viewController
  }()

  private var hasUnsavedChanges = false
  private var autosaveTimer: Timer?

  /// The identifier for the displayed note; nil if the note is not yet saved to the database.
  let noteIdentifier: Note.Identifier

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
        if let newNoteButton = toolbarButtonBuilder?.makeNewNoteButtonItem() {
          toolbarItems = [UIBarButtonItem.flexibleSpace(), newNoteButton]
        }
      } else {
        navigationItem.rightBarButtonItem = toolbarButtonBuilder?.makeNewNoteButtonItem()
        navigationController?.isToolbarHidden = true
        toolbarItems = []
      }
    }
  }

  /// Writes a note to storage.
  private func updateNote(_ note: Note) throws {
    assert(Thread.isMainThread)
    var note = note
    // Copy over the initial reference, if any
    note.reference = configuration.note.reference
    setTitleMarkdown(note.title)
    note.folder = configuration.folder?.rawValue
    Logger.shared.debug("SavingTextEditViewController: Updating note \(noteIdentifier)")
    try noteStorage.updateNote(noteIdentifier: noteIdentifier, updateBlock: { oldNote in
      var mergedNote = note
      mergedNote.copyContentKeysForMatchingContent(from: oldNote)
      mergedNote.folder = oldNote.folder
      return mergedNote
    })
  }

  private func tryUpdateNote(_ note: Note) {
    do {
      try updateNote(note)
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
    tryUpdateNote(note)
    hasUnsavedChanges = false
    completion?()
  }

  /// Saves the current contents to the database, whether or not hasUnsavedChanges is true.
  private func forceSave() throws {
    let note = Note(parsedString: textEditViewController.textStorage.storage.rawString)
    try updateNote(note)
    hasUnsavedChanges = false
  }

  /// Inserts an image at the current insertion point.
  private func insertImageData(_ imageData: Data, type: UTType) {
    do {
      try forceSave()
      let reference = try storeImageData(imageData, type: type)
      let markdown = "\n\n![](\(reference))\n\n"
      let initialRange = textEditViewController.selectedRange
      var rawRange = textEditViewController.textStorage.storage.rawStringRange(forRange: initialRange)
      rawRange.location += markdown.utf16.count
      rawRange.length = 0
      textEditViewController.textStorage.replaceCharacters(in: initialRange, with: markdown)
      textEditViewController.selectedRange = textEditViewController.textStorage.storage.range(forRawStringRange: rawRange)
    } catch {
      Logger.shared.error("Could not save initial image: \(error)")
    }
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

extension SavingTextEditViewController: ImageStorage {
  func storeImageData(_ imageData: Data, type: UTType) throws -> String {
    return try noteStorage.writeAssociatedData(imageData, noteIdentifier: noteIdentifier, role: "embeddedImage", type: type)
  }

  func retrieveImageDataForKey(_ key: String) throws -> Data {
    return try noteStorage.readAssociatedData(from: noteIdentifier, key: key)
  }
}
