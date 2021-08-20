// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import Combine
import Logging
import SnapKit
import TextMarkupKit
import UIKit

public struct AttributedQuote: Identifiable, Hashable {
  public var id: String { "\(noteId):\(key)" }
  public var noteId: String
  public var key: String
  public var text: String
  public var title: String
  public var thumbnailImage: Data?

  public static func == (lhs: AttributedQuote, rhs: AttributedQuote) -> Bool {
    return lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

/// Displays a list of quotes.
public final class QuotesViewController: UIViewController {
  public init(database: NoteDatabase) {
    self.database = database
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let database: NoteDatabase
  private var quoteSubscription: AnyCancellable?

  /// This is the set of *all* eligible quote identifiers ot show. We will show a subset of these.
  public var quoteIdentifiers: [ContentIdentifier] = [] {
    didSet {
      shuffleQuotes()
    }
  }

  /// This is the set of *visible* quote identifiers -- a randomly selected subset from `quoteIdentifiers`
  private var visibleQuoteIdentifiers: [ContentIdentifier] = [] {
    willSet {
      quoteSubscription = nil
    }
    didSet {
      do {
        try updateSnapshot(with: database.attributedQuotes(for: visibleQuoteIdentifiers))
      } catch {
        Logger.shared.error("Unexpected error fetching quotes: \(error)")
      }
    }
  }

  /// Updates the collection view given quotes.
  private func updateSnapshot(with quotes: [AttributedQuote]) {
    var snapshot = NSDiffableDataSourceSnapshot<Int, AttributedQuote>()
    snapshot.appendSections([0])
    snapshot.appendItems(quotes.shuffled())
    dataSource.apply(snapshot, animatingDifferences: dataSource.snapshot().numberOfItems > 0)
  }

  private lazy var layout: UICollectionViewLayout = {
    var config = UICollectionLayoutListConfiguration(appearance:
      .plain
    )
    config.showsSeparators = false
    config.backgroundColor = .grailBackground
    return UICollectionViewCompositionalLayout.list(using: config)
  }()

  private lazy var collectionView: UICollectionView = {
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    collectionView.delegate = self
    collectionView.backgroundColor = .grailBackground
    return collectionView
  }()

  private lazy var dataSource: UICollectionViewDiffableDataSource<Int, AttributedQuote> = {
    let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, AttributedQuote> { cell, _, quote in
      cell.contentConfiguration = QuoteContentConfiguration(quote: quote)
      cell.backgroundConfiguration = UIBackgroundConfiguration.clear()
    }
    let dataSource = UICollectionViewDiffableDataSource<Int, AttributedQuote>(collectionView: collectionView) { collectionView, indexPath, quote in
      collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: quote)
    }
    return dataSource
  }()

  // MARK: - View lifecycle

  override public func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .grailBackground

    let shuffleButton = UIBarButtonItem(image: UIImage(systemName: "shuffle"), style: .plain, target: self, action: #selector(shuffleQuotes))
    navigationItem.rightBarButtonItem = shuffleButton

    [
      collectionView,
    ].forEach(view.addSubview)

    collectionView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
  }

  @objc private func shuffleQuotes() {
    visibleQuoteIdentifiers = Array(quoteIdentifiers.shuffled().prefix(5))
  }
}

// MARK: - NotebookSecondaryViewController

extension QuotesViewController: NotebookSecondaryViewController {
  private struct ViewControllerState: Codable {
    let title: String?
    let quoteIdentifiers: [ContentIdentifier]
  }

  public static var notebookDetailType: String { "QuotesViewController" }

  public var shouldShowWhenCollapsed: Bool { true }

  private var currentViewControllerState: ViewControllerState {
    ViewControllerState(title: title, quoteIdentifiers: quoteIdentifiers)
  }

  public func userActivityData() throws -> Data {
    try JSONEncoder().encode(currentViewControllerState)
  }

  public static func makeFromUserActivityData(data: Data, database: NoteDatabase, coverImageCache: CoverImageCache) throws -> QuotesViewController {
    let quoteVC = QuotesViewController(database: database)
    let viewControllerState = try JSONDecoder().decode(ViewControllerState.self, from: data)
    quoteVC.quoteIdentifiers = viewControllerState.quoteIdentifiers
    quoteVC.title = viewControllerState.title
    return quoteVC
  }
}

// MARK: - UICollectionViewDelegate

extension QuotesViewController: UICollectionViewDelegate {
  public func collectionView(
    _ collectionView: UICollectionView,
    contextMenuConfigurationForItemAt indexPath: IndexPath,
    point: CGPoint
  ) -> UIContextMenuConfiguration? {
    guard let content = dataSource.itemIdentifier(for: indexPath) else { return nil }
    let cellFrame = collectionView.cellForItem(at: indexPath)?.frame ?? CGRect(origin: point, size: .zero)
    let viewNoteAction = UIAction(title: "View Book", image: UIImage(systemName: "book")) { [notebookViewController] _ in
      notebookViewController?.pushNote(with: content.noteId, selectedText: content.text, autoFirstResponder: true)
    }
    let shareQuoteAction = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
      self?.shareQuote(quote: content, sourceFrame: cellFrame)
    }
    return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
      UIMenu(title: "", children: [viewNoteAction, shareQuoteAction])
    }
  }

  private func shareQuote(quote: AttributedQuote, sourceFrame: CGRect) {
    let configuration = QuoteContentConfiguration(quote: quote)
    let view = configuration.makeContentView()
    let backgroundView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 600, height: 100)))
    backgroundView.backgroundColor = .grailBackground
    backgroundView.addSubview(view)
    view.snp.makeConstraints { make in
      make.edges.equalToSuperview().inset(8)
    }
    backgroundView.layoutIfNeeded()
    let size = backgroundView.systemLayoutSizeFitting(CGSize(width: 600, height: CGFloat.greatestFiniteMagnitude))
    backgroundView.frame = CGRect(origin: .zero, size: size)
    let renderer = UIGraphicsImageRenderer(size: backgroundView.bounds.size)
    let image = renderer.image { _ in
      backgroundView.drawHierarchy(in: backgroundView.bounds, afterScreenUpdates: true)
    }

    // TODO: copypasta
    let (formattedQuote, _) = ParsedAttributedString(
      string: String(quote.text.withTypographySubstitutions.strippingLeadingAndTrailingWhitespace),
      style: .plainText(textStyle: .body, fontDesign: .serif)
    ).decomposedChapterAndVerseAnnotation

    let activityViewController = UIActivityViewController(activityItems: [image, formattedQuote.string], applicationActivities: nil)
    let popover = activityViewController.popoverPresentationController
    popover?.sourceView = view
    popover?.sourceRect = sourceFrame
    present(activityViewController, animated: true, completion: nil)
  }
}

// MARK: - Private

private struct QuoteContentConfiguration: UIContentConfiguration {
  let quote: AttributedQuote

  func makeContentView() -> UIView & UIContentView {
    QuoteView(configuration: self)
  }

  func updated(for state: UIConfigurationState) -> QuoteContentConfiguration {
    self
  }
}

private final class QuoteView: UIView, UIContentView {
  var configuration: UIContentConfiguration {
    didSet {
      apply(configuration: configuration)
    }
  }

  init(configuration: QuoteContentConfiguration) {
    self.configuration = configuration
    super.init(frame: .zero)

    let textStack = UIStackView(arrangedSubviews: [quoteLabel, attributionLabel])
    textStack.axis = .vertical
    textStack.spacing = 16

    let stack = UIStackView(arrangedSubviews: [coverImageView, textStack])
    stack.axis = .horizontal
    stack.distribution = .fillProportionally
    stack.alignment = .top
    stack.spacing = 8

    let quoteBackground = UIView(frame: .zero)
    quoteBackground.addSubview(stack)

    [
      quoteBackground,
    ].forEach(addSubview)

    quoteBackground.snp.makeConstraints { make in
      make.top.equalToSuperview().inset(24)
      make.bottom.equalToSuperview().inset(24)
      make.left.right.equalTo(readableContentGuide).inset(8)
    }

    stack.snp.makeConstraints { make in
      make.edges.equalToSuperview().inset(8)
    }

    apply(configuration: configuration)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let quoteLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return label
  }()

  private let attributionLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    return label
  }()

  private let coverImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFit
    imageView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    return imageView
  }()

  private func apply(configuration: UIContentConfiguration) {
    guard let quoteContentConfiguration = configuration as? QuoteContentConfiguration else {
      return
    }
    let (formattedQuote, attributionFragment) = ParsedAttributedString(
      string: String(quoteContentConfiguration.quote.text.withTypographySubstitutions.strippingLeadingAndTrailingWhitespace),
      style: .plainText(textStyle: .body, fontDesign: .serif)
    ).decomposedChapterAndVerseAnnotation
    quoteLabel.attributedText = formattedQuote

    // Try to line up the top of the capheight of the quote with the top of any image that appears in the cell
    let attributes = formattedQuote.attributes(at: 0, effectiveRange: nil)
    let lineHeightMultiple = attributes.lineHeightMultiple
    if lineHeightMultiple > 0 {
      let font = attributes.font
      let firstLineExtraHeight = (lineHeightMultiple - 1) * font.lineHeight
      let ascenderCapHeightDelta = font.ascender - font.capHeight
      quoteLabel.superview?.transform = CGAffineTransform(translationX: 0, y: -(firstLineExtraHeight + ascenderCapHeightDelta))
    } else {
      quoteLabel.superview?.transform = .identity
    }

    // Strip the opening & closing parenthesis of attributionFragment
    let trimmedFragment = attributionFragment
      .strippingLeadingAndTrailingWhitespace
      .dropFirst()
      .dropLast()
    if trimmedFragment.split(separator: " ").count > 1 {
      // It looks like the attribution fragment is more than one word. Use that exclusively as the attribution.
      attributionLabel.attributedText = ParsedAttributedString(string: String(trimmedFragment), style: .plainText(textStyle: .caption1))
    } else {
      let attributionMarkdown = [
        String(quoteContentConfiguration.quote.title.strippingLeadingAndTrailingWhitespace),
        String(trimmedFragment),
      ].filter { !$0.isEmpty }.joined(separator: ", ")
      attributionLabel.attributedText = ParsedAttributedString(string: attributionMarkdown, style: .plainText(textStyle: .caption1))
    }

    if let imageData = quoteContentConfiguration.quote.thumbnailImage, let image = imageData.image(maxSize: 320) {
      coverImageView.isHidden = false
      coverImageView.image = image
      coverImageView.snp.remakeConstraints { make in
        make.width.equalTo(readableContentGuide).multipliedBy(0.25)
        make.height.equalTo(coverImageView.snp.width).multipliedBy(image.size.height / image.size.width)
      }
    } else {
      coverImageView.isHidden = true
    }
  }
}
