// Copyright © 2018 Brian's Brain. All rights reserved.

import MaterialComponents
import SwipeCellKit
import UIKit

final class DocumentCollectionViewCell: SwipeCollectionViewCell {

  let titleLabel = UILabel(frame: .zero)
  private let divider = UIView(frame: .zero)
  private var inkTouchController: MDCInkTouchController!

  override init(frame: CGRect) {
    super.init(frame: frame)
    inkTouchController = MDCInkTouchController(view: contentView)
    inkTouchController.addInkView()
    titleLabel.frame = self.contentView.bounds
    let stylesheet = Stylesheet.default
    titleLabel.font = stylesheet.typographyScheme.body2
    titleLabel.textColor = stylesheet.colorScheme.onSurfaceColor
    self.backgroundColor = stylesheet.colorScheme.surfaceColor
    divider.backgroundColor = stylesheet.colorScheme.onSurfaceColor.withAlphaComponent(0.12)
    self.contentView.addSubview(titleLabel)
    self.contentView.addSubview(divider)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let bounds = self.contentView.bounds
    self.titleLabel.frame = bounds.insetBy(dx: 16, dy: 12)
    var dividerFrame = bounds
    dividerFrame.origin.y += dividerFrame.size.height - 1
    dividerFrame.size.height = 1
    self.divider.frame = dividerFrame
  }
}
