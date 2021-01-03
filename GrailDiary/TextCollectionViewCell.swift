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
