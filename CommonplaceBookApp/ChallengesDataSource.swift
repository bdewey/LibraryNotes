// Copyright © 2017-present Brian's Brain. All rights reserved.

import CocoaLumberjack
import MaterialComponents
import SDWebImage
import SnapKit
import UIKit

public final class ChallengesDataSource: NSObject {
  public struct Challenge {
    let title: String
    let body: String
    let caption: String
    let trophyURL: URL
    let achieved: Bool

    init(title: String, body: String, caption: String, trophyURL: URL, achieved: Bool) {
      self.title = title
      self.body = body
      self.caption = caption
      self.trophyURL = trophyURL
      self.achieved = achieved
    }
  }

  public weak var collectionView: UICollectionView? {
    didSet {
      collectionView?.register(Card.self, forCellWithReuseIdentifier: Card.reuseIdentifier)
    }
  }

  public var cellWidth: CGFloat = 200.0 {
    didSet {
      collectionView?.reloadData()
    }
  }

  public var challenges: [Challenge] = [] {
    didSet {
      collectionView?.reloadData()
    }
  }
}

extension ChallengesDataSource {
  final class Card: MDCCardCollectionCell {
    static let reuseIdentifier = "ChallengesDataSource.Card"

    override init(frame: CGRect) {
      super.init(frame: frame)
      contentView.addSubview(controlStack)
      controlStack.snp.makeConstraints { make in
        make.edges.equalToSuperview().inset(8)
        self.widthConstraint = make.width.equalTo(targetWidth).constraint
      }
    }

    required init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    var challenge: Challenge! {
      didSet {
        let textColor = challenge.achieved
          ? UIColor(white: 0, alpha: 0.87)
          : UIColor(white: 0, alpha: 0.38)
        titleLabel.attributedText = NSAttributedString(
          string: challenge.title,
          attributes: [
            .font: Stylesheet.hablaEspanol.typographyScheme.headline6,
            .kern: 0.25,
            .foregroundColor: textColor,
          ]
        )
        bodyLabel.attributedText = NSAttributedString(
          string: challenge.body,
          attributes: [
            .font: Stylesheet.hablaEspanol.typographyScheme.body2,
            .kern: 0.25,
            .foregroundColor: textColor,
          ]
        )
        captionLabel.attributedText = NSAttributedString(
          string: challenge.caption,
          attributes: [
            .font: Stylesheet.hablaEspanol.typographyScheme.caption,
            .kern: 0.4,
            .foregroundColor: UIColor(white: 0, alpha: 0.6),
          ]
        )
        imageView.sd_setImage(with: challenge.trophyURL, completed: nil)
        captionLabel.isHidden = !challenge.achieved
        imageView.isHidden = !challenge.achieved
      }
    }

    private var widthConstraint: Constraint!

    var targetWidth: CGFloat = 200.0 {
      didSet {
        widthConstraint.update(offset: targetWidth)
      }
    }

    private lazy var controlStack: UIStackView = {
      let controlStack = UIStackView(arrangedSubviews: [
        titleLabel,
        bodyLabel,
        captionLabel,
        imageView,
      ])
      controlStack.axis = .vertical
      controlStack.spacing = 8
      return controlStack
    }()

    private lazy var titleLabel: UILabel = {
      let titleLabel = UILabel(frame: .zero)
      return titleLabel
    }()

    private lazy var bodyLabel: UILabel = {
      let bodyLabel = UILabel(frame: .zero)
      bodyLabel.font = Stylesheet.hablaEspanol.typographyScheme.body2
      return bodyLabel
    }()

    private lazy var captionLabel: UILabel = {
      let bodyLabel = UILabel(frame: .zero)
      bodyLabel.font = Stylesheet.hablaEspanol.typographyScheme.caption
      return bodyLabel
    }()

    private lazy var imageView: FLAnimatedImageView = {
      let imageView = FLAnimatedImageView()
      imageView.contentMode = .scaleAspectFit
      return imageView
    }()
  }
}

extension ChallengesDataSource: UICollectionViewDataSource {
  public func collectionView(
    _ collectionView: UICollectionView,
    numberOfItemsInSection section: Int
  ) -> Int {
    return challenges.count
  }

  public func collectionView(
    _ collectionView: UICollectionView,
    cellForItemAt indexPath: IndexPath
  ) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: Card.reuseIdentifier,
      for: indexPath
    ) as! Card // swiftlint:disable:this force_cast
    cell.challenge = challenges[indexPath.row]
    cell.targetWidth = cellWidth
    return cell
  }
}
