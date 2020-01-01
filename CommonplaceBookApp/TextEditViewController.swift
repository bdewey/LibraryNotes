// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import MiniMarkdown
import MobileCoreServices
import UIKit

public protocol TextEditViewControllerDelegate: AnyObject {
  func textEditViewController(_ viewController: TextEditViewController, didChange markdown: String)
  func textEditViewControllerDidClose(_ viewController: TextEditViewController)
}

/// Allows editing of a single text file.
public final class TextEditViewController: UIViewController {
  /// Designated initializer.
  public init(notebook: NoteStorage) {
    self.parsingRules = notebook.parsingRules

    var renderers = TextEditViewController.renderers
    notebook.addImageRenderer(to: &renderers)
    self.textStorage = TextEditViewController.makeTextStorage(
      parsingRules: parsingRules,
      formatters: TextEditViewController.formatters(),
      renderers: renderers
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
    notebook: NoteStorage,
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
      parsingRules: notebook.parsingRules,
      noteStorage: notebook
    )
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // Init-time state.

  private let parsingRules: ParsingRules
  private let textStorage: MiniMarkdownTextStorage

  public weak var delegate: (TextEditViewControllerDelegate & MarkdownEditingTextViewImageStoring)?

  /// The markdown
  public var markdown: String {
    get {
      return textStorage.markdown
    }
    set {
      textStorage.markdown = newValue
    }
  }

  /// Identifier of the page we are editing.
  public var noteIdentifier: Note.Identifier?

  private static func formatters(
  ) -> [NodeType: RenderedMarkdown.FormattingFunction] {
    var formatters: [NodeType: RenderedMarkdown.FormattingFunction] = [:]
    formatters[.heading] = {
      let heading = $0 as! Heading // swiftlint:disable:this force_cast
      switch heading.headingLevel {
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
    formatters[.delimiter] = { delimiter, attributes in
      if delimiter.parent is QuestionAndAnswer.PrefixedLine {
        attributes.bold = true
        attributes.listLevel = 1
      } else {
        attributes.color = UIColor.quaternaryLabel
      }
    }
    formatters[.bold] = { $1.bold = true }
    formatters[.emphasis] = { $1.italic.toggle() }
    formatters[.table] = { $1.familyName = "Menlo" }
    formatters[.codeSpan] = { $1.familyName = "Menlo" }
    formatters[.cloze] = { $1.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.3) }
    formatters[.clozeHint] = {
      $1.color = UIColor.secondaryLabel
    }
    formatters[.hashtag] = { $1.backgroundColor = UIColor.secondarySystemBackground }
    formatters[.blockQuote] = {
      $1.italic = true
      $1.blockquoteBorderColor = UIColor.systemGreen
      $1.listLevel += 1
    }
    return formatters
  }

  private static let renderers: [NodeType: RenderedMarkdown.RenderFunction] = {
    var renderers: [NodeType: RenderedMarkdown.RenderFunction] = [:]
    renderers[.listItem] = { node, attributes in
      let listItem = node as! ListItem // swiftlint:disable:this force_cast
      let text = String(listItem.slice.string[listItem.markerRange])
      let replacement = listItem.listType == .unordered
        ? "\u{2022}\t"
        : text.replacingOccurrences(of: " ", with: "\t")
      return NSAttributedString(string: replacement, attributes: attributes)
    }
    renderers[.delimiter] = { node, attributes in
      var text = String(node.slice.substring)
      if node.parent is Heading || node.parent is BlockQuote || node.parent is QuestionAndAnswer.PrefixedLine {
        text = text.replacingOccurrences(of: " ", with: "\t")
      }
      return NSAttributedString(
        string: text,
        attributes: attributes
      )
    }
    return renderers
  }()

  private static func makeTextStorage(
    parsingRules: ParsingRules,
    formatters: [NodeType: RenderedMarkdown.FormattingFunction],
    renderers: [NodeType: RenderedMarkdown.RenderFunction]
  ) -> MiniMarkdownTextStorage {
    let textStorage = MiniMarkdownTextStorage(
      parsingRules: parsingRules,
      formatters: formatters,
      renderers: renderers
    )
    textStorage.defaultAttributes = [
      .font: UIFont.preferredFont(forTextStyle: .body),
      .foregroundColor: UIColor.label,
    ]
    textStorage.defaultAttributes.headIndent = 28
    textStorage.defaultAttributes.firstLineHeadIndent = 28
    return textStorage
  }

  private lazy var textView: UITextView = {
    let layoutManager = LayoutManager()
    textStorage.addLayoutManager(layoutManager)
    let textContainer = NSTextContainer()
    layoutManager.addTextContainer(textContainer)
    let textView = MarkdownEditingTextView(frame: .zero, textContainer: textContainer)
    textView.backgroundColor = UIColor.systemBackground
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

  public override func loadView() {
    view = textView
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
    navigationItem.leftItemsSupplementBackButton = true
    view.accessibilityIdentifier = "edit-document-view"
    textView.delegate = self
  }

  /// If true, the text view will become first responder upon becoming visible.
  public var autoFirstResponder = false

  public override func viewWillAppear(_ animated: Bool) {
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

  public override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    delegate?.textEditViewControllerDidClose(self)
  }

  public override func viewWillLayoutSubviews() {
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

  public override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    DDLogDebug("Checking if we can perform action \(action)")
    if action == #selector(paste(itemProviders:)), UIPasteboard.general.image != nil {
      DDLogDebug("Looks like you want to paste an image! Okay!")
      return true
    }
    return super.canPerformAction(action, withSender: sender)
  }

  public override func paste(itemProviders: [NSItemProvider]) {
    DDLogInfo("Pasting \(itemProviders)")
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
    delegate?.textEditViewController(self, didChange: self.textStorage.markdown)
  }
}

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
    guard range.length == 0 else { return true }
    if text == "\n" {
      if let currentNode = textStorage.node(at: range.location),
        let listItem = currentNode.findFirstAncestor(
          where: { $0.type == .listItem }
        ) as? ListItem {
        if listItem.isEmpty {
          // List termination! Someone's hitting return on a list item that contains nothing.
          // Erase this marker.
          replaceCharacters(
            in: NSRange(
              location: listItem.initialLocationPair.rendered,
              length: listItem.markdown.count
            ),
            with: "\n"
          )
          return false
        }
        switch listItem.listType {
        case .unordered:
          replaceCharacters(in: range, with: "\n* ")
        case .ordered:
          if let containerNumber = listItem.orderedListNumber {
            replaceCharacters(in: range, with: "\n\(containerNumber + 1). ")
          } else {
            return true
          }
        }
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
    } else {
      return true
    }
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
