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
      return MarkdownFixupTextBundle(fileURL: fileURL)
    } else {
      return nil
    }
  }
}

/// Allows editing of a single text file.
final class TextEditViewController: UIViewController, UITextViewDelegate {

  // Init-time state.

  let fileMetadata: FileMetadata

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

  private lazy var textStorage: MiniMarkdownTextStorage = {
    let textStorage = MiniMarkdownTextStorage(
      parsingRules: ParsingRules(),
      formatters: TextEditViewController.formatters,
      renderers: TextEditViewController.renderers
    )
    textStorage.defaultAttributes = NSAttributedString.Attributes(
      Stylesheet.default.typographyScheme.body2
    )
    return textStorage
  }()

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

  /// Designated initializer.
  init(fileMetadata: FileMetadata) {
    self.fileMetadata = fileMetadata
    super.init(nibName: nil, bundle: nil)
    self.navigationItem.title = fileMetadata.displayName
    self.addChild(appBar.headerViewController)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // Load-time state.

  fileprivate var document: TextEditViewControllerDocument? {
    didSet {
      self.textView.attributedText = document?.text
    }
  }

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
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    guard let document = fileMetadata.makeDocument() else {
      let message = MDCSnackbarMessage(text: "Could not open \(fileMetadata.displayName)")
      MDCSnackbarManager.show(message)
      return
    }
    document.open { (success) in
      if success {
        self.document = document
      } else {
        let messageText = "Error opening \(self.fileMetadata.displayName): " +
          "\(document.previousError?.localizedDescription ?? "Unknown error")"
        let message = MDCSnackbarMessage(text: messageText)
        MDCSnackbarManager.show(message)
      }
    }
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(handleKeyboardNotification(_:)),
                                           name: UIResponder.keyboardWillHideNotification,
                                           object: nil)
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(handleKeyboardNotification(_:)),
                                           name: UIResponder.keyboardWillChangeFrameNotification,
                                           object: nil)
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    document?.close(completionHandler: { (_) in
      self.document = nil
    })
    NotificationCenter.default.removeObserver(self)
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
}
