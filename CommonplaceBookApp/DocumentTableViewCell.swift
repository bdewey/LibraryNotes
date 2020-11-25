//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

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

  @available(*, unavailable)
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
