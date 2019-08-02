// Copyright © 2017-present Brian's Brain. All rights reserved.

import MaterialComponents
import SnapKit
import UIKit

final class DocumentTableViewCell: UITableViewCell {
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)

    let verticalStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
    verticalStack.axis = .vertical
    verticalStack.alignment = .leading
    titleLabel.numberOfLines = 0

    let horizontalStack = UIStackView(arrangedSubviews: [ageLabel, verticalStack])
    horizontalStack.alignment = .center

    contentView.addSubview(horizontalStack)
    contentView.addSubview(divider)
    horizontalStack.snp.makeConstraints { (make) in
      make.edges.equalToSuperview().inset(8)
      make.height.greaterThanOrEqualTo(72)
    }
    ageLabel.snp.makeConstraints { (make) in
      make.width.equalTo(56)
    }
    divider.snp.makeConstraints { (make) in
      make.height.equalTo(1)
      make.width.equalTo(verticalStack.snp.width)
      make.bottom.equalToSuperview()
      make.right.equalToSuperview().inset(8)
    }

    backgroundColor = UIColor.systemBackground
    divider.backgroundColor = UIColor.separator
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  let titleLabel = UILabel(frame: .zero)
  let detailLabel = UILabel(frame: .zero)
  let ageLabel = UILabel(frame: .zero)

  private let divider = UIView(frame: .zero)
}
