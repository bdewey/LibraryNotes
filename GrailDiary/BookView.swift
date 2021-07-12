// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import UIKit

public struct BookViewContentConfiguration: UIContentConfiguration {
  public var book: AugmentedBook?
  public var coverImage: UIImage?

  public func makeContentView() -> UIView & UIContentView {
    BookView(configuration: self)
  }

  public func updated(for state: UIConfigurationState) -> BookViewContentConfiguration {
    self
  }
}

public final class BookView: UIView, UIContentView {
  public var configuration: UIContentConfiguration {
    didSet {
      apply(configuration: configuration)
    }
  }

  public init(configuration: BookViewContentConfiguration) {
    self.configuration = configuration
    super.init(frame: UIScreen.main.bounds)
    addSubview(contentStack)
    contentStack.snp.makeConstraints { make in
      make.edges.equalToSuperview().inset(10)
      make.height.lessThanOrEqualTo(200)
    }
    apply(configuration: configuration)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override public func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
    super.systemLayoutSizeFitting(targetSize)
  }

  override public func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
    super.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: horizontalFittingPriority, verticalFittingPriority: verticalFittingPriority)
  }

  private let coverImageView = UIImageView(frame: .zero)

  private let titleLabel: UILabel = {
    let label = UILabel()
    label.font = .preferredFont(forTextStyle: .headline)
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

  private let starRatingView: StarRatingView = {
    let view = StarRatingView(frame: .zero)
    view.isUserInteractionEnabled = false
    return view
  }()

  private let readingStatusLabel: UILabel = {
    let label = UILabel()
    label.font = .preferredFont(forTextStyle: .caption1)
    label.textColor = .secondaryLabel
    return label
  }()

  private lazy var labelStack: UIStackView = {
    let stackView = UIStackView(arrangedSubviews: [
      titleLabel,
      authorLabel,
      starRatingView,
      readingStatusLabel,
    ])
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
    stack.alignment = .top

    coverImageView.setContentHuggingPriority(.required, for: .horizontal)
    return stack
  }()

  private lazy var padding: CGFloat = ceil(authorLabel.font.lineHeight * 0.5)

  private func apply(configuration: UIContentConfiguration) {
    guard let configuration = configuration as? BookViewContentConfiguration else {
      return
    }
    if let image = configuration.coverImage {
      coverImageView.image = image
      coverImageView.snp.remakeConstraints { make in
        make.width.equalTo(100)
        make.height.equalTo(coverImageView.snp.width).multipliedBy(image.size.height / image.size.width)
      }
    } else {
      coverImageView.image = nil
      coverImageView.snp.remakeConstraints { make in
        make.width.equalTo(100)
        make.height.equalTo(0)
      }
    }
    titleLabel.text = configuration.book?.title
    if let year = configuration.book?.originalYearPublished ?? configuration.book?.yearPublished {
      titleLabel.text?.append(" (\(year))")
    }
    authorLabel.text = configuration.book?.authors.joined(separator: ", ")
    starRatingView.rating = configuration.book?.rating ?? 0
    starRatingView.isHidden = starRatingView.rating == 0
    readingStatusLabel.text = configuration.book?.readingHistory?.currentReadingStatus
  }
}
