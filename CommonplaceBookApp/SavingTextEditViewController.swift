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

/// Watches for changes from a `TextEditViewController` and saves them to storage.
/// Changes are autosaved on a periodic interval and flushed when this VC closes.
final class SavingTextEditViewController: UIViewController, TextEditViewControllerDelegate, MarkdownEditingTextViewImageStoring {
  /// Designated initializer.
  /// - parameter viewController: The view controller to monitor.
  /// - parameter noteIdentifier: The identifier for the contents of `viewController`. If nil, the VC holds unsaved content.
  /// - parameter NoteSqliteStorage: Where to save the contents.
  init(_ viewController: TextEditViewController, noteIdentifier: Note.Identifier?, noteStorage: NoteDatabase) {
    self.textEditViewController = viewController
    self.noteIdentifier = noteIdentifier
    self.noteStorage = noteStorage
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  internal var noteIdentifier: Note.Identifier?
  private let noteStorage: NoteDatabase
  private let textEditViewController: TextEditViewController

  private var hasUnsavedChanges = false
  private var autosaveTimer: Timer?

  internal func setTitleMarkdown(_ markdown: String) {
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
    navigationController?.hidesBarsOnSwipe = true
    configureToolbar()
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    configureToolbar()
  }

  private func configureToolbar() {
    if splitViewController?.isCollapsed ?? false {
      navigationController?.isToolbarHidden = false
      toolbarItems = [UIBarButtonItem.flexibleSpace(), AppCommandsButtonItems.newNote()]
    } else {
      navigationItem.rightBarButtonItem = AppCommandsButtonItems.newNote()
      navigationController?.isToolbarHidden = true
      toolbarItems = []
    }
  }

  /// Writes a note to storage.
  private func updateNote(_ note: Note) {
    assert(Thread.isMainThread)
    setTitleMarkdown(note.metadata.title)
    do {
      if let noteIdentifier = noteIdentifier {
        Logger.shared.info("SavingTextEditViewController: Updating note \(noteIdentifier)")
        try noteStorage.updateNote(noteIdentifier: noteIdentifier, updateBlock: { oldNote in
          var mergedNote = note
          mergedNote.copyContentKeysForMatchingContent(from: oldNote)
          return mergedNote
        })
      } else {
        noteIdentifier = try noteStorage.createNote(note)
        Logger.shared.info("SavingTextEditViewController: Created note \(noteIdentifier!)")
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
