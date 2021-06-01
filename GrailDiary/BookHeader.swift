// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import UIKit

/// Displays information about a book, intended to be used as a scrollaway header when looking at book notes.
final class BookHeader: UIView {
  init(book: Book, coverImage: UIImage? = nil) {
    if let coverImage = coverImage {
      let imageView = UIImageView(image: coverImage)
      coverImageView = imageView
    } else {
      self.coverImageView = nil
    }

    super.init(frame: .zero)
    preservesSuperviewLayoutMargins = true
    backgroundColor = .clear
    titleLabel.text = book.title
    authorLabel.text = book.authors.joined(separator: ", ")

    [
      background,
      titleLabel,
      authorLabel,
      coverImageView,
    ].compactMap { $0 }.forEach(addSubview)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let background = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
  private let coverImageView: UIImageView?

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

  private let imageWidthPercent: CGFloat = 0.25

  private lazy var padding: CGFloat = ceil(authorLabel.font.lineHeight * 0.5)

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    var size = size
    size.width -= layoutMargins.left + layoutMargins.right
    let imageWidth = ceil(size.width * imageWidthPercent)
    let imageHeight = coverImageView?.image.flatMap { image in imageWidth * image.size.height / image.size.width } ?? 0
    let textWidth = size.width - (imageWidth + padding)
    let titleHeight = titleLabel.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height
    let authorHeight = authorLabel.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height
    return CGSize(
      width: size.width + layoutMargins.left + layoutMargins.right,
      height: max(imageHeight, titleHeight + padding + authorHeight) + 2 * padding
    )
  }

  override func layoutSubviews() {
    background.frame = bounds
    background.frame.origin.y -= 1000
    background.frame.size.height += 1000
    var layoutArea = bounds.inset(by: UIEdgeInsets(top: padding, left: layoutMargins.left, bottom: padding, right: layoutMargins.right))
    if let coverImageView = coverImageView, let image = coverImageView.image {
      let imageWidth = ceil(layoutArea.size.width * imageWidthPercent)
      let imageHeight = imageWidth * image.size.height / image.size.width
      coverImageView.frame = CGRect(origin: layoutArea.origin, size: CGSize(width: imageWidth, height: imageHeight))
      (_, layoutArea) = layoutArea.divided(atDistance: imageWidth + padding, from: .minXEdge)
    }
    let titleHeight = titleLabel.sizeThatFits(CGSize(width: layoutArea.width, height: .greatestFiniteMagnitude)).height
    (titleLabel.frame, layoutArea) = layoutArea.divided(atDistance: titleHeight + padding, from: .minYEdge)
    let authorHeight = authorLabel.sizeThatFits(CGSize(width: layoutArea.width, height: .greatestFiniteMagnitude)).height
    (authorLabel.frame, layoutArea) = layoutArea.divided(atDistance: authorHeight, from: .minYEdge)
  }
}
