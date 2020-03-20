// Copyright © 2020 Brian's Brain. All rights reserved.

import SnapKit
import UIKit

public final class ButtonCell: UITableViewCell {
  public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    contentView.addSubview(button)
    button.snp.makeConstraints { make in
      make.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20))
    }
    button.addTarget(self, action: #selector(onTap), for: .touchUpInside)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public let button = UIButton(type: .roundedRect)
  public var tapHandler: (() -> Void)?

  @objc private func onTap() {
    tapHandler?()
  }
}
