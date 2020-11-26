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

import Logging
import MobileCoreServices
import UIKit

public protocol TextEditViewControllerDelegate: AnyObject {
  func textEditViewControllerDidChangeContents(_ viewController: TextEditViewController)
  func textEditViewControllerDidClose(_ viewController: TextEditViewController)
}

/// Allows editing of a single text file.
public final class TextEditViewController: UIViewController {
  /// Designated initializer.
  public init(notebook: NoteSqliteStorage) {
    self.textStorage = TextEditViewController.makeTextStorage(
      formatters: TextEditViewController.formatters()
    )
    super.init(nibName: nil, bundle: nil)
    textStorage.delegate = self
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleKeyboardNotification(_:)),
      name: UIResponder.keyboardWillHideNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleKeyboardNotification(_:)),
      name: UIResponder.keyboardWillChangeFrameNotification,
      object: nil
    )
  }

  /// Constructs a new blank document that will save back to `notebook` on changes.
  static func makeBlankDocument(
    notebook: NoteSqliteStorage,
    currentHashtag: String?,
    autoFirstResponder: Bool
  ) -> SavingTextEditViewController {
    var initialText = "# "
    let initialOffset = initialText.count
    initialText += "\n"
    if let hashtag = currentHashtag {
      initialText += hashtag
      initialText += "\n"
    }
    let viewController = TextEditViewController(notebook: notebook)
    viewController.markdown = initialText
    viewController.selectedRange = NSRange(location: initialOffset, length: 0)
    viewController.autoFirstResponder = autoFirstResponder
    return SavingTextEditViewController(
      viewController,
      noteIdentifier: nil,
      noteStorage: notebook
    )
  }

  @available(*, unavailable)
  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // Init-time state.

  public let textStorage: ParsedTextStorage

  public weak var delegate: (TextEditViewControllerDelegate & MarkdownEditingTextViewImageStoring)?

  /// The markdown
  public var markdown: String {
    get {
      return textStorage.storage.rawString as String
    }
    set {
      textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length), with: newValue)
    }
  }

  /// Identifier of the page we are editing.
  public var noteIdentifier: Note.Identifier?

  private static func formatters(
  ) -> [SyntaxTreeNodeType: FormattingFunction] {
    var formatters: [SyntaxTreeNodeType: FormattingFunction] = [:]
    formatters[.header] = {
      let headingLevel = $0.children[0].length
      switch headingLevel {
      case 1:
        $1.textStyle = .title1
      case 2:
        $1.textStyle = .title2
      default:
        $1.textStyle = .title3
      }
      $1.listLevel = 1
    }
    formatters[.list] = { $1.listLevel += 1 }
    formatters[.delimiter] = { _, attributes in
      attributes.color = .quaternaryLabel
      // TODO: Support Q&A cards
//      if delimiter.parent is QuestionAndAnswer.PrefixedLine {
//        attributes.bold = true
//        attributes.listLevel = 1
//      } else {
//        attributes.color = UIColor.quaternaryLabel
//      }
    }
    formatters[.questionAndAnswer] = { $1.listLevel = 1 }
    formatters[.qnaDelimiter] = { $1.bold = true }
    formatters[.strongEmphasis] = { $1.bold = true }
    formatters[.emphasis] = { $1.italic.toggle() }

    // TODO:
    formatters[.code] = { $1.familyName = "Menlo" }
    formatters[.cloze] = { $1.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.3) }
    formatters[.clozeHint] = {
      $1.color = UIColor.secondaryLabel
    }
    formatters[.hashtag] = { $1.backgroundColor = UIColor.grailSecondaryBackground }

    formatters[.blockquote] = {
      $1.italic = true
      $1.blockquoteBorderColor = UIColor.systemOrange
      $1.listLevel += 1
    }
    return formatters
  }

  private static func makeTextStorage(
    formatters: [SyntaxTreeNodeType: FormattingFunction]
  ) -> ParsedTextStorage {
    var defaultAttributes: AttributedStringAttributes = [
      .font: UIFont.preferredFont(forTextStyle: .body),
      .foregroundColor: UIColor.label,
    ]
    defaultAttributes.headIndent = 28
    defaultAttributes.firstLineHeadIndent = 28
    let storage = ParsedAttributedString(
      grammar: MiniMarkdownGrammar.shared,
      defaultAttributes: defaultAttributes,
      formattingFunctions: formatters,
      replacementFunctions: [
        .softTab: formatTab,
        .unorderedListOpening: formatBullet,
      ]
    )
    return ParsedTextStorage(storage: storage)
  }

  private lazy var textView: UITextView = {
    let layoutManager = LayoutManager()
    textStorage.addLayoutManager(layoutManager)
    let textContainer = NSTextContainer()
    layoutManager.addTextContainer(textContainer)
    let textView = MarkdownEditingTextView(frame: .zero, textContainer: textContainer)
    textView.backgroundColor = .grailBackground
    textView.textContainerInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    textView.pasteConfiguration = UIPasteConfiguration(
      acceptableTypeIdentifiers: [
        kUTTypeJPEG as String,
        kUTTypePNG as String,
        kUTTypeImage as String,
        kUTTypePlainText as String,
      ]
    )
    textView.imageStorage = delegate
    return textView
  }()

  public var selectedRange: NSRange {
    get {
      return textView.selectedRange
    }
    set {
      textView.selectedRange = newValue
    }
  }

  // MARK: - Lifecycle

  override public func loadView() {
    view = textView
  }

  override public func viewDidLoad() {
    super.viewDidLoad()
    view.accessibilityIdentifier = "edit-document-view"
    textView.delegate = self
  }

  /// If true, the text view will become first responder upon becoming visible.
  public var autoFirstResponder = false

  override public func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    textView.contentOffset = CGPoint(x: 0, y: -1 * textView.adjustedContentInset.top)
    if autoFirstResponder {
      textView.becomeFirstResponder()
      // We only do this behavior on first appearance.
      autoFirstResponder = false
    }
    adjustMargins(size: view!.bounds.size)
    let highlightMenuItem = UIMenuItem(title: "Highlight", action: #selector(convertTextToCloze))
    UIMenuController.shared.menuItems = [highlightMenuItem]
  }

  override public func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    delegate?.textEditViewControllerDidClose(self)
  }

  override public func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    adjustMargins(size: view.frame.size)
  }

  private func adjustMargins(size: CGSize) {
    // I wish I could use autolayout to set the insets.
    let readableContentGuide = textView.readableContentGuide
    textView.textContainerInset = UIEdgeInsets(
      top: 8,
      left: readableContentGuide.layoutFrame.minX,
      bottom: 8,
      right: textView.bounds.maxX - readableContentGuide.layoutFrame.maxX
    )
  }

  // MARK: - Keyboard

  @objc func handleKeyboardNotification(_ notification: Notification) {
    guard let keyboardInfo = KeyboardInfo(notification) else { return }
    textView.contentInset.bottom = keyboardInfo.frameEnd.height
    textView.verticalScrollIndicatorInsets.bottom = textView.contentInset.bottom
    textView.scrollRangeToVisible(textView.selectedRange)
  }

  // MARK: - Paste

  override public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    Logger.shared.debug("Checking if we can perform action \(action)")
    if action == #selector(paste(itemProviders:)), UIPasteboard.general.image != nil {
      Logger.shared.debug("Looks like you want to paste an image! Okay!")
      return true
    }
    return super.canPerformAction(action, withSender: sender)
  }

  override public func paste(itemProviders: [NSItemProvider]) {
    Logger.shared.info("Pasting \(itemProviders)")
  }
}

extension TextEditViewController: NSTextStorageDelegate {
  public func textStorage(
    _ textStorage: NSTextStorage,
    didProcessEditing editedMask: NSTextStorage.EditActions,
    range editedRange: NSRange,
    changeInLength delta: Int
  ) {
    guard editedMask.contains(.editedCharacters) else { return }
    delegate?.textEditViewControllerDidChangeContents(self)
  }
}

// MARK: - UITextViewDelegate

extension TextEditViewController: UITextViewDelegate {
  func replaceCharacters(in range: NSRange, with str: String) {
    textStorage.replaceCharacters(in: range, with: str)
    textView.selectedRange = NSRange(location: range.location + str.count, length: 0)
  }

  public func textView(
    _ textView: UITextView,
    shouldChangeTextIn range: NSRange,
    replacementText text: String
  ) -> Bool {
    // We do syntax highlighting. Don't do typing attributes, ever.
    textView.typingAttributes = [:]

    // Right now we only do special processing when inserting a newline
    guard range.length == 0, text == "\n" else { return true }
    let nodePath = textStorage.storage.path(to: range.location)
    if let listItem = nodePath.first(where: { $0.node.type == .listItem }) {
      if let paragraph = listItem.first(where: { $0.type == .paragraph }) {
        let paragraphText = textStorage.storage[paragraph.range]
        if String(utf16CodeUnits: paragraphText, count: paragraphText.count).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          // List termination! Someone's hitting return on a list item that contains nothing.
          // Erase this marker.
          replaceCharacters(
            in: NSRange(
              location: listItem.startIndex,
              length: listItem.node.length
            ),
            with: "\n"
          )
          return false
        }
      }

      // List continuation!
      //
      // I'm force-unwrapping here because if there is a list item in the path but no list,
      // then the grammar is wrong and crashing is appropriate.
      let list = nodePath.first(where: { $0.node.type == .list })!
      let listType = list.node[ListTypeKey.self]!
      switch listType {
      case .unordered:
        replaceCharacters(in: range, with: "\n* ")
      case .ordered:
        let listNumber: Int
        if let listNumberNode = listItem.first(where: { $0.type == .orderedListNumber }) {
          let chars = textStorage.storage[NSRange(location: listNumberNode.startIndex, length: listNumberNode.node.length)]
          let string = String(utf16CodeUnits: chars, count: chars.count)
          listNumber = Int(string) ?? 0
        } else {
          listNumber = 0
        }
        replaceCharacters(in: range, with: "\n\(listNumber + 1). ")
      }
      return false
    } else if line(at: range.location).hasPrefix("Q: ") {
      replaceCharacters(in: range, with: "\nA: ")
    } else if line(at: range.location).hasPrefix("A:\t") {
      replaceCharacters(in: range, with: "\n\nQ: ")
    } else {
      // To make this be a separate paragraph in any conventional Markdown processor, we need
      // the blank line.
      replaceCharacters(in: range, with: "\n\n")
    }
    return false
  }

  /// Gets the line of text that contains a given location.
  private func line(at location: Int) -> String {
    let string = textStorage.string
    var startIndex = string.index(string.startIndex, offsetBy: location)
    if startIndex == string.endIndex || string[startIndex] == "\n" {
      startIndex = string.index(before: startIndex)
    }
    while startIndex != string.startIndex, startIndex == string.endIndex || string[startIndex] != "\n" {
      startIndex = string.index(before: startIndex)
    }
    if string[startIndex] == "\n" {
      startIndex = string.index(after: startIndex)
    }
    var endIndex = startIndex
    while endIndex != string.endIndex, string[endIndex] != "\n" {
      endIndex = string.index(after: endIndex)
    }
    return String(string[startIndex ..< endIndex])
  }
}

// MARK: - Commands

private extension TextEditViewController {
  /// Converts the currently selected text to a cloze.
  @objc func convertTextToCloze() {
    let range = textView.selectedRange
    textView.selectedRange = NSRange(location: range.upperBound, length: 0)
    textView.insertText(")")
    textView.selectedRange = NSRange(location: range.lowerBound, length: 0)
    textView.insertText("?[](")
    textView.selectedRange = NSRange(location: range.upperBound + 4, length: 0)
  }
}

// MARK: - Replacement functions

private func formatTab(
  node: SyntaxTreeNode,
  startIndex: Int,
  buffer: SafeUnicodeBuffer
) -> [unichar] {
  return Array("\t".utf16)
}

private func formatBullet(
  node: SyntaxTreeNode,
  startIndex: Int,
  buffer: SafeUnicodeBuffer
) -> [unichar] {
  return Array("\u{2022}".utf16)
}
