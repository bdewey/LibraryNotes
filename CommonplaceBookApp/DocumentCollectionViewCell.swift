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
    self.contentView.addSubview(titleLabel)
    self.contentView.addSubview(statusIcon)
    self.contentView.addSubview(divider)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

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
    let layoutRect = bounds.insetBy(dx: 16, dy: 12)
    let (statusIconSlice, textSlice) = layoutRect.divided(atDistance: 24.0, from: .maxXEdge)
    self.statusIcon.frame = statusIconSlice
    self.titleLabel.frame = textSlice
    self.divider.frame = bounds.divided(atDistance: 1, from: .maxYEdge).slice
  }
}
