// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

import CommonplaceBook
import MaterialComponents
import MiniMarkdown
import textbundle_swift

fileprivate typealias TextEditViewControllerDocument = UIDocument & EditableDocument

fileprivate struct KeyboardInfo {
  var animationCurve: UIView.AnimationCurve
  var animationDuration: Double
  var isLocal: Bool
  var frameBegin: CGRect
  var frameEnd: CGRect
}

extension KeyboardInfo {
  init?(_ notification: Notification) {
    guard notification.name == UIResponder.keyboardWillShowNotification || notification.name == UIResponder.keyboardWillChangeFrameNotification else { return nil }
    let u = notification.userInfo!
    
    animationCurve = UIView.AnimationCurve(rawValue: u[UIWindow.keyboardAnimationCurveUserInfoKey] as! Int)!
    animationDuration = u[UIWindow.keyboardAnimationDurationUserInfoKey] as! Double
    isLocal = u[UIWindow.keyboardIsLocalUserInfoKey] as! Bool
    frameBegin = u[UIWindow.keyboardFrameBeginUserInfoKey] as! CGRect
    frameEnd = u[UIWindow.keyboardFrameEndUserInfoKey] as! CGRect
  }
}

extension FileMetadata {
  fileprivate func makeDocument() -> TextEditViewControllerDocument? {
    if contentTypeTree.contains("public.plain-text") {
      return PlainTextDocument(fileURL: fileURL)
    } else if contentTypeTree.contains("org.textbundle.package") {
      return TextBundleDocument(fileURL: fileURL)
    } else {
      return nil
    }
  }
}

/// Allows editing of a single text file.
final class TextEditViewController: UIViewController, UITextViewDelegate {
  
  // Init-time state.
  
  let commonplaceBook: CommonplaceBook
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
    textStorage.stylesheet.nodeAttributes[.heading] = { (_, attributes) in
      attributes.fontSize = 20
      attributes.familyName = "LibreFranklin-Medium"
    }
    textStorage.stylesheet.nodeAttributes[.emphasis] = { (_, attributes) in
      attributes.italic = true
    }
    textStorage.stylesheet.nodeAttributes[.bold] = { (_, attributes) in
      attributes.bold = true
    }
    textStorage.stylesheet.nodeAttributes[.list] = { $1.list = true }
    
    // TODO: The equivalent of this code should be done in building / normalizing the string
    
//    textStorage.stylesheet.customizations.listItem = { (string, block, attributes) in
//      if let firstWhitespaceIndex = block.slice.substring.firstIndex(where: { $0.isWhitespace }) {
//        var attributes = attributes
//        attributes[.treatAsTab] = true
//        string.addAttributes(
//          attributes,
//          range: NSRange(
//            firstWhitespaceIndex...firstWhitespaceIndex,
//            in: block.slice.string
//          )
//        )
//      }
//    }
    return textStorage
  }()
  
  private let layoutManagerDelegate = TreatAsTabLayoutManagerDelegate()
  
  private lazy var textView: UITextView = {
    let layoutManager = NSLayoutManager()
    layoutManager.delegate = layoutManagerDelegate
    textStorage.addLayoutManager(layoutManager)
    let textContainer = NSTextContainer()
    layoutManager.addTextContainer(textContainer)
    let textView = UITextView(frame: .zero, textContainer: textContainer)
    textView.backgroundColor = Stylesheet.default.colorScheme.surfaceColor
    textView.textContainerInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    return textView
  }()
  
  /// Designated initializer.
  init(commonplaceBook: CommonplaceBook, fileMetadata: FileMetadata) {
    self.commonplaceBook = commonplaceBook
    self.fileMetadata = fileMetadata
    super.init(nibName: nil, bundle: nil)
    self.navigationItem.title = "Commonplace Book"
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
        self.textView.text = document?.text
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
        let messageText = "Error opening \(self.fileMetadata.displayName): \(document.previousError?.localizedDescription ?? "Unknown error")"
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
  
  func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    appBar.headerViewController.headerView.trackingScrollWillEndDragging(withVelocity: velocity, targetContentOffset: targetContentOffset)
  }
}
