// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

import CommonplaceBook
import MaterialComponents
import MiniMarkdown

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

/// Allows editing of a single text file.
final class TextEditViewController: UIViewController, UITextViewDelegate {
  
  // Init-time state.
  
  let commonplaceBook: CommonplaceBook
  let documentURL: URL
  
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
    textStorage.stylesheet.heading = { (block, attributes) in
      attributes.fontSize = 20
    }
    textStorage.stylesheet.emphasis = { (_, attributes) in
      attributes.italic = true
    }
    textStorage.stylesheet.bold = { (_, attributes) in
      attributes.bold = true
    }
    return textStorage
  }()
  
  private lazy var textView: UITextView = {
    let layoutManager = NSLayoutManager()
    textStorage.addLayoutManager(layoutManager)
    let textContainer = NSTextContainer()
    layoutManager.addTextContainer(textContainer)
    let textView = UITextView(frame: .zero, textContainer: textContainer)
    textView.backgroundColor = Stylesheet.default.colorScheme.surfaceColor
    return textView
  }()
  
  /// Designated initializer.
  init(commonplaceBook: CommonplaceBook, documentURL: URL) {
    self.commonplaceBook = commonplaceBook
    self.documentURL = documentURL
    super.init(nibName: nil, bundle: nil)
    self.navigationItem.title = "Commonplace Book"
    self.addChild(appBar.headerViewController)
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // Load-time state.
  
  var changeDelegate: TextStorageChangeCreatingDelegate!
  var document: PlainTextDocument? {
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
    commonplaceBook.openDocument(
      at: documentURL.lastPathComponent,
      using: PlainTextDocument.Factory.default
    ) { (result) in
      switch result {
      case .success(let document):
        self.document = document
      case .failure(let error):
        let messageText = "Error opening \(self.documentURL): \(error.localizedDescription)"
        let message = MDCSnackbarMessage(text: messageText)
        MDCSnackbarManager.show(message)
        print(messageText)
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
    textView.scrollIndicatorInsets = textView.contentInset
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
