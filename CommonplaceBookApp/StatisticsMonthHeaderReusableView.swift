// Copyright © 2018-present Brian's Brain. All rights reserved.

import CollectionViewLayouts
import UIKit

public final class StatisticsMonthHeaderReusableView: UICollectionReusableView {
  override init(frame: CGRect) {
    self.label = UILabel(frame: .zero)
    super.init(frame: frame)
    label.frame = self.bounds
    label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    label.textAlignment = .center
    addSubview(label)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let label: UILabel

  public var date: Date! {
    didSet {
      let string = DateFormatter.formatterWithMonthYear.string(from: date).localizedUppercase
      let attributedString = NSAttributedString(
        string: string,
        attributes: [
          .font: Stylesheet.hablaEspanol.typographyScheme.overline,
          .kern: 2.0,
          .foregroundColor: UIColor(white: 0, alpha: 0.6),
        ]
      )
      label.attributedText = attributedString
    }
  }
}
