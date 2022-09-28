// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Logging
import MobileCoreServices
import ObjectiveCTextStorageWrapper
import SnapKit
import TextMarkupKit
import UIKit

public protocol TextEditViewControllerDelegate: AnyObject {
  func textEditViewControllerDidChangeContents(_ viewController: TextEditViewController)
  func textEditViewControllerDidClose(_ viewController: TextEditViewController)
  func testEditViewController(_ viewController: TextEditViewController, hashtagSuggestionsFor hashtag: String) -> [String]
  func textEditViewController(_ viewController: TextEditViewController, didAttach book: AugmentedBook)
}

@objc protocol TextEditingFormattingActions {
  /// Turns the current paragraph into a summary (`tl;dr:`) paragraph if it isn't, or a normal paragraph if it is.
  func toggleSummaryParagraph()

  /// Turns the current paragraph into a first-level heading (`# `) if it isn't, or a normal paragraph if it is.
  func toggleHeading()

  /// Turns the current paragraph into a second-level heading (`## `) if it isn't, or a normal paragraph if it is.
  func toggleSubheading()

  /// Turns the current paragraph into a quote (`> `) if it isn't one, or a normal paragraph if it is.
  func toggleQuote()
}

/// Allows editing of a single text file.
public final class TextEditViewController: UIViewController {
  /// Designated initializer.
  public init(imageStorage: NoteScopedImageStorage) {
    self.imageStorage = imageStorage
    super.init(nibName: nil, bundle: nil)
    textView.textStorage.delegate = self
    textView.imageStorage = imageStorage
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

  @available(*, unavailable)
  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let imageStorage: NoteScopedImageStorage

  // Init-time state.

  public lazy var parsedAttributedString: ParsedAttributedString = {
    let style = GrailDiaryGrammar.defaultEditingStyle().renderingImages(from: imageStorage)
    let storage = ParsedAttributedString(string: "", style: style)
    return storage
  }()

  public weak var delegate: TextEditViewControllerDelegate?

  /// The markdown
  public var markdown: String {
    get {
      return parsedAttributedString.rawString as String
    }
    set {
      textView.textStorage.replaceCharacters(in: NSRange(location: 0, length: textView.textStorage.length), with: newValue)
    }
  }

  public private(set) lazy var textView: MarkupFormattingTextView = {
    let view = MarkupFormattingTextView(parsedAttributedString: parsedAttributedString, layoutManager: LayoutManager())
    view.backgroundColor = .grailBackground
    view.accessibilityIdentifier = "edit-document-view"
    view.isFindInteractionEnabled = true
    view.textContainerInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    view.keyboardDismissMode = .onDragWithAccessory
    return view
  }()

  public var selectedRange: NSRange {
    get {
      return textView.selectedRange
    }
    set {
      textView.selectedRange = newValue
    }
  }

  public var selectedRawTextRange: NSRange {
    get {
      let selectedRange = textView.selectedRange
      return parsedAttributedString.rawStringRange(forRange: selectedRange)
    }
    set {
      let visibleRange = parsedAttributedString.range(forRawStringRange: newValue)
      textView.selectedRange = visibleRange
    }
  }

  /// An optional view that will appear at the top of the textView and look like an extension of the navigation bar when scrolled to the top.
  var extendedNavigationHeaderView: UIView? {
    willSet {
      extendedNavigationHeaderView?.removeFromSuperview()
    }
    didSet {
      guard let extendedNavigationHeaderView = extendedNavigationHeaderView else {
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
    guard let navigationBorderView = navigationBorderView else {
      return
    }
    let yPosition = max(0, textView.contentOffset.y + textView.adjustedContentInset.top - textView.contentInset.top)
    navigationBorderView.frame = CGRect(
      origin: CGPoint(x: 0, y: yPosition),
      size: CGSize(width: textView.frame.width, height: 1 / UIScreen.main.scale)
    )
  }

  // TODO: This class should probably own the creation of this view, not just its alpha.
  /// The navigationItem.titleView used for this view in a navigation stack. Exposed here so we can adjust its alpha on scroll.
  var navigationTitleView: UIView?

  /// All of the related data for our typeahead accessory.
  private struct TypeaheadAccessory {
    /// The text location that the accessory is anchored at. This the first character of a hashtag.
    let anchor: Int

    /// The view that displays the shadow. This is the view added to the UITextView.
    let shadowView: UIView

    /// The actual collection view.
    let collectionView: UICollectionView

    /// Data source for `collectionView`
    let dataSource: UICollectionViewDiffableDataSource<String, String>
  }

  /// The current typeahead accessory view, if present.
  private var typeaheadAccessory: TypeaheadAccessory? {
    willSet {
      typeaheadAccessory?.shadowView.removeFromSuperview()
    }
    didSet {
      (typeaheadAccessory?.shadowView).flatMap(textView.addSubview)
    }
  }

  /// Creates a typeahead accessory for text starting at location `anchor`. If the accessory already exists, returns it.
  private func makeTypeaheadAccessoryIfNecessary(anchoredAt anchor: Int) -> TypeaheadAccessory {
    if let typeaheadAccessory = typeaheadAccessory, typeaheadAccessory.anchor == anchor {
      return typeaheadAccessory
    }
    let gridUnit: CGFloat = 8
    let anchorPosition = textView.position(from: textView.beginningOfDocument, offset: anchor)!
    let caretPosition = textView.caretRect(for: anchorPosition)
    let listConfiguration = UICollectionLayoutListConfiguration(appearance: .plain)
    let layout = UICollectionViewCompositionalLayout.list(using: listConfiguration)
    let frame = CGRect(x: caretPosition.minX, y: caretPosition.maxY + gridUnit, width: 200, height: 200)
    let shadowView = UIView(frame: frame)
    shadowView.layer.shadowRadius = gridUnit
    shadowView.layer.shadowColor = UIColor.secondaryLabel.cgColor
    shadowView.layer.shadowOpacity = 0.25
    shadowView.layer.shadowPath = CGPath(
      roundedRect: shadowView.bounds,
      cornerWidth: gridUnit,
      cornerHeight: gridUnit,
      transform: nil
    )
    shadowView.clipsToBounds = false
    var innerFrame = frame
    innerFrame.origin = .zero
    let typeaheadSelectionView = UICollectionView(frame: innerFrame, collectionViewLayout: layout)
    typeaheadSelectionView.backgroundColor = .systemBackground
    typeaheadSelectionView.layer.borderWidth = 1
    typeaheadSelectionView.layer.borderColor = UIColor.systemGray.cgColor
    typeaheadSelectionView.layer.cornerRadius = gridUnit
    typeaheadSelectionView.delegate = self
    shadowView.addSubview(typeaheadSelectionView)

    let hashtagCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, String> { cell, _, hashtag in
      var contentConfiguration = cell.defaultContentConfiguration()
      contentConfiguration.text = hashtag
      contentConfiguration.textProperties.color = .label
      cell.contentConfiguration = contentConfiguration
    }

    let typeaheadDataSource = UICollectionViewDiffableDataSource<String, String>(collectionView: typeaheadSelectionView) { collectionView, indexPath, hashtag -> UICollectionViewCell? in
      collectionView.dequeueConfiguredReusableCell(using: hashtagCellRegistration, for: indexPath, item: hashtag)
    }
    let typeaheadInfo = TypeaheadAccessory(
      anchor: anchor,
      shadowView: shadowView,
      collectionView: typeaheadSelectionView,
      dataSource: typeaheadDataSource
    )
    typeaheadAccessory = typeaheadInfo
    return typeaheadInfo
  }

  // MARK: - Lifecycle

  override public func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(textView)
    textView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    textView.delegate = self

    var inputBarItems = [UIBarButtonItem]()

    let insertHashtagAction = UIAction { [textView] _ in
      let nextLocation = textView.selectedRange.location + 1
      textView.textStorage.replaceCharacters(in: textView.selectedRange, with: "#")
      textView.selectedRange = NSRange(location: nextLocation, length: 0)
    }
    inputBarItems.append(UIBarButtonItem(title: "#", primaryAction: insertHashtagAction))

    inputBarItems.append(toggleBoldfaceBarButtonItem)

    inputBarItems.append(toggleItalicsBarButtonItem)

    inputBarItems.append(UIBarButtonItem(image: UIImage(systemName: "text.quote"), primaryAction: UIAction { [weak self] _ in
      self?.toggleQuote()
    }))

    inputBarItems.append(UIBarButtonItem(title: "tl;dr:", image: nil, primaryAction: UIAction { [weak self] _ in
      self?.toggleSummaryParagraph()
    }))

    inputBarItems.append(UIBarButtonItem(image: UIImage(systemName: "list.bullet"), primaryAction: UIAction { [weak self, textView, parsedAttributedString] _ in
      guard let self = self else { return }
      guard let nodePath = try? parsedAttributedString.path(to: max(0, textView.selectedRange.location - 1)) else {
        assertionFailure()
        return
      }
      let existingSelectedLocation = textView.selectedRange.location
      if let existingListItem = nodePath.first(where: { $0.node.type == .listItem }) {
        textView.textStorage.replaceCharacters(in: NSRange(location: existingListItem.range.location, length: 2), with: "")
        textView.selectedRange = NSRange(location: existingSelectedLocation - 2, length: textView.selectedRange.length)
      } else {
        let lineRange = self.lineRange(at: existingSelectedLocation)
        textView.textStorage.replaceCharacters(in: NSRange(location: lineRange.location, length: 0), with: "* ")
        textView.selectedRange = NSRange(location: existingSelectedLocation + 2, length: 0)
      }
    }))

    if textView.canPerformAction(#selector(UIResponder.captureTextFromCamera), withSender: nil) {
      inputBarItems.append(UIBarButtonItem(image: UIImage(systemName: "camera"), primaryAction: UIAction.captureTextFromCamera(responder: textView, identifier: nil)))
    }

    let importActions = WebImporterConfiguration.shared.map { config in
      UIAction(title: config.title, image: config.image, handler: { [weak self] _ in
        guard let self = self else { return }
        let webViewController = WebScrapingViewController(initialURL: config.initialURL, javascript: config.importJavascript)
        webViewController.delegate = self
        let navigationController = UINavigationController(rootViewController: webViewController)
        navigationController.navigationBar.tintColor = .grailTint
        self.present(navigationController, animated: true, completion: nil)
      })
    }

    if !importActions.isEmpty, UserDefaults.standard.enableExperimentalFeatures {
      inputBarItems.append(UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"), menu: UIMenu(children: importActions)))
    }

    var barItemsWithSpaces = [UIBarButtonItem]()
    for barItem in inputBarItems {
      if !barItemsWithSpaces.isEmpty {
        barItemsWithSpaces.append(.flexibleSpace())
      }
      barItemsWithSpaces.append(barItem)
    }

    let inputBar = UIToolbar(frame: .zero)
    inputBar.items = barItemsWithSpaces
    inputBar.sizeToFit()
    inputBar.tintColor = .grailTint
    textView.inputAccessoryView = inputBar
  }

  /// If true, the text view will become first responder upon becoming visible.
  public var autoFirstResponder = false

  override public func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if autoFirstResponder {
      textView.becomeFirstResponder()
      // We only do this behavior on first appearance.
      autoFirstResponder = false
    }
    adjustMargins()
    navigationController?.navigationBar.standardAppearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterial)
    if extendedNavigationHeaderView != nil {
      navigationController?.navigationBar.standardAppearance.shadowColor = nil
    }
  }

  override public func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    delegate?.textEditViewControllerDidClose(self)
    layoutNavigationBorderView()
  }

  override public func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    if let bookHeader = extendedNavigationHeaderView as? BookHeader {
      bookHeader.minimumTextX = view.readableContentGuide.layoutFrame.minX + 28
    }
    if let extendedNavigationHeaderView = extendedNavigationHeaderView {
      let height = extendedNavigationHeaderView.sizeThatFits(CGSize(width: view.frame.width, height: UIView.layoutFittingExpandedSize.height)).height
      extendedNavigationHeaderView.frame = CGRect(origin: CGPoint(x: 0, y: -height), size: CGSize(width: view.frame.width, height: height))
    }
    adjustMargins()
  }

  var didPerformInitialLayout = false

  override public func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if !didPerformInitialLayout {
      didPerformInitialLayout = true
      textView.contentOffset.y = -textView.adjustedContentInset.top
    }
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

  // MARK: - Commands

  override public var isEditing: Bool {
    get {
      textView.isFirstResponder
    }
    set {
      if newValue {
        _ = textView.becomeFirstResponder()
      } else {
        textView.resignFirstResponder()
      }
    }
  }

  func editEndOfDocument() {
    let endRange = NSRange(location: textView.textStorage.count, length: 0)
    textView.selectedRange = endRange
    textView.scrollRangeToVisible(endRange)
    textView.becomeFirstResponder()
  }

  var toggleBoldfaceBarButtonItem: UIBarButtonItem {
    UIBarButtonItem(primaryAction: UIAction(title: "Bold", image: UIImage(systemName: "bold")) { [weak self] _ in
      self?.toggleBoldface(nil)
    })
  }

  /// Toggles "bold" at the current location in `textView`
  /// - Parameter sender: Unused
  public override func toggleBoldface(_ sender: Any?) {
    toggleInlineDelimitedText(nodeType: .strongEmphasis, openingDelimiter: "**", closingDelimiter: "**")
  }

  var toggleItalicsBarButtonItem: UIBarButtonItem {
    UIBarButtonItem(primaryAction: UIAction(title: "Italic", image: UIImage(systemName: "italic")) { [weak self] _ in
      self?.toggleItalics(nil)
    })
  }

  public override func toggleItalics(_ sender: Any?) {
    toggleInlineDelimitedText(nodeType: .emphasis, openingDelimiter: "_", closingDelimiter: "_")
  }

  private func toggleInlineDelimitedText(nodeType: SyntaxTreeNodeType, openingDelimiter: String, closingDelimiter: String) {
    guard let nodePath = try? parsedAttributedString.path(to: textView.selectedRange.location) else {
      assertionFailure()
      return
    }
    if let node = nodePath.first(where: { $0.node.type == nodeType }) {
      // Case 1: The current location is currently contained in a "bold" region. Remove the delimiters.
      let delimiters = node.findNodes(where: { $0.type == .delimiter }).sorted(by: { $0.range.location < $1.range.location })
      var locationDelta = 0
      var initialLocation = textView.selectedRange.location
      for delimiter in delimiters.reversed() {
        let delimiterVisibleRange = parsedAttributedString.range(forRawStringRange: delimiter.range)
        if delimiterVisibleRange.location < initialLocation {
          locationDelta -= delimiter.range.length
        }
        textView.textStorage.replaceCharacters(in: delimiterVisibleRange, with: "")
      }
      textView.selectedRange = NSRange(location: initialLocation - locationDelta, length: 0)
    } else if textView.selectedRange.length > 0 {
      // Case 2: The current selected text isn't of the desired type and has non-zero length. Put delimiters around the selected text.
      let currentSelectedRange = textView.selectedRange
      let nextLocation = currentSelectedRange.upperBound + openingDelimiter.utf16.count
      textView.textStorage.replaceCharacters(in: NSRange(location: currentSelectedRange.upperBound, length: 0), with: closingDelimiter)
      textView.textStorage.replaceCharacters(in: NSRange(location: currentSelectedRange.location, length: 0), with: openingDelimiter)
      textView.selectedRange = NSRange(location: nextLocation, length: 0)
    } else if let wordRange = try? textView.textStorage.rangeOfWord(at: textView.selectedRange.location) {
      // Case 3: The current text isn't bold but has zero length. Put delimiters around the current word.
      textView.textStorage.replaceCharacters(in: NSRange(location: wordRange.upperBound, length: 0), with: closingDelimiter)
      textView.textStorage.replaceCharacters(in: NSRange(location: wordRange.lowerBound, length: 0), with: openingDelimiter)
      textView.selectedRange = NSRange(location: wordRange.upperBound + openingDelimiter.utf16.count + closingDelimiter.utf16.count, length: 0)
    }
  }

  // MARK: - Keyboard

  @objc func handleKeyboardNotification(_ notification: Notification) {
    guard let keyboardInfo = KeyboardInfo(notification) else { return }
    textView.contentInset.bottom = keyboardInfo.frameEnd.height
    textView.verticalScrollIndicatorInsets.bottom = textView.contentInset.bottom
    textView.scrollRangeToVisible(textView.selectedRange)
  }

  /// Look for arrow keys when the typeahead controller is on screen.
  override public func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    guard let typeaheadInfo = typeaheadAccessory else {
      super.pressesBegan(presses, with: event)
      return
    }
    let typeaheadSelectionView = typeaheadInfo.collectionView
    let dataSource = typeaheadInfo.dataSource
    var didHandleEvent = false
    for press in presses {
      guard let key = press.key else { continue }
      if key.charactersIgnoringModifiers == UIKeyCommand.inputDownArrow {
        if var selectedItem = typeaheadSelectionView.indexPathsForSelectedItems?.first {
          selectedItem.item = min(dataSource.snapshot().numberOfItems - 1, selectedItem.item + 1)
          typeaheadSelectionView.selectItem(at: selectedItem, animated: true, scrollPosition: .top)
        } else {
          typeaheadSelectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: true, scrollPosition: .top)
        }
        didHandleEvent = true
      }
      if key.charactersIgnoringModifiers == UIKeyCommand.inputUpArrow {
        if var selectedItem = typeaheadSelectionView.indexPathsForSelectedItems?.first {
          selectedItem.item = max(0, selectedItem.item - 1)
          typeaheadSelectionView.selectItem(at: selectedItem, animated: true, scrollPosition: .top)
        } else {
          typeaheadSelectionView.selectItem(at: IndexPath(item: dataSource.snapshot().numberOfItems - 1, section: 0), animated: true, scrollPosition: .top)
        }
        didHandleEvent = true
      }
      if key.charactersIgnoringModifiers == "\r",
         let selectedItem = typeaheadSelectionView.indexPathsForSelectedItems?.first
      {
        collectionView(typeaheadSelectionView, didSelectItemAt: selectedItem)
        didHandleEvent = true
      }
      if key.charactersIgnoringModifiers == UIKeyCommand.inputEscape {
        typeaheadAccessory = nil
        didHandleEvent = true
      }
    }
    if !didHandleEvent {
      super.pressesBegan(presses, with: event)
    }
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

// MARK: - UICollectionViewDelegate

extension TextEditViewController: UICollectionViewDelegate {
  /// Handles selection for the typeahead accessory -- replaces the hashtag at the cursor with the selected hashtag.
  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    guard
      let nodePath = try? parsedAttributedString.path(to: textView.selectedRange.location - 1),
      let selectedHashtag = typeaheadAccessory?.dataSource.itemIdentifier(for: indexPath),
      let hashtagNode = nodePath.first(where: { $0.node.type == .hashtag })
    else {
      return
    }
    let hashtagVisibleRange = parsedAttributedString.range(forRawStringRange: hashtagNode.range)
    textView.textStorage.replaceCharacters(in: hashtagVisibleRange, with: selectedHashtag)
    textView.selectedRange = NSRange(location: hashtagVisibleRange.location + selectedHashtag.utf16.count, length: 0)
    typeaheadAccessory = nil
  }
}

// MARK: - UITextViewDelegate

extension TextEditViewController: UITextViewDelegate {
  func replaceCharacters(in range: NSRange, with str: String) {
    textView.textStorage.replaceCharacters(in: range, with: str)
    textView.selectedRange = NSRange(location: range.location + str.count, length: 0)
  }

  public func textViewDidChangeSelection(_ textView: UITextView) {
    if textView.selectedRange.location == 0 {
      // If we're at the beginning of the text, make sure there's no typeahead accessory.
      typeaheadAccessory = nil
      return
    }
    // the cursor moved. If there's a hashtag view controller, see if we've strayed from its hashtag.
    let nodePath = (try? parsedAttributedString.path(to: textView.selectedRange.location - 1)) ?? []
    if let hashtagNode = nodePath.first(where: { $0.node.type == .hashtag }),
       hashtagNode.range.location == typeaheadAccessory?.anchor
    {
      // The cursor has moved, but we're still in the same hashtag as currently defined in typeaheadInfo, so we leave it.
    } else {
      // In all other cases we make sure we clear the typeahead view.
      typeaheadAccessory = nil
    }
  }

  public func textViewDidChange(_ textView: UITextView) {
    guard textView.selectedRange.location > 0 else { return }
    if
      let nodePath = try? parsedAttributedString.path(to: textView.selectedRange.location - 1),
      let hashtagNode = nodePath.first(where: { $0.node.type == .hashtag })
    {
      let hashtag = String(utf16CodeUnits: parsedAttributedString[hashtagNode.range], count: hashtagNode.range.length)
      let suggestions = delegate?.testEditViewController(self, hashtagSuggestionsFor: hashtag) ?? []
      if suggestions.isEmpty { typeaheadAccessory = nil }
      let visibleRange = parsedAttributedString.range(forRawStringRange: hashtagNode.range)
      let typeaheadInfo = makeTypeaheadAccessoryIfNecessary(anchoredAt: visibleRange.location)
      var snapshot = NSDiffableDataSourceSnapshot<String, String>()
      snapshot.appendSections(["main"])
      snapshot.appendItems(suggestions)
      typeaheadInfo.dataSource.apply(snapshot, animatingDifferences: true)
      Logger.shared.info("In a hashtag: \(hashtag)")
    } else {
      typeaheadAccessory = nil
    }
  }

  public func textView(
    _ textView: UITextView,
    shouldChangeTextIn range: NSRange,
    replacementText text: String
  ) -> Bool {
    // We do syntax highlighting. Don't do typing attributes, ever.
    textView.typingAttributes = [:]

    let rawStringRange = parsedAttributedString.rawStringRange(forRange: range)
    if rawStringRange.length != range.length {
      let selectionRange = parsedAttributedString.range(forRawStringRange: rawStringRange)
      Logger.shared.info("Changing selection range from \(range) to \(selectionRange) because of text replacement")
      textView.selectedRange = selectionRange
    }

    // Right now we only do special processing when inserting a newline
    guard range.length == 0, text == "\n" else { return true }
    guard let nodePath = try? parsedAttributedString.path(to: range.location - 1) else {
      // If range.location == 0, we expect to get an invalid argument exception and we should just return.
      return true
    }
    if let listItem = nodePath.first(where: { $0.node.type == .listItem }) {
      if let listDelimiter = nodePath.first(where: { $0.node.type == .listDelimiter }) {
        // We are hitting "return" right after a list delimiter. Replace that delimiter with a return instead.
        let delimiterRange = parsedAttributedString.range(forRawStringRange: listDelimiter.range)
        replaceCharacters(in: delimiterRange, with: "\n")
        return false
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
          let chars = parsedAttributedString[listNumberNode.range]
          let string = String(utf16CodeUnits: chars, count: chars.count)
          listNumber = Int(string) ?? 0
        } else {
          listNumber = 0
        }
        replaceCharacters(in: range, with: "\n\(listNumber + 1). ")
      }
      return false
    } else if line(at: range.location).hasPrefix("Q: ") {
      if line(at: range.location).count <= 4 {
        replaceCharacters(in: lineRange(at: range.location), with: "")
      } else {
        replaceCharacters(in: range, with: "\nA: ")
      }
    } else if line(at: range.location).hasPrefix("A:\t") {
      replaceCharacters(in: range, with: "\n\nQ: ")
    } else {
      // To make this be a separate paragraph in any conventional Markdown processor, we need
      // the blank line.
      replaceCharacters(in: range, with: "\n\n")
    }
    return false
  }

  public func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
    guard range.length > 0 else {
      return nil
    }
    let highlight = UICommand(title: "Highlight", action: #selector(convertTextToCloze))
    return UIMenu(children: suggestedActions + [highlight])
  }

  /// Gets the line of text that contains a given location.
  private func line(at location: Int) -> String {
    let nsstring = textView.textStorage.string as NSString
    let lineRange = nsstring.lineRange(for: NSRange(location: location, length: 0))
    return nsstring.substring(with: lineRange)
  }

  private func lineRange(at location: Int) -> NSRange {
    (textView.textStorage.string as NSString).lineRange(for: NSRange(location: location, length: 0))
  }

  public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let systemContentInset = scrollView.adjustedContentInset.top - scrollView.contentInset.top
    let visibleOffsetY = scrollView.contentOffset.y + systemContentInset
    if let headerHeight = extendedNavigationHeaderView?.frame.height, visibleOffsetY < 0 {
      let alpha = 1 - (-visibleOffsetY / headerHeight)
      navigationTitleView?.alpha = alpha
    } else {
      navigationTitleView?.alpha = 1
    }
    layoutNavigationBorderView()
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

// MARK: - WebScrapingViewControllerDelegate

extension TextEditViewController: WebScrapingViewControllerDelegate {
  public func webScrapingViewController(_ viewController: WebScrapingViewController, didScrapeMarkdown markdown: String) {
    textView.textStorage.replaceCharacters(in: selectedRange, with: markdown)
    dismiss(animated: true, completion: nil)
  }

  public func webScrapingViewControllerDidCancel(_ viewController: WebScrapingViewController) {
    dismiss(animated: true, completion: nil)
  }
}

// MARK: - TextEditingFormattingActions

extension TextEditViewController: TextEditingFormattingActions {
  func toggleHeading() {
    toggleParagraph(type: .header, openingDelimiter: "# ")
  }

  func toggleSubheading() {
    toggleParagraph(type: .header, openingDelimiter: "## ")
  }

  func toggleQuote() {
    toggleParagraph(type: .blockquote, openingDelimiter: "> ")
  }

  /// Turns the current paragraph into a summary (`tl;dr:`) paragraph if it isn't, or a normal paragraph if it is.
  func toggleSummaryParagraph() {
    toggleParagraph(type: .summary, openingDelimiter: "tl;dr: ")
  }

  private func toggleParagraph(type: SyntaxTreeNodeType, openingDelimiter: String) {
    guard let (blockType, openingRange) = try? block(containing: textView.selectedRange.location) else {
      assertionFailure()
      return
    }
    let visibleRange = parsedAttributedString.range(forRawStringRange: openingRange)
    if blockType == type {
      textView.textStorage.replaceCharacters(in: visibleRange, with: "")
      textView.selectedRange = NSRange(location: textView.selectedRange.location - visibleRange.length, length: 0)
    } else {
      var replacementString = openingDelimiter
      if blockType == .blankLine {
        replacementString.insert("\n", at: replacementString.startIndex)
      }
      textView.textStorage.replaceCharacters(in: visibleRange, with: replacementString)
      textView.selectedRange = NSRange(location: textView.selectedRange.location - visibleRange.length + replacementString.count, length: 0)
    }
  }

  /// Returns the type of MiniMarkdown block containing `location`
  /// - Parameter location: The location to be contained.
  /// - Returns: A tuple containing the type of block that contains `location` and the opening delimiter for the block.
  private func block(containing location: Int) throws -> (type: SyntaxTreeNodeType, openingDelimiterRange: NSRange)? {
    guard parsedAttributedString.count > 0 else {
      // There's no parsed path if the buffer is empty.
      return (type: .paragraph, openingDelimiterRange: NSRange(location: 0, length: 0))
    }
    guard let nodePath = try? parsedAttributedString.path(to: textView.selectedRange.location) else {
      throw GenericLocalizedError(errorDescription: "Location \(location) is not in the parse tree for parsedAttributedString")
    }
    if
      let heading = nodePath.first(where: { $0.node.type == .header }),
      let delimiter = heading.first(where: { $0.type == .delimiter }),
      let softTab = heading.first(where: { $0.type == .softTab })
    {
      return (type: .header, openingDelimiterRange: delimiter.range.union(softTab.range))
    }
    let blocks: [(SyntaxTreeNodeType, SyntaxTreeNodeType)] = [
      (.summary, .summaryDelimiter),
      (.listItem, .listDelimiter),
      (.blockquote, .delimiter),
    ]
    for (blockType, delimiterType) in blocks {
      if let info = nodePath.searchForBlockType(blockType, delimiter: delimiterType) {
        return info
      }
    }
    for blockType in [SyntaxTreeNodeType.blankLine, SyntaxTreeNodeType.paragraph] {
      if let blockNode = nodePath.first(where: { $0.node.type == blockType }) {
        return (type: blockType, openingDelimiterRange: NSRange(location: blockNode.range.location, length: 0))
      }
    }
    return nil
  }
}

private extension Array<AnchoredNode> {
  func searchForBlockType(
    _ type: SyntaxTreeNodeType,
    delimiter: SyntaxTreeNodeType
  ) -> (type: SyntaxTreeNodeType, openingDelimiterRange: NSRange)? {
    if let blockNode = first(where: { $0.node.type == type }), let delimiterNode = blockNode.first(where: { $0.type == delimiter }) {
      return (type: type, openingDelimiterRange: delimiterNode.range)
    } else {
      return nil
    }
  }
}
