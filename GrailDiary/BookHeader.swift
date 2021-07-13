// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import Logging
import UIKit

private extension Logger {
  static let bookHeader: Logger = {
    var logger = Logger(label: "org.brians-brain.BookHeader")
    logger.logLevel = .debug
    return logger
  }()
}

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

    [
      titleLabel,
      authorLabel,
      starRatingView,
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
    return label
  }()

  private let authorLabel: UILabel = {
    let label = UILabel()
    label.font = .preferredFont(forTextStyle: .subheadline)
    label.textColor = .secondaryLabel
    return label
  }()

  private lazy var starRatingView: StarRatingView = {
    let view = StarRatingView(frame: .zero)
    view.rating = book.rating ?? 0
    view.delegate = self
    return view
  }()

  private let readingStatusLabel: UILabel = {
    let label = UILabel()
    label.font = .preferredFont(forTextStyle: .caption1)
    label.textColor = .secondaryLabel
    return label
  }()

  private lazy var readingHistoryButton: UIButton = {
    let button = UIButton(type: .system, primaryAction: UIAction(handler: { [weak self] _ in
      guard let self = self else { return }
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
    titleLabel.frame = frames.titleLabel
    authorLabel.frame = frames.authorLabel
    starRatingView.frame = frames.starRatingView
    readingHistoryButton.frame = frames.readingHistoryButton
    readingStatusLabel.frame = frames.readingStatusLabel
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    // TODO: Compute this for real
    let frames = makeLayoutFrames(bounds: CGRect(origin: .zero, size: size))
    var result = size
    result.height = max(frames.imageColumnHeight, frames.infoColumnHeight)
    return result
  }

  private struct LayoutFrames {
    var coverImageView: CGRect = .zero
    var titleLabel: CGRect = .zero
    var authorLabel: CGRect = .zero
    var starRatingView: CGRect = .zero
    var readingHistoryButton: CGRect = .zero
    var readingStatusLabel: CGRect = .zero
    var imageColumnHeight: CGFloat = 0
    var infoColumnHeight: CGFloat = 0
  }

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

    // Trim the layout area horizontally to fit in the readableContentGuide
    layoutArea.origin.x = max(layoutArea.origin.x, readableContentGuide.layoutFrame.origin.x)
    layoutArea.size.width = min(layoutArea.size.width, readableContentGuide.layoutFrame.size.width)

    if let imageSize = coverImageView.image?.size, imageSize.width > 0, imageSize.height > 0 {
      let imageWidth = ceil(layoutArea.width * imageWidthFraction)
      (frames.coverImageView, layoutArea) = layoutArea.divided(atDistance: imageWidth, from: .minXEdge)
      frames.coverImageView.size.height = imageWidth * (imageSize.height / imageSize.width)
      let originAdjustment = titleLabel.font.ascender - titleLabel.font.capHeight
      frames.coverImageView.origin.y += originAdjustment
      layoutArea = layoutArea.inset(by: .left(padding))
    }
    layoutArea = layoutArea.inset(by: .left(max(0, minimumTextX - layoutArea.minX)))
    let titleSize = titleLabel.sizeThatFits(layoutArea.size)
    (frames.titleLabel, layoutArea) = layoutArea.divided(atDistance: titleSize.height, from: .minYEdge)
    layoutArea = layoutArea.inset(by: .top(padding))
    let authorSize = authorLabel.sizeThatFits(layoutArea.size)
    (frames.authorLabel, layoutArea) = layoutArea.divided(atDistance: authorSize.height, from: .minYEdge)
    layoutArea = layoutArea.inset(by: .top(padding))
    let starSize = starRatingView.systemLayoutSizeFitting(layoutArea.size)
    (frames.starRatingView, layoutArea) = layoutArea.divided(atDistance: starSize.height, from: .minYEdge)
    frames.starRatingView.size.width = starSize.width

    // Now go from the bottom
    let buttonSize = readingHistoryButton.sizeThatFits(layoutArea.size)
    (frames.readingHistoryButton, layoutArea) = layoutArea.divided(atDistance: buttonSize.height, from: .maxYEdge)
    frames.readingHistoryButton.size.width = buttonSize.width
    layoutArea = layoutArea.inset(by: .bottom(padding))

    let readLabelSize = readingStatusLabel.sizeThatFits(layoutArea.size)
    (frames.readingStatusLabel, layoutArea) = layoutArea.divided(atDistance: readLabelSize.height, from: .maxYEdge)
    layoutArea = layoutArea.inset(by: .bottom(padding))

    frames.imageColumnHeight = frames.coverImageView.maxY + padding
    frames.infoColumnHeight = (frames.readingHistoryButton.maxY - layoutArea.height) + padding

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

internal extension ReadingHistory {
  var currentReadingStatus: String? {
    guard let entries = entries else { return nil }
    var yearRead: Int?
    for entry in entries {
      if let finishDateComponents = entry.finish {
        yearRead = [yearRead, finishDateComponents.year].compactMap { $0 }.max()
      } else {
        return "Currently reading"
      }
    }
    if let yearRead = yearRead {
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
