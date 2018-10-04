// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

import CocoaLumberjack
import CommonplaceBook
import FlashcardKit
import MaterialComponents
import MiniMarkdown
import TextBundleKit

private typealias TextEditViewControllerDocument = EditableDocument

/// Allows editing of a single text file.
final class TextEditViewController: UIViewController,
  MDCScrollEventForwarder,
  StylesheetContaining {

  /// Designated initializer.
  init(document: EditableDocument, parsingRules: ParsingRules, stylesheet: Stylesheet) {
    self.document = document
    self.parsingRules = parsingRules
    self.stylesheet = stylesheet
    self.textStorage = document.markdownTextStorage(
      parsingRules: parsingRules,
      formatters: TextEditViewController.formatters(with: stylesheet),
      renderers: TextEditViewController.renderers,
      stylesheet: stylesheet
    )
    super.init(nibName: nil, bundle: nil)
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(handleKeyboardNotification(_:)),
                                           name: UIResponder.keyboardWillHideNotification,
                                           object: nil)
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(handleKeyboardNotification(_:)),
                                           name: UIResponder.keyboardWillChangeFrameNotification,
                                           object: nil)
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // Init-time state.

  private let document: TextEditViewControllerDocument
  private let parsingRules: ParsingRules
  internal let stylesheet: Stylesheet
  internal let textStorage: MiniMarkdownTextStorage
  public var headerView: MDCFlexibleHeaderView?
  public let desiredShiftBehavior = MDCFlexibleHeaderShiftBehavior.enabled

  private static func formatters(
    with stylesheet: Stylesheet
  ) -> [NodeType: RenderedMarkdown.FormattingFunction] {
    var formatters: [NodeType: RenderedMarkdown.FormattingFunction] = [:]
    formatters[.heading] = {
      let heading = $0 as! Heading // swiftlint:disable:this force_cast
      if heading.headingLevel == 1 {
        $1.fontSize = 20
        $1.kern = 0.25
      } else {
        $1.fontSize = 16
        $1.kern = 0.15
      }
    }
    formatters[.list] = { $1.listLevel += 1 }
    formatters[.bold] = { $1.bold = true }
    formatters[.emphasis] = { $1.italic = true }
    formatters[.table] = { $1.familyName = "Menlo" }
    formatters[.cloze] = { $1.backgroundColor = stylesheet.colorScheme.darkSurfaceColor }
    return formatters
  }

  private static let renderers: [NodeType: RenderedMarkdown.RenderFunction] = {
    var renderers: [NodeType: RenderedMarkdown.RenderFunction] = [:]
    renderers[.listItem] = { (node, attributes) in
      let listItem = node as! ListItem // swiftlint:disable:this force_cast
      let text = String(listItem.slice.string[listItem.markerRange])
      let replacement = listItem.listType == .unordered
        ? "\u{2022}\t"
        : text.replacingOccurrences(of: " ", with: "\t")
      return NSAttributedString(string: replacement, attributes: attributes.attributes)
    }
    return renderers
  }()

  private lazy var textView: UITextView = {
    let layoutManager = NSLayoutManager()
    textStorage.addLayoutManager(layoutManager)
    let textContainer = NSTextContainer()
    layoutManager.addTextContainer(textContainer)
    let textView = UITextView(frame: .zero, textContainer: textContainer)
    textView.backgroundColor = stylesheet.colorScheme.surfaceColor
    textView.textContainerInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    return textView
  }()

  // MARK: - Lifecycle
  override func loadView() {
    self.view = textView
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    textView.delegate = self
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    textView.contentOffset = CGPoint(x: 0, y: -1 * textView.adjustedContentInset.top)
  }

  // MARK: - Keyboard

  @objc func handleKeyboardNotification(_ notification: Notification) {
    guard let keyboardInfo = KeyboardInfo(notification) else { return }
    textView.contentInset.bottom = keyboardInfo.frameEnd.height
    textView.scrollIndicatorInsets.bottom = textView.contentInset.bottom
    textView.scrollRangeToVisible(textView.selectedRange)
  }
}

extension TextEditViewController: UITextViewDelegate {
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    forwardScrollViewDidScroll(scrollView)
  }

  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    forwardScrollViewDidEndDecelerating(scrollView)
  }

  func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    forwardScrollViewDidEndDragging(scrollView, willDecelerate: decelerate)
  }

  func scrollViewWillEndDragging(
    _ scrollView: UIScrollView,
    withVelocity velocity: CGPoint,
    targetContentOffset: UnsafeMutablePointer<CGPoint>
  ) {
    forwardScrollViewWillEndDragging(
      scrollView,
      withVelocity: velocity,
      targetContentOffset: targetContentOffset
    )
  }
}

extension TextEditViewController: UIScrollViewForTracking {
  var scrollViewForTracking: UIScrollView {
    return textView
  }
}
