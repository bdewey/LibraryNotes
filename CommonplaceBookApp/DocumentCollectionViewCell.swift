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
    statusIcon.contentMode = .scaleAspectFit
    self.contentView.addSubview(titleLabel)
    self.contentView.addSubview(detailLabel)
    self.contentView.addSubview(ageLabel)
    self.contentView.addSubview(statusIcon)
    self.contentView.addSubview(divider)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  let titleLabel = UILabel(frame: .zero)
  let detailLabel = UILabel(frame: .zero)
  let ageLabel = UILabel(frame: .zero)
  let statusIcon = UIImageView(frame: .zero)
  var stylesheet: Stylesheet? {
    didSet {
      if let stylesheet = stylesheet {
        self.backgroundColor = stylesheet.colors.surfaceColor
        divider.backgroundColor = stylesheet.colors.onSurfaceColor.withAlphaComponent(0.12)
      }
    }
  }
  private let divider = UIView(frame: .zero)
  private var inkTouchController: MDCInkTouchController!

  override func layoutSubviews() {
    super.layoutSubviews()
    let bounds = self.contentView.bounds
    var layoutRect = bounds.insetBy(dx: 16, dy: 0)
    layoutRect.removeSection(atDistance: 56.0, from: .minXEdge) { (ageSlice) in
      ageLabel.frame = ageSlice.inset(by: UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 16))
    }
    self.divider.frame = layoutRect.divided(atDistance: 1, from: .maxYEdge).slice
    layoutRect.removeSection(atDistance: 24.0, from: .maxXEdge) { (statusIconSlice) in
      statusIcon.frame = statusIconSlice
    }
    titleLabel.sizeToFit()
    layoutRect.removeSection(atDistance: 32.0, from: .minYEdge) { (titleLabelSlice) in
      // Applying an inset to the top to bottom-align the label in the 32-point high slice
      self.titleLabel.frame = titleLabelSlice.inset(
        by: UIEdgeInsets(top: 32.0 - titleLabel.bounds.height, left: 0, bottom: 0, right: 0)
      )
    }
    detailLabel.sizeToFit()
    layoutRect.removeSection(atDistance: 20.0, from: .minYEdge) { (detailLabelSlice) in
      self.detailLabel.frame = detailLabelSlice.inset(
        by: UIEdgeInsets(top: 20.0 - detailLabel.bounds.height, left: 0, bottom: 0, right: 0)
      )
    }
  }
}

extension CGRect {
  mutating func removeSection(
    atDistance distance: CGFloat,
    from edge: CGRectEdge,
    block: (CGRect) -> Void
  ) {
    let division = self.divided(atDistance: distance, from: edge)
    block(division.slice)
    self = division.remainder
  }
}
