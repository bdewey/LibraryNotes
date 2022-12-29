// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Foundation
import SnapKit
import TextMarkupKit
import UIKit
import UniformTypeIdentifiers

/// Provides rich text editing of a single file.
public final class RichTextEditViewController: UIViewController, TextEditViewController {
  /// Designated initializer.
  public init(imageStorage: NoteScopedImageStorage) {
    self.imageStorage = imageStorage
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private lazy var textView: UITextView = {
    // TODO: Convert to TextKit2
    let layoutManager = LayoutManager()
    let textContainer = NSTextContainer()
    layoutManager.addTextContainer(textContainer)
    let storage = NSTextStorage()
    storage.addLayoutManager(layoutManager)
    let view = UITextView(frame: .zero, textContainer: textContainer)
    view.backgroundColor = .grailBackground
    view.accessibilityIdentifier = "edit-document-view"
    view.isFindInteractionEnabled = true
    view.textContainerInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    view.keyboardDismissMode = .onDragWithAccessory
    view.allowsEditingTextAttributes = true
    view.usesStandardTextScaling = true
    return view
  }()

  // MARK: - View lifecycle

  override public func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(textView)
    textView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
  }

  override public func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    if let bookHeader = extendedNavigationHeaderView as? BookHeader {
      bookHeader.minimumTextX = view.readableContentGuide.layoutFrame.minX + 28
    }
    if let extendedNavigationHeaderView {
      let height = extendedNavigationHeaderView.sizeThatFits(CGSize(width: view.frame.width, height: UIView.layoutFittingExpandedSize.height)).height
      extendedNavigationHeaderView.frame = CGRect(origin: CGPoint(x: 0, y: -height), size: CGSize(width: view.frame.width, height: height))
    }
    adjustMargins()
  }

  override public func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    layoutNavigationBorderView()
  }

  override public func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    adjustMargins()
  }

  private func adjustMargins() {
    // I wish I could use autolayout to set the insets.
    let extendedNavigationHeight: CGFloat = extendedNavigationHeaderView?.frame.height ?? 0
    textView.contentInset.top = extendedNavigationHeight
    let readableContentGuide = view.readableContentGuide
    textView.textContainerInset = UIEdgeInsets(
      top: 8,
      left: readableContentGuide.layoutFrame.minX,
      bottom: 8,
      right: view.bounds.maxX - readableContentGuide.layoutFrame.maxX
    )
  }

  public var markdown: String {
    get {
      textView.text
    }
    set {
      let storage = ParsedAttributedString(string: newValue, style: .defaultRichTextEditing.renderingImages(from: imageStorage))
      textView.attributedText = storage
    }
  }

  public var navigationTitleView: UIView?

  #warning("copypasta")
  public var extendedNavigationHeaderView: UIView? {
    willSet {
      extendedNavigationHeaderView?.removeFromSuperview()
    }
    didSet {
      guard let extendedNavigationHeaderView else {
        return
      }
      textView.addSubview(extendedNavigationHeaderView)
      let navigationBorderView = UIView(frame: .zero)
      navigationBorderView.backgroundColor = .tertiaryLabel
      textView.addSubview(navigationBorderView)
      self.navigationBorderView = navigationBorderView
      view.setNeedsLayout()
    }
  }

  /// The border between `extendedNavigationHeaderView` and the text content.
  private var navigationBorderView: UIView?

  /// Position `navigationBorderView` between the header & text. Note this depends on scroll position since it will pin to the top, so call
  /// this on each scrollViewDidScroll.
  private func layoutNavigationBorderView() {
    guard let navigationBorderView else {
      return
    }
    let yPosition = max(0, textView.contentOffset.y + textView.adjustedContentInset.top - textView.contentInset.top)
    navigationBorderView.frame = CGRect(
      origin: CGPoint(x: 0, y: yPosition),
      size: CGSize(width: textView.frame.width, height: 1 / UIScreen.main.scale)
    )
  }

  public var autoFirstResponder: Bool = false

  public weak var delegate: TextEditViewControllerDelegate?

  private let imageStorage: NoteScopedImageStorage

  public func editEndOfDocument() {
    #warning("Not implemented")
    fatalError()
  }

  public var selectedRange: NSRange {
    get {
      textView.selectedRange
    }
    set {
      textView.selectedRange = newValue
    }
  }

  public var selectedRawTextRange: NSRange {
    get {
      textView.selectedRange
    }
    set {
      textView.selectedRange = newValue
    }
  }

  public func insertImageData(_ imageData: Data, type: UTType) throws {
    #warning("Not implemented")
    fatalError()
  }
}

private extension ParsedAttributedString.Style {
  static let defaultRichTextEditing: ParsedAttributedString.Style = {
    var attributes = AttributedStringAttributesDescriptor.standardAttributes()
    attributes.paragraphSpacing = 20
    var style = GrailDiaryGrammar.defaultEditingStyle(defaultAttributes: attributes).removingDelimiters()
    style.formatters[.blockquote] = AnyParsedAttributedStringFormatter {
      $0.italic = true
      $0.blockquoteBorderColor = UIColor.systemOrange
    }
    return style
  }()

  func removingDelimiters() -> ParsedAttributedString.Style {
    var copy = self
    copy.formatters[.blankLine] = .remove
    copy.formatters[.delimiter] = .remove
    copy.formatters[.clozeHint] = .remove
    return copy
  }
}
