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

/// Displays information about a book, intended to be used as a scrollaway header when looking at book notes.
final class BookHeader: UIView {
  init(book: AugmentedBook, coverImage: UIImage? = nil) {
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
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let coverImageView: UIImageView

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

  private lazy var contentStack: UIStackView = {
    let emptySpace = UIView()
    emptySpace.setContentHuggingPriority(.defaultLow, for: .vertical)
    let labelStack = UIStackView(arrangedSubviews: [titleLabel, authorLabel, emptySpace])
    labelStack.axis = .vertical
    labelStack.distribution = .fill
    labelStack.spacing = padding

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
