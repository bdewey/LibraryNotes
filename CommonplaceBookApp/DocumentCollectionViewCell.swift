// Copyright © 2018 Brian's Brain. All rights reserved.

import CommonplaceBook
import MaterialComponents
import SwipeCellKit
import UIKit

final class DocumentCollectionViewCell: SwipeCollectionViewCell {

  override init(frame: CGRect) {
    super.init(frame: frame)
    inkTouchController = MDCInkTouchController(view: contentView)
    inkTouchController.addInkView()
    stack.frame = self.contentView.bounds
    self.contentView.addSubview(stack)
    self.contentView.addSubview(divider)
    stack.addArrangedSubview(titleLabel)
    stack.addArrangedSubview(statusIcon)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  let stack = UIStackView(frame: .zero)
  let titleLabel = UILabel(frame: .zero)
  let statusIcon = UIImageView(frame: .zero)
  var stylesheet: Stylesheet? {
    didSet {
      if let stylesheet = stylesheet {
        titleLabel.font = stylesheet.typographyScheme.body2
        titleLabel.textColor = stylesheet.colorScheme.onSurfaceColor
        self.backgroundColor = stylesheet.colorScheme.surfaceColor
        divider.backgroundColor = stylesheet.colorScheme.onSurfaceColor.withAlphaComponent(0.12)
      }
    }
  }
  private let divider = UIView(frame: .zero)
  private var inkTouchController: MDCInkTouchController!

  override func layoutSubviews() {
    super.layoutSubviews()
    let bounds = self.contentView.bounds
    self.stack.frame = bounds.insetBy(dx: 16, dy: 12)
    var dividerFrame = bounds
    dividerFrame.origin.y += dividerFrame.size.height - 1
    dividerFrame.size.height = 1
    self.divider.frame = dividerFrame
  }
}
