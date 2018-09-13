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

  private lazy var textStorage: MiniMarkdownTextStorage = {
    let textStorage = MiniMarkdownTextStorage()
    textStorage.defaultAttributes = NSAttributedString.Attributes(
      Stylesheet.default.typographyScheme.body2
    )
    // TODO: Change font
    textStorage.stylesheet[.heading] = { (_, attributes) in
      attributes.fontSize = 20
      attributes.familyName = "LibreFranklin-Medium"
    }
    textStorage.stylesheet[.emphasis] = { (_, attributes) in
      attributes.italic = true
    }
    textStorage.stylesheet[.bold] = { (_, attributes) in
      attributes.bold = true
    }
    textStorage.stylesheet[.list] = { $1.list = true }
    textStorage.stylesheet[.table] = { $1.familyName = "Menlo" }
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

  var changeDelegate: TextStorageChangeCreatingDelegate!
  fileprivate var document: TextEditViewControllerDocument? {
    didSet {
      changeDelegate.suppressChangeBlock {
        self.textView.attributedText = document?.text
      }
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
    changeDelegate = TextStorageChangeCreatingDelegate(changeBlock: { [weak self](change) in
      self?.document?.applyChange(change)
    })
    textView.textStorage.delegate = changeDelegate
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
