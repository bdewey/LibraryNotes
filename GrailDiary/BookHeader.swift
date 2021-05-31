// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import UIKit

final class BookHeader: UIView {
  init(book: Book, coverImage: UIImage? = nil) {
    super.init(frame: .zero)
    preservesSuperviewLayoutMargins = true
    backgroundColor = .grailBackground
    titleLabel.text = book.title
    authorLabel.text = book.authors.joined(separator: ", ")
    let textStack = UIStackView(arrangedSubviews: [titleLabel, authorLabel])
    textStack.axis = .vertical

    let spacingUnit = UIFont.preferredFont(forTextStyle: .subheadline).lineHeight * 0.5
    textStack.spacing = spacingUnit

    let coverImageView: UIView
    if let coverImage = coverImage {
      let imageView = UIImageView(image: coverImage)
      imageView.snp.makeConstraints { make in
        make.width.equalTo(imageView.snp.height).multipliedBy(coverImage.size.width / coverImage.size.height)
        make.height.equalTo(8 * spacingUnit)
      }
      imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
      coverImageView = imageView
    } else {
      let blank = UIView(frame: .zero)
      blank.isHidden = true
      coverImageView = blank
    }

    let stack = UIStackView(arrangedSubviews: [coverImageView, textStack])
    stack.axis = .horizontal
    stack.spacing = 8

    let background = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    [
      background,
      stack,
    ].forEach(addSubview)
    background.snp.makeConstraints { make in
      // Make the top extend beyond the frame for rubber-banding
      make.top.equalToSuperview().inset(-1000)
      make.left.right.bottom.equalToSuperview()
    }
    stack.snp.makeConstraints { make in
      make.left.right.equalTo(layoutMarginsGuide)
      make.top.bottom.equalToSuperview().inset(8)
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
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
}
