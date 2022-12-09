// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Combine
import Foundation
@preconcurrency import KeyValueCRDT
import LinkPresentation
import Logging
import ObjectiveCTextStorageWrapper
import SnapKit
import TextMarkupKit
import UIKit
import UniformTypeIdentifiers

private extension Logger {
  static let textSaving: Logger = {
    var logger = Logger(label: "org.brians-brain.SavingTextEditViewController")
    logger.logLevel = .info
    return logger
  }()
}

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
    self.noteTextVersionCancellable = database.readPublisher(noteIdentifier: noteIdentifier, key: .noteText)
      .sink(receiveCompletion: { _ in
        Logger.textSaving.info("No longer getting updates for \(noteIdentifier)")
      }, receiveValue: { [weak self] versions in
        self?.updateVersionIfNeeded(versions)
      })
    if #available(iOS 16.0, *) {
      self.navigationItem.style = .editor
      let metadata = LPLinkMetadata()
      var urlComponents = URLComponents(url: database.fileURL, resolvingAgainstBaseURL: false)!
      urlComponents.queryItems = [.init(name: "id", value: noteIdentifier)]
      let noteURL = urlComponents.url!
      metadata.originalURL = noteURL
      metadata.url = noteURL
      if let coverImage {
        metadata.imageProvider = NSItemProvider(object: coverImage)
      }
      self.navigationItem.documentProperties = UIDocumentProperties(metadata: metadata)
    }
    setTitleMarkdown(note.metadata.preferredTitle)
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
    if let initialSelectedRange {
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
    if versionArray.count > 1 {
      Logger.textSaving.info("Picked winner \(winningVersion.authorID.uuidString) from \(versionArray.map { ($0.authorID, $0.timestamp) })")
    }
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
    if #available(iOS 16.0, *) {
      if let metadata = navigationItem.documentProperties?.metadata {
        metadata.title = label.attributedText?.string
        navigationItem.documentProperties?.metadata = metadata
      }
    }
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
      if self?.hasUnsavedChanges ?? false { Logger.textSaving.debug("SavingTextEditViewController: autosave") }
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

  @objc func editOrInsertBookDetails() {
    if let book = note.metadata.book {
      editBookDetails(book: book)
    } else if let apiKey = ApiKey.googleBooks {
      insertBookDetails(apiKey: apiKey)
    }
  }

  static var centerItemGroups: [UIBarButtonItemGroup] {
    let blockFormatItems: [UIBarButtonItem] = [
      UIBarButtonItem(title: "Heading", image: UIImage(systemName: "number"), target: nil, action: #selector(TextEditingFormattingActions.toggleHeading)),
      UIBarButtonItem(title: "Quote", image: UIImage(systemName: "text.quote"), target: nil, action: #selector(TextEditingFormattingActions.toggleQuote)),
      UIBarButtonItem(title: "Bulleted list", image: UIImage(systemName: "list.bullet"), target: nil, action: #selector(TextEditingFormattingActions.toggleBulletList)),
      UIBarButtonItem(title: "Numbered list", image: UIImage(systemName: "list.number"), target: nil, action: #selector(TextEditingFormattingActions.toggleNumberedList)),
      UIBarButtonItem(title: "Summary", image: UIImage(systemName: "text.insert"), target: nil, action: #selector(TextEditingFormattingActions.toggleSummaryParagraph)),
    ]
    return [
      UIBarButtonItem(title: "Info", image: UIImage(systemName: "info.circle"), target: nil, action: #selector(editOrInsertBookDetails)).creatingFixedGroup(),
      .optionalGroup(
        customizationIdentifier: "block-format",
        representativeItem: UIBarButtonItem(title: "Paragraph", image: UIImage(systemName: "paragraphsign")),
        items: blockFormatItems
      ),
      .optionalGroup(
        customizationIdentifier: "format",
        representativeItem: UIBarButtonItem(title: "Format", image: UIImage(systemName: "bold.italic.underline")),
        items: [
          TextEditViewController.toggleBoldfaceBarButtonItem,
          TextEditViewController.toggleItalicsBarButtonItem,
        ]
      ),
    ]
  }

  private func configureToolbar() {
    navigationItem.customizationIdentifier = "savingTextEditViewController"
    navigationItem.centerItemGroups = Self.centerItemGroups
    if splitViewController?.isCollapsed ?? false {
      navigationController?.isToolbarHidden = false
      toolbarItems = [UIBarButtonItem.flexibleSpace(), NotebookViewController.makeNewNoteButtonItem()]
    } else {
      navigationItem.pinnedTrailingGroup = NotebookViewController.makeNewNoteButtonItem().creatingFixedGroup()
    }
  }

  /// Writes a note to storage.
  @MainActor
  private func saveNote() throws {
    // TODO: This is awkward. Get rid of self.note here and get everything from oldNote.
    // I think this may depend on refactoring updateNote so I can know if oldNote was really an old note,
    // or if it was a blank note instead.
    Logger.textSaving.debug("SavingTextEditViewController: Updating note \(noteIdentifier)")
    try noteStorage.updateNote(noteIdentifier: noteIdentifier, updateBlock: { oldNote in
      var mergedNote = note
      mergedNote.copyContentKeysForMatchingContent(from: oldNote)
      mergedNote.metadata.folder = note.metadata.folder
      return mergedNote
    })
  }

  @MainActor
  private func tryUpdateNote() {
    do {
      try saveNote()
    } catch {
      Logger.textSaving.error("SavingTextEditViewController: Unexpected error saving page: \(error)")
      let alert = UIAlertController(title: "Oops", message: "There was an error saving this note: \(error)", preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
      present(alert, animated: true, completion: nil)
    }
  }

  /// If there is updated markdown, creates a new Note in the background then saves it to storage.
  /// - parameter completion: A block to call after processing changes.
  @MainActor
  private func saveIfNeeded() {
    assert(Thread.isMainThread)
    guard hasUnsavedChanges else {
      return
    }
    note.updateMarkdown(textEditViewController.parsedAttributedString.rawString)
    tryUpdateNote()
    hasUnsavedChanges = false
  }

  /// Saves the current contents to the database, whether or not hasUnsavedChanges is true.
  private func forceSave() throws {
    note.updateMarkdown(textEditViewController.parsedAttributedString.rawString)
    try saveNote()
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
      Logger.textSaving.error("Could not save initial image: \(error)")
    }
  }

  func textEditViewControllerDidChangeContents(_ viewController: TextEditViewController) {
    hasUnsavedChanges = true
    restorationState.containsOnlyDefaultContent = false
  }

  func textEditViewControllerDidClose(_ viewController: TextEditViewController) {
    saveIfNeeded()
    Logger.textSaving.info("SavingTextEditViewController: Flushing and canceling timer")
    Task {
      do {
        try await noteStorage.flush()
      } catch {
        Logger.textSaving.error("Error saving changes: \(error)")
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
    Logger.textSaving.info("Attaching book: \(book.title)")
    note.metadata.book = book
    note.metadata.modifiedTimestamp = Date()
    tryUpdateNote()
  }
}

extension SavingTextEditViewController: NotebookSecondaryViewController {
  static var notebookDetailType: String { "SavingTextEditViewController" }

  func userActivityData() throws -> Data {
    try JSONEncoder().encode(restorationState)
  }

  var shouldShowWhenCollapsed: Bool { !restorationState.containsOnlyDefaultContent }

  static func makeFromUserActivityData(data: Data, database: NoteDatabase, coverImageCache: CoverImageCache) throws -> SavingTextEditViewController {
    let restorationState = try JSONDecoder().decode(RestorationState.self, from: data)
    let note: Note
    do {
      note = try database.note(noteIdentifier: restorationState.noteIdentifier)
    } catch {
      Logger.textSaving.warning("Could not load note \(restorationState.noteIdentifier) when recovering user activity. Assuming note wasn't saved.")
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
    Logger.textSaving.info("Updating book: \(book.title)")
    note.metadata.book = book
    note.metadata.modifiedTimestamp = Date()
    tryUpdateNote()
  }
}

extension SavingTextEditViewController: BookEditDetailsViewControllerDelegate {
  public func bookSearchViewController(_ viewController: BookEditDetailsViewController, didSelect book: AugmentedBook, coverImage: UIImage?) {
    if let image = coverImage, let imageData = image.jpegData(compressionQuality: 0.8) {
      do {
        try imageStorage.storeCoverImage(imageData, type: .jpeg)
      } catch {
        Logger.textSaving.error("Unexpected error saving image data: \(error)")
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
