// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Combine
import Foundation
import KeyValueCRDT
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

    /// If true, the initial contents are some sort of placeholder, with no real user value.
    ///
    /// This value determines if this view controller is initially visible in compact environments.
    /// As soon as the user edits anything in this view controller, this will be set to false.
    var containsOnlyDefaultContent: Bool
  }

  /// Designated initializer.
  ///
  /// - Parameters:
  ///   - noteIdentifier: The note identifier we are editing. Defaults to a new UUID.
  ///   - note: The note to edit. Defaults to a new, single-heading Markdown note.
  ///   - database: The database that the note is in.
  ///   - containsOnlyDefaultContent: If true, the initial contents are some sort of placeholder, with no real user value. This value determines if this view controller is initially visible in compact environments.
  ///   - initialSelectedRange: Initial range of selected text. Defaults to nil.
  ///   - autoFirstResponder: If true, this view will become the first responder upon appearing.
  init(
    noteIdentifier: Note.Identifier = UUID().uuidString,
    note: Note = Note(markdown: "# \n"),
    database: NoteDatabase,
    coverImageCache: CoverImageCache,
    containsOnlyDefaultContent: Bool,
    initialSelectedRange: NSRange? = nil,
    autoFirstResponder: Bool = false
  ) {
    self.noteIdentifier = noteIdentifier
    self.note = note
    self.noteStorage = database
    self.coverImageCache = coverImageCache
    self.initialSelectedRange = initialSelectedRange
    self.autoFirstResponder = autoFirstResponder
    self.imageStorage = NoteScopedImageStorage(identifier: noteIdentifier, database: database)
    self.restorationState = RestorationState(noteIdentifier: noteIdentifier, containsOnlyDefaultContent: containsOnlyDefaultContent)
    super.init(nibName: nil, bundle: nil)
    setTitleMarkdown(note.metadata.preferredTitle)
    self.noteTextVersionCancellable = database.readPublisher(noteIdentifier: noteIdentifier, key: .noteText)
      .sink(receiveCompletion: { _ in
        Logger.shared.info("No longer getting updates for \(noteIdentifier)")
      }, receiveValue: { [weak self] versions in
        self?.updateVersionIfNeeded(versions)
      })
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private var note: Note
  private let noteStorage: NoteDatabase
  private let coverImageCache: CoverImageCache
  private let imageStorage: NoteScopedImageStorage

  private var coverImage: UIImage? {
    get {
      coverImageCache.coverImage(bookID: noteIdentifier, maxSize: 250)
    }
    set {
      if let imageData = newValue?.jpegData(compressionQuality: 0.8) {
        try? noteStorage.writeValue(
          .blob(mimeType: UTType.jpeg.preferredMIMEType!, blob: imageData),
          noteIdentifier: noteIdentifier,
          key: .coverImage
        )
      } else {
        try? noteStorage.writeValue(
          .null,
          noteIdentifier: noteIdentifier,
          key: .coverImage
        )
      }
      coverImageCache.invalidate()
    }
  }

  private var restorationState: RestorationState
  private let initialSelectedRange: NSRange?
  private let autoFirstResponder: Bool
  private lazy var textEditViewController: TextEditViewController = {
    let viewController = TextEditViewController(imageStorage: imageStorage)
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

  private var noteTextVersionCancellable: AnyCancellable?
  private func updateVersionIfNeeded(_ versions: [NoteDatabaseKey: [Version]]) {
    guard
      let versionArray = versions[.noteText],
      let winningVersion = versionArray.max(by: { $0.timestamp < $1.timestamp }),
      winningVersion.authorID != noteStorage.instanceID
    else {
      return
    }
    Logger.shared.info("Found an updated version of note text. Winning author = \(winningVersion.authorID.uuidString), text = \(winningVersion.value.text ?? "nil")")
    textEditViewController.markdown = winningVersion.value.text ?? ""
    hasUnsavedChanges = false
  }

  /// The identifier for the displayed note; nil if the note is not yet saved to the database.
  let noteIdentifier: Note.Identifier

  internal func setTitleMarkdown(_ markdown: String) {
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
    if let book = note.metadata.book {
      let bookHeader = BookHeader(
        book: book,
        coverImage: coverImageCache.coverImage(bookID: noteIdentifier, maxSize: 250)
      )
      bookHeader.delegate = self
      textEditViewController.extendedNavigationHeaderView = bookHeader
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

  func editBookDetails(book: AugmentedBook) {
    guard let apiKey = ApiKey.googleBooks else { return }
    let bookViewController = BookEditDetailsViewController(apiKey: apiKey, book: book, coverImage: coverImage, showSkipButton: false)
    bookViewController.delegate = self
    bookViewController.title = "Edit Book Details"
    let navigationController = UINavigationController(rootViewController: bookViewController)
    navigationController.navigationBar.tintColor = .grailTint
    present(navigationController, animated: true, completion: nil)
  }

  func insertBookDetails(apiKey: String) {
    let bookViewController = BookEditDetailsViewController(apiKey: apiKey, showSkipButton: false)
    bookViewController.delegate = self
    bookViewController.title = "Insert Book Details"
    let navigationController = UINavigationController(rootViewController: bookViewController)
    navigationController.navigationBar.tintColor = .grailTint
    present(navigationController, animated: true, completion: nil)
  }

  func makeInsertBookDetailsButton() -> UIBarButtonItem? {
    return UIBarButtonItem(image: UIImage(systemName: "text.book.closed"), primaryAction: UIAction { [weak self] _ in
      self?.editOrInsertBookDetails()
    })
  }

  private func editOrInsertBookDetails() {
    if let book = note.metadata.book {
      editBookDetails(book: book)
    } else if let apiKey = ApiKey.googleBooks {
      insertBookDetails(apiKey: apiKey)
    }
  }

  private func configureToolbar() {
    if splitViewController?.isCollapsed ?? false {
      navigationItem.rightBarButtonItem = makeInsertBookDetailsButton()
      navigationController?.isToolbarHidden = false
      if let newNoteButton = notebookViewController?.makeNewNoteButtonItem() {
        toolbarItems = [UIBarButtonItem.flexibleSpace(), newNoteButton]
      }
    } else {
      navigationItem.rightBarButtonItems = [notebookViewController?.makeNewNoteButtonItem(), makeInsertBookDetailsButton()]
        .compactMap { $0 }
      navigationController?.isToolbarHidden = true
      toolbarItems = []
    }
  }

  /// Writes a note to storage.
  private func updateNote(_ note: Note) throws {
    assert(Thread.isMainThread)
    var note = note
    // TODO: This is awkward. Get rid of self.note here and get everything from oldNote.
    // I think this may depend on refactoring updateNote so I can know if oldNote was really an old note,
    // or if it was a blank note instead.
    note.metadata.folder = self.note.metadata.folder
    note.metadata.book = self.note.metadata.book
    note.metadata.creationTimestamp = self.note.metadata.creationTimestamp
    setTitleMarkdown(note.metadata.preferredTitle)
    Logger.shared.debug("SavingTextEditViewController: Updating note \(noteIdentifier)")
    try noteStorage.updateNote(noteIdentifier: noteIdentifier, updateBlock: { oldNote in
      var mergedNote = note
      mergedNote.copyContentKeysForMatchingContent(from: oldNote)
      mergedNote.metadata.folder = note.metadata.folder
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
  private func saveIfNeeded() {
    assert(Thread.isMainThread)
    guard hasUnsavedChanges else {
      return
    }
    let note = Note(parsedString: textEditViewController.parsedAttributedString.rawString)
    tryUpdateNote(note)
    hasUnsavedChanges = false
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
      let reference: String = try imageStorage.storeImageData(imageData, type: type)
      let markdown = "\n\n\(reference)\n\n"
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
    restorationState.containsOnlyDefaultContent = false
  }

  func textEditViewControllerDidClose(_ viewController: TextEditViewController) {
    saveIfNeeded()
    Logger.shared.info("SavingTextEditViewController: Flushing and canceling timer")
    Task {
      do {
        try await noteStorage.flush()
      } catch {
        Logger.shared.error("Error saving changes: \(error)")
      }
      autosaveTimer?.invalidate()
      autosaveTimer = nil
    }
  }

  func testEditViewController(_ viewController: TextEditViewController, hashtagSuggestionsFor hashtag: String) -> [String] {
    let hashtags = (try? noteStorage.allTags) ?? []
    let existingHashtags = hashtags.filter { $0.hasPrefix(hashtag) }

    // Make sure that "hashtag" is in the suggested results
    if existingHashtags.first == hashtag {
      return existingHashtags
    } else {
      return Array([[hashtag], existingHashtags].joined())
    }
  }

  func textEditViewController(_ viewController: TextEditViewController, didAttach book: AugmentedBook) {
    Logger.shared.info("Attaching book: \(book.title)")
    note.metadata.book = book
    note.metadata.modifiedTimestamp = Date()
    tryUpdateNote(note)
  }
}

extension SavingTextEditViewController: NotebookSecondaryViewController {
  static var notebookDetailType: String { "SavingTextEditViewController" }

  func userActivityData() throws -> Data {
    return try JSONEncoder().encode(restorationState)
  }

  var shouldShowWhenCollapsed: Bool { !restorationState.containsOnlyDefaultContent }

  static func makeFromUserActivityData(data: Data, database: NoteDatabase, coverImageCache: CoverImageCache) throws -> SavingTextEditViewController {
    let restorationState = try JSONDecoder().decode(RestorationState.self, from: data)
    let note: Note
    do {
      note = try database.note(noteIdentifier: restorationState.noteIdentifier)
    } catch {
      Logger.shared.warning("Could not load note \(restorationState.noteIdentifier) when recovering user activity. Assuming note wasn't saved.")
      let (text, _) = Note.makeBlankNoteText()
      note = Note(markdown: text)
    }

    return SavingTextEditViewController(
      noteIdentifier: restorationState.noteIdentifier,
      note: note,
      database: database,
      coverImageCache: coverImageCache,
      containsOnlyDefaultContent: restorationState.containsOnlyDefaultContent
    )
  }
}

extension SavingTextEditViewController: BookHeaderDelegate {
  func bookHeader(_ bookHeader: BookHeader, didUpdate book: AugmentedBook) {
    Logger.shared.info("Updating book: \(book.title)")
    note.metadata.book = book
    note.metadata.modifiedTimestamp = Date()
    tryUpdateNote(note)
  }
}

extension SavingTextEditViewController: BookEditDetailsViewControllerDelegate {
  public func bookSearchViewController(_ viewController: BookEditDetailsViewController, didSelect book: AugmentedBook, coverImage: UIImage?) {
    if let image = coverImage, let imageData = image.jpegData(compressionQuality: 0.8) {
      do {
        try imageStorage.storeCoverImage(imageData, type: .jpeg)
      } catch {
        Logger.shared.error("Unexpected error saving image data: \(error)")
      }
    }
    textEditViewController(textEditViewController, didAttach: book)
    textEditViewController.extendedNavigationHeaderView = BookHeader(book: book, coverImage: coverImage)
    dismiss(animated: true, completion: nil)
  }

  public func bookSearchViewControllerDidSkip(_ viewController: BookEditDetailsViewController) {
    // NOTHING
  }

  public func bookSearchViewControllerDidCancel(_ viewController: BookEditDetailsViewController) {
    dismiss(animated: true, completion: nil)
  }
}

// extension SavingTextEditViewController: BookEditDetailsViewControllerDelegate {
//  func bookEditDetailsViewControllerDidCancel(_ viewController: BookEditDetailsViewController) {
//    dismiss(animated: true, completion: nil)
//  }
//
//  func bookEditDetailsViewController(_ viewController: BookEditDetailsViewController, didFinishEditing book: AugmentedBook, coverImage: UIImage?) {
//    Logger.shared.info("Attaching book: \(book.title)")
//    self.coverImage = coverImage
//    note.metadata.book = book
//    note.metadata.modifiedTimestamp = Date()
//    tryUpdateNote(note)
//    let coverImage = coverImageCache.coverImage(bookID: noteIdentifier, maxSize: 250)
//    textEditViewController.extendedNavigationHeaderView = BookHeader(book: book, coverImage: coverImage)
//    dismiss(animated: true, completion: nil)
//  }
// }