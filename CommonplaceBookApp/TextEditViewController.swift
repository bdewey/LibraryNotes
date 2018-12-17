// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

import CocoaLumberjack
import CommonplaceBook
import CwlSignal
import FlashcardKit
import MaterialComponents
import MiniMarkdown
import TextBundleKit

private typealias TextEditViewControllerDocument = EditableDocument

extension Tag {
  fileprivate static let textEditViewController = Tag(rawValue: "textEditViewController")
}

/// Allows editing of a single text file.
final class TextEditViewController: UIViewController,
  MDCScrollEventForwarder,
  StylesheetContaining {

  /// Designated initializer.
  init(document: EditableDocument, parsingRules: ParsingRules, stylesheet: Stylesheet) {
    self.document = document
    self.parsingRules = parsingRules
    self.stylesheet = stylesheet
    var renderers = TextEditViewController.renderers
    if let configurer = document as? ConfiguresRenderers {
      configurer.configureRenderers(&renderers)
    }
    self.textStorage = TextEditViewController.makeTextStorage(
      parsingRules: parsingRules,
      formatters: TextEditViewController.formatters(with: stylesheet),
      renderers: renderers,
      stylesheet: stylesheet
    )
    super.init(nibName: nil, bundle: nil)
    self.endpoint = document.textSignal.subscribeValues { [weak self](taggedString) in
      guard taggedString.tag != Tag.textEditViewController,
            let textStorage = self?.textStorage else {
        return
      }
      textStorage.markdown = taggedString.value
    }
    textStorage.delegate = self
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
    document.close()
  }

  // Init-time state.

  private let document: TextEditViewControllerDocument
  private let parsingRules: ParsingRules
  internal let stylesheet: Stylesheet
  private let textStorage: MiniMarkdownTextStorage
  internal var miniMarkdownSignal: Signal<[Node]> { return textStorage.markdownSignal }
  private var endpoint: SignalEndpoint<Tagged<String>>?
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
    formatters[.delimiter] = { (_, attributes) in
      attributes.color = stylesheet.colors
        .onSurfaceColor
        .withAlphaComponent(stylesheet.alpha[.darkTextDisabled] ?? 0.5)
    }
    formatters[.bold] = { $1.bold = true }
    formatters[.emphasis] = { $1.italic = true }
    formatters[.table] = { $1.familyName = "Menlo" }
    formatters[.cloze] = { $1.backgroundColor = stylesheet.colors.darkSurfaceColor }
    formatters[.hashtag] = { $1.backgroundColor = stylesheet.colors.darkSurfaceColor }
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

  private static func makeTextStorage(
    parsingRules: ParsingRules,
    formatters: [NodeType: RenderedMarkdown.FormattingFunction],
    renderers: [NodeType: RenderedMarkdown.RenderFunction],
    stylesheet: Stylesheet
  ) -> MiniMarkdownTextStorage {
    let textStorage = MiniMarkdownTextStorage(
      parsingRules: parsingRules,
      formatters: formatters,
      renderers: renderers
    )
    textStorage.defaultAttributes = NSAttributedString.Attributes(
      stylesheet.typographyScheme.body2
    )
    textStorage.defaultAttributes.kern = stylesheet.kern[.body2] ?? 1.0
    textStorage.defaultAttributes.color = stylesheet.colors
      .onSurfaceColor
      .withAlphaComponent(stylesheet.alpha[.darkTextHighEmphasis] ?? 1.0)
    return textStorage
  }

  private lazy var textView: UITextView = {
    let layoutManager = NSLayoutManager()
    textStorage.addLayoutManager(layoutManager)
    let textContainer = NSTextContainer()
    layoutManager.addTextContainer(textContainer)
    let textView = UITextView(frame: .zero, textContainer: textContainer)
    textView.backgroundColor = stylesheet.colors.surfaceColor
    textView.textContainerInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
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
  override func loadView() {
    self.view = textView
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    textView.delegate = self
  }

  /// If true, the text view will become first responder upon becoming visible.
  public var autoFirstResponder = false

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    textView.contentOffset = CGPoint(x: 0, y: -1 * textView.adjustedContentInset.top)
    if autoFirstResponder {
      textView.becomeFirstResponder()
      // We only do this behavior on first appearance.
      autoFirstResponder = false
    }
  }

  // MARK: - Keyboard

  @objc func handleKeyboardNotification(_ notification: Notification) {
    guard let keyboardInfo = KeyboardInfo(notification) else { return }
    textView.contentInset.bottom = keyboardInfo.frameEnd.height
    textView.scrollIndicatorInsets.bottom = textView.contentInset.bottom
    textView.scrollRangeToVisible(textView.selectedRange)
  }
}

extension TextEditViewController: NSTextStorageDelegate {
  func textStorage(
    _ textStorage: NSTextStorage,
    didProcessEditing editedMask: NSTextStorage.EditActions,
    range editedRange: NSRange,
    changeInLength delta: Int
  ) {
    guard editedMask.contains(.editedCharacters) else { return }
    document.applyTaggedModification(tag: .textEditViewController) { (_) in
      self.textStorage.markdown
    }
  }
}

extension TextEditViewController: UITextViewDelegate {

  func replaceCharacters(in range: NSRange, with str: String) {
    textStorage.replaceCharacters(in: range, with: str)
    textView.selectedRange = NSRange(location: range.location + str.count, length: 0)
  }

  func textView(
    _ textView: UITextView,
    shouldChangeTextIn range: NSRange,
    replacementText text: String
  ) -> Bool {
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
