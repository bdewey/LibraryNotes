// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

import SnapKit
import UIKit

public final class TextCollectionViewCell: UICollectionViewCell {
  override public init(frame: CGRect) {
    self.textLabel = UILabel(frame: .zero)
    super.init(frame: frame)
    textLabel.frame = contentView.bounds
    contentView.addSubview(textLabel)
    textLabel.snp.makeConstraints { make in
      make.left.equalToSuperview().inset(16)
      make.right.equalToSuperview().inset(16)
      make.top.equalToSuperview().inset(12)
      make.bottom.equalToSuperview().inset(12)
    }
  }

  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public let textLabel: UILabel
}
