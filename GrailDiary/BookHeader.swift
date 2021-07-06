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
    super.init(frame: .zero)
    preservesSuperviewLayoutMargins = true
    backgroundColor = .grailBackground
    titleLabel.text = book.title
    authorLabel.text = book.authors.joined(separator: ", ")

    [
      contentStack,
    ].compactMap { $0 }.forEach(addSubview)

    if let coverImage = coverImage, coverImage.size.height != 0 {
      coverImageView.snp.makeConstraints { make in
        make.width.equalTo(coverImageView.snp.height).multipliedBy(coverImage.size.width / coverImage.size.height)
      }
    }

    contentStack.snp.makeConstraints { make in
      make.top.bottom.equalToSuperview().inset(padding)
      make.right.equalTo(readableContentGuide)
      // TODO: Find a better way to get the value 28 from the formatters
      make.left.equalTo(readableContentGuide).inset(28)
    }
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
    if self.book.readingHistory != nil {
      self.book.readingHistory!.startReading(startDate: now)
    } else {
      var readingHistory = ReadingHistory()
      readingHistory.startReading(startDate: now)
      self.book.readingHistory = readingHistory
    }
  }

  private func finishReading() {
    let today = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    if self.book.readingHistory != nil {
      self.book.readingHistory!.finishReading(finishDate: today)
    } else {
      var readingHistory = ReadingHistory()
      readingHistory.finishReading(finishDate: today)
      self.book.readingHistory = readingHistory
    }
  }

  private lazy var labelStack: UIStackView = {
    let emptySpace = UIView()
    emptySpace.setContentHuggingPriority(.defaultLow, for: .vertical)

    let stackView = UIStackView(arrangedSubviews: [titleLabel, authorLabel, emptySpace, readingStatusLabel, readingHistoryButton])
    stackView.axis = .vertical
    stackView.distribution = .fill
    stackView.alignment = .leading
    stackView.spacing = padding
    return stackView
  }()

  private lazy var contentStack: UIStackView = {
    let stack = UIStackView(arrangedSubviews: [coverImageView, labelStack])
    stack.axis = .horizontal
    stack.spacing = padding

    coverImageView.setContentHuggingPriority(.required, for: .horizontal)
    return stack
  }()

  private lazy var padding: CGFloat = ceil(authorLabel.font.lineHeight * 0.5)

  override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
    let superSize = super.systemLayoutSizeFitting(targetSize)
    let stackSize = contentStack.systemLayoutSizeFitting(targetSize)
    Logger.bookHeader.debug("systemLayoutSize: Super = \(superSize), stack = \(stackSize)")
    return CGSize(width: max(superSize.width, stackSize.width), height: max(superSize.height, stackSize.height))
  }
}

private extension ReadingHistory {
  var currentReadingStatus: String? {
    guard let entries = entries else { return nil }
    var yearRead: Int?
    for entry in entries {
      if let finishDateComponents = entry.finish {
        yearRead = [yearRead, finishDateComponents.year].compactMap({ $0 }).max()
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
