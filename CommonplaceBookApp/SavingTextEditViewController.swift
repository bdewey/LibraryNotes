// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import Foundation
import MiniMarkdown
import SnapKit

/// Watches for changes from a `TextEditViewController` and saves them to storage.
/// Changes are autosaved on a periodic interval and flushed when this VC closes.
final class SavingTextEditViewController: UIViewController, TextEditViewControllerDelegate, MarkdownEditingTextViewImageStoring {
  /// Designated initializer.
  /// - parameter viewController: The view controller to monitor.
  /// - parameter noteIdentifier: The identifier for the contents of `viewController`. If nil, the VC holds unsaved content.
  /// - parameter parsingRules: Rules for parsing the markdown content and extracting metadata.
  /// - parameter noteStorage: Where to save the contents.
  init(_ viewController: TextEditViewController, noteIdentifier: Note.Identifier?, parsingRules: ParsingRules, noteStorage: NoteStorage) {
    self.textEditViewController = viewController
    self.noteIdentifier = noteIdentifier
    self.parsingRules = parsingRules
    self.noteStorage = noteStorage
    super.init(nibName: nil, bundle: nil)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(textEditViewController.view)
    textEditViewController.view.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    addChild(textEditViewController)
    textEditViewController.didMove(toParent: self)
    textEditViewController.delegate = self
    self.autosaveTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
      if self?.hasUnsavedChanges ?? false { DDLogInfo("SavingTextEditViewController: autosave") }
      self?.saveIfNeeded()
    })
    navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
    navigationItem.leftItemsSupplementBackButton = true
    navigationItem.largeTitleDisplayMode = .never
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  internal var noteIdentifier: Note.Identifier?
  private let parsingRules: ParsingRules
  private let noteStorage: NoteStorage
  private let textEditViewController: TextEditViewController

  private var hasUnsavedChanges = false
  private var autosaveTimer: Timer?

  internal func setTitleMarkdown(_ markdown: String) {
    let nodes = parsingRules.parse(markdown)
    let attributedTitle = nodes
      .map { return MarkdownAttributedStringRenderer.textOnly.render(node: $0) }
      .joined()
    navigationItem.title = attributedTitle.string
  }

  /// Writes a note to storage.
  private func updateNote(_ note: Note) {
    assert(Thread.isMainThread)
    setTitleMarkdown(note.metadata.title)
    do {
      if let noteIdentifier = noteIdentifier {
        DDLogInfo("SavingTextEditViewController: Updating note \(noteIdentifier)")
        try noteStorage.updateNote(noteIdentifier: noteIdentifier, updateBlock: { oldNote in
          ChallengeTemplate.assignMatchingTemplateIdentifiers(from: oldNote.challengeTemplates, to: note.challengeTemplates)
          return note
        })
      } else {
        noteIdentifier = try noteStorage.createNote(note)
        DDLogInfo("SavingTextEditViewController: Created note \(noteIdentifier!)")
      }
    } catch {
      DDLogError("SavingTextEditViewController: Unexpected error saving page: \(error)")
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
    let markdown = textEditViewController.markdown
    hasUnsavedChanges = false
    DispatchQueue.global(qos: .default).async {
      let note = Note(markdown: markdown, parsingRules: self.parsingRules)
      DispatchQueue.main.async {
        self.updateNote(note)
        completion?()
      }
    }
  }

  func textEditViewController(_ viewController: TextEditViewController, didChange markdown: String) {
    hasUnsavedChanges = true
  }

  func textEditViewControllerDidClose(_ viewController: TextEditViewController) {
    saveIfNeeded {
      DDLogInfo("SavingTextEditViewController: Flushing and canceling timer")
      try? self.noteStorage.flush()
      self.autosaveTimer?.invalidate()
      self.autosaveTimer = nil
    }
  }

  func markdownEditingTextView(_ textView: MarkdownEditingTextView, store imageData: Data, suffix: String) throws -> String {
    let key = imageData.sha1Digest() + "." + suffix
    return try noteStorage.storeAssetData(imageData, key: key)
  }
}
