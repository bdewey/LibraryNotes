// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

public final class HashtagCollectionViewCell: UICollectionViewCell {
  public override init(frame: CGRect) {
    self.hashtagLabel = UILabel(frame: .zero)
    super.init(frame: frame)
    hashtagLabel.frame = contentView.bounds
    hashtagLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    contentView.addSubview(hashtagLabel)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public let hashtagLabel: UILabel
}
