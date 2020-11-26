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

import Foundation
import Logging
import SnapKit
import UIKit

/// Creates and wraps a TextEditViewController, then watches for changes and saves them to a database.
/// Changes are autosaved on a periodic interval and flushed when this VC closes.
final class SavingTextEditViewController: UIViewController, TextEditViewControllerDelegate, MarkdownEditingTextViewImageStoring {
  /// Holds configuration settings for the view controller.
  struct Configuration {
    var noteIdentifier: Note.Identifier?
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

    let viewController = TextEditViewController()
    viewController.markdown = configuration.note.text ?? ""
    viewController.selectedRange = configuration.initialSelectedRange
    viewController.autoFirstResponder = configuration.autoFirstResponder
    self.textEditViewController = viewController
    super.init(nibName: nil, bundle: nil)
    setTitleMarkdown(configuration.note.metadata.title)
  }

  /// Initializes a view controller for a new, unsaved note.
  convenience init(database: NoteDatabase, currentHashtag: String? = nil, autoFirstResponder: Bool = false) {
    let (note, initialOffset) = Note.makeBlankNote(hashtag: currentHashtag)
    let configuration = Configuration(
      noteIdentifier: nil,
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
  private let textEditViewController: TextEditViewController

  private var hasUnsavedChanges = false
  private var autosaveTimer: Timer?

  /// The identifier for the displayed note; nil if the note is not yet saved to the database.
  var noteIdentifier: Note.Identifier? { configuration.noteIdentifier }

  /// The current note.
  var note: Note { configuration.note }

  internal func setTitleMarkdown(_ markdown: String) {
    guard chromeStyle == .splitViewController else { return }
    navigationItem.title = ParsedAttributedString(string: markdown, settings: .plainText(textStyle: .body)).string
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
  
  @objc private func didTapTestText() {
    var lines = [String]()
    lines.append("The Shining\n* ")
    for i in 0 ..< 25 {
      lines.append("All work and no play makes ?[who?](Jack) a dull boy. \(i)\n")
    }
    for character in lines.joined() {
      textEditViewController.insertText(String(character))
    }
  }
  
  private func makeTestTextButton() -> UIBarButtonItem {
    UIBarButtonItem(
      image: UIImage(systemName: "rectangle.and.pencil.and.ellipsis"),
      style: .plain,
      target: self,
      action: #selector(didTapTestText)
    )
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
        toolbarItems = [makeTestTextButton(), UIBarButtonItem.flexibleSpace(), AppCommandsButtonItems.newNote()]
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
    setTitleMarkdown(note.metadata.title)
    do {
      if let noteIdentifier = configuration.noteIdentifier {
        Logger.shared.info("SavingTextEditViewController: Updating note \(noteIdentifier)")
        try noteStorage.updateNote(noteIdentifier: noteIdentifier, updateBlock: { oldNote in
          var mergedNote = note
          mergedNote.copyContentKeysForMatchingContent(from: oldNote)
          return mergedNote
        })
      } else {
        configuration.noteIdentifier = try noteStorage.createNote(note)
        Logger.shared.info("SavingTextEditViewController: Created note \(configuration.noteIdentifier!)")
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

  func markdownEditingTextView(_ textView: MarkdownEditingTextView, store imageData: Data, suffix: String) throws -> String {
    let key = imageData.sha1Digest() + "." + suffix
    return try noteStorage.storeAssetData(imageData, key: key)
  }
}
