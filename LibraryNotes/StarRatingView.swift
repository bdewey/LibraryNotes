// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import SnapKit
import UIKit

public protocol StarRatingViewDelegate: AnyObject {
  func starRatingView(_ view: StarRatingView, didChangeRating rating: Int)
}

public final class StarRatingView: UIView {
  public weak var delegate: StarRatingViewDelegate?

  public var rating = 0 {
    didSet {
      configureUI()
      delegate?.starRatingView(self, didChangeRating: rating)
    }
  }

  override public init(frame: CGRect) {
    super.init(frame: frame)
    let stack = UIStackView(arrangedSubviews: starViews)
    addSubview(stack)
    stack.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    configureUI()
  }

  private lazy var starViews: [UIImageView] = (1 ... 5).map { index in
    let imageView = UIImageView(image: UIImage(systemName: "star")!)
    imageView.tag = index
    imageView.isUserInteractionEnabled = true
    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapStar))
    imageView.addGestureRecognizer(tapGestureRecognizer)
    return imageView
  }

  private func configureUI() {
    (0 ..< rating).forEach { index in
      starViews[index].image = UIImage(systemName: "star.fill")
    }
    (rating ..< starViews.endIndex).forEach { index in
      starViews[index].image = UIImage(systemName: "star")
    }
  }

  @objc private func didTapStar(sender: UITapGestureRecognizer) {
    let newRating = sender.view?.tag ?? 0
    if rating == 1, newRating == 1 {
      // special case to reset rating to zero
      rating = 0
    } else {
      rating = newRating
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
