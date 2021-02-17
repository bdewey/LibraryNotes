// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Logging
import MobileCoreServices
import UIKit

public protocol TextEditViewControllerDelegate: AnyObject {
  func textEditViewControllerDidChangeContents(_ viewController: TextEditViewController)
  func textEditViewControllerDidClose(_ viewController: TextEditViewController)
  func testEditViewController(_ viewController: TextEditViewController, hashtagSuggestionsFor hashtag: String) -> [String]
}

/// Allows editing of a single text file.
public final class TextEditViewController: UIViewController {
  /// Designated initializer.
  public init(imageStorage: ImageStorage) {
    self.imageStorage = imageStorage
    super.init(nibName: nil, bundle: nil)
    textStorage.delegate = self
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

  private let imageStorage: ImageStorage

  // Init-time state.

  public lazy var textStorage: ParsedTextStorage = {
    var defaultAttributes: AttributedStringAttributes = [
      .font: UIFont.preferredFont(forTextStyle: .body),
      .foregroundColor: UIColor.label,
    ]
    defaultAttributes.headIndent = 28
    defaultAttributes.firstLineHeadIndent = 28
    let storage = ParsedAttributedString(
      grammar: MiniMarkdownGrammar.shared,
      defaultAttributes: defaultAttributes,
      quickFormatFunctions: formatters,
      fullFormatFunctions: [
        .softTab: { _, _, _, _ in Array("\t".utf16) },
        .unorderedListOpening: { _, _, _, _ in Array("\u{2022}".utf16) },
        .image: imageStorage.imageReplacement,
      ]
    )
    return ParsedTextStorage(storage: storage)
  }()

  public weak var delegate: TextEditViewControllerDelegate?

  /// The markdown
  public var markdown: String {
    get {
      return textStorage.storage.rawString as String
    }
    set {
      textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length), with: newValue)
    }
  }

  private lazy var formatters: [SyntaxTreeNodeType: QuickFormatFunction] = {
    var formatters: [SyntaxTreeNodeType: QuickFormatFunction] = [:]
    formatters[.header] = {
      let headingLevel = $0.children[0].length
      switch headingLevel {
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
    formatters[.delimiter] = { _, attributes in
      attributes.color = .quaternaryLabel
    }
    formatters[.questionAndAnswer] = { $1.listLevel = 1 }
    formatters[.qnaDelimiter] = { $1.bold = true }
    formatters[.strongEmphasis] = { $1.bold = true }
    formatters[.emphasis] = { $1.italic.toggle() }

    formatters[.code] = { $1.familyName = "Menlo" }
    formatters[.cloze] = { $1.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.3) }
    formatters[.clozeHint] = {
      $1.color = UIColor.secondaryLabel
    }
    formatters[.hashtag] = { $1.backgroundColor = UIColor.grailSecondaryBackground }

    formatters[.summaryDelimiter] = { $1.bold = true }
    formatters[.summary] = {
      $1.blockquoteBorderColor = UIColor.systemOrange
      $1.italic = true
    }

    formatters[.blockquote] = {
      $1.italic = true
      $1.blockquoteBorderColor = UIColor.systemOrange
      $1.listLevel += 1
    }
    formatters[.emoji] = {
      $1.familyName = "Apple Color Emoji"
    }
    return formatters
  }()

  private lazy var textView: MarkdownEditingTextView = {
    let layoutManager = LayoutManager()
    textStorage.addLayoutManager(layoutManager)
    let textContainer = NSTextContainer()
    layoutManager.addTextContainer(textContainer)
    let textView = MarkdownEditingTextView(frame: .zero, textContainer: textContainer)
    textView.backgroundColor = .grailBackground
    textView.textContainerInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    textView.pasteConfiguration = UIPasteConfiguration(
      acceptableTypeIdentifiers: [
        kUTTypeJPEG as String,
        kUTTypePNG as String,
        kUTTypeImage as String,
        kUTTypePlainText as String,
      ]
    )
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

    let typeaheadDataSource = UICollectionViewDiffableDataSource<String, String>(collectionView: typeaheadSelectionView) { (collectionView, indexPath, hashtag) -> UICollectionViewCell? in
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

  override public func loadView() {
    view = textView
  }

  override public func viewDidLoad() {
    super.viewDidLoad()
    view.accessibilityIdentifier = "edit-document-view"
    textView.delegate = self

    var inputBarItems = [UIBarButtonItem]()

    let insertHashtagAction = UIAction { [textView] _ in
      let nextLocation = textView.selectedRange.location + 1
      textView.textStorage.replaceCharacters(in: textView.selectedRange, with: "#")
      textView.selectedRange = NSRange(location: nextLocation, length: 0)
    }
    inputBarItems.append(UIBarButtonItem(title: "#", primaryAction: insertHashtagAction))

    inputBarItems.append(UIBarButtonItem(image: UIImage(systemName: "bold"), primaryAction: UIAction { [textView] _ in
      let currentSelectedRange = textView.selectedRange
      let nextLocation = currentSelectedRange.upperBound + 2
      textView.textStorage.replaceCharacters(in: NSRange(location: currentSelectedRange.upperBound, length: 0), with: "**")
      textView.textStorage.replaceCharacters(in: NSRange(location: currentSelectedRange.location, length: 0), with: "**")
      textView.selectedRange = NSRange(location: nextLocation, length: 0)
    }))

    inputBarItems.append(UIBarButtonItem(image: UIImage(systemName: "italic"), primaryAction: UIAction { [textView] _ in
      let currentSelectedRange = textView.selectedRange
      let nextLocation = currentSelectedRange.upperBound + 1
      textView.textStorage.replaceCharacters(in: NSRange(location: currentSelectedRange.upperBound, length: 0), with: "_")
      textView.textStorage.replaceCharacters(in: NSRange(location: currentSelectedRange.location, length: 0), with: "_")
      textView.selectedRange = NSRange(location: nextLocation, length: 0)
    }))

    inputBarItems.append(UIBarButtonItem(image: UIImage(systemName: "text.quote"), primaryAction: UIAction { [textView, textStorage] _ in
      let nodePath = textStorage.storage.path(to: textView.selectedRange.location)
      if let blockQuote = nodePath.first(where: { $0.node.type == .blockquote }) {
        textStorage.replaceCharacters(in: NSRange(location: blockQuote.range.location, length: 2), with: "")
        textView.selectedRange = NSRange(location: textView.selectedRange.location - 2, length: textView.selectedRange.length)
      } else if let paragraph = nodePath.first(where: { $0.node.type == .paragraph }) {
        textStorage.replaceCharacters(in: NSRange(location: paragraph.range.location, length: 0), with: "> ")
        textView.selectedRange = NSRange(location: textView.selectedRange.location + 2, length: 0)
      }
    }))

    inputBarItems.append(UIBarButtonItem(title: "tl;dr:", image: nil, primaryAction: UIAction { [textView, textStorage] _ in
      let nodePath = textStorage.storage.path(to: textView.selectedRange.location)
      if let paragraph = nodePath.first(where: { $0.node.type == .paragraph }) {
        textStorage.replaceCharacters(in: NSRange(location: paragraph.range.location, length: 0), with: "tl;dr: ")
        textView.selectedRange = NSRange(location: textView.selectedRange.location + 7, length: 0)
      } else {
        textStorage.replaceCharacters(in: NSRange(location: textView.selectedRange.location, length: 0), with: "tl;dr: ")
        textView.selectedRange = NSRange(location: textView.selectedRange.location + 7, length: 0)
      }
    }))

    inputBarItems.append(UIBarButtonItem(image: UIImage(systemName: "list.bullet"), primaryAction: UIAction { [textView, textStorage] _ in
      let nodePath = textStorage.storage.path(to: max(0, textView.selectedRange.location - 1))
      let existingSelectedLocation = textView.selectedRange.location
      if let existingListItem = nodePath.first(where: { $0.node.type == .listItem }) {
        textStorage.replaceCharacters(in: NSRange(location: existingListItem.range.location, length: 2), with: "")
        textView.selectedRange = NSRange(location: existingSelectedLocation - 2, length: textView.selectedRange.length)
      } else {
        let lineRange = self.lineRange(at: existingSelectedLocation)
        textStorage.replaceCharacters(in: NSRange(location: lineRange.location, length: 0), with: "* ")
        textView.selectedRange = NSRange(location: existingSelectedLocation + 2, length: 0)
      }
    }))

    var importActions = WebImporterConfiguration.shared.map { config in
      UIAction(title: config.title, image: config.image, handler: { [weak self] _ in
        guard let self = self else { return }
        let webViewController = WebScrapingViewController(initialURL: config.initialURL, javascript: config.importJavascript)
        webViewController.delegate = self
        let navigationController = UINavigationController(rootViewController: webViewController)
        navigationController.navigationBar.tintColor = .grailTint
        self.present(navigationController, animated: true, completion: nil)
      })
    }
    if let apiKey = ApiKey.googleBooks, !apiKey.isEmpty {
      importActions.append(UIAction(title: "Search Google Books", image: UIImage(systemName: "text.book.closed"), handler: { [weak self] _ in
        self?.insertBookDetails(apiKey: apiKey)
      }))
    }

    if !importActions.isEmpty {
      inputBarItems.append(UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"), menu: UIMenu(children: importActions)))
    }

    let inputBar = UIToolbar(frame: .zero)
    inputBar.items = inputBarItems
    inputBar.sizeToFit()
    inputBar.tintColor = .grailTint
    textView.inputAccessoryView = inputBar
  }

  /// If true, the text view will become first responder upon becoming visible.
  public var autoFirstResponder = false

  override public func viewWillAppear(_ animated: Bool) {
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

  override public func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    delegate?.textEditViewControllerDidClose(self)
  }

  override public func viewWillLayoutSubviews() {
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
    let nodePath = textStorage.storage.path(to: textView.selectedRange.location - 1)
    guard
      let selectedHashtag = typeaheadAccessory?.dataSource.itemIdentifier(for: indexPath),
      let hashtagNode = nodePath.first(where: { $0.node.type == .hashtag })
    else {
      return
    }
    textView.textStorage.replaceCharacters(in: hashtagNode.range, with: selectedHashtag)
    textView.selectedRange = NSRange(location: hashtagNode.range.location + selectedHashtag.utf16.count, length: 0)
    typeaheadAccessory = nil
  }
}

// MARK: - UITextViewDelegate

extension TextEditViewController: UITextViewDelegate {
  func replaceCharacters(in range: NSRange, with str: String) {
    textStorage.replaceCharacters(in: range, with: str)
    textView.selectedRange = NSRange(location: range.location + str.count, length: 0)
  }

  public func textViewDidChangeSelection(_ textView: UITextView) {
    // the cursor moved. If there's a hashtag view controller, see if we've strayed from its hashtag.
    let nodePath = textStorage.storage.path(to: textView.selectedRange.location - 1)
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
    let nodePath = textStorage.storage.path(to: textView.selectedRange.location - 1)
    if let hashtagNode = nodePath.first(where: { $0.node.type == .hashtag }) {
      let hashtag = String(utf16CodeUnits: textStorage.storage[hashtagNode.range], count: hashtagNode.range.length)
      let suggestions = delegate?.testEditViewController(self, hashtagSuggestionsFor: hashtag) ?? []
      if suggestions.isEmpty { typeaheadAccessory = nil }
      let typeaheadInfo = makeTypeaheadAccessoryIfNecessary(anchoredAt: hashtagNode.range.location)
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

    // Right now we only do special processing when inserting a newline
    guard range.length == 0, text == "\n" else { return true }
    let nodePath = textStorage.storage.path(to: range.location)
    if let listItem = nodePath.first(where: { $0.node.type == .listItem }) {
      if let paragraph = listItem.first(where: { $0.type == .paragraph }) {
        let paragraphText = textStorage.storage[paragraph.range]
        if String(utf16CodeUnits: paragraphText, count: paragraphText.count).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          // List termination! Someone's hitting return on a list item that contains nothing.
          // Erase this marker.
          replaceCharacters(
            in: NSRange(
              location: listItem.startIndex,
              length: listItem.node.length
            ),
            with: "\n"
          )
          return false
        }
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
          let chars = textStorage.storage[NSRange(location: listNumberNode.startIndex, length: listNumberNode.node.length)]
          let string = String(utf16CodeUnits: chars, count: chars.count)
          listNumber = Int(string) ?? 0
        } else {
          listNumber = 0
        }
        replaceCharacters(in: range, with: "\n\(listNumber + 1). ")
      }
      return false
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
  }

  /// Gets the line of text that contains a given location.
  private func line(at location: Int) -> String {
    let nsstring = textStorage.string as NSString
    let lineRange = nsstring.lineRange(for: NSRange(location: location, length: 0))
    return nsstring.substring(with: lineRange)
  }

  private func lineRange(at location: Int) -> NSRange {
    (textStorage.string as NSString).lineRange(for: NSRange(location: location, length: 0))
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

  func insertBookDetails(apiKey: String) {
    let bookViewController = BookSearchViewController(apiKey: apiKey)
    bookViewController.delegate = self
    bookViewController.title = "Insert Book Details"
    let navigationController = UINavigationController(rootViewController: bookViewController)
    navigationController.navigationBar.tintColor = .grailTint
    present(navigationController, animated: true, completion: nil)
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

// MARK: - BookSearchViewControllerDelegate

extension TextEditViewController: BookSearchViewControllerDelegate {
  public func bookSearchViewController(_ viewController: BookSearchViewController, didSelect book: Book) {
    var imageKey: String?
    if let image = book.coverImage, let imageData = image.jpegData(compressionQuality: 0.8) {
      imageKey = try? imageStorage.storeImageData(imageData, type: .jpeg)
    }
    var markdown = book.markdownTitle
    if let imageKey = imageKey {
      markdown += "\n\n![](\(imageKey))\n\n"
    }
    textView.textStorage.replaceCharacters(in: selectedRange, with: markdown)
    dismiss(animated: true, completion: nil)
  }

  public func bookSearchViewControllerDidCancel(_ viewController: BookSearchViewController) {
    dismiss(animated: true, completion: nil)
  }
}
