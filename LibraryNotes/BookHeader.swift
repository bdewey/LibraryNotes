// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import os
import UIKit

private extension Logger {
  @MainActor
  static let bookHeader = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "BookHeader")
}

@MainActor
protocol BookHeaderDelegate: AnyObject {
  func bookHeader(_ bookHeader: BookHeader, didUpdate book: AugmentedBook)
}

/// Displays information about a book, intended to be used as a scrollaway header when looking at book notes.
final class BookHeader: UIView {
  init(book: AugmentedBook, coverImage: UIImage? = nil) {
    self.book = book
    self.coverImageView = UIImageView(image: coverImage)
    coverImageView.contentMode = .scaleAspectFit
    super.init(frame: UIScreen.main.bounds)
    preservesSuperviewLayoutMargins = true
    backgroundColor = .grailBackground
    titleLabel.text = book.title
    authorLabel.text = book.authors.joined(separator: ", ")
    tagsLabel.text = book.tags?.joined(separator: ", ")

    [
      titleLabel,
      authorLabel,
      starRatingView,
      tagsLabel,
      readingStatusLabel,
      readingHistoryButton,
      coverImageView,
    ].forEach(addSubview)
    configureReadingHistoryButton()
  }

  weak var delegate: BookHeaderDelegate?

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let coverImageView: UIImageView
  private var book: AugmentedBook {
    didSet {
      configureReadingHistoryButton()
      delegate?.bookHeader(self, didUpdate: book)
    }
  }

  private let titleLabel: UILabel = {
    let label = UILabel()
    label.font = .preferredFont(forTextStyle: .title1)
    label.textColor = .label
    label.numberOfLines = 0
    label.accessibilityIdentifier = "book-header-title"
    return label
  }()

  private let authorLabel: UILabel = {
    let label = UILabel()
    label.font = .preferredFont(forTextStyle: .subheadline)
    label.textColor = .secondaryLabel
    label.accessibilityIdentifier = "book-header-author"
    return label
  }()

  private lazy var starRatingView: StarRatingView = {
    let view = StarRatingView(frame: .zero)
    view.rating = book.rating ?? 0
    view.delegate = self
    return view
  }()

  private let tagsLabel: UILabel = {
    let label = UILabel()
    label.font = .preferredFont(forTextStyle: .caption1)
    label.textColor = .secondaryLabel
    return label
  }()

  private let readingStatusLabel: UILabel = {
    let label = UILabel()
    label.font = .preferredFont(forTextStyle: .caption1)
    label.textColor = .secondaryLabel
    return label
  }()

  private lazy var readingHistoryButton: UIButton = {
    let button = UIButton(type: .system, primaryAction: UIAction(handler: { [weak self] _ in
      guard let self else { return }
      if self.book.readingHistory?.isCurrentlyReading ?? false {
        self.finishReading()
      } else {
        self.startReading()
      }
      self.setNeedsLayout()
    }))
    return button
  }()

  private func configureReadingHistoryButton() {
    if book.readingHistory?.isCurrentlyReading ?? false {
      readingHistoryButton.setTitle("Finish reading", for: .normal)
    } else if book.readingHistory?.entries.isEmpty ?? true {
      readingHistoryButton.setTitle("Start reading", for: .normal)
    } else {
      readingHistoryButton.setTitle("Start rereading", for: .normal)
    }
    readingStatusLabel.text = book.readingHistory?.currentReadingStatus
  }

  private func startReading() {
    let now = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    if book.readingHistory != nil {
      book.readingHistory!.startReading(startDate: now)
    } else {
      var readingHistory = ReadingHistory()
      readingHistory.startReading(startDate: now)
      book.readingHistory = readingHistory
    }
  }

  private func finishReading() {
    let today = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    if book.readingHistory != nil {
      book.readingHistory!.finishReading(finishDate: today)
    } else {
      var readingHistory = ReadingHistory()
      readingHistory.finishReading(finishDate: today)
      book.readingHistory = readingHistory
    }
  }

  private lazy var padding: CGFloat = ceil(authorLabel.font.lineHeight * 0.5)

  private let imageWidthFraction = 0.25

  override func layoutSubviews() {
    super.layoutSubviews()
    let frames = makeLayoutFrames(bounds: bounds)
    coverImageView.frame = frames.coverImageView
    Logger.bookHeader.trace("BookHeader.layoutSubviews bounds = \(self.bounds.debugDescription), coverImageView = \(frames.coverImageView.debugDescription)")
    titleLabel.frame = frames.titleLabel
    authorLabel.frame = frames.authorLabel
    starRatingView.frame = frames.starRatingView
    readingHistoryButton.frame = frames.readingHistoryButton
    readingStatusLabel.frame = frames.readingStatusLabel
    tagsLabel.frame = frames.tagsLabel
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    // TODO: Compute this for real
    let frames = makeLayoutFrames(bounds: CGRect(origin: .zero, size: size))
    var result = size
    result.height = max(frames.imageColumnHeight, frames.infoColumnHeight)
    assert(result.height != .infinity)
    Logger.bookHeader.trace("BookHeader.sizeThatFits constraining size = \(size.debugDescription) height = \(result.height)")
    return result
  }

  private struct LayoutFrames {
    var coverImageView: CGRect = .zero
    var titleLabel: CGRect = .zero
    var authorLabel: CGRect = .zero
    var starRatingView: CGRect = .zero
    var readingHistoryButton: CGRect = .zero
    var readingStatusLabel: CGRect = .zero
    var tagsLabel: CGRect = .zero
    var imageColumnHeight: CGFloat = 0
    var infoColumnHeight: CGFloat = 0

    /// Returns whether all of the layout frames are contained in `bounds`.
    @MainActor
    func areContained(in bounds: CGRect) -> Bool {
      let keyPaths: [KeyPath<LayoutFrames, CGRect>] = [
        \.coverImageView,
        \.titleLabel,
        \.authorLabel,
        \.starRatingView,
        \.readingHistoryButton,
        \.readingStatusLabel,
        \.tagsLabel,
      ]
      var invalidFrames: [CGRect] = []
      for keyPath in keyPaths {
        let frame = self[keyPath: keyPath]
        if frame.origin.x == .infinity || frame.origin.y == .infinity || frame.size.height == .infinity || frame.size.width == .infinity {
          Logger.bookHeader.error("Invalid frame \(frame.debugDescription) has infinite dimension")
          invalidFrames.append(frame)
        }
        if !bounds.contains(frame) {
          Logger.bookHeader.error("Invalid frame \(frame.debugDescription) is not contained in \(bounds.debugDescription)")
          invalidFrames.append(frame)
        }
      }
      return invalidFrames.isEmpty
    }
  }

  /// The minimum X coordinate of the content in `BookHeader`
  var minimumTextX: CGFloat = 0 {
    didSet {
      setNeedsLayout()
    }
  }

  private func makeLayoutFrames(bounds: CGRect) -> LayoutFrames {
    var layoutArea = bounds
    var frames = LayoutFrames()
    layoutArea.origin.y += padding
    layoutArea.size.height -= 2 * padding

    // Trim the layout area horizontally to put content in an area no wider than readableContentGuide.layoutFrame.width
    let contentWidth = min(readableContentGuide.layoutFrame.width, layoutArea.width)
    layoutArea.origin.x += (layoutArea.width - contentWidth) / 2
    layoutArea.size.width = contentWidth
    assert(bounds.contains(layoutArea))

    if let imageSize = coverImageView.image?.size, imageSize.width > 0, imageSize.height > 0 {
      let imageWidth = ceil(layoutArea.width * imageWidthFraction)
      (frames.coverImageView, layoutArea) = layoutArea.divided(atDistance: imageWidth, from: .minXEdge)
      frames.coverImageView.size.height = min(imageWidth * (imageSize.height / imageSize.width), layoutArea.height)
      let originAdjustment = titleLabel.font.ascender - titleLabel.font.capHeight
      frames.coverImageView.origin.y += originAdjustment
      frames.coverImageView.size.height -= originAdjustment
      assert(bounds.contains(frames.coverImageView))
      layoutArea = layoutArea.inset(by: .left(padding))
    }
    assert(bounds.contains(layoutArea))
    layoutArea = layoutArea.inset(by: .left(max(0, minimumTextX - layoutArea.minX)))
    assert(bounds.contains(layoutArea))
    let titleSize = titleLabel.sizeThatFits(layoutArea.size)
    (frames.titleLabel, layoutArea) = layoutArea.divided(atDistance: titleSize.height, from: .minYEdge)
    layoutArea = layoutArea.inset(by: .top(padding))
    let authorSize = authorLabel.sizeThatFits(layoutArea.size)
    (frames.authorLabel, layoutArea) = layoutArea.divided(atDistance: authorSize.height, from: .minYEdge)
    layoutArea = layoutArea.inset(by: .top(padding))
    let starSize = starRatingView.systemLayoutSizeFitting(layoutArea.size)
    (frames.starRatingView, layoutArea) = layoutArea.divided(atDistance: starSize.height, from: .minYEdge)
    frames.starRatingView.size.width = min(starSize.width, layoutArea.width)

    // Now go from the bottom
    let buttonSize = readingHistoryButton.sizeThatFits(layoutArea.size)
    (frames.readingHistoryButton, layoutArea) = layoutArea.divided(atDistance: buttonSize.height, from: .maxYEdge)
    frames.readingHistoryButton.size.width = min(buttonSize.width, layoutArea.width)
    layoutArea = layoutArea.inset(by: .bottom(padding))

    let readLabelSize = readingStatusLabel.sizeThatFits(layoutArea.size)
    (frames.readingStatusLabel, layoutArea) = layoutArea.divided(atDistance: readLabelSize.height, from: .maxYEdge)
    layoutArea = layoutArea.inset(by: .bottom(padding))

    let tagsLabelSize = tagsLabel.sizeThatFits(layoutArea.size)
    (frames.tagsLabel, layoutArea) = layoutArea.divided(atDistance: tagsLabelSize.height, from: .maxYEdge)
    layoutArea = layoutArea.inset(by: .bottom(padding))

    frames.imageColumnHeight = frames.coverImageView.maxY + padding
    frames.infoColumnHeight = (frames.readingHistoryButton.maxY - layoutArea.height) + padding

    assert(frames.areContained(in: bounds))
    return frames
  }

  override func layoutMarginsDidChange() {
    setNeedsLayout()
  }
}

extension BookHeader: StarRatingViewDelegate {
  func starRatingView(_ view: StarRatingView, didChangeRating rating: Int) {
    book.rating = rating
  }
}

extension ReadingHistory {
  var currentReadingStatus: String? {
    guard let entries else { return nil }
    var yearRead: Int?
    for entry in entries {
      if let finishDateComponents = entry.finish {
        yearRead = [yearRead, finishDateComponents.year].compactMap { $0 }.max()
      } else {
        return "Currently reading"
      }
    }
    if let yearRead {
      return "Read in \(yearRead)"
    } else {
      return nil
    }
  }
}

private extension UIEdgeInsets {
  static func top(_ value: CGFloat) -> UIEdgeInsets {
    UIEdgeInsets(top: value, left: 0, bottom: 0, right: 0)
  }

  static func bottom(_ value: CGFloat) -> UIEdgeInsets {
    UIEdgeInsets(top: 0, left: 0, bottom: value, right: 0)
  }

  static func left(_ value: CGFloat) -> UIEdgeInsets {
    UIEdgeInsets(top: 0, left: value, bottom: 0, right: 0)
  }
}
