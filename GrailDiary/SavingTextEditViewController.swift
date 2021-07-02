// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Foundation
import Logging
import ObjectiveCTextStorageWrapper
import SnapKit
import TextMarkupKit
import UIKit
import UniformTypeIdentifiers

/// Creates and wraps a TextEditViewController, then watches for changes and saves them to a database.
/// Changes are autosaved on a periodic interval and flushed when this VC closes.
final class SavingTextEditViewController: UIViewController, TextEditViewControllerDelegate {
  /// Holds configuration settings for the view controller.
  private struct RestorationState: Codable {
    var noteIdentifier: String
  }

  init(
    noteIdentifier: Note.Identifier = UUID().uuidString,
    note: Note = Note(markdown: "# \n"),
    database: NoteDatabase,
    initialSelectedRange: NSRange? = nil,
    initialImage: UIImage? = nil,
    autoFirstResponder: Bool = false
  ) {
    self.noteIdentifier = noteIdentifier
    self.note = note
    self.noteStorage = database
    self.initialSelectedRange = initialSelectedRange
    self.autoFirstResponder = autoFirstResponder
    self.restorationState = RestorationState(noteIdentifier: noteIdentifier)
    super.init(nibName: nil, bundle: nil)
    setTitleMarkdown(note.title)
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

  private var note: Note
  private let noteStorage: NoteDatabase
  private let restorationState: RestorationState
  private let initialSelectedRange: NSRange?
  private let autoFirstResponder: Bool
  private lazy var textEditViewController: TextEditViewController = {
    let viewController = TextEditViewController(imageStorage: self)
    viewController.markdown = note.text ?? ""
    if let initialSelectedRange = initialSelectedRange {
      viewController.selectedRawTextRange = initialSelectedRange
    }
    viewController.autoFirstResponder = autoFirstResponder
    viewController.delegate = self
    return viewController
  }()

  private var hasUnsavedChanges = false
  private var autosaveTimer: Timer?

  /// The identifier for the displayed note; nil if the note is not yet saved to the database.
  let noteIdentifier: Note.Identifier

  internal func setTitleMarkdown(_ markdown: String) {
    guard chromeStyle == .splitViewController else { return }
    let label = UILabel(frame: .zero)
    label.attributedText = ParsedAttributedString(string: markdown, style: .plainText(textStyle: .headline))
    navigationItem.titleView = label
    textEditViewController.navigationTitleView = label
  }

  override var isEditing: Bool {
    get { textEditViewController.isEditing }
    set { textEditViewController.isEditing = newValue }
  }

  func editEndOfDocument() { textEditViewController.editEndOfDocument() }

  override func viewDidLoad() {
    super.viewDidLoad()
    if case .book(let book) = note.reference {
      textEditViewController.extendedNavigationHeaderView = BookHeader(
        book: AugmentedBook(book),
        coverImage: (try? noteStorage.readAssociatedData(from: noteIdentifier, key: Note.coverImageKey))?.image(maxSize: 250)
      )
    }
    view.addSubview(textEditViewController.view)
    textEditViewController.view.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    addChild(textEditViewController)
    textEditViewController.didMove(toParent: self)
    autosaveTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
      if self?.hasUnsavedChanges ?? false { Logger.shared.debug("SavingTextEditViewController: autosave") }
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
        if let newNoteButton = notebookViewController?.makeNewNoteButtonItem() {
          toolbarItems = [UIBarButtonItem.flexibleSpace(), newNoteButton]
        }
      } else {
        navigationItem.rightBarButtonItem = notebookViewController?.makeNewNoteButtonItem()
        navigationController?.isToolbarHidden = true
        toolbarItems = []
      }
    }
  }

  /// Writes a note to storage.
  private func updateNote(_ note: Note) throws {
    assert(Thread.isMainThread)
    var note = note
    // TODO: This is awkward. Get rid of self.note here and get everything from oldNote.
    // I think this may depend on refactoring updateNote so I can know if oldNote was really an old note,
    // or if it was a blank note instead.
    note.folder = self.note.folder
    note.reference = self.note.reference
    note.creationTimestamp = self.note.creationTimestamp
    setTitleMarkdown(note.title)
    Logger.shared.debug("SavingTextEditViewController: Updating note \(noteIdentifier)")
    try noteStorage.updateNote(noteIdentifier: noteIdentifier, updateBlock: { oldNote in
      var mergedNote = note
      mergedNote.copyContentKeysForMatchingContent(from: oldNote)
      mergedNote.folder = note.folder
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
    let note = Note(parsedString: textEditViewController.parsedAttributedString.rawString)
    tryUpdateNote(note)
    hasUnsavedChanges = false
    completion?()
  }

  /// Saves the current contents to the database, whether or not hasUnsavedChanges is true.
  private func forceSave() throws {
    let note = Note(parsedString: textEditViewController.parsedAttributedString.rawString)
    try updateNote(note)
    hasUnsavedChanges = false
  }

  /// Inserts an image at the current insertion point.
  private func insertImageData(_ imageData: Data, type: UTType) {
    do {
      try forceSave()
      let reference = try storeImageData(imageData, type: type, key: nil)
      let markdown = "\n\n![](\(reference))\n\n"
      let initialRange = textEditViewController.selectedRange
      var rawRange = textEditViewController.parsedAttributedString.rawStringRange(forRange: initialRange)
      rawRange.location += markdown.utf16.count
      rawRange.length = 0
      textEditViewController.textView.textStorage.replaceCharacters(in: initialRange, with: markdown)
      textEditViewController.selectedRange = textEditViewController.parsedAttributedString.range(forRawStringRange: rawRange)
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

  func textEditViewController(_ viewController: TextEditViewController, didAttach book: Book) {
    Logger.shared.info("Attaching book: \(book.title)")
    note.reference = .book(book)
    note.timestamp = Date()
    tryUpdateNote(note)
  }
}

extension SavingTextEditViewController: NotebookSecondaryViewController {
  static var notebookDetailType: String { "SavingTextEditViewController" }

  func userActivityData() throws -> Data {
    return try JSONEncoder().encode(restorationState)
  }

  static func makeFromUserActivityData(data: Data, database: NoteDatabase) throws -> SavingTextEditViewController {
    let restorationState = try JSONDecoder().decode(RestorationState.self, from: data)
    let note: Note
    do {
      note = try database.note(noteIdentifier: restorationState.noteIdentifier)
    } catch {
      Logger.shared.warning("Could not load note \(restorationState.noteIdentifier) when recovering user activity. Assuming note wasn't saved.")
      let (text, _) = Note.makeBlankNoteText()
      note = Note(markdown: text)
    }

    return SavingTextEditViewController(noteIdentifier: restorationState.noteIdentifier, note: note, database: database)
  }
}

extension SavingTextEditViewController: ImageStorage {
  func storeImageData(_ imageData: Data, type: UTType, key: String?) throws -> String {
    try forceSave()
    let imageKey = try noteStorage.writeAssociatedData(imageData, noteIdentifier: noteIdentifier, role: "embeddedImage", type: type, key: key)
    return "![](\(imageKey))"
  }

  func retrieveImageDataForKey(_ key: String) throws -> Data {
    return try noteStorage.readAssociatedData(from: noteIdentifier, key: key)
  }
}
