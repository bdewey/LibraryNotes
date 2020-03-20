// Copyright © 2017-present Brian's Brain. All rights reserved.

import Combine
import SnapKit
import UIKit

final class DocumentTableViewCell: UITableViewCell {
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)


    contentView.addSubview(labelStack)
    contentView.addSubview(divider)
    remakeLabelStackConstraints()
    divider.snp.makeConstraints { make in
      make.height.equalTo(1)
      make.bottom.equalToSuperview()
      make.left.right.equalToSuperview().inset(20)
    }

    backgroundColor = .grailBackground
    divider.backgroundColor = UIColor.separator
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  var documentModifiedTimestamp: Date? {
    get { documentModifiedTimestampSubject.value }
    set { documentModifiedTimestampSubject.value = newValue }
  }

  let titleLabel = UILabel(frame: .zero)
  let detailLabel = UILabel(frame: .zero)
  var verticalPadding: CGFloat = 20 {
    didSet {
      remakeLabelStackConstraints()
    }
  }

  private lazy var labelStack: UIStackView = {
    let verticalStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
    verticalStack.axis = .vertical
    verticalStack.alignment = .leading
    titleLabel.numberOfLines = 0
    return verticalStack
  }()
  private let divider = UIView(frame: .zero)
  private var documentModifiedTimestampSubject = CurrentValueSubject<Date?, Never>(nil)

  private func remakeLabelStackConstraints() {
    labelStack.snp.remakeConstraints { make in
      make.edges.equalToSuperview().inset(UIEdgeInsets(top: verticalPadding, left: 20, bottom: verticalPadding, right: 20))
    }
  }
}
