// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

import CommonplaceBook
import MaterialComponents
import MiniMarkdown
import TextBundleKit

private typealias TextEditViewControllerDocument = EditableDocument

extension FileMetadata {
  fileprivate func makeDocument() -> EditableDocument? {
    if contentTypeTree.contains("public.plain-text") {
      return PlainTextDocument(fileURL: fileURL)
    } else if contentTypeTree.contains("org.textbundle.package") {
      return TextBundleEditableDocument(fileURL: fileURL)
    } else {
      return nil
    }
  }
}

/// Allows editing of a single text file.
final class TextEditViewController: UIViewController, UITextViewDelegate {

  /// Designated initializer.
  init?(fileMetadata: FileMetadata) {
    self.fileMetadata = fileMetadata
    guard let document = fileMetadata.makeDocument() else {
      let message = MDCSnackbarMessage(text: "Could not open \(fileMetadata.displayName)")
      MDCSnackbarManager.show(message)
      return nil
    }
    var renderers = TextEditViewController.renderers
    if let configurer = document as? ConfiguresRenderers {
      configurer.configureRenderers(&renderers)
    }
    self.document = document
    self.textStorage = TextEditViewController.makeTextStorage(
      formatters: TextEditViewController.formatters,
      renderers: renderers
    )
    super.init(nibName: nil, bundle: nil)
    self.navigationItem.title = fileMetadata.displayName
    self.addChild(appBar.headerViewController)
    self.document.delegate = self
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(handleKeyboardNotification(_:)),
                                           name: UIResponder.keyboardWillHideNotification,
                                           object: nil)
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(handleKeyboardNotification(_:)),
                                           name: UIResponder.keyboardWillChangeFrameNotification,
                                           object: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // Init-time state.

  private let fileMetadata: FileMetadata
  private var document: TextEditViewControllerDocument!
  private let textStorage: MiniMarkdownTextStorage

  let appBar: MDCAppBar = {
    let appBar = MDCAppBar()
    MDCAppBarColorThemer.applySemanticColorScheme(Stylesheet.default.colorScheme, to: appBar)
    MDCAppBarTypographyThemer.applyTypographyScheme(Stylesheet.default.typographyScheme, to: appBar)
    return appBar
  }()

  private static let formatters: [NodeType: RenderedMarkdown.FormattingFunction] = {
    var formatters: [NodeType: RenderedMarkdown.FormattingFunction] = [:]
    formatters[.heading] = { $1.fontSize = 24 }
    formatters[.list] = { $1.listLevel += 1 }
    formatters[.bold] = { $1.bold = true }
    formatters[.emphasis] = { $1.italic = true }
    formatters[.table] = { $1.familyName = "Menlo" }
    return formatters
  }()

  private static let renderers: [NodeType: RenderedMarkdown.RenderFunction] = {
    var renderers: [NodeType: RenderedMarkdown.RenderFunction] = [:]
    renderers[.listItem] = { (node, attributes) in
      let listItem = node as! ListItem // swiftlint:disable:this force_cast
      let text = String(listItem.slice.string[listItem.markerRange])
      let replacement = listItem.listType == .unordered
        ? "\u{2022}\t"
        : text.replacingOccurrences(of: " ", with: "\t")
      return RenderedMarkdownNode(
        type: .listItem,
        text: text,
        renderedResult: NSAttributedString(string: replacement, attributes: attributes.attributes)
      )
    }
    return renderers
  }()

  private static func makeTextStorage(
    formatters: [NodeType: RenderedMarkdown.FormattingFunction],
    renderers: [NodeType: RenderedMarkdown.RenderFunction]
  ) -> MiniMarkdownTextStorage {
    let textStorage = MiniMarkdownTextStorage(
      parsingRules: ParsingRules(),
      formatters: formatters,
      renderers: renderers
    )
    textStorage.defaultAttributes = NSAttributedString.Attributes(
      Stylesheet.default.typographyScheme.body2
    )
    return textStorage
  }

  private lazy var textView: UITextView = {
    let layoutManager = NSLayoutManager()
    textStorage.addLayoutManager(layoutManager)
    let textContainer = NSTextContainer()
    layoutManager.addTextContainer(textContainer)
    let textView = UITextView(frame: .zero, textContainer: textContainer)
    textView.backgroundColor = Stylesheet.default.colorScheme.surfaceColor
    textView.textContainerInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    return textView
  }()

  // MARK: - Lifecycle
  override func loadView() {
    self.view = textView
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    appBar.addSubviewsToParent()
    appBar.headerViewController.headerView.trackingScrollView = textView
    appBar.headerViewController.headerView.shiftBehavior = .enabled
    textView.delegate = self
    document.open { (success) in
      if !success {
        let messageText = "Error opening \(self.fileMetadata.displayName): " +
        "\(self.document.previousError?.localizedDescription ?? "Unknown error")"
        let message = MDCSnackbarMessage(text: messageText)
        MDCSnackbarManager.show(message)
      }
    }
  }

  override func viewDidDisappear(_ animated: Bool) {
    document.close { (_) in
      self.document = nil
    }
  }

  // MARK: - Keyboard

  @objc func handleKeyboardNotification(_ notification: Notification) {
    guard let keyboardInfo = KeyboardInfo(notification) else { return }
    textView.contentInset.bottom = keyboardInfo.frameEnd.height
    textView.scrollIndicatorInsets.bottom = textView.contentInset.bottom
    textView.scrollRangeToVisible(textView.selectedRange)
  }

  // MARK: - Scrolling

  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    appBar.headerViewController.headerView.trackingScrollDidScroll()
  }

  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    appBar.headerViewController.headerView.trackingScrollDidEndDecelerating()
  }

  func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    appBar.headerViewController.headerView.trackingScrollDidEndDraggingWillDecelerate(decelerate)
  }

  func scrollViewWillEndDragging(
    _ scrollView: UIScrollView,
    withVelocity velocity: CGPoint,
    targetContentOffset: UnsafeMutablePointer<CGPoint>
  ) {
    appBar.headerViewController.headerView.trackingScrollWillEndDragging(
      withVelocity: velocity,
      targetContentOffset: targetContentOffset
    )
  }

  func textViewDidChange(_ textView: UITextView) {
    document.didUpdateText()
  }
}

extension TextEditViewController: EditableDocumentDelegate {
  func editableDocumentDidLoadText(_ text: String) {
    textStorage.markdown = text
  }

  func editableDocumentCurrentText() -> String {
    return textStorage.markdown
  }
}
